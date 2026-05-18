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

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$DB_HOST" "$@"
}

info "cold reset TiDB on $DB_HOST"
remote 'set -euo pipefail
  export PATH=/root/.tiup/bin:$PATH
  tiup cluster stop tpcc-tidb --yes
  sync
  echo 3 > /proc/sys/vm/drop_caches
  tiup cluster start tpcc-tidb --yes
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

