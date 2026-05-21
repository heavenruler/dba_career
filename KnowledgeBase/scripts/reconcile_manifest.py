#!/usr/bin/env python3
"""Reconcile orphan PDFs into output_with_md5.txt.

For every PDF under collector/ whose doc_id (md5 of URL) is not in the
manifest, read the PDF's embedded metadata (Title + Subject) — FireShot
Pro writes the original page title to Title and the source URL to
Subject — and append a new manifest block.

Run again is safe: existing manifest entries are left untouched.
"""
import hashlib
import re
import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "output_with_md5.txt"
COLLECTOR_DIR = ROOT / "collector"


def parse_manifest_ids() -> set[str]:
    if not MANIFEST_PATH.exists():
        return set()
    ids: set[str] = set()
    block: list[str] = []
    for line in MANIFEST_PATH.read_text(encoding="utf-8").splitlines():
        if line.strip() == "----":
            if len(block) >= 3 and re.fullmatch(r"[0-9a-f]{32}", block[2].strip()):
                ids.add(block[2].strip())
            block = []
        else:
            block.append(line)
    if len(block) >= 3 and re.fullmatch(r"[0-9a-f]{32}", block[2].strip()):
        ids.add(block[2].strip())
    return ids


def pdfinfo_fields(pdf_path: Path) -> dict[str, str]:
    proc = subprocess.run(
        ["pdfinfo", "-enc", "UTF-8", str(pdf_path)],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return {}
    fields: dict[str, str] = {}
    for line in proc.stdout.splitlines():
        if ":" in line:
            key, _, value = line.partition(":")
            fields[key.strip()] = value.strip()
    return fields


def first_text_line(pdf_path: Path, max_chars: int = 200) -> str:
    """Fallback title: first non-empty text line on page 1."""
    proc = subprocess.run(
        ["pdftotext", "-f", "1", "-l", "1", "-layout", "-enc", "UTF-8", str(pdf_path), "-"],
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        return ""
    for raw in proc.stdout.splitlines():
        line = raw.strip()
        if 4 <= len(line) <= max_chars:
            return line
    return ""


def main() -> int:
    if not COLLECTOR_DIR.exists():
        raise SystemExit(f"collector dir missing: {COLLECTOR_DIR}")

    existing = parse_manifest_ids()
    pdfs = sorted(
        p for p in COLLECTOR_DIR.glob("*.pdf") if re.fullmatch(r"[0-9a-f]{32}", p.stem)
    )

    new_blocks: list[str] = []
    no_url: list[str] = []
    url_mismatch: list[tuple[str, str, str]] = []  # (pdf_id, expected_id_from_url, url)

    for pdf in pdfs:
        if pdf.stem in existing:
            continue
        fields = pdfinfo_fields(pdf)
        title = (fields.get("Title") or "").strip()
        url = (fields.get("Subject") or "").strip()

        if not url:
            no_url.append(pdf.stem)
            continue

        url_md5 = hashlib.md5(url.encode("utf-8")).hexdigest()
        if url_md5 != pdf.stem:
            # The PDF was named by file md5 not URL md5, or URL was
            # rewritten. Keep the filename doc_id (it owns the PDF) and
            # record the mismatch.
            url_mismatch.append((pdf.stem, url_md5, url))

        if not title:
            title = first_text_line(pdf) or pdf.stem

        # Sanitise: title/url must be a single line each.
        title = re.sub(r"\s+", " ", title).strip()
        url = re.sub(r"\s+", "", url)

        new_blocks.append(f"{title}\n{url}\n{pdf.stem}\n----")

    if new_blocks:
        existing_text = MANIFEST_PATH.read_text(encoding="utf-8") if MANIFEST_PATH.exists() else ""
        if existing_text and not existing_text.endswith("\n"):
            existing_text += "\n"
        # Make sure existing file ends on a `----` separator before append.
        trailing = existing_text.rstrip().splitlines()[-1] if existing_text.strip() else ""
        if trailing != "----":
            existing_text = existing_text.rstrip() + "\n----\n"
        MANIFEST_PATH.write_text(
            existing_text + "\n".join(new_blocks) + "\n",
            encoding="utf-8",
        )

    print(f"appended manifest blocks: {len(new_blocks)}")
    print(f"orphan PDFs without embedded URL: {len(no_url)}")
    for stem in no_url[:10]:
        print(f"  - {stem}")
    if len(no_url) > 10:
        print(f"  ... +{len(no_url) - 10}")

    print(f"url-md5 mismatch (manifest kept PDF-name doc_id): {len(url_mismatch)}")
    for stem, expected, url in url_mismatch[:10]:
        print(f"  - {stem} (md5(url)={expected}) {url}")
    if len(url_mismatch) > 10:
        print(f"  ... +{len(url_mismatch) - 10}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
