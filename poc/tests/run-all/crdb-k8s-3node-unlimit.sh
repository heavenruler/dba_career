#!/bin/bash
# 全流程 wrapper：cleanup → prepare → run，在 .31 nohup 背景跑
set -euo pipefail
exec >>/tmp/cock-tpcc-runner/run-all.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export CRDB_HOST=172.24.40.32
export CRDB_PORT=30007
export CRDB_USER=root
export CRDB_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=k8s-3node-unlimit
export TOPO=cockroach-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/cock-tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/cock-tpcc-runner/cockroach-tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/cock-tpcc-runner/cockroach-tpcc.sh prepare

echo "--- run $(date '+%H:%M:%S') ---"
bash /tmp/cock-tpcc-runner/cockroach-tpcc.sh run

echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
