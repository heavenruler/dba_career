#!/usr/bin/env python3
"""Build the generated Obsidian source layer from KnowledgeBase provenance."""
from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path
from urllib.parse import urlparse


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "output_with_md5.txt"
COLLECTOR_DIR = ROOT / "collector"
FILTERED_DIR = ROOT / "generated" / "filtered"
EXTRACTED_DIR = ROOT / "generated" / "extracted"
VAULT_DIR = ROOT / "obsidian"
SOURCE_DIR = VAULT_DIR / "90 Sources"
MAP_DIR = VAULT_DIR / "10 Maps"
MANAGED_MAPS = (
    MAP_DIR / "KnowledgeBase.md",
    MAP_DIR / "Source Catalog.md",
    MAP_DIR / "Tag Index.md",
)
VALID_DOC_ID = re.compile(r"[0-9a-f]{32}")
INVALID_FILENAME = re.compile(r'[\\/:*?"<>|#^[\]]')
WHITESPACE = re.compile(r"\s+")


def yaml_scalar(value: str) -> str:
    return json.dumps(value, ensure_ascii=False)


def parse_manifest() -> tuple[list[dict], list[str]]:
    lines = MANIFEST_PATH.read_text(encoding="utf-8").splitlines()
    docs_by_id: dict[str, dict] = {}
    duplicates: list[str] = []
    block: list[str] = []

    def add_block() -> None:
        if len(block) < 3:
            return
        title, url, doc_id = (item.strip() for item in block[:3])
        if not title or not VALID_DOC_ID.fullmatch(doc_id):
            return
        if doc_id in docs_by_id:
            duplicates.append(doc_id)
            return
        docs_by_id[doc_id] = {"doc_id": doc_id, "title": title, "url": url}

    for line in lines:
        if line.strip() == "----":
            add_block()
            block = []
        else:
            block.append(line)
    add_block()
    return list(docs_by_id.values()), duplicates


def safe_filename(title: str, doc_id: str) -> str:
    name = INVALID_FILENAME.sub(" ", title)
    name = WHITESPACE.sub(" ", name).strip(" .")
    if not name:
        name = "Untitled"
    return f"{name[:100].rstrip()} -- {doc_id[:8]}.md"


def load_filtered(doc_id: str) -> dict | None:
    path = FILTERED_DIR / doc_id / "knowledge.json"
    if not path.is_file():
        return None
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    return data if isinstance(data, dict) else None


def relative_repo_path(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def source_note(doc: dict, filename: str) -> tuple[str, list[str], str]:
    doc_id = doc["doc_id"]
    title = doc["title"]
    url = doc["url"]
    filtered = load_filtered(doc_id)
    tags = ["source"]
    summary = ""
    sections: list[dict] = []
    source_kind = "extracted_text" if (EXTRACTED_DIR / doc_id / "full.md").is_file() else "pdf"
    if filtered:
        source_kind = "llm_filtered"
        summary = str(filtered.get("summary") or "").strip()
        sections = [
            section for section in filtered.get("sections", [])
            if isinstance(section, dict) and section.get("heading")
        ]
        tags.extend(str(tag).strip() for tag in filtered.get("tags", []) if str(tag).strip())

    tags = list(dict.fromkeys(tags))
    domain = urlparse(url).netloc.lower()
    pdf_path = COLLECTOR_DIR / f"{doc_id}.pdf"
    extracted_path = EXTRACTED_DIR / doc_id / "full.md"
    filtered_path = FILTERED_DIR / doc_id / "knowledge.json"
    link_stem = Path(filename).stem

    frontmatter = [
        "---",
        f"doc_id: {yaml_scalar(doc_id)}",
        f"title: {yaml_scalar(title)}",
        "aliases:",
        f"  - {yaml_scalar(title)}",
        f"url: {yaml_scalar(url)}",
        f"source_domain: {yaml_scalar(domain)}",
        f"source_kind: {yaml_scalar(source_kind)}",
        f"pdf_exists: {'true' if pdf_path.is_file() else 'false'}",
        f"knowledge_status: {yaml_scalar('filtered' if filtered else 'extracted' if extracted_path.is_file() else 'source-only')}",
        "tags:",
    ]
    frontmatter.extend(f"  - {yaml_scalar(tag)}" for tag in tags)
    frontmatter.extend(["generated: true", "---", "", f"# {title}", ""])

    body = [
        "> [!info] Provenance",
        f"> - doc_id: `{doc_id}`",
        f"> - source_kind: `{source_kind}`",
        f"> - source: [original URL]({url})" if url else "> - source: unavailable",
        f"> - PDF: [open local PDF](../../collector/{doc_id}.pdf)",
        "",
    ]
    if summary:
        body.extend(["## Summary", "", summary, ""])
    if sections:
        body.extend(["## Knowledge Outline", ""])
        for section in sections:
            heading = WHITESPACE.sub(" ", str(section.get("heading"))).strip()
            section_tags = ", ".join(str(tag) for tag in section.get("tags", []) if str(tag).strip())
            suffix = f" — {section_tags}" if section_tags else ""
            body.append(f"- {heading}{suffix}")
        body.append("")
    body.extend([
        "## Repository Paths",
        "",
        f"- PDF: `{relative_repo_path(pdf_path)}`",
        f"- Extracted: `{relative_repo_path(extracted_path)}`",
        f"- Filtered: `{relative_repo_path(filtered_path)}`",
        "",
        "## Notes",
        "",
        "<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->",
        "",
    ])
    return "\n".join(frontmatter + body), tags, link_stem


def build_files() -> tuple[dict[Path, str], dict]:
    docs, duplicates = parse_manifest()
    generated: dict[Path, str] = {}
    catalog_rows = []
    tags_to_links: dict[str, list[str]] = defaultdict(list)
    status_counts: Counter[str] = Counter()
    missing_pdfs = []
    filename_collisions = []

    for doc in sorted(docs, key=lambda item: (item["title"].casefold(), item["doc_id"])):
        filename = safe_filename(doc["title"], doc["doc_id"])
        source_path = SOURCE_DIR / filename
        if source_path in generated:
            filename_collisions.append(filename)
            continue
        content, tags, link_stem = source_note(doc, filename)
        generated[source_path] = content
        filtered = load_filtered(doc["doc_id"])
        status = "filtered" if filtered else "extracted" if (EXTRACTED_DIR / doc["doc_id"] / "full.md").is_file() else "source-only"
        status_counts[status] += 1
        if not (COLLECTOR_DIR / f"{doc['doc_id']}.pdf").is_file():
            missing_pdfs.append(doc["doc_id"])
        catalog_rows.append((doc["title"], link_stem, doc["doc_id"], status))
        for tag in tags:
            tags_to_links[tag].append(link_stem)

    home = [
        "# KnowledgeBase",
        "",
        "Human-facing entry point for the KnowledgeBase pipeline.",
        "",
        "## Start Here",
        "",
        "- [[Source Catalog]]",
        "- [[Tag Index]]",
        "- [[Concepts]]",
        "- [[Runbooks]]",
        "- [[Cases]]",
        "- [[Career]]",
        "",
        "## Current Coverage",
        "",
        f"- Sources: {len(docs)}",
        f"- Filtered: {status_counts['filtered']}",
        f"- Extracted only: {status_counts['extracted']}",
        f"- Source only: {status_counts['source-only']}",
        f"- Manifest duplicate doc_id entries ignored: {len(duplicates)}",
        f"- Missing PDFs: {len(missing_pdfs)}",
        "",
        "Generated by `make obsidian`.",
        "",
    ]
    generated[MAP_DIR / "KnowledgeBase.md"] = "\n".join(home)

    catalog = [
        "# Source Catalog",
        "",
        f"Generated source index: {len(catalog_rows)} unique documents.",
        "",
    ]
    for title, link_stem, doc_id, status in catalog_rows:
        safe_title = title.replace("|", "｜")
        catalog.append(f"- [[{link_stem}|{safe_title}]] — `{doc_id}` — {status}")
    catalog.append("")
    generated[MAP_DIR / "Source Catalog.md"] = "\n".join(catalog)

    tag_index = ["# Tag Index", ""]
    for tag, links in sorted(tags_to_links.items(), key=lambda item: (-len(item[1]), item[0].casefold())):
        tag_index.extend([f"## {tag} ({len(links)})", ""])
        tag_index.extend(f"- [[{link}]]" for link in sorted(links)[:50])
        if len(links) > 50:
            tag_index.append(f"- … {len(links) - 50} more; use Obsidian tag search.")
        tag_index.append("")
    generated[MAP_DIR / "Tag Index.md"] = "\n".join(tag_index)

    stats = {
        "documents": len(docs),
        "duplicates": duplicates,
        "missing_pdfs": missing_pdfs,
        "filename_collisions": filename_collisions,
        "source_pages": len([path for path in generated if path.parent == SOURCE_DIR]),
        "filtered": status_counts["filtered"],
        "extracted": status_counts["extracted"],
        "source_only": status_counts["source-only"],
    }
    return generated, stats


def write_files(expected: dict[Path, str]) -> None:
    SOURCE_DIR.mkdir(parents=True, exist_ok=True)
    MAP_DIR.mkdir(parents=True, exist_ok=True)
    expected_sources = {path for path in expected if path.parent == SOURCE_DIR}
    for path in SOURCE_DIR.glob("*.md"):
        if path not in expected_sources:
            path.unlink()
    for path, content in expected.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(path.suffix + ".tmp")
        temp.write_text(content, encoding="utf-8")
        temp.replace(path)


def check_files(expected: dict[Path, str]) -> list[str]:
    errors = []
    expected_sources = {path for path in expected if path.parent == SOURCE_DIR}
    actual_sources = set(SOURCE_DIR.glob("*.md")) if SOURCE_DIR.exists() else set()
    for path in sorted(expected_sources - actual_sources):
        errors.append(f"missing: {path.relative_to(ROOT)}")
    for path in sorted(actual_sources - expected_sources):
        errors.append(f"unexpected: {path.relative_to(ROOT)}")
    for path, content in expected.items():
        if path.is_file() and path.read_text(encoding="utf-8") != content:
            errors.append(f"stale: {path.relative_to(ROOT)}")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected, stats = build_files()
    if args.check:
        errors = check_files(expected)
        errors.extend(f"duplicate manifest doc_id: {doc_id}" for doc_id in stats["duplicates"])
        errors.extend(f"missing PDF: {doc_id}" for doc_id in stats["missing_pdfs"])
        errors.extend(f"filename collision: {name}" for name in stats["filename_collisions"])
        for error in errors[:50]:
            print(error)
        if len(errors) > 50:
            print(f"... {len(errors) - 50} more")
        print(json.dumps({**stats, "errors": len(errors)}, ensure_ascii=False))
        return 1 if errors else 0
    write_files(expected)
    print(json.dumps(stats, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
