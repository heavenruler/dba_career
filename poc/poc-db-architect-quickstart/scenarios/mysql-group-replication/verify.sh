#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mysql-group-replication"

node1="$(podman ps --format '{{.Names}}' | rg '^mysql-group-replication-.*node-1$' -m 1 || true)"
if [[ -z "${node1}" ]]; then
  echo "[ERROR] 找不到 mysql-group-replication node-1 容器"
  exit 1
fi

for _ in {1..50}; do
  if podman exec "${node1}" mysql -uroot -prootpass -Nse "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';" 2>/dev/null | grep -q '^3$'; then
    echo "[OK] mysql-group-replication 驗證成功"
    exit 0
  fi
  sleep 4
done

echo "[ERROR] mysql-group-replication 驗證逾時"
exit 1
