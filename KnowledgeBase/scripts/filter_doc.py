#!/usr/bin/env python3
import argparse
import json
import os
import re
import subprocess
import tempfile
import urllib.error
import urllib.request
from datetime import datetime
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
你是個人知識庫建置助手。請從 PDF 抽出的全文中過濾出真正有知識價值的內容。

涵蓋範疇（不局限於以下，遇到任一即視為有價值）：
- 技術類：DBA / 資料庫、架構設計、分析設計師、SRE / DevOps / SecOps、平台工程、雲端、可觀測性、效能調優、軟體工程實務
- 人文類：心理學、認知科學、行為經濟、溝通、領導力、決策框架
- 職涯類：職場、面試（system design / behavior / coding）、簡歷、薪資談判、職涯規劃
- 其他：研究方法、學習方法、行業案例、事故覆盤、書摘要點

任務（嚴格遵守 extractive-only 規則）：
1. 任一上述範疇有訊息密度的內容都保留；不要因為「不是 DBA」就丟掉。
2. **section.content 必須是原文逐字片段（extractive）**：
   - 不要改寫、意譯、潤飾、補充說明、加範例、加類比、加結論
   - 不要拼接不相鄰段落；保留原段落結構與順序
   - SQL / 命令 / 參數 / 程式碼 / 數字 / 公式 一字不動照抄（含原本縮排、註解、空白行、行號）
   - 若該段在原文中出現多次（如重複頁眉），只保留一次
3. 移除雜訊：廣告、側欄、作者卡片、導覽、推薦閱讀、評論、版權聲明、頁碼、頁眉頁腳、URL、時間戳、訂閱/打賞引導、無關促銷
4. heading 可由你命名（給每段一個短標題）；summary、tags、discarded_noise 可由你撰寫；除此之外 **content 欄位一律 extractive**
5. 不要捏造原文沒有的內容；找不到對應章節寧可不列、不要硬擠
6. discarded_noise 列出你丟掉的雜訊類型即可（不必逐字引用）
7. tags 反映文件的真實主題（可同時混合上述範疇，例如 ['SRE','事故覆盤','溝通']）

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
    knowledge = json.loads(text)
    return knowledge, {"tokens": result.get("usage") or {}, "rate_limits": None}


def format_openai_usage(usage: dict) -> str:
    tokens = usage.get("tokens") or {}
    inp = tokens.get("input_tokens", 0)
    out = tokens.get("output_tokens", 0)
    total = tokens.get("total_tokens", inp + out)
    return f"tokens  in={inp} out={out} total={total} (OpenAI API；無 5h window 概念，依帳單計費)"


def call_codex(prompt: str, model: str | None) -> tuple[dict, dict]:
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
            "--json",
            "-",
        ]
        if model:
            cmd[2:2] = ["--model", model]

        # codex 在大文件 + reasoning 時可能跑 5–10 分鐘；舊版 300s 對 60K char 偏緊。
        # 可用 env CODEX_TIMEOUT 覆寫（秒）。
        timeout_s = int(os.environ.get("CODEX_TIMEOUT", "900"))
        proc = subprocess.run(
            cmd,
            input=prompt,
            text=True,
            capture_output=True,
            timeout=timeout_s,
        )
        if proc.returncode != 0:
            raise RuntimeError(f"codex exec failed ({proc.returncode}): {proc.stderr or proc.stdout}")
        if not output_path.exists():
            raise RuntimeError("codex exec did not write an output message")

        tokens: dict = {}
        thread_id: str | None = None
        for line in proc.stdout.splitlines():
            try:
                event = json.loads(line)
            except json.JSONDecodeError:
                continue
            etype = event.get("type")
            if etype == "thread.started":
                thread_id = event.get("thread_id")
            elif etype == "turn.completed":
                tokens = event.get("usage") or {}

        rate_limits = read_codex_rate_limits(thread_id) if thread_id else None
        knowledge = json.loads(output_path.read_text(encoding="utf-8").strip())
        return knowledge, {"tokens": tokens, "rate_limits": rate_limits}


def read_codex_rate_limits(thread_id: str) -> dict | None:
    sessions_dir = Path.home() / ".codex" / "sessions"
    if not sessions_dir.exists():
        return None
    for path in sessions_dir.rglob(f"rollout-*-{thread_id}.jsonl"):
        try:
            last = None
            for line in path.read_text(encoding="utf-8").splitlines():
                try:
                    event = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if event.get("type") != "event_msg":
                    continue
                payload = event.get("payload", {})
                if payload.get("type") == "token_count":
                    last = payload.get("rate_limits")
            return last
        except OSError:
            return None
    return None


def format_codex_usage(usage: dict) -> str:
    tokens = usage.get("tokens") or {}
    inp = tokens.get("input_tokens", 0)
    cached = tokens.get("cached_input_tokens", 0)
    out = tokens.get("output_tokens", 0)
    reasoning = tokens.get("reasoning_output_tokens", 0)
    parts = [
        f"tokens  in={inp} (cached={cached}) out={out} reasoning={reasoning} total={inp + out}",
    ]

    limits = usage.get("rate_limits") or {}
    primary = limits.get("primary")
    secondary = limits.get("secondary")
    plan = limits.get("plan_type")
    if primary:
        used = primary.get("used_percent", 0)
        reset = primary.get("resets_at")
        reset_str = datetime.fromtimestamp(reset).strftime("%Y-%m-%d %H:%M") if reset else "?"
        parts.append(f"5h window used={used:.1f}% remaining={100 - used:.1f}% resets@{reset_str}")
    if secondary:
        used = secondary.get("used_percent", 0)
        reset = secondary.get("resets_at")
        reset_str = datetime.fromtimestamp(reset).strftime("%Y-%m-%d %H:%M") if reset else "?"
        parts.append(f"7d window used={used:.1f}% remaining={100 - used:.1f}% resets@{reset_str}")
    if plan:
        parts.append(f"plan={plan}")
    return " | ".join(parts)


def filter_doc(doc: dict, provider: str, model: str | None) -> tuple[Path, dict, str]:
    source_path = extracted_text_path(doc["doc_id"])
    if not source_path.exists():
        raise FileNotFoundError(f"Missing extracted text: {source_path.relative_to(ROOT)}. Run make extract_pdf DOC_ID={doc['doc_id']} first.")

    text = source_path.read_text(encoding="utf-8", errors="replace")
    prompt = build_prompt(doc, text)
    if provider == "codex":
        knowledge, usage = call_codex(prompt, model)
        filter_model = model or "codex-default"
        usage_line = format_codex_usage(usage)
    elif provider == "openai":
        knowledge, usage = call_openai(prompt, model or DEFAULT_MODEL)
        filter_model = model or DEFAULT_MODEL
        usage_line = format_openai_usage(usage)
    else:
        raise ValueError(f"Unsupported provider: {provider}")

    knowledge.update({
        "doc_id": doc["doc_id"],
        "url": doc.get("url"),
        "source_domain": doc.get("source_domain"),
        "source_md": str(source_path.relative_to(ROOT)),
        "filter_provider": provider,
        "filter_model": filter_model,
        "filter_usage": usage,
    })

    output_path = filtered_output_path(doc["doc_id"])
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(knowledge, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return output_path, usage, usage_line


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
    output_path, _usage, usage_line = filter_doc(
        docs[args.doc_id],
        args.provider,
        args.model or (DEFAULT_CODEX_MODEL if args.provider == "codex" else DEFAULT_MODEL),
    )
    print(f"filtered -> {output_path.relative_to(ROOT)}")
    if usage_line:
        print(f"usage     {usage_line}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
