#!/usr/bin/env bash
# Suite wrapper: gate → prepare → run → collect, fixed TPCC_TS.
# Designed to run on .31 in the background (launched via launch-vm1-suite.sh).
#
# Usage:
#   run-vm1-suite.sh --db <db> --iso <iso> --topology <topo> \
#                    --db-host <ip> --ts <ts>
#
# Env (inherited):
#   TPCC_BASE, TPCC_ARTIFACTS, WAREHOUSES, THREADS_LIST, ROUNDS,
#   WARMUP_SEC, RUN_SEC, ROUND_SLEEP_SEC, per-DB PORT/USER/DB

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" ISO="" TOPO="" DB_HOST="" TS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --iso) ISO=$2; shift 2 ;;
    --topology) TOPO=$2; shift 2 ;;
    --db-host) DB_HOST=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB" && -n "$ISO" && -n "$TOPO" && -n "$DB_HOST" && -n "$TS" ]] || die "missing required args"

: "${TPCC_BASE:=/tmp/poc-tpcc}"
: "${TPCC_ARTIFACTS:=$TPCC_BASE/artifacts}"
RUNLOCKS_DIR="$TPCC_BASE/runlocks"
LOG_DIR="$TPCC_BASE/logs"
mkdir -p "$RUNLOCKS_DIR" "$LOG_DIR"

LOCK_FILE="$RUNLOCKS_DIR/${DB}-${TOPO}-${ISO}.lock"
LOG_FILE="$LOG_DIR/${DB}-${TOPO}-${ISO}-${TS}.log"

# Suite-level lock: atomic create via hard link (ln). Fail closed on collision.
LOCK_TMP="${LOCK_FILE}.$$"
cat > "$LOCK_TMP" <<EOF
pid=$$
db=$DB
iso=$ISO
topology=$TOPO
ts=$TS
start_time=$(date '+%Y-%m-%dT%H:%M:%S%z')
log_path=$LOG_FILE
EOF
if ! ln "$LOCK_TMP" "$LOCK_FILE" 2>/dev/null; then
  rm -f "$LOCK_TMP"
  prev_pid=$(awk -F= '/^pid=/{print $2}' "$LOCK_FILE" 2>/dev/null || true)
  if [[ -n "$prev_pid" ]] && kill -0 "$prev_pid" 2>/dev/null; then
    die "suite already running: pid=$prev_pid lock=$LOCK_FILE"
  fi
  die "stale lock present (pid=$prev_pid not running). Inspect & remove manually: $LOCK_FILE"
fi
rm -f "$LOCK_TMP"

cleanup() {
  local rc=$?
  if [[ $rc -eq 0 ]]; then
    rm -f "$LOCK_FILE"
    info "suite complete; lock removed"
  else
    info "suite failed (rc=$rc); lock kept for inspection: $LOCK_FILE"
  fi
}
trap cleanup EXIT

info "suite start db=$DB iso=$ISO topo=$TOPO ts=$TS"
info "log=$LOG_FILE"
info "artifact=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")"

info "[1/4] gate"
bash "$SELF/gate.sh" --db "$DB" --iso "$ISO" --db-host "$DB_HOST" --ts "$TS"

info "[2/4] prepare"
bash "$SELF/prepare.sh" --db "$DB" --iso "$ISO" --topology "$TOPO" --db-host "$DB_HOST" --ts "$TS"

info "[3/4] run"
bash "$SELF/run.sh" --db "$DB" --iso "$ISO" --topology "$TOPO" --db-host "$DB_HOST" --ts "$TS"

info "[4/4] collect"
bash "$SELF/collect.sh" --db "$DB" --iso "$ISO" --topology "$TOPO" --db-host "$DB_HOST" --ts "$TS"

ROOT=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")
write_phase_done "$ROOT" "suite" "$(cat <<JSON
{
  "phase": "suite",
  "db": "$DB",
  "iso": "$ISO",
  "topology": "$TOPO",
  "ts": "$TS",
  "completed_at": "$(date '+%Y-%m-%dT%H:%M:%S%z')"
}
JSON
)"

info "suite done: $ROOT"
