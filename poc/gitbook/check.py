#!/usr/bin/env python3
"""Fail-closed checks for the repository-local GitBook."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from urllib.parse import unquote


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parent
SUMMARY = ROOT / "SUMMARY.md"

LINK_RE = re.compile(r"(?<!!)\[[^]]+\]\(([^)]+)\)")
IMAGE_RE = re.compile(r"!\[[^]]*\]\(([^)]+)\)")
PRIVATE_IP_RE = re.compile(
    r"(?<![\d.])(?:10\.\d{1,3}\.\d{1,3}\.\d{1,3}"
    r"|172\.(?:1[6-9]|2\d|3[01])\.\d{1,3}\.\d{1,3}"
    r"|192\.168\.\d{1,3}\.\d{1,3})(?![\d.])"
)
FORBIDDEN_RE = re.compile(
    r"104corp\.atlassian\.net|g-test-poc|l-test-poc|BEGIN (?:RSA |OPENSSH )?PRIVATE KEY"
    r"|\[E-(?:FACT|SPEC|PENDING)\]|\bartifact\b|產物",
    re.IGNORECASE,
)


def markdown_files() -> list[Path]:
    return sorted(ROOT.rglob("*.md"))


def check_summary(errors: list[str]) -> None:
    if not SUMMARY.exists():
        errors.append("SUMMARY.md is missing")
        return
    summary_text = SUMMARY.read_text(encoding="utf-8")
    listed = set()
    for raw_target in LINK_RE.findall(summary_text):
        target = raw_target.split("#", 1)[0]
        if not target:
            continue
        path = (ROOT / unquote(target)).resolve()
        listed.add(path)
        if not path.is_file():
            errors.append(f"SUMMARY missing target: {raw_target}")

    expected = {p.resolve() for p in markdown_files() if p.name != "SUMMARY.md"}
    omitted = sorted(expected - listed)
    for path in omitted:
        errors.append(f"SUMMARY omits: {path.relative_to(ROOT)}")


def check_links(path: Path, text: str, errors: list[str]) -> None:
    for raw_target in LINK_RE.findall(text):
        target = raw_target.strip().strip("<>")
        if target.startswith(("http://", "https://", "mailto:")) or target.startswith("#"):
            continue
        file_part = unquote(target.split("#", 1)[0])
        if not file_part:
            continue
        resolved = (path.parent / file_part).resolve()
        if not resolved.exists():
            errors.append(f"{path.relative_to(ROOT)}: broken link {raw_target}")


def check_images(path: Path, text: str, errors: list[str]) -> None:
    """Images must exist and stay inside gitbook/ (charts are regenerable via `make charts`)."""
    for raw_target in IMAGE_RE.findall(text):
        target = unquote(raw_target.split("#", 1)[0].strip())
        if target.startswith(("http://", "https://")):
            errors.append(f"{path.relative_to(ROOT)}: external image not allowed {raw_target}")
            continue
        resolved = (path.parent / target).resolve()
        if not resolved.is_file():
            errors.append(f"{path.relative_to(ROOT)}: missing image {raw_target}")
        elif ROOT not in resolved.parents:
            errors.append(f"{path.relative_to(ROOT)}: image outside gitbook/ {raw_target}")


def check_fences(path: Path, text: str, errors: list[str]) -> None:
    in_fence = False
    fence_start = 0
    for lineno, line in enumerate(text.splitlines(), start=1):
        if line.startswith("```"):
            in_fence = not in_fence
            if in_fence:
                fence_start = lineno
    if in_fence:
        errors.append(f"{path.relative_to(ROOT)}:{fence_start}: unclosed code fence")


def check_metadata(path: Path, text: str, errors: list[str]) -> None:
    if re.fullmatch(r"\d{2}-.*\.md", path.name) and "最後驗證" not in text:
        errors.append(f"{path.relative_to(ROOT)}: missing last-verified metadata")


def check_sensitive(path: Path, text: str, errors: list[str]) -> None:
    if PRIVATE_IP_RE.search(text):
        errors.append(f"{path.relative_to(ROOT)}: contains a private IP address")
    if FORBIDDEN_RE.search(text):
        errors.append(f"{path.relative_to(ROOT)}: contains internal or sensitive identifier")


def main() -> int:
    errors: list[str] = []
    check_summary(errors)
    for path in markdown_files():
        text = path.read_text(encoding="utf-8")
        check_links(path, text, errors)
        check_images(path, text, errors)
        check_fences(path, text, errors)
        check_metadata(path, text, errors)
        check_sensitive(path, text, errors)

    if errors:
        print("GitBook check FAILED")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"GitBook check PASS ({len(markdown_files())} Markdown files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
