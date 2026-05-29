#!/usr/bin/env bash
# Detached launcher for run-vm1-suite.sh.
# Called via ssh from MAC; returns immediately after the suite is in flight.
#
# Usage:
#   launch-vm1-suite.sh --db <db> --iso <iso> --topology <topo> \
#                       --db-host <ip> --ts <ts>
#
# Env (forwarded to suite via current environment):
#   TPCC_BASE, TPCC_ARTIFACTS, WAREHOUSES, THREADS_LIST, ROUNDS,
#   WARMUP_SEC, RUN_SEC, ROUND_SLEEP_SEC, per-DB PORT/USER/DB

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)

DB="" ISO="" TOPO="" DB_HOST="" TS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --iso) ISO=$2; shift 2 ;;
    --topology) TOPO=$2; shift 2 ;;
    --db-host) DB_HOST=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
for v in DB ISO TOPO DB_HOST TS; do
  [[ -n "${!v}" ]] || { echo "missing required arg: --${v,,}" >&2; exit 1; }
done

: "${TPCC_BASE:=/tmp/poc-tpcc}"
mkdir -p "$TPCC_BASE/logs" "$TPCC_BASE/runlocks"

LOCK="$TPCC_BASE/runlocks/${DB}-${TOPO}-${ISO}.lock"
LOG="$TPCC_BASE/logs/${DB}-${TOPO}-${ISO}-${TS}.log"

# Fail-fast on existing lock (suite.sh re-checks, but we want clear MAC feedback)
# stale lock auto-removed here so N=2/N=3 批次重跑不會卡死；suite.sh 內部還有 ln() race check。
if [[ -e "$LOCK" ]]; then
  prev_pid=$(awk -F= '/^pid=/{print $2}' "$LOCK" 2>/dev/null || true)
  if [[ -n "$prev_pid" ]] && kill -0 "$prev_pid" 2>/dev/null; then
    echo "ERROR: suite already running pid=$prev_pid lock=$LOCK" >&2
    cat "$LOCK" >&2 || true
    exit 2
  fi
  echo "WARN: stale lock (pid=$prev_pid not running); auto-removing $LOCK" >&2
  cat "$LOCK" >&2 || true
  rm -f "$LOCK"
fi

# Detach: setsid + nohup + redirect all stdio + disown
nohup setsid bash "$SELF/run-vm1-suite.sh" \
    --db "$DB" --iso "$ISO" --topology "$TOPO" \
    --db-host "$DB_HOST" --ts "$TS" \
    </dev/null >"$LOG" 2>&1 &
suite_pid=$!
disown 2>/dev/null || true

# Wait up to 10s for suite.sh to write the lock (proves it actually started)
for _ in 1 2 3 4 5 6 7 8 9 10; do
  [[ -e "$LOCK" ]] && break
  sleep 1
done

if [[ ! -e "$LOCK" ]]; then
  echo "ERROR: suite did not create lock within 10s. Check log:" >&2
  echo "  $LOG" >&2
  tail -40 "$LOG" >&2 || true
  exit 4
fi

echo "OK suite launched"
echo "log=$LOG"
echo "wrapper_pid=$suite_pid"
cat "$LOCK"
