#!/bin/bash
# 全流程 wrapper：cleanup → prepare → run，在 .31 nohup 背景跑
# RF=3 / 直連 .32:5433（prepare --no-check，不需 HAProxy）
set -euo pipefail
exec >>/tmp/yuga-tpcc-runner/run-all-vm-3node-direct.log 2>&1

echo "=== START $(date '+%Y-%m-%d %H:%M:%S') ==="

export YUGA_HOST=172.24.40.32
export YUGA_PORT=5433
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

echo "--- wait for YBDB ready ---"
for i in $(seq 1 60); do
  if psql "host=${YUGA_HOST} port=${YUGA_PORT} user=${YUGA_USER} dbname=yugabyte sslmode=disable" \
      -c "SELECT 1" -q >/dev/null 2>&1; then
    echo "YBDB ready at ${i}s"
    break
  fi
  echo "  waiting... ${i}/60"
  sleep 5
done

echo "--- cleanup $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh cleanup || echo "cleanup non-fatal: $?"
sleep 5

echo "--- prepare $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh prepare

echo "--- run $(date '+%H:%M:%S') ---"
bash /tmp/yuga-tpcc-runner/yuga-tpcc.sh run

echo "=== END $(date '+%Y-%m-%d %H:%M:%S') ==="
