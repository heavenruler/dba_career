#!/usr/bin/env python3
import json
import re
from collections import Counter
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "output_with_md5.txt"
COLLECTOR_DIR = ROOT / "collector"
EXTRACTED_DIR = ROOT / "generated" / "extracted"
DATA_DIR = ROOT / "generated" / "kb"
AUDIT_PATH = DATA_DIR / "source_audit.jsonl"
SUMMARY_PATH = DATA_DIR / "source_audit_summary.json"


def parse_manifest() -> tuple[dict[str, dict], Counter]:
    if not MANIFEST_PATH.exists():
        raise FileNotFoundError(f"Missing {MANIFEST_PATH}")

    docs = {}
    doc_id_counts = Counter()
    block = []
    for line in MANIFEST_PATH.read_text(encoding="utf-8").splitlines():
        if line.strip() == "----":
            add_manifest_block(block, docs, doc_id_counts)
            block = []
        else:
            block.append(line)
    add_manifest_block(block, docs, doc_id_counts)
    return docs, doc_id_counts


def add_manifest_block(block: list[str], docs: dict[str, dict], doc_id_counts: Counter) -> None:
    if len(block) < 3:
        return
    title = block[0].strip()
    url = block[1].strip()
    md5 = block[2].strip()
    if title and url and re.fullmatch(r"[0-9a-f]{32}", md5):
        doc_id_counts[md5] += 1
        docs[md5] = {
            "doc_id": md5,
            "title": title,
            "url": url,
            "source_domain": urlparse(url).netloc.lower(),
        }


def collect_pdfs() -> set[str]:
    if not COLLECTOR_DIR.exists():
        return set()
    return {
        path.stem
        for path in COLLECTOR_DIR.glob("*.pdf")
        if re.fullmatch(r"[0-9a-f]{32}", path.stem)
    }


def collect_extracted() -> set[str]:
    if not EXTRACTED_DIR.exists():
        return set()
    return {
        path.name
        for path in EXTRACTED_DIR.iterdir()
        if path.is_dir()
        and re.fullmatch(r"[0-9a-f]{32}", path.name)
        and (path / "full.md").exists()
    }


def build_audit_rows() -> tuple[list[dict], Counter]:
    manifest, manifest_doc_id_counts = parse_manifest()
    pdfs = collect_pdfs()
    extracted = collect_extracted()
    all_doc_ids = sorted(set(manifest) | pdfs | extracted)
    rows = []

    for doc_id in all_doc_ids:
        manifest_record = manifest.get(doc_id)
        has_manifest = manifest_record is not None
        has_pdf = doc_id in pdfs
        has_extracted = doc_id in extracted

        if has_manifest and has_extracted:
            status = "manifest_ok"
        elif has_manifest and has_pdf:
            status = "needs_extraction"
        elif has_manifest:
            status = "missing_pdf"
        elif has_extracted:
            status = "orphan_extracted"
        elif has_pdf:
            status = "orphan_pdf"
        else:
            status = "unknown"

        if has_manifest and not has_pdf:
            pdf_status = "missing_pdf"
        elif has_pdf and not has_manifest:
            pdf_status = "orphan_pdf"
        elif has_pdf:
            pdf_status = "ok"
        else:
            pdf_status = "missing"

        rows.append({
            "doc_id": doc_id,
            "status": status,
            "pdf_status": pdf_status,
            "has_manifest": has_manifest,
            "has_pdf": has_pdf,
            "has_extracted": has_extracted,
            "title": manifest_record["title"] if manifest_record else None,
            "url": manifest_record["url"] if manifest_record else None,
            "source_domain": manifest_record["source_domain"] if manifest_record else None,
            "source_pdf": f"collector/{doc_id}.pdf" if has_pdf else None,
            "source_md": f"generated/extracted/{doc_id}/full.md" if has_extracted else None,
        })

    return rows, manifest_doc_id_counts


def write_jsonl(path: Path, rows: list[dict]) -> None:
    with path.open("w", encoding="utf-8") as file:
        for row in rows:
            file.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def write_summary(path: Path, rows: list[dict], manifest_doc_id_counts: Counter) -> dict:
    status_counts = Counter(row["status"] for row in rows)
    pdf_status_counts = Counter(row["pdf_status"] for row in rows)
    duplicate_manifest_ids = {
        doc_id: count
        for doc_id, count in sorted(manifest_doc_id_counts.items())
        if count > 1
    }
    summary = {
        "total": len(rows),
        "manifest_entries": sum(manifest_doc_id_counts.values()),
        "manifest_unique_doc_ids": len(manifest_doc_id_counts),
        "manifest_duplicate_entries": sum(count - 1 for count in duplicate_manifest_ids.values()),
        "manifest_duplicate_doc_ids": duplicate_manifest_ids,
        "status_counts": dict(sorted(status_counts.items())),
        "pdf_status_counts": dict(sorted(pdf_status_counts.items())),
    }
    path.write_text(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return summary


def main() -> int:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    rows, manifest_doc_id_counts = build_audit_rows()
    write_jsonl(AUDIT_PATH, rows)
    summary = write_summary(SUMMARY_PATH, rows, manifest_doc_id_counts)

    print(f"audit rows: {summary['total']} -> {AUDIT_PATH.relative_to(ROOT)}")
    print(f"summary -> {SUMMARY_PATH.relative_to(ROOT)}")
    for status, count in summary["status_counts"].items():
        print(f"{status}: {count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
