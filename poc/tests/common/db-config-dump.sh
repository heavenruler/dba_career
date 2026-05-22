#!/usr/bin/env bash
set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" ISO="" DB_HOST="" TS="" TOPO="vm-1node"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --iso) ISO=$2; shift 2 ;;
    --db-host) DB_HOST=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    --topology) TOPO=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB" && -n "$ISO" && -n "$DB_HOST" && -n "$TS" ]] || die "missing required args"

: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts}"
ROOT=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")
mk_artifact_tree "$ROOT"
flock_phase "$ROOT" "db-config"

CONFIG_DIR="$ROOT/db-config"
ISO_CONN_PARAMS=$(get_conn_params "$DB" "$ISO")

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$DB_HOST" "$@"
}

case "$DB" in
  tidb)
    require_cmd mysql
    {
      echo "=== SHOW GLOBAL VARIABLES ==="
      mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" -e "SHOW GLOBAL VARIABLES;"
      echo
      echo "=== tiup cluster show-config tpcc-tidb ==="
      remote 'export PATH=/root/.tiup/bin:$PATH; tiup cluster show-config tpcc-tidb'
    } > "$CONFIG_DIR/effective-config.txt" 2>&1
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" \
      -e "SELECT @@global.tidb_enable_auto_analyze AS tidb_enable_auto_analyze, @@global.tidb_txn_mode AS tidb_txn_mode; SHOW CONFIG WHERE TYPE IN ('tidb','tikv','pd') AND NAME IN ('mem-quota-query','storage.block-cache.capacity','raftstore.sync-log','replication.max-replicas','schedule.leader-schedule-limit','schedule.region-schedule-limit','schedule.replica-schedule-limit');" \
      > "$CONFIG_DIR/cluster-settings.txt" 2>&1
    tidb_iso=$([[ "$ISO" == "rc" ]] && echo "READ-COMMITTED" || echo "REPEATABLE-READ")
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" "${TIDB_DB:-tpcc}" \
      -e "SET SESSION transaction_isolation='${tidb_iso}'; SET SESSION tidb_txn_mode='pessimistic'; BEGIN; SELECT @@transaction_isolation AS transaction_isolation, @@tidb_txn_mode AS tidb_txn_mode; COMMIT;" \
      > "$CONFIG_DIR/isolation.txt" 2>&1
    ;;
  crdb)
    require_cmd cockroach psql
    cockroach sql --insecure --host="$DB_HOST:${CRDB_PORT:-26257}" -e "SHOW ALL CLUSTER SETTINGS;" \
      > "$CONFIG_DIR/effective-config.txt" 2>&1
    cockroach sql --insecure --host="$DB_HOST:${CRDB_PORT:-26257}" \
      -e "SHOW CLUSTER SETTING sql.stats.automatic_collection.enabled; SHOW CLUSTER SETTING server.host_based_authentication.configuration; SHOW CLUSTER SETTING sql.txn.read_committed_isolation.enabled; SHOW CLUSTER SETTING sql.txn.repeatable_read_isolation.enabled;" \
      > "$CONFIG_DIR/cluster-settings.txt" 2>&1
    psql "postgres://${CRDB_USER:-root}@${DB_HOST}:${CRDB_PORT:-26257}/${CRDB_DB:-tpcc}?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -c "BEGIN; SHOW transaction_isolation; COMMIT;" \
      > "$CONFIG_DIR/isolation.txt" 2>&1
    ;;
  ybdb)
    require_cmd curl psql
    # NOTE: avoid `curl ... | head -N` — head closes the pipe early, curl
    # sees SIGPIPE and exits 23 (Write error); under set -o pipefail this
    # kills the script. Fetch full /varz to a tmp first, then slice.
    VARZ_TMP=$(mktemp)
    curl -s --max-time 30 "http://${DB_HOST}:9000/varz" > "$VARZ_TMP" || warn "curl /varz failed"
    cp "$VARZ_TMP" "$CONFIG_DIR/effective-config.txt"
    grep -E 'memory_limit_hard_bytes|db_block_cache_size_percentage|durable_wal_write|require_durable_wal_write|yb_enable_read_committed_isolation|ysql_enable_auth|ysql_enable_auto_analyze|ysql_default_transaction_isolation' \
      "$VARZ_TMP" > "$CONFIG_DIR/cluster-settings.txt" || true
    rm -f "$VARZ_TMP"
    psql "postgres://${YBDB_USER:-yugabyte}@${DB_HOST}:${YBDB_PORT:-5433}/${YBDB_DB:-tpcc}?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 \
      -c "BEGIN; SHOW transaction_isolation; COMMIT;" \
      -c "SHOW yb_effective_transaction_isolation_level" \
      > "$CONFIG_DIR/isolation.txt" 2>&1 || warn "psql isolation dump failed"
    ;;
  *) die "unknown db: $DB" ;;
esac

write_phase_done "$ROOT" "db-config" "$(cat <<JSON
{
  "phase": "db-config",
  "db": "$DB",
  "topology": "$TOPO",
  "iso": "$ISO",
  "ts": "$TS",
  "db_host": "$DB_HOST"
}
JSON
)"
info "db config dump written: $CONFIG_DIR"

