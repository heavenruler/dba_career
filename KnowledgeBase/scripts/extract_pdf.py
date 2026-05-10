#!/usr/bin/env python3
import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "output_with_md5.txt"
COLLECTOR_DIR = ROOT / "collector"
EXTRACTED_DIR = ROOT / "generated" / "extracted"


def parse_manifest() -> list[dict]:
    docs = []
    block = []
    for line in MANIFEST_PATH.read_text(encoding="utf-8").splitlines():
        if line.strip() == "----":
            add_manifest_block(block, docs)
            block = []
        else:
            block.append(line)
    add_manifest_block(block, docs)
    return docs


def add_manifest_block(block: list[str], docs: list[dict]) -> None:
    if len(block) < 3:
        return
    title = block[0].strip()
    url = block[1].strip()
    doc_id = block[2].strip()
    if title and url and re.fullmatch(r"[0-9a-f]{32}", doc_id):
        docs.append({
            "doc_id": doc_id,
            "title": title,
            "url": url,
            "source_domain": urlparse(url).netloc.lower(),
        })


def extract_with_pdftotext(pdf_path: Path) -> str:
    proc = subprocess.run(
        ["pdftotext", "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
        check=True,
        capture_output=True,
        text=True,
    )
    return proc.stdout


def extract_with_python(pdf_path: Path) -> str:
    try:
        from pypdf import PdfReader
    except ImportError:
        try:
            from PyPDF2 import PdfReader
        except ImportError as exc:
            raise RuntimeError("missing PDF extractor: install poppler/pdftotext or pypdf") from exc

    reader = PdfReader(str(pdf_path))
    pages = []
    for index, page in enumerate(reader.pages, start=1):
        text = page.extract_text() or ""
        pages.append(f"\n\n<!-- page:{index} -->\n\n{text}")
    return "\n".join(pages)


def extract_pdf(pdf_path: Path) -> tuple[str, str]:
    if shutil.which("pdftotext"):
        return extract_with_pdftotext(pdf_path), "pdftotext"
    return extract_with_python(pdf_path), "python"


def write_extraction(doc: dict) -> dict:
    doc_id = doc["doc_id"]
    pdf_path = COLLECTOR_DIR / f"{doc_id}.pdf"
    if not pdf_path.exists():
        return {**doc, "status": "missing_pdf", "source_pdf": str(pdf_path.relative_to(ROOT))}

    text, extractor = extract_pdf(pdf_path)
    out_dir = EXTRACTED_DIR / doc_id
    out_dir.mkdir(parents=True, exist_ok=True)
    full_md = out_dir / "full.md"
    metadata_path = out_dir / "metadata.json"

    full_md.write_text(text.strip() + "\n", encoding="utf-8")
    metadata = {
        **doc,
        "status": "ok",
        "extractor": extractor,
        "source_pdf": str(pdf_path.relative_to(ROOT)),
        "source_md": str(full_md.relative_to(ROOT)),
        "char_count": len(text),
    }
    metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract collector PDFs into generated/extracted.")
    parser.add_argument("--doc-id", help="Extract one 32-character document id.")
    parser.add_argument("--all", action="store_true", help="Extract every manifest PDF found in collector.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not args.doc_id and not args.all:
        raise SystemExit("Use --doc-id <md5> or --all")

    docs = parse_manifest()
    if args.doc_id:
        docs = [doc for doc in docs if doc["doc_id"] == args.doc_id]
        if not docs:
            raise SystemExit(f"doc_id not found in manifest: {args.doc_id}")

    results = [write_extraction(doc) for doc in docs]
    ok = sum(1 for result in results if result["status"] == "ok")
    missing = sum(1 for result in results if result["status"] == "missing_pdf")
    print(f"extracted: {ok} -> {EXTRACTED_DIR.relative_to(ROOT)}")
    print(f"missing_pdf: {missing}")
    return 0 if ok or missing else 1


if __name__ == "__main__":
    raise SystemExit(main())
