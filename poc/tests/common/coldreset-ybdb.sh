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

# 2026-06-09: K8s topology → kubectl rollout restart sts/yb-tserver + sts/yb-master
if [[ "${TOPOLOGY:-}" =~ ^k8s- ]]; then
  K3S_HOST="${K3S_HOST:-172.24.40.32}"
  NS="${K8S_NAMESPACE:-yb-demo}"
  DB_PORT="${YBDB_PORT:-30005}"
  info "K8s cold-reset: kubectl rollout restart sts/yb-tserver + drop_caches × 3 k3s nodes"
  ssh -o StrictHostKeyChecking=accept-new "root@$K3S_HOST" "set -euo pipefail
    k3s kubectl -n '$NS' rollout restart sts/yb-tserver
    k3s kubectl -n '$NS' rollout status sts/yb-tserver --timeout=300s
  "
  for ip in 172.24.40.32 172.24.40.33 172.24.40.34; do
    ssh -o StrictHostKeyChecking=accept-new "root@$ip" 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>&1 || warn "drop_caches failed on $ip"
  done
  for i in $(seq 1 60); do
    if psql "postgres://yugabyte@${K3S_HOST}:${DB_PORT}/yugabyte" -t -c 'SELECT 1' >/dev/null 2>&1; then
      sleep 60
      info "cold reset YugabyteDB (K8s) done"
      exit 0
    fi
    sleep 5
  done
  die "YBDB NodePort $K3S_HOST:$DB_PORT not reachable post-cold-reset"
fi

YB_TSERVER_FLAGS="memory_limit_hard_bytes=11811160064,db_block_cache_size_percentage=50,durable_wal_write=true,require_durable_wal_write=true,yb_enable_read_committed_isolation=true,ysql_enable_auth=false,ysql_enable_auto_analyze=false"

# HAProxy 等 proxy 拓樸：db-host 是 proxy（無 yugabyte user）；cold-reset 必須
# 走實 cluster member。advertise_address 已硬寫 .32，因此 ssh 也跟著 .32。
case "$DB_HOST" in
  172.24.40.32|172.24.40.33|172.24.40.34) CLUSTER_HOST="$DB_HOST" ;;
  *)                                       CLUSTER_HOST="172.24.40.32" ;;  # HAProxy → fallback .32
esac

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$CLUSTER_HOST" "$@"
}

info "cold reset YugabyteDB on $CLUSTER_HOST (db-host=$DB_HOST)"
remote "set -euo pipefail
  runuser -u yugabyte -- yugabyted stop --base_dir=/var/yugabyte || true
  sync
  echo 3 > /proc/sys/vm/drop_caches
  runuser -u yugabyte -- yugabyted start --base_dir=/var/yugabyte --advertise_address=172.24.40.32 --join=172.24.40.33 --tserver_flags=${YB_TSERVER_FLAGS}
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

