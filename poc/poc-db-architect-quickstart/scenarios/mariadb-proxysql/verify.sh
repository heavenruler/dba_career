#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mariadb-proxysql"

master="$(podman ps --format '{{.Names}}' | rg '^mariadb-proxysql-.*master-1$' -m 1 || true)"
if [[ -z "${master}" ]]; then
  echo "[ERROR] 找不到 mariadb-proxysql master 容器"
  exit 1
fi

for _ in {1..40}; do
  if podman exec "${master}" mariadb -h127.0.0.1 -P6033 -uappuser -papppass -e 'SELECT 1' >/dev/null 2>&1 && \
     podman exec "${master}" mariadb -h127.0.0.1 -P6032 -uadmin -padmin -Nse 'SELECT COUNT(*) FROM runtime_mysql_servers;' 2>/dev/null | grep -q '^3$'; then
    echo "[OK] mariadb-proxysql 驗證成功"
    exit 0
  fi
  sleep 3
done

echo "[ERROR] mariadb-proxysql 驗證逾時"
exit 1
