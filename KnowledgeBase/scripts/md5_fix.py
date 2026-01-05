#!/usr/bin/env python3
import hashlib
import sys
from pathlib import Path


def compute_md5(text: str) -> str:
    return hashlib.md5(text.encode("utf-8")).hexdigest()


def main() -> int:
    path = Path("output_with_md5.txt")
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

        if (not old_hash) or (old_hash == "nnn") or (len(old_hash) != 32) or (old_hash != correct):
            new_hash = correct
        else:
            new_hash = old_hash

        out_lines.extend([title, url, new_hash, "----"])

    path.write_text("\n".join(out_lines) + "\n", encoding="utf-8")
    print(f"已修補 {len(blocks)} 個區塊並更新 MD5")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())


