#!/bin/bash
# 全流程 wrapper：cleanup → prepare only，在 .31 nohup 背景跑
# RF=3 / HAProxy .32:15433 → roundrobin 三節點 :5433
# 原始測試沿用 vm-3node-direct 同份資料（未重建），此 wrapper 加入 cleanup+prepare 供重跑使用
set -euo pipefail
exec >>/tmp/yuga-tpcc-runner/prepare-vm-3node-haproxy.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export YUGA_HOST=172.24.40.32
export YUGA_PORT=15433
export YUGA_USER=yugabyte
export YUGA_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=vm-3node
export TOPO=yuga-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/yuga-tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh prepare


echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
