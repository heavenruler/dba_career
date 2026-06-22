#!/usr/bin/env bash
# run-round-only.sh — 純 go-tpc tpcc run，不含 cold-reset / warmup / prepare
# 接 env 變數：
#   DB           tidb|crdb|ybdb
#   TPCC_CLIENT  (caller 傳入，此腳本在 client 上直接執行)
#   RESULT_DIR   結果根目錄（本機 mac side，由 Makefile 建）
#   SMOKE_ROUND  round 序號
#   WAREHOUSES   預設 4
#   RUN_SEC      預設 300
#   THREADS_LIST 預設 16（可多值空格分隔）
#
# 寫結果到：$RESULT_DIR/round-$SMOKE_ROUND/<db>/go-tpc-stdout.txt
# 此腳本由 Makefile phase-roundrun-only-<db> 透過 ssh 到 TPCC_CLIENT 執行
set -euo pipefail

DB=${DB:?DB not set}
SMOKE_ROUND=${SMOKE_ROUND:?SMOKE_ROUND not set}
RESULT_DIR=${RESULT_DIR:?RESULT_DIR not set}
WAREHOUSES=${WAREHOUSES:-4}
RUN_SEC=${RUN_SEC:-300}
THREADS_LIST=${THREADS_LIST:-16}

# DB 連線參數
case "$DB" in
  tidb)
    DB_HOST=${TIDB_HOST:-172.24.40.32}
    DB_PORT=${TIDB_PORT:-4000}
    DRIVER=mysql
    DB_NAME=${TIDB_DB:-tpcc}
    EXTRA_FLAGS=""
    ;;
  crdb)
    DB_HOST=${CRDB_HOST:-172.24.40.32}
    DB_PORT=${CRDB_PORT:-26257}
    DRIVER=postgres
    DB_NAME=${CRDB_DB:-tpcc}
    EXTRA_FLAGS="--conn-params sslmode=disable"
    ;;
  ybdb)
    DB_HOST=${YBDB_HOST:-172.24.40.32}
    DB_PORT=${YBDB_PORT:-5433}
    DRIVER=postgres
    DB_NAME=${YBDB_DB:-tpcc}
    EXTRA_FLAGS="--conn-params sslmode=disable"
    ;;
  *)
    echo "[run-round-only] ERROR: unknown DB=$DB (must be tidb|crdb|ybdb)" >&2
    exit 1
    ;;
esac

ROUND_DIR="$RESULT_DIR/round-$SMOKE_ROUND/$DB"
mkdir -p "$ROUND_DIR"

STDOUT_FILE="$ROUND_DIR/go-tpc-stdout.txt"

echo "[run-round-only] DB=$DB ROUND=$SMOKE_ROUND W=$WAREHOUSES T=$THREADS_LIST S=${RUN_SEC}s"
echo "[run-round-only] output → $STDOUT_FILE"

# go-tpc tpcc run (純 run，不 prepare / warmup / cold-reset)
go-tpc tpcc \
  --host "$DB_HOST" \
  --port "$DB_PORT" \
  --driver "$DRIVER" \
  --db "$DB_NAME" \
  --warehouses "$WAREHOUSES" \
  --threads "$THREADS_LIST" \
  --time "${RUN_SEC}s" \
  $EXTRA_FLAGS \
  run \
  2>&1 | tee "$STDOUT_FILE"

echo "[run-round-only] DB=$DB ROUND=$SMOKE_ROUND done"
