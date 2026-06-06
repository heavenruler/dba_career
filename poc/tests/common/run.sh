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
# Phase isolation guard (T105 Layer 3 hard gate) — auto-pick scope assert by $ROOT path.
# Refuses any cross-scope contamination (e.g. TUNING_PROFILE on /S-BASE/ run, or /T-THRD/ output
# from a baseline target).
source "$SELF/lib/guard.sh"
case "$ROOT" in
  */T-THRD/*)  assert_threadcontrol_target "$ROOT" ;;
  */S-K8S/*)   assert_phase_k8s_target "$ROOT" ;;
  */X-CROSS/*) assert_phase_crossregion_target "$ROOT" ;;
  *)           assert_baseline_target "$ROOT" ;;   # default: vm-1node / vm-3node / unspecified
esac

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

# HAProxy 等 proxy 拓樸：db-host 是 proxy（無 mpstat 等套件、無 DB process）；
# DB-host OS 監控 ssh 必須走實 cluster member。
#
# Fan-out (T108b)：若 $CLUSTER_HOSTS 設定 → 多 host 並行採；否則沿用既有單 host 行為（unchanged）。
# 詳 tests/common/lib/host-resolution.sh + results/PHASES.md §4.
source "$SELF/lib/host-resolution.sh"
resolve_hosts "$TOPO" "$DB_HOST"
# Legacy single-host alias (kept for backward-compat code paths within run.sh)
CLUSTER_HOST=$(host_ssh_target "${RESOLVED_HOSTS[0]}")

info "run start  db=$DB iso=$ISO topo=$TOPO host=$DB_HOST cluster-host=$CLUSTER_HOST fanout=$FANOUT_ENABLED hosts=${#RESOLVED_HOSTS[@]}"

# ---- 1. cold-reset (per-DB script) ---------------------------------
info "cold-reset"
bash "$SELF/coldreset-${DB}.sh" --db-host "$DB_HOST"

# ---- 2. active isolation gate (call gate-isolation.sh) -------------
info "active isolation gate"
bash "$SELF/gate-isolation.sh" --db "$DB" --iso "$ISO" --db-host "$DB_HOST" --ts "$TS" --topology "$TOPO"

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
    # client-side (.31): characterise driver overhead; db-side (DB_HOST): characterise DB engine saturation
    DUR=$((RUN_SEC + 5))
    ( mpstat 1 "$DUR"  > "$RD/mpstat.txt"  2>&1 ) &
    ( iostat -xz 1 "$DUR" > "$RD/iostat-1s.txt" 2>&1 ) &
    ( vmstat 1 "$DUR"  > "$RD/vmstat-1s.txt"  2>&1 ) &
    ( sar -n DEV 1 "$DUR" > "$RD/sar-net.txt" 2>&1 ) &

    # DB-host monitors: branch on $FANOUT_ENABLED to preserve backward-compat artifact names.
    if [[ "$FANOUT_ENABLED" == "true" ]]; then
      # Fan-out path (T108b): per-host with logical id suffix. Used by phase-k8s / phase-crossregion.
      write_hosts_manifest "${PHASE_NAME:-unknown}" "${RESULT_SCOPE:-unknown}" "${MANIFEST_SHA:-unset}" "$RD"
      for entry in "${RESOLVED_HOSTS[@]}"; do
        h=$(host_ssh_target "$entry")
        sfx=$(host_artifact_suffix "$entry")
        ( ssh root@"$h" "mpstat 1 $DUR"      > "$RD/mpstat-db${sfx}.txt"    2>&1 ) &
        ( ssh root@"$h" "iostat -xz 1 $DUR"  > "$RD/iostat-1s-db${sfx}.txt" 2>&1 ) &
        ( ssh root@"$h" "vmstat 1 $DUR"      > "$RD/vmstat-1s-db${sfx}.txt" 2>&1 ) &
        ( ssh root@"$h" "sar -n DEV 1 $DUR"  > "$RD/sar-net-db${sfx}.txt"   2>&1 ) &
        ( for ((i=0; i<RUN_SEC/60+1; i++)); do ssh root@"$h" free -h >> "$RD/free-1m-db${sfx}.txt"; sleep 60; done ) &
      done
    else
      # Backward-compat path: bit-exact to pre-T108b behavior. Do NOT change filenames.
      ( ssh root@"$CLUSTER_HOST" "mpstat 1 $DUR"      > "$RD/mpstat-db.txt"    2>&1 ) &
      ( ssh root@"$CLUSTER_HOST" "iostat -xz 1 $DUR"  > "$RD/iostat-1s-db.txt" 2>&1 ) &
      ( ssh root@"$CLUSTER_HOST" "vmstat 1 $DUR"      > "$RD/vmstat-1s-db.txt" 2>&1 ) &
      ( ssh root@"$CLUSTER_HOST" "sar -n DEV 1 $DUR"  > "$RD/sar-net-db.txt"   2>&1 ) &
      ( for ((i=0; i<RUN_SEC/60+1; i++)); do ssh root@"$CLUSTER_HOST" free -h >> "$RD/free-1m.txt"; sleep 60; done ) &
    fi
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
