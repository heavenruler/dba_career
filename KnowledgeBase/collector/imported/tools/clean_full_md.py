#!/usr/bin/env python3
"""
Clean and restructure full.md using OpenAI.

Usage:
  python tools/clean_full_md.py --input path/to/full.md --output path/to/full2.md
"""

import argparse
import os
import sys
from pathlib import Path


PROMPT = """
You are a technical editor. Clean and restructure the markdown content.

Goals:
- Remove navigation, share buttons, headers/footers, timestamps, and URLs that are not part of content.
- Merge broken lines and fix hyphenation while preserving meaning.
- Preserve headings and lists; normalize heading levels if needed.
- Keep image references and captions near their images.
- Keep code blocks intact.
- Keep the author line only if it is meaningful to the article.

Output only the cleaned markdown. No commentary.
""".strip()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--model", default="gpt-5-mini")
    args = parser.parse_args()

    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    try:
        from openai import OpenAI  # type: ignore
    except Exception as exc:
        raise RuntimeError(f"openai not available: {exc}")

    content = open(args.input, "r", encoding="utf-8", errors="ignore").read()

    client = OpenAI(api_key=api_key)
    resp = client.responses.create(
        model=args.model,
        input=[
            {"role": "system", "content": PROMPT},
            {"role": "user", "content": content},
        ],
    )

    output_text = resp.output_text
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8") as f:
        f.write(output_text)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
