#!/usr/bin/env bash
# Phase 5 (run) — 1 cold-reset + warmup 20m + 5 round × 5 min × 4 threads, with parallel OS monitor.
#
# Usage:
#   run.sh --db <tidb|crdb|ybdb> --iso <rc|rr|strict> \
#          --topology <vm-1node|...> --db-host <ip> --ts <ts>
#
# Env (Makefile-provided):
#   TPCC_ARTIFACTS, WAREHOUSES, THREADS_LIST (default "16 32 64 128"),
#   ROUNDS (default 5), WARMUP_SEC (default 1200), RUN_SEC (default 300),
#   ROUND_SLEEP_SEC (default 60),
#   per-DB PORT/USER/DB + conn-params

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" ISO="" TOPO="vm-1node" DB_HOST="" TS=""
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
[[ -n "$DB" && -n "$ISO" && -n "$DB_HOST" && -n "$TS" ]] || die "missing required args"

: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts}"
: "${WAREHOUSES:=128}"
: "${THREADS_LIST:=16 32 64 128}"
: "${ROUNDS:=5}"
: "${WARMUP_SEC:=1200}"
: "${RUN_SEC:=300}"
: "${ROUND_SLEEP_SEC:=60}"

ROOT=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")
if [[ ! -f "$ROOT/.prepare.done" ]]; then
  latest=$(ls -d "${TPCC_ARTIFACTS}/${DB}-${TOPO}-${ISO}-"*/.prepare.done 2>/dev/null | sort | tail -1)
  [[ -n "$latest" ]] || die "prepare phase not complete: no .prepare.done found for $DB/$TOPO/$ISO"
  ROOT=$(dirname "$latest")
  TS=$(basename "$ROOT" | sed "s|${DB}-${TOPO}-${ISO}-||")
  warn "TS auto-detected from latest prepare: $TS"
fi
flock_phase "$ROOT" "run"

RUNS_DIR="$ROOT/runs"
mkdir -p "$RUNS_DIR"
ISO_CONN_PARAMS=$(get_conn_params "$DB" "$ISO")
DRIVER=$(get_driver "$DB")

case "$DB" in
  tidb) PORT="${TIDB_PORT:-4000}"; USER="${TIDB_USER:-root}"; DBNAME="${TIDB_DB:-tpcc}" ;;
  crdb) PORT="${CRDB_PORT:-26257}"; USER="${CRDB_USER:-root}"; DBNAME="${CRDB_DB:-tpcc}" ;;
  ybdb) PORT="${YBDB_PORT:-5433}"; USER="${YBDB_USER:-yugabyte}"; DBNAME="${YBDB_DB:-tpcc}" ;;
esac

info "run start  db=$DB iso=$ISO topo=$TOPO host=$DB_HOST"

# ---- 1. cold-reset (per-DB script) ---------------------------------
info "cold-reset"
bash "$SELF/coldreset-${DB}.sh" --db-host "$DB_HOST"

# ---- 2. active isolation gate (call gate-isolation.sh) -------------
info "active isolation gate"
bash "$SELF/gate-isolation.sh" --db "$DB" --iso "$ISO" --db-host "$DB_HOST" --ts "$TS"

# ---- 3. warmup 20m (single threads=64, no recording) ---------------
info "warmup ${WARMUP_SEC}s (threads=64)"
go-tpc tpcc run \
  -d "$DRIVER" -H "$DB_HOST" -P "$PORT" -U "$USER" -D "$DBNAME" \
  --conn-params "$ISO_CONN_PARAMS" \
  --warehouses="$WAREHOUSES" \
  --time="${WARMUP_SEC}s" \
  --threads=64 \
  --output=plain \
  > "$RUNS_DIR/warmup.log" 2>&1

# ---- 4. for each threads × round ----------------------------------
for threads in $THREADS_LIST; do
  for ((r=1; r<=ROUNDS; r++)); do
    RD="$RUNS_DIR/threads-${threads}/round-${r}"
    mkdir -p "$RD"
    info "  run threads=$threads round=$r → $RD"

    # parallel OS monitors (sample every 1s for run duration)
    DUR=$((RUN_SEC + 5))
    ( mpstat 1 "$DUR"  > "$RD/mpstat.txt"  2>&1 ) &
    ( iostat -xz 1 "$DUR" > "$RD/iostat-1s.txt" 2>&1 ) &
    ( vmstat 1 "$DUR"  > "$RD/vmstat-1s.txt"  2>&1 ) &
    ( sar -n DEV 1 "$DUR" > "$RD/sar-net.txt" 2>&1 ) &
    ( for ((i=0; i<RUN_SEC/60+1; i++)); do ssh root@"$DB_HOST" free -h >> "$RD/free-1m.txt"; sleep 60; done ) &
    MON_PIDS=$(jobs -p)

    # go-tpc run
    go-tpc tpcc run \
      -d "$DRIVER" -H "$DB_HOST" -P "$PORT" -U "$USER" -D "$DBNAME" \
      --conn-params "$ISO_CONN_PARAMS" \
      --warehouses="$WAREHOUSES" \
      --time="${RUN_SEC}s" \
      --threads="$threads" \
      --output=plain \
      2>&1 | tee "$RD/go-tpc-stdout.txt"

    # wait for monitors to finish (some have 5s buffer)
    wait $MON_PIDS 2>/dev/null || true

    info "  sleeping ${ROUND_SLEEP_SEC}s between rounds"
    sleep "$ROUND_SLEEP_SEC"
  done
done

# ---- 5. write run.done --------------------------------------------
write_phase_done "$ROOT" "run" "$(cat <<JSON
{
  "phase": "run",
  "db": "$DB",
  "iso": "$ISO",
  "topology": "$TOPO",
  "ts": "$TS",
  "db_host": "$DB_HOST",
  "warehouses": $WAREHOUSES,
  "threads_list": "$THREADS_LIST",
  "rounds": $ROUNDS,
  "warmup_sec": $WARMUP_SEC,
  "run_sec": $RUN_SEC
}
JSON
)"
info "run phase complete"
