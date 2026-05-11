#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "output_with_md5.txt"
EXTRACTED_DIR = ROOT / "generated" / "extracted"
FILTERED_DIR = ROOT / "generated" / "filtered"

DEFAULT_MODEL = os.environ.get("OPENAI_MODEL", "gpt-5.4-mini")
DEFAULT_CODEX_MODEL = os.environ.get("CODEX_MODEL")
MAX_INPUT_CHARS = 60000


SCHEMA = {
    "name": "knowledge_filter",
    "schema": {
        "type": "object",
        "additionalProperties": False,
        "required": ["doc_id", "title", "summary", "sections", "discarded_noise", "tags"],
        "properties": {
            "doc_id": {"type": "string"},
            "title": {"type": "string"},
            "summary": {"type": "string"},
            "tags": {"type": "array", "items": {"type": "string"}},
            "discarded_noise": {"type": "array", "items": {"type": "string"}},
            "sections": {
                "type": "array",
                "items": {
                    "type": "object",
                    "additionalProperties": False,
                    "required": ["heading", "content", "section_type", "tags"],
                    "properties": {
                        "heading": {"type": "string"},
                        "content": {"type": "string"},
                        "section_type": {
                            "type": "string",
                            "enum": ["concept", "procedure", "sql", "config", "warning", "troubleshooting", "reference"],
                        },
                        "tags": {"type": "array", "items": {"type": "string"}},
                    },
                },
            },
        },
    },
    "strict": True,
}


def parse_manifest() -> dict[str, dict]:
    docs = {}
    block = []
    for line in MANIFEST_PATH.read_text(encoding="utf-8").splitlines():
        if line.strip() == "----":
            add_manifest_block(block, docs)
            block = []
        else:
            block.append(line)
    add_manifest_block(block, docs)
    return docs


def add_manifest_block(block: list[str], docs: dict[str, dict]) -> None:
    if len(block) < 3:
        return
    title = block[0].strip()
    url = block[1].strip()
    doc_id = block[2].strip()
    if title and url and re.fullmatch(r"[0-9a-f]{32}", doc_id):
        docs[doc_id] = {
            "doc_id": doc_id,
            "title": title,
            "url": url,
            "source_domain": urlparse(url).netloc.lower(),
        }


def extracted_text_path(doc_id: str) -> Path:
    return EXTRACTED_DIR / doc_id / "full.md"


def filtered_output_path(doc_id: str) -> Path:
    return FILTERED_DIR / doc_id / "knowledge.json"


def build_prompt(doc: dict, text: str) -> str:
    clipped = text[:MAX_INPUT_CHARS]
    return f"""
你是 DBA 知識庫建置助手。請從 PDF 抽出的全文中過濾出真正有知識價值的內容。

任務：
1. 保留可用於 DBA/資料庫工程知識庫的技術內容。
2. 移除廣告、側欄、作者卡片、導覽、推薦閱讀、評論、版權聲明、頁碼、重複頁眉頁腳。
3. 不要捏造原文沒有的內容。
4. 可整理語句，但要保留技術含義、參數、SQL、命令、風險條件。
5. section content 要可直接拆塊進 RAG；避免空泛摘要。

文件資訊：
doc_id: {doc["doc_id"]}
title: {doc.get("title") or ""}
url: {doc.get("url") or ""}

PDF 抽取全文：
{clipped}
""".strip()


def call_openai(prompt: str, model: str) -> dict:
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is required for LLM filtering")

    payload = {
        "model": model,
        "input": [
            {
                "role": "system",
                "content": "Return only valid JSON matching the requested schema. Use Traditional Chinese for summaries and headings when possible.",
            },
            {"role": "user", "content": prompt},
        ],
        "text": {
            "format": {
                "type": "json_schema",
                "name": SCHEMA["name"],
                "schema": SCHEMA["schema"],
                "strict": SCHEMA["strict"],
            }
        },
    }
    request = urllib.request.Request(
        "https://api.openai.com/v1/responses",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            result = json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"OpenAI API error {exc.code}: {body}") from exc

    try:
        text = result["output"][0]["content"][0]["text"]
    except (KeyError, IndexError, TypeError) as exc:
        raise RuntimeError(f"Unexpected OpenAI response shape: {json.dumps(result, ensure_ascii=False)[:1000]}") from exc
    return json.loads(text)


def call_codex(prompt: str, model: str | None) -> dict:
    with tempfile.TemporaryDirectory() as tmp_dir:
        schema_path = Path(tmp_dir) / "schema.json"
        output_path = Path(tmp_dir) / "codex-output.json"
        schema_path.write_text(json.dumps(SCHEMA["schema"], ensure_ascii=False), encoding="utf-8")

        cmd = [
            "codex",
            "exec",
            "--cd",
            str(ROOT),
            "--sandbox",
            "read-only",
            "--output-schema",
            str(schema_path),
            "--output-last-message",
            str(output_path),
            "-",
        ]
        if model:
            cmd[2:2] = ["--model", model]

        proc = subprocess.run(
            cmd,
            input=prompt,
            text=True,
            capture_output=True,
            timeout=300,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"codex exec failed ({proc.returncode}): {proc.stderr or proc.stdout}")
        if not output_path.exists():
            raise RuntimeError("codex exec did not write an output message")
        output_text = output_path.read_text(encoding="utf-8").strip()
        return json.loads(output_text)


def filter_doc(doc: dict, provider: str, model: str | None) -> Path:
    source_path = extracted_text_path(doc["doc_id"])
    if not source_path.exists():
        raise FileNotFoundError(f"Missing extracted text: {source_path.relative_to(ROOT)}. Run make extract_pdf DOC_ID={doc['doc_id']} first.")

    text = source_path.read_text(encoding="utf-8", errors="replace")
    prompt = build_prompt(doc, text)
    if provider == "codex":
        knowledge = call_codex(prompt, model)
        filter_model = model or "codex-default"
    elif provider == "openai":
        knowledge = call_openai(prompt, model or DEFAULT_MODEL)
        filter_model = model or DEFAULT_MODEL
    else:
        raise ValueError(f"Unsupported provider: {provider}")

    knowledge.update({
        "doc_id": doc["doc_id"],
        "url": doc.get("url"),
        "source_domain": doc.get("source_domain"),
        "source_md": str(source_path.relative_to(ROOT)),
        "filter_provider": provider,
        "filter_model": filter_model,
    })

    output_path = filtered_output_path(doc["doc_id"])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(knowledge, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return output_path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Use an LLM to filter extracted PDF text into clean knowledge JSON.")
    parser.add_argument("--doc-id", required=True, help="32-character document id to filter.")
    parser.add_argument("--provider", choices=["codex", "openai"], default=os.environ.get("FILTER_PROVIDER", "codex"))
    parser.add_argument("--model", default=None, help="Model override. Defaults to Codex config for provider=codex, or OPENAI_MODEL/gpt-5.4-mini for provider=openai.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    docs = parse_manifest()
    if args.doc_id not in docs:
        raise SystemExit(f"doc_id not found in manifest: {args.doc_id}")
    output_path = filter_doc(docs[args.doc_id], args.provider, args.model or (DEFAULT_CODEX_MODEL if args.provider == "codex" else DEFAULT_MODEL))
    print(f"filtered -> {output_path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
