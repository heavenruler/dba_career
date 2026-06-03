#!/usr/bin/env python3
"""Verify all markdown links in poc/results/README.md.

Categories:
  - FILE_MISS    : `](./path)` target file does not exist
  - ANCHOR_MISS  : `](#anchor)` in-file anchor not found (no matching heading slug or <a id>)
  - XFILE_MISS   : `](./path.md#anchor)` cross-file but the target file missing
  - XANCHOR_MISS : `](./path.md#anchor)` file exists but anchor not in target
  - EXT_WARN     : http(s)://... external link — informational only

Anchor matching:
  - GitHub-style slug from heading text (lowercase ASCII; spaces → '-';
    punctuation stripped; Chinese chars kept as-is)
  - Explicit <a id="..."></a> in source
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
README = ROOT / "README.md"

# --- slug / anchor extraction ---------------------------------------------------


def heading_to_slug(text: str) -> str:
    """GitHub-flavored slug.

    Algorithm (mirrors `github-slugger`):
      1. Strip inline markdown formatting (backtick / bold / link text).
      2. Lowercase ASCII letters.
      3. Drop every char that is NOT a Unicode word char (\\w), hyphen, or
         whitespace. This removes ASCII punctuation, full-width punctuation
         (e.g. （）／：「」), symbols (=, %, …), etc.
      4. Replace each whitespace char individually with '-' (do NOT collapse;
         consecutive spaces produce consecutive hyphens — GitHub behavior).
    Non-ASCII letters (e.g. CJK) are preserved as-is.
    """
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = re.sub(r"\*\*([^*]+)\*\*", r"\1", text)
    text = re.sub(r"\[([^\]]+)\]\([^)]+\)", r"\1", text)
    s = text.lower().strip()
    s = re.sub(r"[^\w\s\-]", "", s, flags=re.UNICODE)
    s = re.sub(r"\s", "-", s)
    return s


def extract_anchors(file_path: Path) -> set[str]:
    """Return set of anchors in file (heading slugs + explicit <a id>)."""
    if not file_path.exists():
        return set()
    try:
        text = file_path.read_text(encoding="utf-8")
    except (UnicodeDecodeError, OSError):
        return set()
    anchors: set[str] = set()
    for m in re.finditer(r"^(#{1,6})\s+(.+?)\s*$", text, re.MULTILINE):
        anchors.add(heading_to_slug(m.group(2)))
    for m in re.finditer(r'<a id="([^"]+)"', text):
        anchors.add(m.group(1))
    return anchors


# --- link extraction -----------------------------------------------------------

_CODE_BLOCK = re.compile(r"```[\s\S]*?```", re.MULTILINE)
# Match ](url); use negative lookbehind to skip images ![alt](url)
_LINK = re.compile(r"(?<!\!)\]\(([^)]+)\)")


def main() -> int:
    if not README.exists():
        print(f"FATAL: {README} not found", file=sys.stderr)
        return 2

    text = README.read_text(encoding="utf-8")
    # Strip fenced code blocks so example commands don't false-positive
    text_no_code = _CODE_BLOCK.sub("", text)
    links = sorted({m.group(1) for m in _LINK.finditer(text_no_code)})

    stats = {
        "OK": 0,
        "FILE_MISS": 0,
        "ANCHOR_MISS": 0,
        "XFILE_MISS": 0,
        "XANCHOR_MISS": 0,
        "EXT_WARN": 0,
    }
    fails: list[str] = []
    warns: list[str] = []

    own_anchors = extract_anchors(README)
    # cache anchors for repeated target files
    xfile_anchor_cache: dict[Path, set[str]] = {}

    for link in links:
        if link.startswith(("http://", "https://", "mailto:")):
            stats["EXT_WARN"] += 1
            warns.append(f"EXT_WARN     {link}")
            continue

        if link.startswith("#"):
            anchor = link[1:]
            if anchor in own_anchors:
                stats["OK"] += 1
            else:
                stats["ANCHOR_MISS"] += 1
                fails.append(f"ANCHOR_MISS  {link}")
            continue

        if "#" in link:
            file_part, anchor = link.split("#", 1)
            target = (ROOT / file_part).resolve()
            if not target.exists():
                stats["XFILE_MISS"] += 1
                fails.append(f"XFILE_MISS   {link}")
                continue
            if target not in xfile_anchor_cache:
                xfile_anchor_cache[target] = extract_anchors(target)
            if anchor in xfile_anchor_cache[target]:
                stats["OK"] += 1
            else:
                stats["XANCHOR_MISS"] += 1
                fails.append(f"XANCHOR_MISS {link}  (file ok, anchor not found)")
            continue

        target = (ROOT / link).resolve()
        if target.exists():
            stats["OK"] += 1
        else:
            stats["FILE_MISS"] += 1
            fails.append(f"FILE_MISS    {link}")

    print(f"Total links checked    : {len(links)}")
    for k, v in stats.items():
        print(f"  {k:<20}: {v}")
    print()

    if warns:
        print("=== External (warn only) ===")
        for w in warns:
            print(f"  {w}")
        print()

    if fails:
        print("=== Failures ===")
        for f in fails:
            print(f"  {f}")
        return 1

    print("All non-external links OK.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
