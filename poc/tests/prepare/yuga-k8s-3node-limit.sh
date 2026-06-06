#!/bin/bash
# Stub: pre-v4.7 K8s prepare for YBDB resource-limited variant.
# Mirrors yuga-k8s-3node-unlimit.sh; switches VARIANT to point at vars/yuga-k8s-3node-limit.yml.
#
# 警告：此腳本為 pre-v4.7（WARMUP=5m / SCENARIO=S-BASE），與 phase-k8s/manifest.yaml (v4.7 / S-K8S)
# 不對齊。phase-k8s/README.md §「Pending v4.7 K8s wrapper」說明補完後此 stub 將 deprecated。
# 本 stub 補齊 codex review challenge #1 指出的缺檔，使 limit / unlimit 對稱可重現。
set -euo pipefail
exec >>/tmp/yuga-tpcc-runner/prepare-limit-2025.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="
export YUGA_HOST=172.24.40.32
export YUGA_PORT=30005
export YUGA_USER=yugabyte
export YUGA_PASS=
export WAREHOUSES=128
export DURATION=10m
export THREADS_LIST="16 32 64 128"
export WARMUP=5m
export VARIANT=k8s-3node-limit
export TOPO=yuga-tc1
export SCENARIO=S-BASE
export RESULT_BASE=/tmp/yuga-tpcc-runner/results
export DB_NAME=tpcc

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh cleanup || echo "cleanup non-fatal: $?"

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh prepare

echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
