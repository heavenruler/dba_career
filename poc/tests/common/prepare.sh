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

# PoC-DESIGN §7.5.4 — vm-3node 每張表預期 shard 數（hard gate 比對基準）
case "$TOPO" in
  vm-3node-1s1r|vm-3node-1s3r) EXPECTED_SHARDS=1 ;;
  vm-3node-3s1r|vm-3node-3s3r) EXPECTED_SHARDS=3 ;;
  *)                           EXPECTED_SHARDS=0 ;;   # vm-1node / 其他 → 不 enforce
esac

info "prepare root: $ROOT  db=$DB iso=$ISO topo=$TOPO host=$DB_HOST expected_shards=$EXPECTED_SHARDS"

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
    # NOTE 1: each -c runs in its own transaction; combining DROP+CREATE under
    # a single -c wraps them in one implicit txn, which YSQL rejects with
    # "DROP DATABASE cannot run inside a transaction block".
    # NOTE 2: if a previous suite was killed mid-prepare, lingering go-tpc
    # sessions still pin the target DB and DROP fails with
    # "database is being accessed by other users". Terminate them first.
    psql "postgres://${USER}@${DB_HOST}:${PORT}/yugabyte" -v ON_ERROR_STOP=1 \
      -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$DBNAME' AND pid <> pg_backend_pid()" \
      -c "DROP DATABASE IF EXISTS $DBNAME" \
      -c "CREATE DATABASE $DBNAME" \
      2>&1 | tee "$PREP_DIR/drop-create.log"
    ;;
esac
info "drop+create done"

# ---- 2. (vm-3node YBDB) pre-create schema with SPLIT INTO $EXPECTED_SHARDS TABLETS
# 為什麼 1s*r 和 3s*r 都要 pre-create：
# yugabyted configure data_placement --rf=N 之後，placement 只覆蓋 N 個 tserver；
# 新建 table 沒帶 SPLIT clause 時 initial tablets = ysql_num_shards_per_tserver
# × num_tservers_in_placement = 1 × N = N（不是 PoC-DESIGN 原假設「3 自然」）。
# RF=1 placement → 1 tablet；RF=3 placement → 3 tablet。所以 1s*r 要 SPLIT 1
# （覆寫 RF=3 case 的 3 tablet 預設），3s*r 要 SPLIT 3（覆寫 RF=1 case 的 1
# tablet 預設）。實作上一律 SPLIT INTO $EXPECTED_SHARDS TABLETS。
# go-tpc 跑 CREATE TABLE IF NOT EXISTS，pre-create 後它會 skip CREATE；INSERT 照常。
# Schema file 內寫 "SPLIT INTO 1 TABLETS"，由 sed substitute 為 EXPECTED_SHARDS。
if [[ "$DB" == "ybdb" && "$TOPO" =~ ^vm-3node ]]; then
  info "YBDB pre-create 9 tables with SPLIT INTO $EXPECTED_SHARDS TABLETS"
  sed "s|SPLIT INTO [0-9]\+ TABLETS|SPLIT INTO $EXPECTED_SHARDS TABLETS|g" \
    "$SELF/lib/ybdb-tpcc-schema-1tablet.sql" | \
  psql "postgres://${USER}@${DB_HOST}:${PORT}/${DBNAME}" -v ON_ERROR_STOP=1 \
    2>&1 | tee "$PREP_DIR/pre-create-${EXPECTED_SHARDS}tablets.log"
fi

# ---- 3. go-tpc prepare ---------------------------------------------
# YBDB 2025.2: inline consistency check (3.3.2.x cross-table aggregates)
# stalls 30+ min; use --no-check and verify via row-count below.
NOCHECK_ARG=""
[[ "$DB" == "ybdb" ]] && NOCHECK_ARG="--no-check"
info "go-tpc tpcc prepare W=$WAREHOUSES driver=$DRIVER $NOCHECK_ARG"
go-tpc tpcc prepare \
  -d "$DRIVER" -H "$DB_HOST" -P "$PORT" -U "$USER" -D "$DBNAME" \
  --conn-params "$ISO_CONN_PARAMS" \
  --warehouses="$WAREHOUSES" \
  $NOCHECK_ARG \
  2>&1 | tee "$PREP_DIR/go-tpc-prepare.log"

# ---- 3b. (vm-3node 3s*r) post-prepare SPLIT 9 tables ---------------
# PoC-DESIGN §7.5.1 (TiDB) / §7.5.2 (CRDB)：prepare 完整 128W 之後手動切 3 region/range。
# YBDB 3s*r 走 cluster default 3 tservers × 1 = 3 tablets，不需 SPLIT。
if [[ "$EXPECTED_SHARDS" == "3" ]]; then
  info "post-prepare SPLIT 9 tables → 3 shards each ($DB)"
  case "$DB" in
    tidb)
      mysql -h "$DB_HOST" -P "$PORT" -u "$USER" "$DBNAME" -e "
        SPLIT TABLE warehouse  INDEX \`PRIMARY\` BETWEEN (1)         AND (128)              REGIONS 3;
        SPLIT TABLE district   INDEX \`PRIMARY\` BETWEEN (1,1)       AND (128,10)           REGIONS 3;
        SPLIT TABLE customer   INDEX \`PRIMARY\` BETWEEN (1,1,1)     AND (128,10,3000)      REGIONS 3;
        SPLIT TABLE new_order  INDEX \`PRIMARY\` BETWEEN (1,1,2101)  AND (128,10,3000)      REGIONS 3;
        SPLIT TABLE orders     INDEX \`PRIMARY\` BETWEEN (1,1,1)     AND (128,10,3000)      REGIONS 3;
        SPLIT TABLE order_line INDEX \`PRIMARY\` BETWEEN (1,1,1,1)   AND (128,10,3000,15)   REGIONS 3;
        SPLIT TABLE stock      INDEX \`PRIMARY\` BETWEEN (1,1)       AND (128,100000)       REGIONS 3;
        SPLIT TABLE item       INDEX \`PRIMARY\` BETWEEN (1)         AND (100000)           REGIONS 3;
        SPLIT TABLE history    INDEX \`PRIMARY\` BETWEEN (1)         AND (3840000)          REGIONS 3;
      " 2>&1 | tee "$PREP_DIR/shard-split.log"
      ;;
    crdb)
      cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e "
        ALTER TABLE warehouse  SPLIT AT VALUES (43), (86);
        ALTER TABLE district   SPLIT AT VALUES (43, 1), (86, 1);
        ALTER TABLE customer   SPLIT AT VALUES (43, 1, 1), (86, 1, 1);
        ALTER TABLE new_order  SPLIT AT VALUES (43, 1, 2101), (86, 1, 2101);
        ALTER TABLE orders     SPLIT AT VALUES (43, 1, 1), (86, 1, 1);
        ALTER TABLE order_line SPLIT AT VALUES (43, 1, 1, 1), (86, 1, 1, 1);
        ALTER TABLE stock      SPLIT AT VALUES (43, 1), (86, 1);
        ALTER TABLE item       SPLIT AT VALUES (33334), (66667);
        ALTER TABLE history    SPLIT AT VALUES ('00000043'), ('00000086');
      " 2>&1 | tee "$PREP_DIR/shard-split.log"
      ;;
    ybdb)
      info "YBDB 3s*r tablets 由 cluster default 3 tservers × ysql_num_shards_per_tserver=1 自然產生，不下 SPLIT"
      ;;
  esac
  info "SPLIT done; sleep 30s waiting rebalance settle"
  sleep 30
fi

# ---- 4. consistency / integrity verification -----------------------
if [[ "$DB" == "ybdb" ]]; then
  info "row-count verification (YBDB; go-tpc check-all skipped — 2025.2 stalls on 3.3.2.x cross-table aggregates)"
  psql "postgres://${USER}@${DB_HOST}:${PORT}/${DBNAME}" -v ON_ERROR_STOP=1 \
    -c "SELECT 'warehouse'  AS tbl, count(*) FROM warehouse
         UNION ALL SELECT 'district',   count(*) FROM district
         UNION ALL SELECT 'customer',   count(*) FROM customer
         UNION ALL SELECT 'history',    count(*) FROM history
         UNION ALL SELECT 'item',       count(*) FROM item
         UNION ALL SELECT 'stock',      count(*) FROM stock
         UNION ALL SELECT 'new_order',  count(*) FROM new_order
         UNION ALL SELECT 'orders',     count(*) FROM orders
         UNION ALL SELECT 'order_line', count(*) FROM order_line;" \
    2>&1 | tee "$PREP_DIR/row-count-check.log"
else
  info "go-tpc tpcc check --check-all"
  go-tpc tpcc check \
    -d "$DRIVER" -H "$DB_HOST" -P "$PORT" -U "$USER" -D "$DBNAME" \
    --conn-params "$ISO_CONN_PARAMS" \
    --warehouses="$WAREHOUSES" \
    --check-all \
    2>&1 | tee "$PREP_DIR/check-all.log" || warn "check-all reported issues; see $PREP_DIR/check-all.log"
fi

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
    # Use ysqlsh (bundled with YB) for \d+ — stock psql from AlmaLinux 8.10
    # (postgresql package) queries pg_class.relhasoids which YB 2025.2's
    # catalog dropped (PG 12+ removed), so psql -c "\d+" exits rc=1 and
    # trips set -e here.
    for tbl in warehouse district customer history new_order orders order_line item stock; do
      ysqlsh -h "$DB_HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -c "\\d+ $tbl" \
        >> "$PREP_DIR/schema.txt" 2>&1
    done
    ysqlsh -h "$DB_HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -c \
      "EXPLAIN SELECT w_name FROM warehouse WHERE w_id=1" > "$PREP_DIR/explain-warehouse.txt" 2>&1
    ysqlsh -h "$DB_HOST" -p "$PORT" -U "$USER" -d "$DBNAME" -c \
      "EXPLAIN SELECT c_first FROM customer WHERE c_w_id=1 AND c_d_id=1 AND c_id=1" > "$PREP_DIR/explain-customer.txt" 2>&1
    ;;
esac

# ---- 8. (vm-3node only) shard-count hard gate (PoC-DESIGN §7.5.4) --
# 9 張表逐張 query 實際 region/range/tablet 數，對比 EXPECTED_SHARDS；
# 任一表不符 → fail-closed，abort 此組（不進 run 階段）。
# fail-closed 邏輯：write shard-count.txt 後 die，prepare.done 不會寫，
# Makefile chain（vm3-${db}-${sub}-rc）因 prepare 失敗就停止。
if [[ "$EXPECTED_SHARDS" != "0" ]]; then
  info "shard-count hard gate (expected=$EXPECTED_SHARDS per table × 9 tables)"
  SHARD_REPORT="$PREP_DIR/shard-count.txt"
  : > "$SHARD_REPORT"
  ALL_PASS=true
  TABLES="warehouse district customer new_order orders order_line stock item history"

  case "$DB" in
    tidb)
      mysql -h "$DB_HOST" -P "$PORT" -u "$USER" -B -N -e "
        SELECT TABLE_NAME, COUNT(*) AS region_count
          FROM information_schema.tikv_region_status
          WHERE DB_NAME='$DBNAME' AND IS_INDEX=0
          GROUP BY TABLE_NAME;
      " > "$PREP_DIR/.shard-raw.tsv" 2>&1 || true
      ;;
    crdb)
      cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" --format=tsv -e "
        SELECT table_name, count(*) AS range_count
          FROM crdb_internal.ranges
          WHERE database_name='$DBNAME' AND index_name='primary'
          GROUP BY table_name;
      " 2>/dev/null | tail -n +2 > "$PREP_DIR/.shard-raw.tsv" || true
      ;;
    ybdb)
      : > "$PREP_DIR/.shard-raw.tsv"
      YB_MASTERS="172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100"
      for tbl in $TABLES; do
        n=$(ssh -o StrictHostKeyChecking=accept-new "root@$DB_HOST" \
              "/opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTERS list_tablets ysql.$DBNAME $tbl 2>/dev/null | tail -n +2 | wc -l" \
              2>/dev/null || echo 0)
        printf "%s\t%s\n" "$tbl" "$n" >> "$PREP_DIR/.shard-raw.tsv"
      done
      ;;
  esac

  for tbl in $TABLES; do
    actual=$(awk -v t="$tbl" '$1==t {print $2}' "$PREP_DIR/.shard-raw.tsv" 2>/dev/null || echo 0)
    actual=${actual:-0}
    if [[ "$actual" == "$EXPECTED_SHARDS" ]]; then
      echo "table=$tbl expected=$EXPECTED_SHARDS actual=$actual pass=true"  >> "$SHARD_REPORT"
    else
      echo "table=$tbl expected=$EXPECTED_SHARDS actual=$actual pass=false" >> "$SHARD_REPORT"
      ALL_PASS=false
    fi
  done

  if $ALL_PASS; then
    echo "overall_pass=true"  >> "$SHARD_REPORT"
    info "shard-count gate PASSED ($EXPECTED_SHARDS shards/table × 9 tables)"
  else
    echo "overall_pass=false" >> "$SHARD_REPORT"
    err  "shard-count gate FAILED — see $SHARD_REPORT"
    cat "$SHARD_REPORT" >&2
    die "shard-count hard gate fail-closed (PoC-DESIGN §7.5.4)"
  fi
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
