#!/usr/bin/env python3
"""Regenerate todo.sh — LLM filter execution queue.

Reads all generated/extracted/<doc_id>/metadata.json (status=ok), skips docs
that already have generated/filtered/<doc_id>/knowledge.json, sorts by
char_count desc (longest = highest filter value), and emits a bash script
with batch markers per ~5h codex window.

Idempotent: safe to re-run any time (especially after adding new PDFs +
make extract_pdf / make ocr_pdf). Existing .todo.state in working dir is
preserved — runtime skip-logic still works on the new list.
"""
import json
from datetime import datetime
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
EXTRACTED = ROOT / "generated" / "extracted"
FILTERED = ROOT / "generated" / "filtered"
TODO_PATH = ROOT / "todo.sh"

BATCH_SIZE = 100  # docs per 5h codex window (rough)
MAX_INPUT_CHARS = 60000  # mirror filter_doc.py MAX_INPUT_CHARS


def collect_docs() -> list[dict]:
    docs: list[dict] = []
    for meta_path in EXTRACTED.glob("*/metadata.json"):
        meta = json.loads(meta_path.read_text(encoding="utf-8"))
        if meta.get("status") != "ok":
            continue
        docs.append({
            "doc_id": meta["doc_id"],
            "char_count": meta.get("char_count", 0),
            "ocr_used": meta.get("ocr_used", False),
            "source_domain": meta.get("source_domain") or "unknown",
            "title": (meta.get("title") or "")[:60].replace("\n", " "),
        })
    docs.sort(key=lambda d: -d["char_count"])
    return docs


def build_script(docs: list[dict]) -> str:
    pending = [d for d in docs if not (FILTERED / d["doc_id"] / "knowledge.json").exists()]
    already = len(docs) - len(pending)
    total_chars_pending = sum(min(d["char_count"], MAX_INPUT_CHARS) for d in pending)
    n_windows = max(1, (len(pending) + BATCH_SIZE - 1) // BATCH_SIZE)
    est_tokens_m = (total_chars_pending + len(pending) * 3000) / 1_000_000

    lines = []
    lines.append("#!/usr/bin/env bash")
    lines.append("# todo.sh — LLM filter execution queue (auto-generated)")
    lines.append(f"# Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    lines.append("#")
    lines.append("# Inventory (snapshot at generation):")
    lines.append(f"#   Total extracted docs : {len(docs)}")
    lines.append(f"#   Already filtered     : {already}  (auto-skipped)")
    lines.append(f"#   Pending              : {len(pending)}")
    lines.append(f"#   Total char (trunc to {MAX_INPUT_CHARS}): {total_chars_pending:,}")
    lines.append(f"#   Est. tokens          : ~{est_tokens_m:.1f}M")
    lines.append(f"#   Est. 5h windows      : {n_windows}  (~{n_windows * 5}h wall-clock)")
    lines.append("#")
    lines.append("# Ordering: char_count desc (longest docs first — most noise to remove = highest filter value)")
    lines.append("#")
    lines.append("# Usage:")
    lines.append("#   ./todo.sh                # run sequentially, idempotent (skip already-filtered)")
    lines.append("#   ./todo.sh --dry-run      # show what would run, do not execute")
    lines.append("#   Ctrl-C                   # stop; re-run later to resume from where you left off")
    lines.append("#")
    lines.append("# Behavior:")
    lines.append("#   - Per-doc failure → logged to filter_failed.log, continues on next doc")
    lines.append("#   - All progress → filter_progress.log")
    lines.append('#   - Each completed doc appended to .todo.state ("<doc_id> <ISO timestamp>")')
    lines.append("#   - Skip logic = (.todo.state has doc_id) OR (generated/filtered/<doc>/knowledge.json exists)")
    lines.append("#   - Codex 5h window 額度滿時，filter_doc 會失敗 → 全部 log 起來；隔一個 window 再跑")
    lines.append("#")
    lines.append("# Regenerate after adding new PDFs:")
    lines.append("#   make todo            # 單獨重生 todo.sh")
    lines.append("#   make sync            # extract + OCR + chunks + audit + regen todo")
    lines.append("")
    lines.append("set -o pipefail   # 讓 `make ... | tee` 抓得到 make 的 exit code")
    lines.append("# 不用 set -u：bash 3.x/4.x 對空 associative array 的處理不一致，會誤觸發 unbound")
    lines.append('cd "$(dirname "$0")"')
    lines.append("")
    lines.append("DRY_RUN=0")
    lines.append('[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1')
    lines.append("")
    lines.append("LOG=filter_progress.log")
    lines.append("FAILED_LOG=filter_failed.log")
    lines.append("STATE_FILE=.todo.state")
    lines.append("mkdir -p generated/filtered")
    lines.append('touch "$STATE_FILE"')
    lines.append("")
    lines.append("# Ctrl-C / kill 時清掉子程序（make filter_doc / python / codex），不留孤兒")
    lines.append("cleanup() {")
    lines.append('  echo')
    lines.append('  echo "[todo.sh] interrupted, stopping current filter..."')
    lines.append('  pkill -P $$ 2>/dev/null || true')
    lines.append('  pkill -f "scripts/filter_doc.py" 2>/dev/null || true')
    lines.append('  pkill -f "codex exec --cd.*KnowledgeBase" 2>/dev/null || true')
    lines.append('  echo "[todo.sh] stopped. Progress saved in .todo.state. Re-run to resume."')
    lines.append('  exit 130')
    lines.append("}")
    lines.append("trap cleanup INT TERM")
    lines.append("")
    lines.append("# Build \"done\" set from state file (key=doc_id, value=1)")
    lines.append("declare -A DONE_SET")
    lines.append("while IFS=' ' read -r doc rest; do")
    lines.append('  [[ -n "$doc" ]] && DONE_SET["$doc"]=1')
    lines.append('done < "$STATE_FILE"')
    lines.append("")
    lines.append("date '+%Y-%m-%d %H:%M:%S [todo.sh] start' | tee -a \"$LOG\"")
    lines.append('echo "[todo.sh] state file has ${#DONE_SET[@]} previously-marked docs" | tee -a "$LOG"')
    lines.append("")
    lines.append("DOCS=(")
    for i, d in enumerate(pending):
        if i % BATCH_SIZE == 0:
            window_idx = i // BATCH_SIZE + 1
            slice_end = min(i + BATCH_SIZE, len(pending))
            avg_chars = sum(x["char_count"] for x in pending[i:slice_end]) // max(1, slice_end - i)
            lines.append(f"  # === window {window_idx}/{n_windows} ({i+1}-{slice_end}, avg {avg_chars} chars/doc) ===")
        title = d["title"].replace('"', "'").replace("`", "'")[:50]
        lines.append(f'  {d["doc_id"]}  # {d["char_count"]:>6d}c  {d["source_domain"]:25s} {title}')
    lines.append(")")
    lines.append("")
    lines.append("TOTAL=${#DOCS[@]}")
    lines.append("IDX=0       # 當前位置（含 skipped），決定 [X/TOTAL] 顯示")
    lines.append("DONE=0      # 本次實跑的篇數")
    lines.append("SKIPPED=0   # 跳過的篇數（state 已標記或 knowledge.json 已存在）")
    lines.append("FAILED_CNT=0")
    lines.append("")
    lines.append('for DOC in "${DOCS[@]}"; do')
    lines.append("  IDX=$((IDX + 1))")
    lines.append("  # Skip if marked done in state file OR if filter output already exists")
    lines.append('  if [[ -n "${DONE_SET[$DOC]:-}" ]] || [[ -f "generated/filtered/$DOC/knowledge.json" ]]; then')
    lines.append("    SKIPPED=$((SKIPPED + 1))")
    lines.append("    # Backfill state file if knowledge.json exists but state file missed it")
    lines.append('    if [[ -z "${DONE_SET[$DOC]:-}" ]]; then')
    lines.append('      echo "$DOC $(date -u \'+%Y-%m-%dT%H:%M:%SZ\') backfilled" >> "$STATE_FILE"')
    lines.append('      DONE_SET["$DOC"]=1')
    lines.append("    fi")
    lines.append("    continue")
    lines.append("  fi")
    lines.append("")
    lines.append('  if [ "$DRY_RUN" = "1" ]; then')
    lines.append('    echo "[dry-run] [$IDX/$TOTAL] make filter_doc DOC_ID=$DOC"')
    lines.append("    continue")
    lines.append("  fi")
    lines.append("")
    lines.append("  DONE=$((DONE + 1))")
    lines.append("  TS=$(date '+%H:%M:%S')")
    lines.append('  echo "[$TS] [$IDX/$TOTAL] filter $DOC  (session#$DONE skipped=$SKIPPED)" | tee -a "$LOG"')
    lines.append('  # tee → stdout (前台即時看 token / 5h window) + filter_progress.log')
    lines.append('  if make filter_doc DOC_ID="$DOC" 2>&1 | tee -a "$LOG"; then')
    lines.append("    # Mark done in state file (append-only, with UTC timestamp)")
    lines.append('    echo "$DOC $(date -u \'+%Y-%m-%dT%H:%M:%SZ\') ok" >> "$STATE_FILE"')
    lines.append('    DONE_SET["$DOC"]=1')
    lines.append("  else")
    lines.append("    FAILED_CNT=$((FAILED_CNT + 1))")
    lines.append('    echo "$DOC" >> "$FAILED_LOG"')
    lines.append('    echo "  ⚠️  FAIL $DOC (continuing). Reason in $LOG; if quota hit, re-run after 5h window resets."')
    lines.append("  fi")
    lines.append("done")
    lines.append("")
    lines.append("date '+%Y-%m-%d %H:%M:%S [todo.sh] done' | tee -a \"$LOG\"")
    lines.append('echo "summary: done=$DONE skipped=$SKIPPED failed=$FAILED_CNT total=$TOTAL"')
    lines.append('[ "$FAILED_CNT" -gt 0 ] && echo "failed doc_ids in: $FAILED_LOG"')
    lines.append("")
    return "\n".join(lines)


def main() -> int:
    docs = collect_docs()
    if not docs:
        raise SystemExit("no extracted docs found — run make extract_pdf first")
    content = build_script(docs)
    TODO_PATH.write_text(content, encoding="utf-8")
    TODO_PATH.chmod(0o755)
    pending = sum(1 for d in docs if not (FILTERED / d["doc_id"] / "knowledge.json").exists())
    print(f"regenerated {TODO_PATH.relative_to(ROOT)}: {len(docs)} docs, {pending} pending")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
