#!/usr/bin/env python3
"""Extract PDFs from collector/ into generated/extracted/<doc_id>/full.md.

Strict-mode output:
- per-page split via `pdftotext -f N -l N`, with `<!-- page:N -->` markers
- YAML frontmatter at the top of full.md (doc_id/title/url/sha256/pages/...)
- metadata.json records sha256, page_count, char_count, avg_chars_per_page,
  needs_ocr (when char density < threshold), extractor, source_pdf
- runs on every PDF in collector/, even those missing from the manifest
  (title falls back to PDF Title, then to the first usable text line).
"""
import argparse
import hashlib
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

# A page with < 50 visible chars per page on average is likely image-only.
OCR_CHAR_DENSITY_THRESHOLD = 50


def parse_manifest() -> dict[str, dict]:
    docs: dict[str, dict] = {}
    if not MANIFEST_PATH.exists():
        return docs

    block: list[str] = []
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


def sha256_of(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as file:
        for chunk in iter(lambda: file.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def pdfinfo_fields(pdf_path: Path) -> dict[str, str]:
    proc = subprocess.run(
        ["pdfinfo", "-enc", "UTF-8", str(pdf_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return {}
    out: dict[str, str] = {}
    for line in proc.stdout.splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            out[key.strip()] = value.strip()
    return out


def page_count_from_info(info: dict[str, str]) -> int:
    try:
        return int(info.get("Pages", "0"))
    except ValueError:
        return 0


def extract_page(pdf_path: Path, page: int) -> str:
    proc = subprocess.run(
        ["pdftotext", "-f", str(page), "-l", str(page), "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
        capture_output=True,
        text=True,
        check=True,
    )
    return proc.stdout


def extract_pages(pdf_path: Path, pages: int) -> tuple[str, list[int]]:
    """Return per-page markdown text + list of char counts per page."""
    chunks: list[str] = []
    per_page_chars: list[int] = []
    for index in range(1, pages + 1):
        page_text = extract_page(pdf_path, index).rstrip()
        per_page_chars.append(len(page_text))
        chunks.append(f"<!-- page:{index} -->\n{page_text}".rstrip())
    return "\n\n".join(chunks) + "\n", per_page_chars


def first_usable_line(text: str, limit: int = 200) -> str:
    for raw in text.splitlines():
        line = raw.strip()
        if 4 <= len(line) <= limit:
            return line
    return ""


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


def write_extraction(pdf_path: Path, manifest_entry: dict | None) -> dict:
    from datetime import datetime, timezone

    info = pdfinfo_fields(pdf_path)
    pages = page_count_from_info(info)
    if pages <= 0:
        return {
            "doc_id": pdf_path.stem,
            "status": "pdfinfo_failed",
            "source_pdf": str(pdf_path.relative_to(ROOT)),
        }

    body, per_page_chars = extract_pages(pdf_path, pages)
    total_chars = sum(per_page_chars)
    avg = total_chars / pages if pages else 0
    needs_ocr = avg < OCR_CHAR_DENSITY_THRESHOLD

    embedded_title = (info.get("Title") or "").strip()
    embedded_url = (info.get("Subject") or "").strip()

    title = (manifest_entry or {}).get("title") or embedded_title or first_usable_line(body) or pdf_path.stem
    url = (manifest_entry or {}).get("url") or embedded_url or None
    source_domain = urlparse(url).netloc.lower() if url else None

    metadata = {
        "doc_id": pdf_path.stem,
        "title": title,
        "url": url,
        "source_domain": source_domain,
        "sha256": sha256_of(pdf_path),
        "page_count": pages,
        "char_count": total_chars,
        "avg_chars_per_page": round(avg, 1),
        "needs_ocr": needs_ocr,
        "extractor": "pdftotext-layout-per-page",
        "extracted_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "source_pdf": str(pdf_path.relative_to(ROOT)),
        "in_manifest": manifest_entry is not None,
    }

    out_dir = EXTRACTED_DIR / pdf_path.stem
    out_dir.mkdir(parents=True, exist_ok=True)
    full_md = out_dir / "full.md"
    metadata_path = out_dir / "metadata.json"

    frontmatter = build_frontmatter(metadata)
    full_md.write_text(frontmatter + body, encoding="utf-8")
    metadata.update({
        "source_md": str(full_md.relative_to(ROOT)),
        "status": "ok",
    })
    metadata_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    return metadata


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract collector PDFs into generated/extracted (strict mode).")
    parser.add_argument("--doc-id", help="Extract one 32-character document id.")
    parser.add_argument("--all", action="store_true", help="Extract every PDF found in collector/.")
    parser.add_argument("--force", action="store_true", help="Re-extract even if metadata.json already exists.")
    parser.add_argument("--skip-existing", action="store_true", help="Skip PDFs whose metadata.json already exists (default in --all).")
    return parser.parse_args()


def discover_pdfs() -> list[Path]:
    return sorted(
        p for p in COLLECTOR_DIR.glob("*.pdf") if re.fullmatch(r"[0-9a-f]{32}", p.stem)
    )


def main() -> int:
    args = parse_args()
    if not args.doc_id and not args.all:
        raise SystemExit("Use --doc-id <md5> or --all")

    manifest = parse_manifest()

    if args.doc_id:
        pdf_path = COLLECTOR_DIR / f"{args.doc_id}.pdf"
        if not pdf_path.exists():
            raise SystemExit(f"PDF not found: {pdf_path.relative_to(ROOT)}")
        targets = [pdf_path]
    else:
        targets = discover_pdfs()

    skip_existing = args.skip_existing or (args.all and not args.force)

    ok = 0
    skipped = 0
    failed: list[tuple[str, str]] = []
    needs_ocr_list: list[str] = []

    for index, pdf in enumerate(targets, start=1):
        existing_meta = EXTRACTED_DIR / pdf.stem / "metadata.json"
        if skip_existing and existing_meta.exists():
            skipped += 1
            continue
        try:
            result = write_extraction(pdf, manifest.get(pdf.stem))
        except subprocess.CalledProcessError as exc:
            failed.append((pdf.stem, f"pdftotext exit {exc.returncode}"))
            continue
        except Exception as exc:  # noqa: BLE001
            failed.append((pdf.stem, str(exc)))
            continue

        if result.get("status") == "ok":
            ok += 1
            if result.get("needs_ocr"):
                needs_ocr_list.append(pdf.stem)
        else:
            failed.append((pdf.stem, result.get("status", "unknown")))

        if args.all and index % 50 == 0:
            print(f"  progress: {index}/{len(targets)} (ok={ok} skipped={skipped} failed={len(failed)})")

    print(f"extracted ok: {ok}")
    print(f"skipped (existing): {skipped}")
    print(f"needs_ocr (low char density): {len(needs_ocr_list)}")
    for stem in needs_ocr_list[:10]:
        print(f"  - {stem}")
    if len(needs_ocr_list) > 10:
        print(f"  ... +{len(needs_ocr_list) - 10}")
    print(f"failed: {len(failed)}")
    for stem, reason in failed[:10]:
        print(f"  - {stem}: {reason}")
    if len(failed) > 10:
        print(f"  ... +{len(failed) - 10}")

    return 0 if ok or skipped else 1


if __name__ == "__main__":
    raise SystemExit(main())
