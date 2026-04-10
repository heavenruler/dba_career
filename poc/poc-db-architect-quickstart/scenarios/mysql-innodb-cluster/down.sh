#!/usr/bin/env bash
set -euo pipefail

for name in \
  mysql-innodb-cluster-router \
  mysql-innodb-cluster-node-1 \
  mysql-innodb-cluster-node-2 \
  mysql-innodb-cluster-node-3; do
  podman rm -f "${name}" >/dev/null 2>&1 || true
done
