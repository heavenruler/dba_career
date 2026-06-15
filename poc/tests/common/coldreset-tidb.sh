#!/usr/bin/env bash
set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB_HOST=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db-host) DB_HOST=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB_HOST" ]] || die "missing --db-host"

# HAProxy 等 proxy 拓樸：db-host 是 proxy（無 tiup / TiDB process）；cold-reset 必須
# 走實 cluster member。tiup cluster 是中心化管理在 .32 上，所以 fallback 一律 .32。
case "$DB_HOST" in
  172.24.40.32|172.24.40.33|172.24.40.34) CLUSTER_HOST="$DB_HOST" ;;
  *)                                       CLUSTER_HOST="172.24.40.32" ;;  # HAProxy → fallback .32
esac

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$CLUSTER_HOST" "$@"
}

info "cold reset TiDB on $CLUSTER_HOST (db-host=$DB_HOST)"
remote 'set -euo pipefail
  export PATH=/root/.tiup/bin:$PATH
  # vm-1node = tpcc-tidb；vm-3node / haproxy = tpcc-tidb-vm3；vm-6node (X-CROSS) = tpcc-tidb-vm6；自動偵測（vm6 優先）
  CLUSTER_NAME=""
  if tiup cluster list 2>/dev/null | awk "{print \$1}" | grep -qx tpcc-tidb-vm6; then
    CLUSTER_NAME=tpcc-tidb-vm6
  elif tiup cluster list 2>/dev/null | awk "{print \$1}" | grep -qx tpcc-tidb-vm3; then
    CLUSTER_NAME=tpcc-tidb-vm3
  elif tiup cluster list 2>/dev/null | awk "{print \$1}" | grep -qx tpcc-tidb; then
    CLUSTER_NAME=tpcc-tidb
  else
    echo "ERROR: no tiup cluster found (expected tpcc-tidb / tpcc-tidb-vm3 / tpcc-tidb-vm6)" >&2
    exit 1
  fi
  echo "cold-resetting tiup cluster=$CLUSTER_NAME"
  tiup cluster stop "$CLUSTER_NAME" --yes
  sync
  echo 3 > /proc/sys/vm/drop_caches
  tiup cluster start "$CLUSTER_NAME" --yes
  for i in $(seq 1 60); do
    if mysql -h 172.24.40.32 -P 4000 -uroot -e "SELECT 1" >/dev/null 2>&1; then
      exit 0
    fi
    sleep 5
  done
  exit 1
'
sleep 60
info "cold reset TiDB done"

