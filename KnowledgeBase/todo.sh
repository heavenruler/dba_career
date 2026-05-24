#!/usr/bin/env bash
# todo.sh — LLM filter execution queue (auto-generated)
# Generated: 2026-05-24 22:19
#
# Inventory (snapshot at generation):
#   Total extracted docs : 897
#   Already filtered     : 897  (auto-skipped)
#   Pending              : 0
#   Total char (trunc to 60000): 0
#   Est. tokens          : ~0.0M
#   Est. 5h windows      : 1  (~5h wall-clock)
#
# Ordering: char_count desc (longest docs first — most noise to remove = highest filter value)
#
# Usage:
#   ./todo.sh                # run sequentially, idempotent (skip already-filtered)
#   ./todo.sh --dry-run      # show what would run, do not execute
#   Ctrl-C                   # stop; re-run later to resume from where you left off
#
# Behavior:
#   - Per-doc failure → logged to filter_failed.log, continues on next doc
#   - All progress → filter_progress.log
#   - Each completed doc appended to .todo.state ("<doc_id> <ISO timestamp>")
#   - Skip logic = (.todo.state has doc_id) OR (generated/filtered/<doc>/knowledge.json exists)
#   - Codex 5h window 額度滿時，filter_doc 會失敗 → 全部 log 起來；隔一個 window 再跑
#
# Regenerate after adding new PDFs:
#   make todo            # 單獨重生 todo.sh
#   make sync            # extract + OCR + chunks + audit + regen todo

set -o pipefail   # 讓 `make ... | tee` 抓得到 make 的 exit code
# 不用 set -u：bash 3.x/4.x 對空 associative array 的處理不一致，會誤觸發 unbound
cd "$(dirname "$0")"

DRY_RUN=0
[[ "${1:-}" == "--dry-run" ]] && DRY_RUN=1

LOG=filter_progress.log
FAILED_LOG=filter_failed.log
STATE_FILE=.todo.state
mkdir -p generated/filtered
touch "$STATE_FILE"

# Ctrl-C / kill 時清掉子程序（make filter_doc / python / codex），不留孤兒
cleanup() {
  echo
  echo "[todo.sh] interrupted, stopping current filter..."
  pkill -P $$ 2>/dev/null || true
  pkill -f "scripts/filter_doc.py" 2>/dev/null || true
  pkill -f "codex exec --cd.*KnowledgeBase" 2>/dev/null || true
  echo "[todo.sh] stopped. Progress saved in .todo.state. Re-run to resume."
  exit 130
}
trap cleanup INT TERM

# 5h window 額度檢查 — 啟動時 & 每篇開跑前都檢
# 邏輯：取 filter_progress.log 最新 5h 行；若 resets_at 已過 → 視為新 window 放行；
#       否則 remaining < 10% 即 exit 0（保護額度），用戶可等 window 重置後再跑
check_5h_quota() {
  local line remain resets_at resets_epoch now_epoch
  line=$(grep -oE '5h window used=[0-9.]+% remaining=[0-9.]+% resets@[0-9-]+ [0-9:]+' "$LOG" 2>/dev/null | tail -1)
  [[ -z "$line" ]] && return 0    # 沒紀錄 → 放行
  remain=$(echo "$line" | sed -nE 's/.*remaining=([0-9.]+).*/\1/p')
  resets_at=$(echo "$line" | sed -nE 's/.*resets@(.+)$/\1/p')
  resets_epoch=$(date -j -f '%Y-%m-%d %H:%M' "$resets_at" '+%s' 2>/dev/null || echo 0)
  now_epoch=$(date '+%s')
  if [[ "$resets_epoch" -gt 0 ]] && [[ "$now_epoch" -ge "$resets_epoch" ]]; then
    # log 是上一個 window 的，window 已重置 → 新一輪，放行
    return 0
  fi
  if awk -v r="$remain" 'BEGIN{exit !(r+0 < 10)}'; then
    echo "[todo.sh] 5h window remaining=${remain}% < 10% (resets@$resets_at) → 停止以保護額度" | tee -a "$LOG"
    echo "  resume: make filter_all  (在 $resets_at 之後)" | tee -a "$LOG"
    exit 0
  fi
}

# Build "done" set from state file (key=doc_id, value=1)
declare -A DONE_SET
while IFS=' ' read -r doc rest; do
  [[ -n "$doc" ]] && DONE_SET["$doc"]=1
done < "$STATE_FILE"

date '+%Y-%m-%d %H:%M:%S [todo.sh] start' | tee -a "$LOG"
echo "[todo.sh] state file has ${#DONE_SET[@]} previously-marked docs" | tee -a "$LOG"
check_5h_quota   # 啟動就先檢一次，剩餘 <10% 直接退出

DOCS=(
)

TOTAL=${#DOCS[@]}
IDX=0       # 當前位置（含 skipped），決定 [X/TOTAL] 顯示
DONE=0      # 本次實跑的篇數
SKIPPED=0   # 跳過的篇數（state 已標記或 knowledge.json 已存在）
FAILED_CNT=0

for DOC in "${DOCS[@]}"; do
  IDX=$((IDX + 1))
  # Skip if marked done in state file OR if filter output already exists
  if [[ -n "${DONE_SET[$DOC]:-}" ]] || [[ -f "generated/filtered/$DOC/knowledge.json" ]]; then
    SKIPPED=$((SKIPPED + 1))
    # Backfill state file if knowledge.json exists but state file missed it
    if [[ -z "${DONE_SET[$DOC]:-}" ]]; then
      echo "$DOC $(date -u '+%Y-%m-%dT%H:%M:%SZ') backfilled" >> "$STATE_FILE"
      DONE_SET["$DOC"]=1
    fi
    continue
  fi

  if [ "$DRY_RUN" = "1" ]; then
    echo "[dry-run] [$IDX/$TOTAL] make filter_doc DOC_ID=$DOC"
    continue
  fi

  check_5h_quota   # 每篇開跑前先檢，避免燒完 1 篇才發現額度爆
  DONE=$((DONE + 1))
  TS=$(date '+%H:%M:%S')
  echo "[$TS] [$IDX/$TOTAL] filter $DOC  (session#$DONE skipped=$SKIPPED)" | tee -a "$LOG"
  # tee → stdout (前台即時看 token / 5h window) + filter_progress.log
  if make filter_doc DOC_ID="$DOC" 2>&1 | tee -a "$LOG"; then
    # Mark done in state file (append-only, with UTC timestamp)
    echo "$DOC $(date -u '+%Y-%m-%dT%H:%M:%SZ') ok" >> "$STATE_FILE"
    DONE_SET["$DOC"]=1
  else
    FAILED_CNT=$((FAILED_CNT + 1))
    echo "$DOC" >> "$FAILED_LOG"
    echo "  ⚠️  FAIL $DOC (continuing). Reason in $LOG; if quota hit, re-run after 5h window resets."
  fi
done

date '+%Y-%m-%d %H:%M:%S [todo.sh] done' | tee -a "$LOG"
echo "summary: done=$DONE skipped=$SKIPPED failed=$FAILED_CNT total=$TOTAL"
if [ "$FAILED_CNT" -gt 0 ]; then
  echo "failed doc_ids in: $FAILED_LOG"
  exit 1
fi
exit 0
