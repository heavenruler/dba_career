#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NETWORK_NAME="poc-mysql-ha-net"
MYSQL_IMAGE="${MYSQL_IMAGE:-docker.io/library/mysql:8.4}"
MYSQL_ROUTER_IMAGE="${MYSQL_ROUTER_IMAGE:-container-registry.oracle.com/mysql/community-router:8.4.8}"

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
    sh -c "cat >/etc/mysql/conf.d/z-innodb-cluster.cnf <<'EOF'
[mysqld]
bind-address=0.0.0.0
server-id=${server_id}
log_bin=mysql-bin
relay_log=relay-bin
binlog_format=ROW
gtid_mode=ON
enforce_gtid_consistency=ON
loose-group_replication_group_name=bbbbbbbb-cccc-dddd-eeee-ffffffffffff
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

run_node "mysql-innodb-cluster-node-1" 3330 31 "mysql-innodb-cluster-node-1" "mysql-innodb-cluster-node-1:33061" "mysql-innodb-cluster-node-1:33061,mysql-innodb-cluster-node-2:33061,mysql-innodb-cluster-node-3:33061" "${ROOT_DIR}/volumes/mysql-innodb-cluster/node1" "appdb"
run_node "mysql-innodb-cluster-node-2" 3331 32 "mysql-innodb-cluster-node-2" "mysql-innodb-cluster-node-2:33061" "mysql-innodb-cluster-node-1:33061,mysql-innodb-cluster-node-2:33061,mysql-innodb-cluster-node-3:33061" "${ROOT_DIR}/volumes/mysql-innodb-cluster/node2" ""
run_node "mysql-innodb-cluster-node-3" 3332 33 "mysql-innodb-cluster-node-3" "mysql-innodb-cluster-node-3:33061" "mysql-innodb-cluster-node-1:33061,mysql-innodb-cluster-node-2:33061,mysql-innodb-cluster-node-3:33061" "${ROOT_DIR}/volumes/mysql-innodb-cluster/node3" ""

wait_ready "mysql-innodb-cluster-node-1"
wait_ready "mysql-innodb-cluster-node-2"
wait_ready "mysql-innodb-cluster-node-3"

podman exec "mysql-innodb-cluster-node-1" mysql -uroot -prootpass <<'EOF'
CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
GRANT CONNECTION_ADMIN, BACKUP_ADMIN, GROUP_REPLICATION_STREAM ON *.* TO 'repl'@'%';
CREATE USER IF NOT EXISTS 'appuser'@'%' IDENTIFIED BY 'apppass';
GRANT ALL PRIVILEGES ON appdb.* TO 'appuser'@'%';
CREATE USER IF NOT EXISTS 'icadmin'@'%' IDENTIFIED BY 'clusterpass';
GRANT ALL PRIVILEGES ON *.* TO 'icadmin'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
EOF

for name in mysql-innodb-cluster-node-2 mysql-innodb-cluster-node-3; do
  podman exec "${name}" mysql -uroot -prootpass -e 'RESET MASTER;' >/dev/null 2>&1 || true
done

for name in mysql-innodb-cluster-node-1 mysql-innodb-cluster-node-2 mysql-innodb-cluster-node-3; do
  podman exec "${name}" mysql -uroot -prootpass -e "CHANGE REPLICATION SOURCE TO SOURCE_USER='repl', SOURCE_PASSWORD='replpass' FOR CHANNEL 'group_replication_recovery';"
done

podman exec "mysql-innodb-cluster-node-1" mysql -uroot -prootpass -e "SET GLOBAL group_replication_bootstrap_group=ON; START GROUP_REPLICATION; SET GLOBAL group_replication_bootstrap_group=OFF;"

for _ in {1..60}; do
  if podman exec "mysql-innodb-cluster-node-1" mysql -uroot -prootpass -Nse "SELECT COUNT(*) FROM performance_schema.replication_group_members WHERE MEMBER_STATE='ONLINE';" | grep -q '^1$'; then
    break
  fi
  sleep 2
done

podman exec "mysql-innodb-cluster-node-1" mysqlsh icadmin:clusterpass@127.0.0.1:3306 --js --execute "shell.connect('icadmin:clusterpass@127.0.0.1:3306'); var cluster = dba.createCluster('labCluster', {adoptFromGR: true}); print(cluster.status());" >/dev/null

podman rm -f mysql-innodb-cluster-router >/dev/null 2>&1 || true
podman run -d --name mysql-innodb-cluster-router \
  --network "${NETWORK_NAME}" \
  --network-alias mysql-innodb-cluster-router \
  -p 6446:6446 \
  -p 6447:6447 \
  "${MYSQL_ROUTER_IMAGE}" \
  sh -c "until mysqlrouter --bootstrap icadmin:clusterpass@mysql-innodb-cluster-node-1:3306 --directory /tmp/mysqlrouter --force >/tmp/mysqlrouter-bootstrap.log 2>&1; do sleep 5; done; exec mysqlrouter --config /tmp/mysqlrouter/mysqlrouter.conf"
