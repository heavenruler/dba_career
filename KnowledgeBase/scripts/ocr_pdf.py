#!/usr/bin/env python3
"""OCR image-only PDFs (avg_chars_per_page < threshold) using tesseract.

Pipeline:
1. Load every metadata.json under generated/extracted/.
2. Pick docs with needs_ocr=true.
3. For each: pdftoppm -r 250 -> tesseract -l chi_sim+chi_tra+eng.
4. Rewrite full.md with frontmatter + per-page OCR text + `<!-- page:N -->`.
5. Update metadata.json with ocr_used=true, ocr_engine, char_count, etc.

Usage:
  python3 scripts/ocr_pdf.py --all              # OCR every needs_ocr doc
  python3 scripts/ocr_pdf.py --doc-id <md5>     # OCR one doc
  python3 scripts/ocr_pdf.py --dry-run          # list targets only
"""
import argparse
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
COLLECTOR_DIR = ROOT / "collector"
EXTRACTED_DIR = ROOT / "generated" / "extracted"

DEFAULT_LANGS = "chi_sim+chi_tra+eng"
DEFAULT_DPI = 250


def yaml_quote(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def build_frontmatter(metadata: dict) -> str:
    keys = [
        "doc_id",
        "title",
        "url",
        "source_domain",
        "sha256",
        "page_count",
        "char_count",
        "avg_chars_per_page",
        "needs_ocr",
        "ocr_used",
        "ocr_engine",
        "extractor",
        "extracted_at",
    ]
    lines = ["---"]
    for key in keys:
        if key not in metadata or metadata[key] is None:
            continue
        value = metadata[key]
        if isinstance(value, bool):
            lines.append(f"{key}: {'true' if value else 'false'}")
        elif isinstance(value, (int, float)):
            lines.append(f"{key}: {value}")
        else:
            lines.append(f"{key}: {yaml_quote(str(value))}")
    lines.append("---")
    return "\n".join(lines) + "\n\n"


def render_pages(pdf_path: Path, dpi: int, work_dir: Path) -> list[Path]:
    prefix = work_dir / "page"
    proc = subprocess.run(
        ["pdftoppm", "-r", str(dpi), "-png", str(pdf_path), str(prefix)],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"pdftoppm failed: {proc.stderr.strip() or proc.stdout.strip()}")
    images = sorted(work_dir.glob("page-*.png"))
    if not images:
        # Some PDFs produce page-NN.png with leading zeros, others just page-1.png
        images = sorted(work_dir.glob("page*.png"))
    return images


def ocr_image(image_path: Path, langs: str) -> str:
    proc = subprocess.run(
        ["tesseract", str(image_path), "-", "-l", langs, "--psm", "6"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise RuntimeError(f"tesseract failed on {image_path.name}: {proc.stderr.strip()}")
    return proc.stdout.rstrip()


def ocr_pdf(pdf_path: Path, metadata: dict, langs: str, dpi: int) -> dict:
    with tempfile.TemporaryDirectory(prefix="ocr-") as tmp:
        tmp_dir = Path(tmp)
        images = render_pages(pdf_path, dpi, tmp_dir)
        if not images:
            raise RuntimeError("pdftoppm produced no images")

        page_chunks: list[str] = []
        per_page_chars: list[int] = []
        for index, image_path in enumerate(images, start=1):
            text = ocr_image(image_path, langs).strip()
            per_page_chars.append(len(text))
            page_chunks.append(f"<!-- page:{index} -->\n{text}".rstrip())

    body = "\n\n".join(page_chunks) + "\n"
    total = sum(per_page_chars)
    pages = len(per_page_chars)
    metadata = {**metadata}
    metadata.update({
        "page_count": pages,
        "char_count": total,
        "avg_chars_per_page": round(total / pages, 1) if pages else 0,
        "needs_ocr": False,
        "ocr_used": True,
        "ocr_engine": f"tesseract:{langs}@{dpi}dpi",
        "extractor": "tesseract-ocr",
        "extracted_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    })

    out_dir = EXTRACTED_DIR / pdf_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)
    (out_dir / "full.md").write_text(build_frontmatter(metadata) + body, encoding="utf-8")
    metadata["source_md"] = f"generated/extracted/{pdf_path.stem}/full.md"
    metadata["status"] = "ok"
    (out_dir / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return metadata


def discover_targets() -> list[Path]:
    out: list[Path] = []
    for meta_path in EXTRACTED_DIR.glob("*/metadata.json"):
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("needs_ocr") and not meta.get("ocr_used"):
            doc_id = meta["doc_id"]
            pdf = COLLECTOR_DIR / f"{doc_id}.pdf"
            if pdf.exists():
                out.append(pdf)
    return sorted(out)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="OCR image-only PDFs in collector.")
    parser.add_argument("--doc-id", help="OCR one 32-char doc id.")
    parser.add_argument("--all", action="store_true", help="OCR every needs_ocr doc.")
    parser.add_argument("--langs", default=DEFAULT_LANGS, help=f"tesseract -l value (default: {DEFAULT_LANGS}).")
    parser.add_argument("--dpi", type=int, default=DEFAULT_DPI, help=f"pdftoppm resolution (default: {DEFAULT_DPI}).")
    parser.add_argument("--dry-run", action="store_true", help="List targets only.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    if not shutil.which("tesseract"):
        raise SystemExit("tesseract not found")
    if not shutil.which("pdftoppm"):
        raise SystemExit("pdftoppm not found (install poppler)")

    available = subprocess.run(
        ["tesseract", "--list-langs"], capture_output=True, text=True, check=False
    ).stdout
    for lang in args.langs.split("+"):
        if lang not in available:
            raise SystemExit(
                f"tesseract language '{lang}' not installed. Run: brew install tesseract-lang"
            )

    if args.doc_id:
        pdf = COLLECTOR_DIR / f"{args.doc_id}.pdf"
        if not pdf.exists():
            raise SystemExit(f"PDF not found: {pdf.relative_to(ROOT)}")
        targets = [pdf]
    elif args.all:
        targets = discover_targets()
    else:
        raise SystemExit("Use --doc-id <md5> or --all")

    print(f"OCR targets: {len(targets)} (langs={args.langs}, dpi={args.dpi})")
    if args.dry_run:
        for pdf in targets:
            print(f"  - {pdf.stem}")
        return 0

    ok = 0
    failed: list[tuple[str, str]] = []
    for index, pdf in enumerate(targets, start=1):
        meta_path = EXTRACTED_DIR / pdf.stem / "metadata.json"
        if not meta_path.exists():
            failed.append((pdf.stem, "metadata.json missing — run extract_pdf first"))
            continue
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        try:
            result = ocr_pdf(pdf, meta, args.langs, args.dpi)
        except Exception as exc:  # noqa: BLE001
            failed.append((pdf.stem, str(exc)))
            continue
        ok += 1
        if index % 10 == 0 or index == len(targets):
            print(f"  progress: {index}/{len(targets)} ok={ok} failed={len(failed)}")

    print(f"OCR ok: {ok}")
    print(f"OCR failed: {len(failed)}")
    for stem, reason in failed[:10]:
        print(f"  - {stem}: {reason}")
    if len(failed) > 10:
        print(f"  ... +{len(failed) - 10}")
    if not targets:
        return 0
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
