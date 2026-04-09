#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mysql-standalone"

CONTAINER_NAME="$(podman ps --format '{{.Names}}' | rg '^mysql-standalone-' -m 1 || true)"
if [[ -z "${CONTAINER_NAME}" ]]; then
  echo "[ERROR] 找不到 mysql-standalone 容器"
  exit 1
fi

for _ in {1..30}; do
  if podman exec "${CONTAINER_NAME}" mysql -uroot -prootpass -e 'SELECT VERSION();' >/dev/null 2>&1; then
    echo "[OK] mysql-standalone 驗證成功"
    exit 0
  fi
  sleep 2
done

echo "[ERROR] mysql-standalone 啟動逾時"
exit 1
