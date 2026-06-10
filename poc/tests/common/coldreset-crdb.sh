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

# 2026-06-09: K8s topology → kubectl rollout restart sts/cockroachdb (no systemd)
if [[ "${TOPOLOGY:-}" =~ ^k8s- ]]; then
  K3S_HOST="${K3S_HOST:-172.24.40.32}"
  NS="${K8S_NAMESPACE:-cockroach-tc1}"
  DB_PORT="${CRDB_PORT:-30007}"
  info "K8s cold-reset: kubectl rollout restart sts/cockroachdb + drop_caches × 3 k3s nodes"
  ssh -o StrictHostKeyChecking=accept-new "root@$K3S_HOST" "set -euo pipefail
    k3s kubectl -n '$NS' rollout restart sts/cockroachdb
    k3s kubectl -n '$NS' rollout status sts/cockroachdb --timeout=240s
  "
  for ip in 172.24.40.32 172.24.40.33 172.24.40.34; do
    ssh -o StrictHostKeyChecking=accept-new "root@$ip" 'sync; echo 3 > /proc/sys/vm/drop_caches' 2>&1 || warn "drop_caches failed on $ip"
  done
  for i in $(seq 1 60); do
    if psql "postgres://root@${K3S_HOST}:${DB_PORT}/defaultdb?sslmode=disable" -t -c 'SELECT 1' >/dev/null 2>&1; then
      sleep 60
      info "cold reset CockroachDB (K8s) done"
      exit 0
    fi
    sleep 5
  done
  die "CRDB NodePort $K3S_HOST:$DB_PORT not reachable post-cold-reset"
fi

# vm-1node: cockroach 只在 .32；vm-3node / haproxy: 三節點都有 cockroach.service。
# 自動 probe 三台是否有 cockroach.service，對有的全部 stop / drop_caches / start。
COCKROACH_HOSTS=()
for h in 172.24.40.32 172.24.40.33 172.24.40.34; do
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=3 "root@$h" \
       'systemctl list-unit-files cockroach.service 2>/dev/null | grep -q cockroach' 2>/dev/null; then
    COCKROACH_HOSTS+=("$h")
  fi
done
[[ ${#COCKROACH_HOSTS[@]} -gt 0 ]] || die "no cockroach.service found on .32/.33/.34"

info "cold reset CockroachDB on hosts: ${COCKROACH_HOSTS[*]} (db-host=$DB_HOST)"
# 平行 stop + drop_caches + start，每台 ssh 內部走 systemctl graceful quit
pids=()
for h in "${COCKROACH_HOSTS[@]}"; do
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$h" '
    set -euo pipefail
    systemctl stop cockroach
    sync
    echo 3 > /proc/sys/vm/drop_caches
    systemctl start cockroach
  ' &
  pids+=($!)
done
fail=0
for p in "${pids[@]}"; do wait "$p" || fail=1; done
[[ $fail -eq 0 ]] || die "cockroach stop/start failed on one or more hosts"

# 等任一節點 SELECT 1 通過（cluster quorum 已恢復）
for i in $(seq 1 60); do
  for h in "${COCKROACH_HOSTS[@]}"; do
    if ssh -o ConnectTimeout=3 "root@$h" \
         "cockroach sql --insecure --host=$h:26257 -e 'SELECT 1'" >/dev/null 2>&1; then
      sleep 60
      info "cold reset CockroachDB done"
      exit 0
    fi
  done
  sleep 5
done
die "cockroach cluster did not come back online within 300s"

