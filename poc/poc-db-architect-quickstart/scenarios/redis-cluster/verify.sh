#!/usr/bin/env bash
set -euo pipefail

echo "[redis-cluster] topology check"
podman exec redis-cluster-node-1 redis-cli -p 7001 cluster info | rg "cluster_state:ok"
podman exec redis-cluster-node-1 redis-cli -p 7001 cluster nodes | head -n 6
