#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mysql-replication"

master="$(podman ps --format '{{.Names}}' | rg '^mysql-replication-.*master-1$' -m 1 || true)"
replica1="$(podman ps --format '{{.Names}}' | rg '^mysql-replication-.*replica-1$' -m 1 || true)"
replica2="$(podman ps --format '{{.Names}}' | rg '^mysql-replication-.*replica-2$' -m 1 || true)"

if [[ -z "${master}" || -z "${replica1}" || -z "${replica2}" ]]; then
  echo "[ERROR] 找不到 mysql-replication 容器"
  exit 1
fi

check_replica() {
  local container="$1"
  local status
  status="$(podman exec "${container}" mysql -uroot -prootpass -e 'SHOW SLAVE STATUS\G' 2>/dev/null || true)"
  if [[ -z "${status}" ]]; then
    status="$(podman exec "${container}" mysql -uroot -prootpass -e 'SHOW REPLICA STATUS\G' 2>/dev/null || true)"
  fi
  [[ "${status}" == *"Replica_IO_Running: Yes"* || "${status}" == *"Slave_IO_Running: Yes"* ]] && \
  [[ "${status}" == *"Replica_SQL_Running: Yes"* || "${status}" == *"Slave_SQL_Running: Yes"* ]]
}

for _ in {1..30}; do
  if podman exec "${master}" mysql -uroot -prootpass -e 'SELECT 1' >/dev/null 2>&1 && \
     check_replica "${replica1}" && check_replica "${replica2}"; then
    echo "[OK] mysql-replication 驗證成功"
    exit 0
  fi
  sleep 3
done

echo "[ERROR] mysql-replication 驗證逾時"
exit 1
