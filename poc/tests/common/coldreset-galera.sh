#!/usr/bin/env bash
# coldreset-galera.sh — rolling cache-drop across all 6 Galera nodes.
#
# Galera 沒有 leader/lease，6 台都是對等的完整副本，理論上可以像 CRDB 一樣
# 平行 stop/drop_caches/start——但 Galera 沒有 Raft 那種「多數派存活即可繼續
# 服務」的容錯設計給「全部一起重啟」這個動作背書：全部同時下線代表沒有一個
# live 的 primary component 可以讓其他節點 rejoin，重新形成 primary 需要靠
# grastate.dat 的 safe_to_bootstrap 手動介入，不是這支腳本該做的事。改用
# 逐台（rolling）restart：任何時刻最多 1 台離線，其餘 5/6 台維持 quorum，
# 每台重啟後等它真正 Synced 回叢集才換下一台。
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

: "${GALERA_BENCH_PASSWORD:?missing GALERA_BENCH_PASSWORD}"
export MYSQL_PWD="$GALERA_BENCH_PASSWORD"
GALERA_USER="${GALERA_USER:-tpcc_bench}"
GALERA_PORT="${GALERA_PORT:-3306}"

# CLUSTER_HOSTS 由 run-vm6-suite.sh export（格式 "name@ip ..."）；vm-1node
# 等非 X-CROSS 拓樸沒有這個 env，退化成只重啟 $DB_HOST 一台（單機測試場景）。
if [[ -n "${CLUSTER_HOSTS:-}" ]]; then
  NODES=()
  for entry in $CLUSTER_HOSTS; do NODES+=("${entry#*@}"); done
else
  NODES=("$DB_HOST")
fi

info "cold reset Galera: rolling restart across ${#NODES[@]} node(s): ${NODES[*]}"

wait_synced() {  # wait_synced <ip> — 等這台自己回報 Synced，最多 60x5s
  local ip=$1
  for i in $(seq 1 60); do
    local state
    state=$(mysql -h "$ip" -P "$GALERA_PORT" -u "$GALERA_USER" -N -B \
      -e "SHOW STATUS LIKE 'wsrep_local_state_comment';" 2>/dev/null | awk '{print $2}')
    [[ "$state" == "Synced" ]] && return 0
    sleep 5
  done
  return 1
}

for ip in "${NODES[@]}"; do
  info "  rolling cold-reset: $ip"
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$ip" '
    systemctl stop mysql
    sync
    echo 3 > /proc/sys/vm/drop_caches
    systemctl start mysql
  '
  wait_synced "$ip" || die "node $ip did not reach wsrep_local_state_comment=Synced within 300s after cold-reset"
done

info "cold reset Galera done (${#NODES[@]} node(s) rolling-restarted)"
