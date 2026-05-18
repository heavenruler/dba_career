#!/usr/bin/env bash
# Read-only status for a vm-1node suite.
#
# Reports:
#   - suite lock (PID alive / dead)
#   - artifact markers: .gate.done / .prepare.done / .run.done / .collect.done / .suite.done
#   - latest log tail
#
# Usage:
#   status-vm1.sh --db <db> --topology <topo> --iso <iso>

set -uo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)

DB="" ISO="" TOPO=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --iso) ISO=$2; shift 2 ;;
    --topology) TOPO=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
for v in DB ISO TOPO; do
  [[ -n "${!v}" ]] || { echo "missing required arg: --${v,,}" >&2; exit 1; }
done

: "${TPCC_BASE:=/tmp/poc-tpcc}"
: "${TPCC_ARTIFACTS:=$TPCC_BASE/artifacts}"

LOCK="$TPCC_BASE/runlocks/${DB}-${TOPO}-${ISO}.lock"
TS=""
LOG=""

echo "=== suite lock ==="
echo "lock=$LOCK"
if [[ -e "$LOCK" ]]; then
  cat "$LOCK"
  pid=$(awk -F= '/^pid=/{print $2}' "$LOCK" 2>/dev/null || true)
  if [[ -n "$pid" ]]; then
    if kill -0 "$pid" 2>/dev/null; then
      echo "pid_state=running"
    else
      echo "pid_state=DEAD (stale lock; inspect manually)"
    fi
  fi
  TS=$(awk -F= '/^ts=/{print $2}' "$LOCK" 2>/dev/null || true)
  LOG=$(awk -F= '/^log_path=/{print $2}' "$LOCK" 2>/dev/null || true)
else
  echo "(no active lock; suite may be done or never started)"
fi

# If lock not present, fall back to latest artifact (by mtime)
if [[ -z "$TS" ]]; then
  latest=$(ls -dt "$TPCC_ARTIFACTS/${DB}-${TOPO}-${ISO}-"*/ 2>/dev/null | head -1)
  if [[ -z "$latest" ]]; then
    echo
    echo "no artifact found for ${DB}-${TOPO}-${ISO}"
    exit 0
  fi
  TS=$(basename "${latest%/}" | sed "s|^${DB}-${TOPO}-${ISO}-||")
  LOG="$TPCC_BASE/logs/${DB}-${TOPO}-${ISO}-${TS}.log"
fi

ROOT="$TPCC_ARTIFACTS/${DB}-${TOPO}-${ISO}-${TS}"
echo
echo "=== artifact markers ==="
echo "artifact=$ROOT"
for marker in gate prepare run collect suite; do
  f="$ROOT/.$marker.done"
  if [[ -e "$f" ]]; then
    echo "  [DONE]    .$marker.done"
  else
    echo "  [missing] .$marker.done"
  fi
done

echo
echo "=== latest log tail (last 20 lines) ==="
if [[ -e "$LOG" ]]; then
  echo "log=$LOG"
  tail -20 "$LOG"
else
  echo "(no log file: $LOG)"
fi
