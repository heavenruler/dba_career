#!/usr/bin/env python3
import argparse
import hashlib
import re
import sys
from pathlib import Path


def compute_md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Repair missing or invalid manifest doc IDs.")
    parser.add_argument("--path", type=Path, default=Path("output_with_md5.txt"))
    args = parser.parse_args()
    path = args.path
    if not path.exists():
        print("找不到 output_with_md5.txt", file=sys.stderr)
        return 1

    # 讀取並分塊（以 ---- 行分隔）
    lines = path.read_text(encoding="utf-8").splitlines()
    blocks = []
    current = []
    for line in lines:
        if line.strip() == "----":
            blocks.append(current)
            current = []
        else:
            current.append(line)
    # 若最後沒有以 ---- 結尾，仍將殘留加入
    if current:
        blocks.append(current)

    out_lines = []
    repaired = 0
    preserved_mismatches = 0
    for block in blocks:
        if not block:
            # 空塊，保持分隔
            out_lines.append("----")
            continue

        title = block[0] if len(block) > 0 else ""
        url = block[1] if len(block) > 1 else ""
        old_hash = block[2] if len(block) > 2 else ""

        if url:
            correct = compute_md5(url)
        else:
            correct = old_hash

        if not re.fullmatch(r"[0-9a-f]{32}", old_hash):
            new_hash = correct
            repaired += 1
        else:
            new_hash = old_hash
            if url and old_hash != correct:
                preserved_mismatches += 1

        out_lines.extend([title, url, new_hash, "----"])

    path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    print(
        f"已檢查 {len(blocks)} 個區塊；修補 {repaired} 筆；"
        f"保留 {preserved_mismatches} 筆合法既有 doc_id（與目前 URL MD5 不同）"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
