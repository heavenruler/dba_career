#!/bin/bash
# 全流程 wrapper：cleanup → prepare only，在 .31 nohup 背景跑
# tidb_rf=3 / AUTO_ANALYZE 關閉 / 直連 .32:4000（不過 HAProxy）
set -euo pipefail
exec >>/tmp/tpcc-runner/prepare-vm-3node-direct.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export TIDB_HOST=172.24.40.32
export TIDB_PORT=4000
export TIDB_USER=root
export TIDB_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=vm-3node-direct
export TOPO=tidb-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/tpcc-runner/tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- disable AUTO_ANALYZE $(date '+%H:%M:%S') ---"
mysql -h "${TIDB_HOST}" -P "${TIDB_PORT}" -u "${TIDB_USER}" \
  -e "SET GLOBAL tidb_enable_auto_analyze = OFF"

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/tpcc-runner/tpcc.sh prepare


echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
