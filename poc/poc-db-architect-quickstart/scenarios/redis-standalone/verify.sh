#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 redis-standalone"
podman exec redis-standalone-1 redis-cli -p 6379 ping | grep -q PONG
echo "[OK] redis-standalone 驗證成功"
