#!/bin/bash
# 全流程 wrapper：cleanup → prepare → run，在 .31 nohup 背景跑
# tidb_rf=3 / AUTO_ANALYZE 關閉 / HAProxy .34:4000 → roundrobin .32:4000 / .33:4000
# prepare 連直連 .32（HAProxy 無法接受 prepare 的 DDL 廣播）；run 改走 HAProxy
set -euo pipefail
exec >>/tmp/tpcc-runner/run-all-vm-3node-haproxy.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export TIDB_USER=root
export TIDB_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=vm-3node
export TOPO=tidb-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup via direct .32 $(date '+%H:%M:%S') ---"
TIDB_HOST=172.24.40.32 TIDB_PORT=4000 bash /tmp/tpcc-runner/tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- disable AUTO_ANALYZE $(date '+%H:%M:%S') ---"
mysql -h 172.24.40.32 -P 4000 -u "${TIDB_USER}" \
  -e "SET GLOBAL tidb_enable_auto_analyze = OFF"

echo "--- prepare via direct .32 $(date '+%H:%M:%S') ---"
TIDB_HOST=172.24.40.32 TIDB_PORT=4000 bash /tmp/tpcc-runner/tpcc.sh prepare

echo "--- run via HAProxy .34:4000 $(date '+%H:%M:%S') ---"
TIDB_HOST=172.24.40.34 TIDB_PORT=4000 bash /tmp/tpcc-runner/tpcc.sh run

echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
