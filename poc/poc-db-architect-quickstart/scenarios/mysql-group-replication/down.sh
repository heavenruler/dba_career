#!/usr/bin/env bash
set -euo pipefail

for name in \
  mysql-group-replication-node-1 \
  mysql-group-replication-node-2 \
  mysql-group-replication-node-3; do
  podman rm -f "${name}" >/dev/null 2>&1 || true
done
