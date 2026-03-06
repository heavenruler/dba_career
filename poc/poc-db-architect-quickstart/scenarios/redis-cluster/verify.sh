#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 redis-cluster"

for p in 7001 7002 7003 7004 7005 7006; do
  podman exec redis-cluster-node-1 redis-cli -h 127.0.0.1 -p "${p}" ping | grep -q PONG
done

STATE="$(podman exec redis-cluster-node-1 redis-cli -h 127.0.0.1 -p 7001 cluster info | awk -F: '/cluster_state/{print $2}' | tr -d '\r')"
KNOWN_NODES="$(podman exec redis-cluster-node-1 redis-cli -h 127.0.0.1 -p 7001 cluster info | awk -F: '/cluster_known_nodes/{print $2}' | tr -d '\r')"

[[ "${STATE}" == "ok" ]]
[[ "${KNOWN_NODES}" == "6" ]]

echo "[OK] redis-cluster 六節點叢集正常"
