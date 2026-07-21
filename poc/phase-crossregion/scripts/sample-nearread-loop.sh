#!/usr/bin/env bash
# phase-crossregion/scripts/sample-nearread-loop.sh
#
# A7(4) 補強（codex 審查 2026-07-22 建議）：check-nearread.sh 之前只在
# 空閒連線上驗證過一次；本腳本在 aaro-smoke 高併發（t128）執行期間，每
# --interval-sec 重複呼叫 check-nearread.sh 取樣，寫入 --log，供事後檢查
# 「高併發負載下是否曾退化（fallback 回 leader）」。設計為呼叫端在背景
# （&）與主線程的 aaro-smoke 同時跑，主線程跑完後用 `wait` 收尾。
#
# 不用 `set -e`：單次取樣失敗要記錄下來繼續採樣，不能讓整個迴圈中止。
#
# Usage:
#   sample-nearread-loop.sh --db <tidb|crdb|ybdb> --host <gcp-host> --port <port> \
#     --duration-sec <N> --interval-sec <M> --log <path>
set -uo pipefail

DB="" HOST="" PORT="" DURATION="" INTERVAL="" LOG=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --host) HOST=$2; shift 2 ;;
    --port) PORT=$2; shift 2 ;;
    --duration-sec) DURATION=$2; shift 2 ;;
    --interval-sec) INTERVAL=$2; shift 2 ;;
    --log) LOG=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${DB:?--db required}"
: "${HOST:?--host required}"
: "${PORT:?--port required}"
: "${DURATION:?--duration-sec required}"
: "${INTERVAL:?--interval-sec required}"
: "${LOG:?--log required}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DETAIL_LOG="$LOG.detail"
: > "$LOG"
: > "$DETAIL_LOG"

END=$(( $(date +%s) + DURATION ))
i=0
while [[ $(date +%s) -lt $END ]]; do
  i=$((i+1))
  ts=$(date '+%Y-%m-%dT%H:%M:%S%z')
  {
    echo "=== sample $i @ $ts ==="
    bash "$SCRIPT_DIR/check-nearread.sh" --db "$DB" --host "$HOST" --port "$PORT"
  } >> "$DETAIL_LOG" 2>&1
  rc=$?
  if [[ $rc -eq 0 ]]; then
    echo "$ts sample=$i PASS" >> "$LOG"
  else
    echo "$ts sample=$i FAIL" >> "$LOG"
  fi
  sleep "$INTERVAL"
done
echo "=== loop done: $i samples over ${DURATION}s (interval=${INTERVAL}s) ===" >> "$LOG"
