#!/bin/bash
# 全流程 wrapper：cleanup → prepare only，在 .31 nohup 背景跑
# 經 HAProxy .32:15257 → roundrobin 三節點 :26257
set -euo pipefail
exec >>/tmp/cock-tpcc-runner/prepare-vm-3node-haproxy.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export CRDB_HOST=172.24.40.32
export CRDB_PORT=15257
export CRDB_USER=root
export CRDB_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=vm-3node
export TOPO=cockroach-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/cock-tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/cock-tpcc-runner/cockroach-tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/cock-tpcc-runner/cockroach-tpcc.sh prepare


echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
