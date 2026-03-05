#!/usr/bin/env python3
"""
PDF -> text (pypdf or OCR) -> chunk -> embeddings -> JSONL.

Usage:
  python tools/pdf_ocr_pipeline.py --pdf <path> --out <path>
"""

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Iterable, List, Optional, Tuple


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


def _line_is_noisy(line: str, repeated: bool) -> bool:
    stripped = line.strip()
    if not stripped:
        return True
    if len(stripped) < 3:
        return True

    lower = stripped.lower()
    nav_keywords = [
        "product",
        "solutions",
        "resources",
        "company",
        "docs",
        "blog",
        "pricing",
        "careers",
        "contact",
        "support",
        "sign in",
        "start for free",
        "learn more",
    ]
    nav_hits = sum(1 for k in nav_keywords if k in lower)
    if nav_hits >= 3:
        return True

    alnum_count = sum(1 for c in stripped if c.isalnum())
    if alnum_count / max(1, len(stripped)) < 0.3:
        return True

    if repeated and len(stripped) < 50:
        return True

    return False


def _clean_lines(text: str) -> str:
    lines = [l.strip() for l in text.split("\n")]
    counts = {}
    for line in lines:
        if line:
            counts[line] = counts.get(line, 0) + 1

    cleaned: List[str] = []
    for line in lines:
        if _line_is_noisy(line, repeated=counts.get(line, 0) >= 2):
            continue
        cleaned.append(line)

    return "\n".join(cleaned)


def normalize_text(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.sub(r"[\uE000-\uF8FF]", " ", text)
    text = _clean_lines(text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    return text.strip()


def chunk_text(text: str, max_len: int) -> List[Tuple[str, int, int]]:
    paras = [p.strip() for p in text.split("\n\n") if p.strip()]
    if not paras:
        return []

    para_positions: List[Tuple[int, int]] = []
    cursor = 0
    for i, p in enumerate(paras):
        start = cursor
        end = start + len(p)
        para_positions.append((start, end))
        cursor = end + (2 if i < len(paras) - 1 else 0)

    chunks: List[Tuple[str, int, int]] = []
    current_paras: List[str] = []
    current_start = 0
    current_end = 0

    for i, p in enumerate(paras):
        candidate = p if not current_paras else "\n\n".join(current_paras + [p])
        if len(candidate) <= max_len:
            if not current_paras:
                current_start = para_positions[i][0]
            current_paras.append(p)
            current_end = para_positions[i][1]
        else:
            if current_paras:
                chunks.append(("\n\n".join(current_paras), current_start, current_end))
            current_paras = [p]
            current_start = para_positions[i][0]
            current_end = para_positions[i][1]

    if current_paras:
        chunks.append(("\n\n".join(current_paras), current_start, current_end))

    return chunks


def embed_texts(texts: Iterable[str], model: str) -> List[List[float]]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    try:
        from openai import OpenAI  # type: ignore
    except Exception as exc:
        raise RuntimeError(f"openai not available: {exc}")

    client = OpenAI(api_key=api_key)
    embeddings: List[List[float]] = []
    batch: List[str] = []
    batch_size = 64
    for text in texts:
        batch.append(text)
        if len(batch) >= batch_size:
            resp = client.embeddings.create(model=model, input=batch)
            embeddings.extend([d.embedding for d in resp.data])
            batch = []
    if batch:
        resp = client.embeddings.create(model=model, input=batch)
        embeddings.extend([d.embedding for d in resp.data])
    return embeddings


def load_pages(pdf_path: Path, ocr_lang: str, ocr_dir: Path, ocr_min_chars: int) -> List[Tuple[int, str, bool]]:
    pages: List[Tuple[int, str, bool]] = []
    try:
        extracted = extract_text_pypdf(pdf_path)
    except Exception:
        extracted = []

    if extracted:
        for idx, text in enumerate(extracted):
            if len(text.strip()) >= ocr_min_chars:
                pages.append((idx + 1, normalize_text(text), False))
            else:
                ocr_text = ocr_page(pdf_path, idx, ocr_dir, ocr_lang)
                pages.append((idx + 1, normalize_text(ocr_text), True))
    else:
        page_count = 1
        try:
            from pypdf import PdfReader  # type: ignore
            page_count = len(PdfReader(str(pdf_path)).pages)
        except Exception:
            pass
        for idx in range(page_count):
            ocr_text = ocr_page(pdf_path, idx, ocr_dir, ocr_lang)
            pages.append((idx + 1, normalize_text(ocr_text), True))
    return pages


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pdf", required=True)
    parser.add_argument("--out", required=True)
    parser.add_argument("--out-embeddings")
    parser.add_argument("--lang", default="chi_tra+eng")
    parser.add_argument("--max-len", type=int, default=800)
    parser.add_argument("--ocr-dir", default="ocr_cache")
    parser.add_argument("--ocr-min-chars", type=int, default=40)
    parser.add_argument("--model", default="text-embedding-3-small")
    parser.add_argument("--no-embed", action="store_true")

    args = parser.parse_args()
    pdf_path = Path(args.pdf)
    out_path = Path(args.out)
    ocr_dir = Path(args.ocr_dir) / pdf_path.stem

    pages = load_pages(pdf_path, args.lang, ocr_dir, args.ocr_min_chars)

    records = []
    clean_rules = ["remove_pua", "remove_nav", "remove_short_lines", "remove_lowinfo_lines", "remove_repeats"]
    for page_num, text, ocr_used in pages:
        if not text:
            continue
        for chunk_index, (chunk, start, end) in enumerate(chunk_text(text, args.max_len)):
            text_hash = hashlib.sha1(chunk.encode("utf-8", errors="ignore")).hexdigest()
            records.append({
                "id": None,
                "doc_id": pdf_path.stem,
                "source": pdf_path.name,
                "source_path": str(pdf_path),
                "page": page_num,
                "chunk_index": chunk_index,
                "char_start": start,
                "char_end": end,
                "lang": args.lang,
                "cleaned": True,
                "clean_rules": clean_rules,
                "ocr": ocr_used,
                "ocr_lang": args.lang if ocr_used else None,
                "text_hash": text_hash,
                "text": chunk,
            })

    for i, rec in enumerate(records):
        rec["id"] = f"{pdf_path.stem}-chunk-{i}"

    embeddings_output: Optional[Path] = None
    if not args.no_embed and records:
        embeddings = embed_texts([r["text"] for r in records], args.model)
        embeddings_output = Path(args.out_embeddings) if args.out_embeddings else None
        if embeddings_output is None:
            if out_path.suffix == ".jsonl":
                embeddings_output = out_path.with_name(out_path.stem + ".embeddings.jsonl")
            else:
                embeddings_output = Path(str(out_path) + ".embeddings.jsonl")
        embeddings_output.parent.mkdir(parents=True, exist_ok=True)
        with embeddings_output.open("w", encoding="utf-8") as f:
            for rec, emb in zip(records, embeddings):
                f.write(json.dumps({
                    "id": rec["id"],
                    "doc_id": rec["doc_id"],
                    "chunk_index": rec["chunk_index"],
                    "embedding": emb,
                    "embedding_model": args.model,
                }, ensure_ascii=True) + "\n")

    out_path.parent.mkdir(parents=True, exist_ok=True)
    with out_path.open("w", encoding="utf-8") as f:
        for rec in records:
            f.write(json.dumps(rec, ensure_ascii=True) + "\n")

    print(json.dumps({
        "pdf": str(pdf_path),
        "pages": len(pages),
        "chunks": len(records),
        "out": str(out_path),
        "embeddings_out": (str(embeddings_output) if embeddings_output else None),
        "embedded": (not args.no_embed),
    }, ensure_ascii=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
