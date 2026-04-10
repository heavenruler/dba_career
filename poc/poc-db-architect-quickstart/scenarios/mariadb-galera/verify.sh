#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mariadb-galera"

node1="$(podman ps --format '{{.Names}}' | rg '^mariadb-galera-.*node-1$' -m 1 || true)"
if [[ -z "${node1}" ]]; then
  echo "[ERROR] 找不到 mariadb-galera node-1 容器"
  exit 1
fi

for _ in {1..40}; do
  size="$(podman exec "${node1}" mariadb -uroot -prootpass -Nse "SHOW STATUS LIKE 'wsrep_cluster_size';" 2>/dev/null | awk '{print $2}' || true)"
  ready="$(podman exec "${node1}" mariadb -uroot -prootpass -Nse "SHOW STATUS LIKE 'wsrep_ready';" 2>/dev/null | awk '{print $2}' || true)"
  if [[ "${size}" == "3" && "${ready}" == "ON" ]]; then
    echo "[OK] mariadb-galera 驗證成功"
    exit 0
  fi
  sleep 4
done

echo "[ERROR] mariadb-galera 驗證逾時"
exit 1
