#!/usr/bin/env bash
set -euo pipefail

echo "[redis-replication] role check"
podman exec redis-replication-master-1 redis-cli -p 6380 INFO replication | rg "role:master"
podman exec redis-replication-replica-1 redis-cli -p 6381 INFO replication | rg "role:slave"
podman exec redis-replication-replica-2 redis-cli -p 6382 INFO replication | rg "role:slave"
