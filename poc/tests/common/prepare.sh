#!/usr/bin/env bash
# Phase 3 (prepare) — DROP+CREATE DB + go-tpc prepare 128W + check + ANALYZE + EXPLAIN dump
#
# Usage:
#   prepare.sh --db <tidb|crdb|ybdb> --iso <rc|rr|strict> \
#              --topology <vm-1node|vm-3node-...> --db-host <ip> --ts <ts>
#
# Phase A (vm-1node) 範圍：不含 §7.5 shard 鎖定 / hotspot dump（vm-3node 才需）。
#
# Env (Makefile-provided):
#   TPCC_ARTIFACTS, WAREHOUSES,
#   TIDB_PORT TIDB_USER TIDB_DB / CRDB_PORT CRDB_USER CRDB_DB / YBDB_PORT YBDB_USER YBDB_DB
#   TIDB_CONN_RC TIDB_CONN_RR PG_CONN_RC PG_CONN_RR PG_CONN_STRICT

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
ROOT=$(artifact_dir "$DB" "$TOPO" "$ISO" "$TS")
mk_artifact_tree "$ROOT"
flock_phase "$ROOT" "prepare"

PREP_DIR="$ROOT/prepare"
ISO_CONN_PARAMS=$(get_conn_params "$DB" "$ISO")
DRIVER=$(get_driver "$DB")

info "prepare root: $ROOT  db=$DB iso=$ISO topo=$TOPO host=$DB_HOST"

# ---- 1. DROP + CREATE database ------------------------------------
case "$DB" in
  tidb)
    PORT="${TIDB_PORT:-4000}"; USER="${TIDB_USER:-root}"; DBNAME="${TIDB_DB:-tpcc}"
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" -e "
      DROP DATABASE IF EXISTS \`$DBNAME\`;
      CREATE DATABASE \`$DBNAME\`;
    " 2>&1 | tee "$PREP_DIR/drop-create.log"
    ;;
  crdb)
    PORT="${CRDB_PORT:-26257}"; USER="${CRDB_USER:-root}"; DBNAME="${CRDB_DB:-tpcc}"
    cockroach sql --insecure --host="$DB_HOST:$PORT" -e "
      DROP DATABASE IF EXISTS $DBNAME CASCADE;
      CREATE DATABASE $DBNAME;
    " 2>&1 | tee "$PREP_DIR/drop-create.log"
    ;;
  ybdb)
    PORT="${YBDB_PORT:-5433}"; USER="${YBDB_USER:-yugabyte}"; DBNAME="${YBDB_DB:-tpcc}"
    # YSQL connects to "yugabyte" db to drop/create the target.
    # NOTE: each -c runs in its own transaction; combining both stmts under a
    # single -c wraps them in one implicit transaction, which YSQL rejects
    # with "DROP DATABASE cannot run inside a transaction block".
    psql "postgres://${USER}@${DB_HOST}:${PORT}/yugabyte" -v ON_ERROR_STOP=1 \
      -c "DROP DATABASE IF EXISTS $DBNAME" \
      -c "CREATE DATABASE $DBNAME" \
      2>&1 | tee "$PREP_DIR/drop-create.log"
    ;;
esac
info "drop+create done"

# ---- 2. (vm-3node-1s1r / 1s3r YBDB only) pre-create schema ---------
# Phase A: skip; Phase B/C: insert pre-create logic here (per §7.5.3)
if [[ "$DB" == "ybdb" && ("$TOPO" == "vm-3node-1s1r" || "$TOPO" == "vm-3node-1s3r") ]]; then
  warn "YBDB pre-create with SPLIT INTO 1 TABLETS not implemented yet (Phase B/C scope)"
fi

# ---- 3. go-tpc prepare ---------------------------------------------
info "go-tpc tpcc prepare W=$WAREHOUSES driver=$DRIVER"
go-tpc tpcc prepare \
  -d "$DRIVER" -H "$DB_HOST" -P "$PORT" -U "$USER" -D "$DBNAME" \
  --conn-params "$ISO_CONN_PARAMS" \
  --warehouses="$WAREHOUSES" \
  2>&1 | tee "$PREP_DIR/go-tpc-prepare.log"

# ---- 4. go-tpc check-all (consistency check) -----------------------
info "go-tpc tpcc check --check-all"
go-tpc tpcc check \
  -d "$DRIVER" -H "$DB_HOST" -P "$PORT" -U "$USER" -D "$DBNAME" \
  --conn-params "$ISO_CONN_PARAMS" \
  --warehouses="$WAREHOUSES" \
  --check-all \
  2>&1 | tee "$PREP_DIR/check-all.log" || warn "check-all reported issues; see $PREP_DIR/check-all.log"

# ---- 5. quiesce 5 min (compaction settle) --------------------------
info "quiesce 5 min"
sleep 300

# ---- 6. ANALYZE / CREATE STATISTICS --------------------------------
info "ANALYZE"
case "$DB" in
  tidb)
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" "$DBNAME" -e "
      ANALYZE TABLE warehouse, district, customer, history, new_order, orders, order_line, item, stock;
    " 2>&1 | tee "$PREP_DIR/analyze.log"
    ;;
  crdb)
    cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e "
      CREATE STATISTICS s_warehouse  FROM warehouse;
      CREATE STATISTICS s_district   FROM district;
      CREATE STATISTICS s_customer   FROM customer;
      CREATE STATISTICS s_history    FROM history;
      CREATE STATISTICS s_new_order  FROM new_order;
      CREATE STATISTICS s_orders     FROM orders;
      CREATE STATISTICS s_order_line FROM order_line;
      CREATE STATISTICS s_item       FROM item;
      CREATE STATISTICS s_stock      FROM stock;
    " 2>&1 | tee "$PREP_DIR/analyze.log"
    ;;
  ybdb)
    psql "postgres://${USER}@${DB_HOST}:${PORT}/${DBNAME}" -v ON_ERROR_STOP=1 -c "ANALYZE;" \
      2>&1 | tee "$PREP_DIR/analyze.log"
    ;;
esac

# ---- 7. SHOW CREATE TABLE + EXPLAIN dump（representative queries）----
info "schema + EXPLAIN dump"
case "$DB" in
  tidb)
    for tbl in warehouse district customer history new_order orders order_line item stock; do
      mysql -h "$DB_HOST" -P "$PORT" -u "$USER" "$DBNAME" -e "SHOW CREATE TABLE $tbl\\G" \
        >> "$PREP_DIR/schema.txt" 2>&1
    done
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" "$DBNAME" -e \
      "EXPLAIN SELECT w_name FROM warehouse WHERE w_id=1" > "$PREP_DIR/explain-warehouse.txt" 2>&1
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" "$DBNAME" -e \
      "EXPLAIN SELECT c_first FROM customer WHERE c_w_id=1 AND c_d_id=1 AND c_id=1" > "$PREP_DIR/explain-customer.txt" 2>&1
    ;;
  crdb)
    for tbl in warehouse district customer history new_order orders order_line item stock; do
      cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e "SHOW CREATE TABLE $tbl;" \
        >> "$PREP_DIR/schema.txt" 2>&1
    done
    cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e \
      "EXPLAIN SELECT w_name FROM warehouse WHERE w_id=1" > "$PREP_DIR/explain-warehouse.txt" 2>&1
    cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e \
      "EXPLAIN SELECT c_first FROM customer WHERE c_w_id=1 AND c_d_id=1 AND c_id=1" > "$PREP_DIR/explain-customer.txt" 2>&1
    ;;
  ybdb)
    for tbl in warehouse district customer history new_order orders order_line item stock; do
      psql "postgres://${USER}@${DB_HOST}:${PORT}/${DBNAME}" -c "\\d+ $tbl" \
        >> "$PREP_DIR/schema.txt" 2>&1
    done
    psql "postgres://${USER}@${DB_HOST}:${PORT}/${DBNAME}" -c \
      "EXPLAIN SELECT w_name FROM warehouse WHERE w_id=1" > "$PREP_DIR/explain-warehouse.txt" 2>&1
    psql "postgres://${USER}@${DB_HOST}:${PORT}/${DBNAME}" -c \
      "EXPLAIN SELECT c_first FROM customer WHERE c_w_id=1 AND c_d_id=1 AND c_id=1" > "$PREP_DIR/explain-customer.txt" 2>&1
    ;;
esac

# ---- 8. (vm-3node only) shard-count hard gate ----------------------
if [[ "$TOPO" != "vm-1node" ]]; then
  warn "vm-3node shard-count hard gate not implemented yet (Phase B/C/D/E/F scope)"
fi

# ---- 9. write prepare.done ----------------------------------------
write_phase_done "$ROOT" "prepare" "$(cat <<JSON
{
  "phase": "prepare",
  "db": "$DB",
  "iso": "$ISO",
  "topology": "$TOPO",
  "ts": "$TS",
  "db_host": "$DB_HOST",
  "warehouses": $WAREHOUSES,
  "conn_params": "$ISO_CONN_PARAMS"
}
JSON
)"
info "prepare done"
