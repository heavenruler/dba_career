#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 redis-sentinel"

for p in 26379 26380 26381; do
  podman exec redis-sentinel-node-1 redis-cli -h 127.0.0.1 -p "${p}" ping | grep -q PONG
done

MASTER_NAME="$(podman exec redis-sentinel-node-1 redis-cli -h 127.0.0.1 -p 26379 SENTINEL get-master-addr-by-name mymaster | sed -n '1p')"
MASTER_PORT="$(podman exec redis-sentinel-node-1 redis-cli -h 127.0.0.1 -p 26379 SENTINEL get-master-addr-by-name mymaster | sed -n '2p')"

[[ "${MASTER_NAME}" == "127.0.0.1" ]]
[[ "${MASTER_PORT}" == "6390" ]]

echo "[OK] Sentinel 三節點與主節點監控正常"
