#!/usr/bin/env bash
set -euo pipefail

echo "[redis-sentinel] monitor check"
podman exec redis-sentinel-node-1 redis-cli -p 26379 SENTINEL masters | rg "mymaster"
podman exec redis-sentinel-node-2 redis-cli -p 26380 SENTINEL ckquorum mymaster
podman exec redis-sentinel-node-3 redis-cli -p 26381 SENTINEL ckquorum mymaster
