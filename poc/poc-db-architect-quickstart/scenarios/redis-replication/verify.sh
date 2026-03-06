#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] 驗證 redis-replication"

MASTER_ROLE="$(podman exec redis-replication-master-1 redis-cli -p 6379 info replication | awk -F: '/^role:/{print $2}' | tr -d '\r')"
REPLICA1_ROLE="$(podman exec redis-replication-replica-1 redis-cli -p 6380 info replication | awk -F: '/^role:/{print $2}' | tr -d '\r')"
REPLICA2_ROLE="$(podman exec redis-replication-replica-2 redis-cli -p 6381 info replication | awk -F: '/^role:/{print $2}' | tr -d '\r')"

[[ "${MASTER_ROLE}" == "master" ]]
[[ "${REPLICA1_ROLE}" == "slave" ]]
[[ "${REPLICA2_ROLE}" == "slave" ]]

echo "[OK] 主從角色正確 (master + 2 replicas)"
