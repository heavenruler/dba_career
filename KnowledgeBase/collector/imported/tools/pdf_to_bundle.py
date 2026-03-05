#!/usr/bin/env python3
"""
Convert PDF into a LobeChat-style bundle directory.

Output structure:
  <pdf>.pdf-<bundle_uuid>/
    <file_uuid>_origin.pdf
    <file_uuid>_content_list.json
    <file_uuid>_model.json
    content_list_v2.json
    layout.json
    full.md
    full2.md
    images/
"""

import argparse
import json
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path
from typing import List, Tuple


def run(cmd: List[str]) -> None:
    result = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed: {' '.join(cmd)}\n{result.stderr.strip()}")


def extract_text_pypdf(pdf_path: Path) -> List[str]:
    try:
        from pypdf import PdfReader  # type: ignore
    except Exception as exc:
        raise RuntimeError(f"pypdf not available: {exc}")

    reader = PdfReader(str(pdf_path))
    pages = []
    for page in reader.pages:
        pages.append(page.extract_text() or "")
    return pages


def ocr_page(pdf_path: Path, page_index: int, out_dir: Path, lang: str) -> str:
    out_dir.mkdir(parents=True, exist_ok=True)
    image_path = out_dir / f"page-{page_index + 1}.png"
    text_base = out_dir / f"page-{page_index + 1}"

    run([
        "magick",
        "-density",
        "300",
        f"{pdf_path}[{page_index}]",
        str(image_path),
    ])

    run([
        "tesseract",
        str(image_path),
        str(text_base),
        "-l",
        lang,
    ])

    text_path = Path(f"{text_base}.txt")
    return text_path.read_text(encoding="utf-8", errors="ignore")


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = [line.strip() for line in text.split("\n")]
    lines = [line for line in lines if line]
    return "\n".join(lines)


def sanitize_text(text: str) -> str:
    return text.encode("utf-8", errors="ignore").decode("utf-8", errors="ignore")


def is_noise_line(line: str) -> bool:
    noise_markers = [
        "赞 分享 推荐 写留言",
        "Captured by FireShot",
        "getfireshot",
        "http://",
        "https://",
    ]
    return any(marker in line for marker in noise_markers)


def is_section_marker(line: str) -> bool:
    return re.fullmatch(r"\d{2}", line) is not None


def is_heading_line(line: str) -> bool:
    if re.match(r"^\d+、", line):
        return True
    if re.match(r"^[（(]\d+[）)]", line):
        return True
    if line in {"Q&A", "Q & A", "Q&A", "Q & A"}:
        return True
    if line.endswith("？") or line.endswith("?"):
        return len(line) <= 40
    if ("：" in line or ":" in line) and len(line) <= 50 and "。" not in line:
        if "MySQL" in line or "SQL" in line:
            return True
    if len(line) <= 10 and any(token in line for token in ["架构", "日志", "更新", "提交", "比较", "Q&A", "Q & A", "层"]):
        return True
    return False


def is_list_line(line: str) -> bool:
    if re.match(r"^[-*]\s+", line):
        return True
    if re.match(r"^\d+\.\s+", line):
        return True
    if re.match(r"^\d+、", line):
        return True
    return False


def should_add_space(prev: str, curr: str) -> bool:
    if not prev or not curr:
        return False
    return prev[-1].isascii() and curr[0].isascii()


def reflow_lines(lines: List[str]) -> List[str]:
    output: List[str] = []
    current = ""
    pending_section = False
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if is_noise_line(line):
            continue
        if is_section_marker(line):
            if current:
                output.append(current)
                current = ""
            output.append(line)
            pending_section = True
            continue
        if line in {"Q:", "A:"}:
            if current:
                output.append(current)
                current = ""
            output.append(line)
            pending_section = False
            continue
        if is_heading_line(line):
            if current:
                output.append(current)
                current = ""
            heading = line
            if not line.startswith("#"):
                heading = f"# {line}"
            if pending_section and not heading.startswith("# "):
                heading = f"# {line}"
            output.append(heading)
            pending_section = False
            continue
        if is_list_line(line):
            if current:
                output.append(current)
                current = ""
            output.append(line)
            pending_section = False
            continue
        pending_section = False
        if not current:
            current = line
        else:
            joiner = " " if should_add_space(current, line) else ""
            current = f"{current}{joiner}{line}"
    if current:
        output.append(current)
    return output


def build_full2(pages: List[Tuple[int, str]]) -> str:
    lines: List[str] = []
    for _, page_text in pages:
        lines.extend(page_text.split("\n"))
    rebuilt = reflow_lines(lines)
    if rebuilt and not rebuilt[0].startswith("# "):
        rebuilt[0] = f"# {rebuilt[0]}"
    return sanitize_text("\n\n".join(rebuilt) + "\n")


def load_pages(pdf_path: Path, ocr_lang: str, ocr_dir: Path, ocr_min_chars: int) -> List[Tuple[int, str]]:
    pages: List[Tuple[int, str]] = []
    try:
        extracted = extract_text_pypdf(pdf_path)
    except Exception:
        extracted = []

    if extracted:
        for idx, text in enumerate(extracted):
            if len(text.strip()) >= ocr_min_chars:
                pages.append((idx + 1, normalize_text(text)))
            else:
                ocr_text = ocr_page(pdf_path, idx, ocr_dir, ocr_lang)
                pages.append((idx + 1, normalize_text(ocr_text)))
    else:
        page_count = 1
        try:
            from pypdf import PdfReader  # type: ignore
            page_count = len(PdfReader(str(pdf_path)).pages)
        except Exception:
            pass
        for idx in range(page_count):
            ocr_text = ocr_page(pdf_path, idx, ocr_dir, ocr_lang)
            pages.append((idx + 1, normalize_text(ocr_text)))
    return pages


def split_paragraphs(text: str) -> List[str]:
    return [p.strip() for p in text.split("\n\n") if p.strip()]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", required=True)
    parser.add_argument("--out-dir")
    parser.add_argument("--lang", default="chi_tra+eng")
    parser.add_argument("--skip-origin", action="store_true")
    parser.add_argument("--ocr-dir", default="ocr_cache")
    parser.add_argument("--ocr-min-chars", type=int, default=40)
    args = parser.parse_args()

    pdf_path = Path(args.pdf)
    bundle_id = str(uuid.uuid4())
    file_id = str(uuid.uuid4())
    out_dir = Path(args.out_dir) if args.out_dir else Path(f"{pdf_path.name}-{bundle_id}")
    images_dir = out_dir / "images"
    images_dir.mkdir(parents=True, exist_ok=True)

    pages = load_pages(pdf_path, args.lang, Path(args.ocr_dir) / pdf_path.stem, args.ocr_min_chars)

    # full.md
    full_md_path = out_dir / "full.md"
    with full_md_path.open("w", encoding="utf-8") as f:
        for _, page_text in pages:
            paragraphs = split_paragraphs(page_text)
            for p in paragraphs:
                f.write(sanitize_text(p) + "\n\n")

    # full2.md
    full2_md_path = out_dir / "full2.md"
    full2_md_path.write_text(build_full2(pages), encoding="utf-8")

    # content_list_v2.json
    content_list_v2 = []
    for page_idx, (_, page_text) in enumerate(pages):
        page_blocks = []
        for p in split_paragraphs(page_text):
            page_blocks.append({
                "type": "paragraph",
                "content": {
                    "paragraph_content": [
                        {"type": "text", "content": sanitize_text(p)}
                    ]
                },
                "bbox": [0, 0, 0, 0],
            })
        content_list_v2.append(page_blocks)
    (out_dir / "content_list_v2.json").write_text(
        json.dumps(content_list_v2, ensure_ascii=True, indent=4),
        encoding="utf-8",
    )

    # content_list.json
    content_list = []
    for page_idx, (_, page_text) in enumerate(pages):
        for p in split_paragraphs(page_text):
            content_list.append({
                "type": "text",
                "text": sanitize_text(p),
                "bbox": [0, 0, 0, 0],
                "page_idx": page_idx,
            })
    (out_dir / f"{file_id}_content_list.json").write_text(
        json.dumps(content_list, ensure_ascii=True, indent=4),
        encoding="utf-8",
    )

    # model.json
    model = []
    for _, page_text in pages:
        page_entries = []
        for p in split_paragraphs(page_text):
            page_entries.append({
                "type": "text",
                "bbox": [0.0, 0.0, 0.0, 0.0],
                "angle": 0,
                "content": sanitize_text(p),
            })
        model.append(page_entries)
    (out_dir / f"{file_id}_model.json").write_text(
        json.dumps(model, ensure_ascii=True, indent=4),
        encoding="utf-8",
    )

    # layout.json
    layout = {"pdf_info": []}
    for page_idx, (_, page_text) in enumerate(pages):
        para_blocks = []
        block_index = 0
        for p in split_paragraphs(page_text):
            para_blocks.append({
                "bbox": [0, 0, 0, 0],
                "type": "text",
                "angle": 0,
                "lines": [
                    {
                        "bbox": [0, 0, 0, 0],
                        "spans": [
                            {"bbox": [0, 0, 0, 0], "type": "text", "content": sanitize_text(p)}
                        ],
                    }
                ],
                "index": block_index,
            })
            block_index += 1

        layout["pdf_info"].append({
            "para_blocks": para_blocks,
            "discarded_blocks": [],
            "page_size": [0, 0],
            "page_idx": page_idx,
        })
    (out_dir / "layout.json").write_text(
        json.dumps(layout, ensure_ascii=True, indent=4),
        encoding="utf-8",
    )

    # origin pdf (optional)
    if not args.skip_origin:
        shutil.copy2(pdf_path, out_dir / f"{file_id}_origin.pdf")

    print(json.dumps({
        "pdf": str(pdf_path),
        "out_dir": str(out_dir),
        "bundle_id": bundle_id,
        "file_id": file_id,
    }, ensure_ascii=True))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
