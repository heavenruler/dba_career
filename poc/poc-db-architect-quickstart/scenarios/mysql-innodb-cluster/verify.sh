#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 mysql-innodb-cluster"

node1="$(podman ps --format '{{.Names}}' | rg '^mysql-innodb-cluster-.*node-1$' -m 1 || true)"
if [[ -z "${node1}" ]]; then
  echo "[ERROR] 找不到 mysql-innodb-cluster node-1 容器"
  exit 1
fi

for _ in {1..60}; do
  if podman exec "${node1}" mysql -uroot -prootpass -Nse "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';" 2>/dev/null | grep -q '^3$' && \
     podman exec "${node1}" mysql -uroot -prootpass -Nse "SELECT cluster_name FROM mysql_innodb_cluster_metadata.clusters;" 2>/dev/null | grep -q '^labCluster$' && \
     podman exec "${node1}" mysql -h127.0.0.1 -P6446 -uappuser -papppass -e 'SELECT 1' >/dev/null 2>&1; then
    echo "[OK] mysql-innodb-cluster 驗證成功"
    exit 0
  fi
  sleep 5
done

echo "[ERROR] mysql-innodb-cluster 驗證逾時"
exit 1
