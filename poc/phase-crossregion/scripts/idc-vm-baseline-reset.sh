#!/usr/bin/env bash
# phase-crossregion/scripts/idc-vm-baseline-reset.sh
#
# IDC 3 node VM baseline reset (per REPLAN-2026-06-15.md §1).
#
# 對 IDC 3 台 DB host (.32/.33/.34) 做 DB-family aware 的 baseline reset：
#   1. snapshot before：disk free / process list / port listening / OS load
#      → phase-crossregion/scripts/.idc-baseline-snapshot-<ts>-before.txt
#   2. stop residual：依 --db 範圍 stop tidb / cockroach / yb-tserver / yb-master / k3s
#   3. clean data dir：
#        TiDB: /opt/tidb/data/* + /var/lib/tidb* (如存在)
#        CRDB: /var/lib/cockroach/*
#        YBDB: /var/yugabyte/* + /var/lib/yugabyte*
#        k3s local-path: /var/lib/rancher/k3s/storage/*
#   4. snapshot after：同 #1 → -after.txt
#   5. disk free 驗 ≥ 50GB → 不足則 fail-closed
#
# 不碰 OS-level config (chrony / sshd / iptables)。
#
# 用法：
#   bash idc-vm-baseline-reset.sh --db tidb|crdb|ybdb|all --dry-run
#   bash idc-vm-baseline-reset.sh --db tidb|crdb|ybdb|all --execute
#
# Env overrides：
#   IDC_HOSTS         (default "172.24.40.32 172.24.40.33 172.24.40.34")
#   SSH_USER          (default root)
#   MIN_FREE_GB       (default 50)
#   SNAPSHOT_DIR      (default 與本 script 同 dir)
#
# Exit:
#   0 = PASS (dry-run 印完 / execute 全部 host disk free ≥ MIN_FREE_GB)
#   1 = FAIL (SSH 失敗 / clean 失敗 / disk free 不足 / 不合法 arg)

set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)

DB=""
MODE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --dry-run) MODE=dry-run; shift ;;
    --execute) MODE=execute; shift ;;
    -h|--help)
      sed -n '2,32p' "$0"
      exit 0
      ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

[[ "$DB" =~ ^(tidb|crdb|ybdb|all)$ ]] || { echo "--db must be tidb|crdb|ybdb|all" >&2; exit 1; }
[[ "$MODE" == "dry-run" || "$MODE" == "execute" ]] || { echo "--dry-run or --execute required" >&2; exit 1; }

: "${IDC_HOSTS:=172.24.40.32 172.24.40.33 172.24.40.34}"
: "${SSH_USER:=root}"
: "${MIN_FREE_GB:=50}"
: "${SNAPSHOT_DIR:=$SELF}"

TS=$(date +%Y%m%d-%H%M%S)
SNAP_BEFORE="$SNAPSHOT_DIR/.idc-baseline-snapshot-${TS}-before.txt"
SNAP_AFTER="$SNAPSHOT_DIR/.idc-baseline-snapshot-${TS}-after.txt"

# --- DB-family targeted services / data dirs ---
# services: 對應 systemctl unit name (best-effort；缺則 stop 跳過)
# data_dirs: glob expansion 在 remote shell 執行
services_for() {
  case "$1" in
    tidb) echo "tidb-4000 tidb tikv pd";;
    crdb) echo "cockroach";;
    ybdb) echo "yb-master yb-tserver";;
    k3s)  echo "k3s k3s-agent";;
  esac
}

data_dirs_for() {
  case "$1" in
    tidb) echo "/opt/tidb/data /var/lib/tidb";;
    crdb) echo "/var/lib/cockroach";;
    ybdb) echo "/var/yugabyte /var/lib/yugabyte";;
    k3s)  echo "/var/lib/rancher/k3s/storage";;
  esac
}

# Selected scopes:
#   tidb → tidb (+ k3s 不動，因 k3s 通常在 driver/.31 而非 dbhost；但 all 仍 sweep)
#   crdb → crdb
#   ybdb → ybdb
#   all  → tidb + crdb + ybdb + k3s
selected_scopes() {
  case "$DB" in
    tidb) echo "tidb";;
    crdb) echo "crdb";;
    ybdb) echo "ybdb";;
    all)  echo "tidb crdb ybdb k3s";;
  esac
}

remote_cmd() {
  # remote_cmd <host> <cmd-string>
  # BatchMode=yes：不互動式 prompt 密碼；無 key 時 fail-fast。
  local host=$1; shift
  ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${SSH_USER}@${host}" "$@"
}

snapshot() {
  # snapshot <host> <output-file>
  local host=$1 out=$2
  {
    echo "===== host=${host} ts=$(date -u +%Y-%m-%dT%H:%M:%SZ) ====="
    echo "--- disk free ---"
    remote_cmd "$host" 'df -h -x tmpfs -x devtmpfs 2>/dev/null || df -h' || echo "(df failed)"
    echo "--- process list (db-related) ---"
    remote_cmd "$host" "ps -eo pid,user,cmd | grep -E 'tidb|tikv|pd-server|cockroach|yb-master|yb-tserver|k3s' | grep -v grep || echo '(no db procs)'" || echo "(ps failed)"
    echo "--- port listening ---"
    remote_cmd "$host" "ss -ltnp 2>/dev/null || netstat -ltnp 2>/dev/null || echo '(ss/netstat unavailable)'" || echo "(port probe failed)"
    echo "--- OS load ---"
    remote_cmd "$host" "uptime; cat /proc/loadavg 2>/dev/null" || echo "(load probe failed)"
    echo
  } >> "$out"
}

# disk_free_gb_root: 取 / 的 available GB（int truncate）；用於 fail-closed 判斷
disk_free_gb_root() {
  local host=$1
  remote_cmd "$host" "df -BG --output=avail / | tail -1 | tr -dc '0-9'" 2>/dev/null || echo 0
}

scopes=$(selected_scopes)

echo "[idc-vm-baseline-reset] mode=$MODE db=$DB hosts=($IDC_HOSTS) scopes=($scopes) ts=$TS"
echo "[idc-vm-baseline-reset] snapshot before → $SNAP_BEFORE"
echo "[idc-vm-baseline-reset] snapshot after  → $SNAP_AFTER"
echo "[idc-vm-baseline-reset] MIN_FREE_GB=$MIN_FREE_GB"

# --- 1. snapshot before ---
: > "$SNAP_BEFORE"
for host in $IDC_HOSTS; do
  echo "[snapshot-before] $host"
  snapshot "$host" "$SNAP_BEFORE" || { echo "snapshot-before failed: $host" >&2; exit 1; }
done

# --- 2. stop residual + 3. clean data dir ---
for host in $IDC_HOSTS; do
  for scope in $scopes; do
    svcs=$(services_for "$scope")
    dirs=$(data_dirs_for "$scope")

    # stop services
    for svc in $svcs; do
      stop_cmd="systemctl stop ${svc} 2>/dev/null || true"
      if [[ "$MODE" == "dry-run" ]]; then
        echo "[dry-run] $host: $stop_cmd"
      else
        echo "[execute] $host: $stop_cmd"
        remote_cmd "$host" "$stop_cmd" || { echo "stop failed: $host $svc" >&2; exit 1; }
      fi
    done

    # clean data dirs
    for dir in $dirs; do
      # 只清 dir 下的內容（含 dotfiles），不刪 dir 本身；用 find 避免 rm -rf 路徑歧義
      clean_cmd="if [ -d ${dir} ]; then find ${dir} -mindepth 1 -maxdepth 1 -exec rm -rf {} +; fi"
      if [[ "$MODE" == "dry-run" ]]; then
        echo "[dry-run] $host: $clean_cmd"
      else
        echo "[execute] $host: $clean_cmd"
        remote_cmd "$host" "$clean_cmd" || { echo "clean failed: $host $dir" >&2; exit 1; }
      fi
    done
  done
done

# --- 4. snapshot after ---
: > "$SNAP_AFTER"
for host in $IDC_HOSTS; do
  echo "[snapshot-after] $host"
  if [[ "$MODE" == "dry-run" ]]; then
    # dry-run 仍跑 snapshot（read-only），便於對比
    snapshot "$host" "$SNAP_AFTER" || { echo "snapshot-after failed: $host" >&2; exit 1; }
  else
    snapshot "$host" "$SNAP_AFTER" || { echo "snapshot-after failed: $host" >&2; exit 1; }
  fi
done

# --- 5. disk free fail-closed verify (僅 execute 模式 enforce) ---
overall_ok=1
for host in $IDC_HOSTS; do
  free_gb=$(disk_free_gb_root "$host")
  free_gb=${free_gb:-0}
  if [[ "$free_gb" -ge "$MIN_FREE_GB" ]]; then
    echo "[verify] $host: / free=${free_gb}GB >= ${MIN_FREE_GB}GB OK"
  else
    echo "[verify] $host: / free=${free_gb}GB < ${MIN_FREE_GB}GB (mode=$MODE)"
    overall_ok=0
  fi
done

if [[ "$MODE" == "execute" && "$overall_ok" -ne 1 ]]; then
  echo "[idc-vm-baseline-reset] FAIL — disk free below ${MIN_FREE_GB}GB (post-execute fail-closed)" >&2
  exit 1
fi

echo "[idc-vm-baseline-reset] PASS mode=$MODE db=$DB"
exit 0
