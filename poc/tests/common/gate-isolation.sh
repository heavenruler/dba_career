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
flock_phase "$ROOT" "gate-isolation"

GATE_DIR="$ROOT/gate"
ISO_CONN_PARAMS=$(get_conn_params "$DB" "$ISO")
EXPECTED=$(expected_iso "$DB" "$ISO")
DRIVER=$(get_driver "$DB")

case "$DB" in
  tidb)
    require_cmd mysql go-tpc
    PORT="${TIDB_PORT:-4000}"
    USER="${TIDB_USER:-root}"
    DB_NAME="${TIDB_DB:-tpcc}"
    if [[ "$ISO" == "rc" ]]; then
      tidb_iso="READ-COMMITTED"
    else
      tidb_iso="REPEATABLE-READ"
    fi
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" "$DB_NAME" \
      -e "SET SESSION transaction_isolation='${tidb_iso}'; SET SESSION tidb_txn_mode='pessimistic'; BEGIN; SELECT @@transaction_isolation AS transaction_isolation, @@tidb_txn_mode AS tidb_txn_mode; COMMIT;" \
      > "$GATE_DIR/isolation-db.txt" 2>&1
    ACTUAL=$(awk 'NR==2 {print $1}' "$GATE_DIR/isolation-db.txt")
    grep -Eq "[[:space:]]pessimistic$|pessimistic" "$GATE_DIR/isolation-db.txt" || die "TiDB pessimistic mode gate failed"
    ;;
  crdb)
    require_cmd psql go-tpc
    PORT="${CRDB_PORT:-26257}"
    USER="${CRDB_USER:-root}"
    DB_NAME="${CRDB_DB:-tpcc}"
    psql "postgres://${USER}@${DB_HOST}:${PORT}/${DB_NAME}?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At -c "SHOW transaction_isolation" \
      > "$GATE_DIR/isolation-db.txt" 2>&1
    ACTUAL=$(grep -E '^(read committed|repeatable read|serializable)$' "$GATE_DIR/isolation-db.txt" | tail -1)
    ;;
  ybdb)
    require_cmd psql go-tpc
    PORT="${YBDB_PORT:-5433}"
    USER="${YBDB_USER:-yugabyte}"
    DB_NAME="${YBDB_DB:-tpcc}"
    # Dual gate: YugabyteDB only honors RC when the tserver gflag
    # yb_enable_read_committed_isolation=true is set; otherwise
    # SHOW transaction_isolation reports the requested value while
    # yb_effective_transaction_isolation_level falls back to
    # 'repeatable read' (snapshot). Verify both.
    psql "postgres://${USER}@${DB_HOST}:${PORT}/${DB_NAME}?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At \
      -c "SHOW transaction_isolation" \
      -c "SHOW yb_effective_transaction_isolation_level" \
      > "$GATE_DIR/isolation-db.txt" 2>&1
    ACTUAL=$(sed -n '1p' "$GATE_DIR/isolation-db.txt")
    YB_EFFECTIVE_DB=$(sed -n '2p' "$GATE_DIR/isolation-db.txt")
    [[ "$YB_EFFECTIVE_DB" == "$EXPECTED" ]] || \
      die "YBDB effective isolation gate mismatch (DB): expected=$EXPECTED effective=${YB_EFFECTIVE_DB:-N/A} — check tserver gflag yb_enable_read_committed_isolation=true"
    ;;
  *) die "unknown db: $DB" ;;
esac

[[ "$ACTUAL" == "$EXPECTED" ]] || die "isolation DB gate mismatch: expected=$EXPECTED actual=${ACTUAL:-N/A}"
cp "$GATE_DIR/isolation-db.txt" "$GATE_DIR/isolation.txt"

case "$DB" in
  tidb)
    go-tpc tpcc run -d "$DRIVER" -H "$DB_HOST" -P "${TIDB_PORT:-4000}" -U "${TIDB_USER:-root}" -D "${TIDB_DB:-tpcc}" \
      --conn-params "$ISO_CONN_PARAMS" --warehouses=1 --time=2s --threads=1 --output=plain \
      2>&1 | tee "$GATE_DIR/isolation-driver.txt"
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" "${TIDB_DB:-tpcc}" \
      -e "SET SESSION transaction_isolation='${tidb_iso}'; SET SESSION tidb_txn_mode='pessimistic'; BEGIN; SELECT @@transaction_isolation AS transaction_isolation, @@tidb_txn_mode AS tidb_txn_mode; COMMIT;" \
      > "$GATE_DIR/isolation-driver-verify.txt" 2>&1
    DRIVER_ACTUAL=$(awk 'NR==2 {print $1}' "$GATE_DIR/isolation-driver-verify.txt")
    ;;
  crdb)
    go-tpc tpcc run -d "$DRIVER" -H "$DB_HOST" -P "${CRDB_PORT:-26257}" -U "${CRDB_USER:-root}" -D "${CRDB_DB:-tpcc}" \
      --conn-params "$ISO_CONN_PARAMS" --warehouses=1 --time=2s --threads=1 --output=plain \
      2>&1 | tee "$GATE_DIR/isolation-driver.txt"
    psql "postgres://${CRDB_USER:-root}@${DB_HOST}:${CRDB_PORT:-26257}/${CRDB_DB:-tpcc}?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At -c "SHOW transaction_isolation" \
      > "$GATE_DIR/isolation-driver-verify.txt" 2>&1
    DRIVER_ACTUAL=$(grep -E '^(read committed|repeatable read|serializable)$' "$GATE_DIR/isolation-driver-verify.txt" | tail -1)
    ;;
  ybdb)
    go-tpc tpcc run -d "$DRIVER" -H "$DB_HOST" -P "${YBDB_PORT:-5433}" -U "${YBDB_USER:-yugabyte}" -D "${YBDB_DB:-tpcc}" \
      --conn-params "$ISO_CONN_PARAMS" --warehouses=1 --time=2s --threads=1 --output=plain \
      2>&1 | tee "$GATE_DIR/isolation-driver.txt"
    # Same dual gate via the driver-side connection (matches DB gate path).
    psql "postgres://${YBDB_USER:-yugabyte}@${DB_HOST}:${YBDB_PORT:-5433}/${YBDB_DB:-tpcc}?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At \
      -c "SHOW transaction_isolation" \
      -c "SHOW yb_effective_transaction_isolation_level" \
      > "$GATE_DIR/isolation-driver-verify.txt" 2>&1
    DRIVER_ACTUAL=$(sed -n '1p' "$GATE_DIR/isolation-driver-verify.txt")
    YB_EFFECTIVE_DRIVER=$(sed -n '2p' "$GATE_DIR/isolation-driver-verify.txt")
    [[ "$YB_EFFECTIVE_DRIVER" == "$EXPECTED" ]] || \
      die "YBDB effective isolation gate mismatch (driver): expected=$EXPECTED effective=${YB_EFFECTIVE_DRIVER:-N/A} — check tserver gflag yb_enable_read_committed_isolation=true"
    ;;
esac

[[ "$DRIVER_ACTUAL" == "$EXPECTED" ]] || die "isolation driver gate mismatch: expected=$EXPECTED actual=${DRIVER_ACTUAL:-N/A}"

write_phase_done "$ROOT" "gate-isolation" "$(cat <<JSON
{
  "phase": "gate-isolation",
  "db": "$DB",
  "topology": "$TOPO",
  "iso": "$ISO",
  "ts": "$TS",
  "db_host": "$DB_HOST",
  "conn_params": "$ISO_CONN_PARAMS",
  "isolation_expected": "$EXPECTED",
  "isolation_actual": "$ACTUAL",
  "driver_actual": "$DRIVER_ACTUAL",
  "yb_effective_db": "${YB_EFFECTIVE_DB:-n/a}",
  "yb_effective_driver": "${YB_EFFECTIVE_DRIVER:-n/a}"
}
JSON
)"
info "isolation gate passed db=$DB iso=$ISO expected=$EXPECTED actual=$ACTUAL${YB_EFFECTIVE_DB:+ yb_effective_db=$YB_EFFECTIVE_DB}${YB_EFFECTIVE_DRIVER:+ yb_effective_driver=$YB_EFFECTIVE_DRIVER}"

