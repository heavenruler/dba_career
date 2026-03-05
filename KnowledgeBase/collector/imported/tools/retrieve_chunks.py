#!/usr/bin/env python3
"""
Retrieve top-k chunks by cosine similarity from embeddings.jsonl.

Usage:
  python tools/retrieve_chunks.py \
    --query "your question" \
    --docs outputs/xxx.jsonl \
    --embeddings outputs/xxx.embeddings.jsonl
"""

import argparse
import json
import math
import os
from typing import Dict, List, Tuple


def load_docs(path: str) -> Dict[str, dict]:
    docs: Dict[str, dict] = {}
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            rec = json.loads(line)
            docs[rec["id"]] = rec
    return docs


def load_embeddings(path: str) -> List[dict]:
    items: List[dict] = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            items.append(json.loads(line))
    return items


def cosine(a: List[float], b: List[float]) -> float:
    dot = 0.0
    norm_a = 0.0
    norm_b = 0.0
    for x, y in zip(a, b):
        dot += x * y
        norm_a += x * x
        norm_b += y * y
    if norm_a == 0.0 or norm_b == 0.0:
        return 0.0
    return dot / (math.sqrt(norm_a) * math.sqrt(norm_b))


def embed_query(text: str, model: str) -> List[float]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("OPENAI_API_KEY is not set")

    try:
        from openai import OpenAI  # type: ignore
    except Exception as exc:
        raise RuntimeError(f"openai not available: {exc}")

    client = OpenAI(api_key=api_key)
    resp = client.embeddings.create(model=model, input=[text])
    return resp.data[0].embedding


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--query", required=True)
    parser.add_argument("--docs", required=True)
    parser.add_argument("--embeddings", required=True)
    parser.add_argument("--top-k", type=int, default=5)
    parser.add_argument("--model", default="text-embedding-3-small")
    args = parser.parse_args()

    docs = load_docs(args.docs)
    items = load_embeddings(args.embeddings)
    query_vec = embed_query(args.query, args.model)

    scored: List[Tuple[float, dict]] = []
    for item in items:
        score = cosine(query_vec, item["embedding"])
        doc = docs.get(item["id"], {})
        scored.append((score, {
            "score": score,
            "id": item["id"],
            "doc_id": item.get("doc_id"),
            "chunk_index": item.get("chunk_index"),
            "page": doc.get("page"),
            "text": doc.get("text"),
        }))

    scored.sort(key=lambda x: x[0], reverse=True)
    for _, row in scored[: args.top_k]:
        print(json.dumps(row, ensure_ascii=True))

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
