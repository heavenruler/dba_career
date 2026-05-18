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

YB_TSERVER_FLAGS="memory_limit_hard_bytes=11811160064,db_block_cache_size_percentage=50,durable_wal_write=true,require_durable_wal_write=true,yb_enable_read_committed_isolation=true,ysql_enable_auth=false,ysql_enable_auto_analyze=false"

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$DB_HOST" "$@"
}

info "cold reset YugabyteDB on $DB_HOST"
remote "set -euo pipefail
  runuser -u yugabyte -- yugabyted stop --base_dir=/var/yugabyte || true
  sync
  echo 3 > /proc/sys/vm/drop_caches
  runuser -u yugabyte -- yugabyted start --base_dir=/var/yugabyte --advertise_address=172.24.40.32 --tserver_flags=${YB_TSERVER_FLAGS}
  for i in \$(seq 1 60); do
    if ysqlsh -h 172.24.40.32 -p 5433 -U yugabyte -d yugabyte -c 'SELECT 1' >/dev/null 2>&1; then
      exit 0
    fi
    sleep 5
  done
  exit 1
"
sleep 60
info "cold reset YugabyteDB done"

