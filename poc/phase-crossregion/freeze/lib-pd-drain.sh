#!/usr/bin/env bash
# freeze/lib-pd-drain.sh — shared PD /pd/api/v1/operators drain-wait poll.
# Sourced by freeze-tidb.sh and scripts/run-vm6-suite.sh (bug #14 fix: ALTER→freeze race).
# Not standalone-executable.
#
# pd_drain_wait <pd_url> <max_sec> <label>
#   Poll every 5s until operators length==0 or max_sec elapsed.
#   Echoes progress; returns 0 if drained, 1 if timed out (caller decides fail-closed policy).
# NOTE: max_sec is caller-supplied and intentionally differs between callers
# (freeze-tidb.sh 150s / run-vm6-suite.sh pre-freeze 300s per bug #14 fix design —
# see SESSION-HISTORY 07-02 節「freeze 內 150s 語意不動」) — do not force a shared default.

pd_drain_wait() {
  local pd_url=$1 max_sec=$2 label=$3
  local iters=$(( (max_sec + 4) / 5 ))
  (( iters < 1 )) && iters=1
  local n=1
  echo "[$label] waiting for PD operators to drain (max ${max_sec}s)..."
  for i in $(seq 1 "$iters"); do
    n=$(curl -sf "${pd_url}/pd/api/v1/operators" 2>/dev/null | jq 'length' 2>/dev/null || echo 1)
    if [[ "$n" -eq 0 ]]; then
      echo "[$label] drained (poll $i/$iters)"
      return 0
    fi
    echo "[$label] poll $i/$iters: $n operator(s) pending, waiting 5s..."
    sleep 5
  done
  echo "[$label] operators still pending after ${max_sec}s ($n remaining)" >&2
  return 1
}
