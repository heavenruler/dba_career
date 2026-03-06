#!/usr/bin/env bash
set -euo pipefail

echo "[redis-standalone] ping check"
podman exec redis-standalone-1 redis-cli -p 6379 PING
