#!/bin/bash
# 全流程 wrapper：cleanup → prepare → run，在 .31 nohup 背景跑
# RF=3 / prepare 走 HAProxy :15433（避免直連 check SQL 被 HAProxy 30s timeout 切斷）
#         execute 走直連 .32:5433（不過 HAProxy）
set -euo pipefail
exec >>/tmp/yuga-tpcc-runner/run-all-vm-3node-direct.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export YUGA_USER=yugabyte
export YUGA_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=vm-3node-direct
export TOPO=yuga-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/yuga-tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup via direct .32:5433 $(date '+%H:%M:%S') ---"
YUGA_HOST=172.24.40.32 YUGA_PORT=5433 bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- prepare via HAProxy .32:15433 $(date '+%H:%M:%S') ---"
YUGA_HOST=172.24.40.32 YUGA_PORT=15433 bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh prepare

echo "--- run via direct .32:5433 $(date '+%H:%M:%S') ---"
YUGA_HOST=172.24.40.32 YUGA_PORT=5433 bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh run

echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
