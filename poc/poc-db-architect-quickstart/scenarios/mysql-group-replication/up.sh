#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NETWORK_NAME="poc-mysql-ha-net"
MYSQL_IMAGE="${MYSQL_IMAGE:-docker.io/library/mysql:8.4}"

create_network() {
  podman network exists "${NETWORK_NAME}" || podman network create "${NETWORK_NAME}" >/dev/null
}

run_node() {
  local name="$1"
  local host_port="$2"
  local server_id="$3"
  local report_host="$4"
  local local_address="$5"
  local seeds="$6"
  local volume_dir="$7"
  local database_arg="$8"

  podman rm -f "${name}" >/dev/null 2>&1 || true
  mkdir -p "${volume_dir}"

  podman run -d --name "${name}" \
    --network "${NETWORK_NAME}" \
    --network-alias "${name}" \
    -p "${host_port}:3306" \
    -e MYSQL_ROOT_PASSWORD=rootpass \
    -e MYSQL_ROOT_HOST=% \
    ${database_arg:+-e MYSQL_DATABASE=${database_arg}} \
    -v "${volume_dir}:/var/lib/mysql" \
    "${MYSQL_IMAGE}" \
    sh -c "cat >/etc/mysql/conf.d/z-group-replication.cnf <<'EOF'
[mysqld]
bind-address=0.0.0.0
server-id=${server_id}
log_bin=mysql-bin
relay_log=relay-bin
binlog_format=ROW
gtid_mode=ON
enforce_gtid_consistency=ON
loose-group_replication_group_name=aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee
loose-group_replication_start_on_boot=OFF
loose-group_replication_local_address=${local_address}
loose-group_replication_group_seeds=${seeds}
loose-group_replication_bootstrap_group=OFF
loose-group_replication_single_primary_mode=ON
loose-group_replication_enforce_update_everywhere_checks=OFF
loose-group_replication_ip_allowlist=127.0.0.1/8,10.0.0.0/8,172.16.0.0/12
loose-group_replication_ssl_mode=DISABLED
loose-group_replication_recovery_get_public_key=ON
plugin_load_add=group_replication.so
mysqlx=OFF
report_host=${report_host}
report_port=3306
skip-name-resolve
EOF
exec docker-entrypoint.sh mysqld"
}

wait_ready() {
  local name="$1"
  for _ in {1..90}; do
    if podman exec "${name}" mysql -uroot -prootpass -e 'SELECT 1' >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "[ERROR] 容器未就緒: ${name}"
  exit 1
}

create_network

run_node "mysql-group-replication-node-1" 3320 21 "mysql-group-replication-node-1" "mysql-group-replication-node-1:33061" "mysql-group-replication-node-1:33061,mysql-group-replication-node-2:33061,mysql-group-replication-node-3:33061" "${ROOT_DIR}/volumes/mysql-group-replication/node1" "appdb"
run_node "mysql-group-replication-node-2" 3321 22 "mysql-group-replication-node-2" "mysql-group-replication-node-2:33061" "mysql-group-replication-node-1:33061,mysql-group-replication-node-2:33061,mysql-group-replication-node-3:33061" "${ROOT_DIR}/volumes/mysql-group-replication/node2" ""
run_node "mysql-group-replication-node-3" 3322 23 "mysql-group-replication-node-3" "mysql-group-replication-node-3:33061" "mysql-group-replication-node-1:33061,mysql-group-replication-node-2:33061,mysql-group-replication-node-3:33061" "${ROOT_DIR}/volumes/mysql-group-replication/node3" ""

wait_ready "mysql-group-replication-node-1"
wait_ready "mysql-group-replication-node-2"
wait_ready "mysql-group-replication-node-3"

podman exec "mysql-group-replication-node-1" mysql -uroot -prootpass <<'EOF'
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
GRANT CONNECTION_ADMIN, BACKUP_ADMIN, GROUP_REPLICATION_STREAM ON *.* TO 'repl'@'%';
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'apppass';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
FLUSH PRIVILEGES;
EOF

for name in mysql-group-replication-node-2 mysql-group-replication-node-3; do
  podman exec "${name}" mysql -uroot -prootpass -e 'RESET MASTER;' >/dev/null 2>&1 || true
done

for name in mysql-group-replication-node-1 mysql-group-replication-node-2 mysql-group-replication-node-3; do
  podman exec "${name}" mysql -uroot -prootpass -e "CHANGE REPLICATION SOURCE TO SOURCE_USER='repl', SOURCE_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';"
done

podman exec "mysql-group-replication-node-1" mysql -uroot -prootpass -e "SET GLOBAL group_replication_bootstrap_group=ON; START GROUP_REPLICATION; SET GLOBAL group_replication_bootstrap_group=OFF;"
podman exec "mysql-group-replication-node-2" mysql -uroot -prootpass -e "START GROUP_REPLICATION;"

for _ in {1..60}; do
  if podman exec "mysql-group-replication-node-1" mysql -uroot -prootpass -Nse "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';" | grep -q '^2$'; then
    break
  fi
  sleep 2
done

sleep 20
podman exec "mysql-group-replication-node-3" mysql -uroot -prootpass -e "START GROUP_REPLICATION;"
