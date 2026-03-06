#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

mkdir -p "${ROOT_DIR}/volumes" \
  "${ROOT_DIR}/volumes/redis-standalone" \
  "${ROOT_DIR}/volumes/redis-replication" \
  "${ROOT_DIR}/volumes/redis-sentinel" \
  "${ROOT_DIR}/volumes/redis-cluster"

if ! command -v podman >/dev/null 2>&1; then
  echo "[ERROR] 找不到 podman，請先執行: brew install podman"
  exit 1
fi

if ! podman machine inspect >/dev/null 2>&1; then
  echo "[INFO] 建立 podman machine"
  podman machine init
fi

if ! podman machine inspect --format '{{.State}}' | grep -q '^running$'; then
  echo "[INFO] 啟動 podman machine"
  podman machine start
fi

echo "[OK] 初始化完成"
