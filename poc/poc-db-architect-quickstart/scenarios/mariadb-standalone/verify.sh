#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mariadb-standalone"

container_name="$(podman ps --format '{{.Names}}' | rg '^mariadb-standalone-' -m 1 || true)"
if [[ -z "${container_name}" ]]; then
  echo "[ERROR] 找不到 mariadb-standalone 容器"
  exit 1
fi

for _ in {1..30}; do
  if podman exec "${container_name}" mariadb -uroot -prootpass -e 'SELECT VERSION();' >/dev/null 2>&1; then
    echo "[OK] mariadb-standalone 驗證成功"
    exit 0
  fi
  sleep 2
done

echo "[ERROR] mariadb-standalone 啟動逾時"
exit 1
