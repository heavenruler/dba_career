#!/bin/bash
# 全流程 wrapper：cleanup → prepare only，在 .31 nohup 背景跑
# K8s NodePort .32:30004 / 容器資源限制啟用（TiKV limit cpu=2/mem=8Gi 為主要瓶頸）
set -euo pipefail
exec >>/tmp/tpcc-runner/prepare-k8s-3node-limit.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export TIDB_HOST=172.24.40.32
export TIDB_PORT=30004
export TIDB_USER=root
export TIDB_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=k8s-3node-limit
export TOPO=tidb-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/tpcc-runner/tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/tpcc-runner/tpcc.sh prepare


echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
