#!/usr/bin/env bash
# Phase 6 (collect) — gather DB-side logs, db-config dump, host env snapshot.
# Runs on .31 client; pulls DB logs via ssh.
#
# Usage: collect.sh --db <db> --iso <iso> --topology <topo> --db-host <ip> --ts <ts>

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
ROOT=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")
[[ -f "$ROOT/.run.done" ]] || die "run phase not complete: $ROOT/.run.done missing"
flock_phase "$ROOT" "collect"

DBCFG="$ROOT/db-config"
ENV_DIR="$ROOT/env"
mkdir -p "$DBCFG" "$ENV_DIR"

info "collect: $ROOT"

# ---- 1. db-config dump (call db-config-dump.sh from Step 2) -------
if [[ -x "$SELF/db-config-dump.sh" ]]; then
  bash "$SELF/db-config-dump.sh" --db "$DB" --iso "$ISO" --db-host "$DB_HOST" --ts "$TS" || \
    warn "db-config-dump.sh exited non-zero"
fi

# ---- 2. env snapshot of DB-host -----------------------------------
{
  echo "=== DB-host: $DB_HOST ==="
  ssh -o StrictHostKeyChecking=accept-new "root@$DB_HOST" '
    uname -a
    cat /etc/os-release
    free -h
    df -h /
    sysctl -n vm.swappiness vm.dirty_ratio vm.dirty_background_ratio
    cat /sys/kernel/mm/transparent_hugepage/enabled
    ulimit -n
  '
} > "$ENV_DIR/db-host-snapshot.txt" 2>&1

# ---- 3. DB process log tail (last 1000 lines) ---------------------
case "$DB" in
  tidb)
    ssh "root@$DB_HOST" '
      for log in /tidb-deploy/tidb-*/log/tidb.log \
                 /tidb-deploy/tikv-*/log/tikv.log \
                 /tidb-deploy/pd-*/log/pd.log; do
        echo "=== $log ==="
        tail -1000 "$log" 2>/dev/null || echo "(not found)"
      done
    ' > "$ROOT/runs/db-log-tail.txt" 2>&1
    ;;
  crdb)
    ssh "root@$DB_HOST" '
      echo "=== cockroach.log tail ==="
      tail -1000 /data/crdb/logs/cockroach.log 2>/dev/null || \
      journalctl -u cockroach -n 1000 --no-pager
    ' > "$ROOT/runs/db-log-tail.txt" 2>&1
    ;;
  ybdb)
    ssh "root@$DB_HOST" '
      echo "=== yb-tserver log tail ==="
      tail -1000 /var/yugabyte/yb-data/tserver/logs/yb-tserver.INFO 2>/dev/null || echo "(not found)"
      echo "=== postgres log tail ==="
      find /var/yugabyte/var -name "postgresql-*.log" -exec tail -200 {} + 2>/dev/null
    ' > "$ROOT/runs/db-log-tail.txt" 2>&1
    ;;
esac

# ---- 4. write collect.done ----------------------------------------
write_phase_done "$ROOT" "collect" "$(cat <<JSON
{
  "phase": "collect",
  "db": "$DB",
  "iso": "$ISO",
  "topology": "$TOPO",
  "ts": "$TS",
  "db_host": "$DB_HOST"
}
JSON
)"
info "collect done"
