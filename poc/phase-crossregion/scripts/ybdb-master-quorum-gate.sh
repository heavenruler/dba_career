#!/usr/bin/env bash
# ybdb-master-quorum-gate.sh — YBDB master raft membership 硬 gate（fail-closed）
#
# 背景（fable-refactor/ybdb-master-quorum-handoff.md + ybdb-master-quorum-handoff-solution.md）：
#   yugabyted 的 master 選擇 region-blind——playbook 從未給 --cloud_location，
#   yugabyted 自己的 conf 全節點都是假 zone cloud1.datacenter1.rack1（master
#   cmdline 上假 zone flag 排在使用者 placement flag 之後、後者 wins），因此
#   configure data_placement --rf=3 擴編 master 時選節點無 region 概念，GCP
#   節點會搶到 master 名額（2026-07-09 兩次全新部署 2/2 復現）。
#
#   本 gate 於 phase4-ybdb-fix6n 內強制把 raft membership 修正為 3 台 IDC-only
#   （yb-admin ADD_SERVER/REMOVE_SERVER，07-09 已 live 驗證 2/2），並同步校正
#   全 6 節點 yugabyted.conf 的 current_masters 快取欄位——該欄位不會因 yb-admin
#   改了真實 raft membership 而自動更新，若不校正，之後任何 yugabyted stop/start
#   （coldreset-ybdb.sh 正是）會用舊值把 tserver 導向已不存在的 master 位址，
#   YSQL proxy 卡死初始化（07-09 實測）。
#
#   conf 校正本身只影響「下次 restart」——從部署以來持續運行、從未重啟過的
#   process（.33/.34）仍帶著部署當下的殘缺 --tserver_master_addrs（07-09
#   Stage B 實測：各自缺了 1 台其他 IDC peer，疑為原始「.33 postgres 死鎖」
#   懸案的真正成因）。故再逐台核對 live tserver_master_addrs 是否與 canonical
#   一致，缺漏就重啟該台一次（一次僅停 1 台，masters 2/3 majority 不失）。
#
#   最後對全 6 節點做 YSQL SELECT 1 健檢，fail 節點先留證據（postgresql-*.log +
#   backend 清單）再做一次 yugabyted 重啟修復複檢，仍 fail 則 fail-closed。
#
# 跑在 .31（jump host；.31 → 全 6 節點 root ssh 已 prime）。冪等：quorum 已正確
# 時跳過手術，只做 conf 校正 + 健檢。
#
# Usage: bash ybdb-master-quorum-gate.sh
# Env:   DUMP_DIR（預設 /tmp/ybdb-quorum-gate；證據與前後狀態 dump）
#        REPAIR_RESTART=0 停用健檢 fail 時的節點重啟修復（預設 1）
#        EXEC_HOST（yb-admin 執行節點，預設 172.24.40.32）
set -euo pipefail

IDC_MASTERS=(172.24.40.32 172.24.40.33 172.24.40.34)
ALL_NODES=(172.24.40.32 172.24.40.33 172.24.40.34 10.160.152.11 10.160.152.12 10.160.152.13)
MASTER_PORT=7100
CANON="172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100"
# 候選列表放全 6 節點：yb-admin 自己找 leader，不管 leader 漂到哪都問得到
CANDIDATES="172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100,10.160.152.11:7100,10.160.152.12:7100,10.160.152.13:7100"
YB_ADMIN=/opt/yugabyte/bin/yb-admin
EXEC_HOST="${EXEC_HOST:-172.24.40.32}"
DUMP_DIR="${DUMP_DIR:-/tmp/ybdb-quorum-gate}"
REPAIR_RESTART="${REPAIR_RESTART:-1}"
SSH="ssh -n -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new"

log() { echo "[quorum-gate $(date +%H:%M:%S)] $*"; }
yb()  { $SSH root@"$EXEC_HOST" "timeout 90 $YB_ADMIN --master_addresses=$CANDIDATES $*" 2>&1; }
# list_all_masters 資料列：uuid(32hex) host:port state role → 印 uuid host role
members() { awk '$1 ~ /^[0-9a-f]{32}$/ {split($2,a,":"); print $1, a[1], $4}'; }
is_idc()  { local h; for h in "${IDC_MASTERS[@]}"; do [[ "$1" == "$h" ]] && return 0; done; return 1; }

mkdir -p "$DUMP_DIR"

# ---- 1. pre-repair 現況（同時是 join race 的 root-cause 證據）----
pre=$(yb list_all_masters || true)
echo "$pre" > "$DUMP_DIR/masters-before.txt"
log "pre-repair masters："
echo "$pre" | sed 's/^/  /'
echo "$pre" | members | grep -q . || { log "FAIL：找不到任何 master leader（cluster 未起或全掛）"; exit 1; }

for ip in "${IDC_MASTERS[@]}"; do
  if ! echo "$pre" | members | awk '{print $2}' | grep -qx "$ip"; then
    $SSH root@"$ip" "tail -150 /var/yugabyte/logs/yugabyted.log 2>/dev/null" \
      > "$DUMP_DIR/yugabyted-$ip.log" || true
    log "evidence：$ip 不在 raft；yugabyted.log 尾段已存 $DUMP_DIR/yugabyted-$ip.log"
  fi
done

# ---- 2. ADD 缺席的 IDC master ----
cur="$pre"
for ip in "${IDC_MASTERS[@]}"; do
  echo "$cur" | members | awk '{print $2}' | grep -qx "$ip" && continue
  # ADD_SERVER 需要目標節點已有 yb-master process（yugabyted join 時啟的 shell master）
  $SSH root@"$ip" "pgrep -x yb-master >/dev/null" || {
    log "FAIL：$ip 不在 raft 且無 yb-master process，無法 ADD_SERVER（需人工介入，見 solution doc）"
    exit 1
  }
  log "ADD_SERVER $ip:$MASTER_PORT"
  yb "change_master_config ADD_SERVER $ip $MASTER_PORT" | sed 's/^/  /' || true
  sleep 5
  cur=$(yb list_all_masters || true)
  echo "$cur" | members | awk '{print $2}' | grep -qx "$ip" \
    || { log "FAIL：ADD_SERVER $ip 後仍不在 raft"; echo "$cur" | sed 's/^/  /'; exit 1; }
done

# ---- 3. REMOVE 非 IDC master（yb-admin 參數序：<ip> <port> [<uuid>]，uuid 在最後）----
while read -r uuid host _; do
  is_idc "$host" && continue
  log "REMOVE_SERVER $host:$MASTER_PORT ($uuid)"
  yb "change_master_config REMOVE_SERVER $host $MASTER_PORT $uuid" | sed 's/^/  /' || true
  sleep 5
done < <(echo "$cur" | members)

# ---- 4. 終局 assert：恰 3 台、全 IDC、恰 1 LEADER ----
post=$(yb list_all_masters || true)
echo "$post" > "$DUMP_DIR/masters-after.txt"
log "post-repair masters："
echo "$post" | sed 's/^/  /'
n=$(echo "$post" | members | wc -l)
nleader=$(echo "$post" | members | awk '$3 == "LEADER"' | wc -l)
nbad=0
while read -r _ host _; do
  is_idc "$host" || nbad=$((nbad + 1))
done < <(echo "$post" | members)
[[ $n -eq 3 && $nleader -eq 1 && $nbad -eq 0 ]] \
  || { log "FAIL：masters=$n leader=$nleader non-idc=$nbad（預期 3/1/0）"; exit 1; }
log "raft membership OK：3 台 IDC-only、1 LEADER"

# ---- 5. 全 6 節點 current_masters 快取校正（防 cold-reset 復活舊 master 位址）----
for ip in "${ALL_NODES[@]}"; do
  out=$($SSH root@"$ip" "old=\$(grep -oE '\"current_masters\" *: *\"[^\"]*\"' /var/yugabyte/conf/yugabyted.conf | sed -E 's/.*: *\"([^\"]*)\"/\1/'); \
    if [ \"\$old\" = '$CANON' ]; then echo 'already canonical'; else \
    sed -i -E 's|\"current_masters\": *\"[^\"]*\"|\"current_masters\": \"$CANON\"|' /var/yugabyte/conf/yugabyted.conf && \
    echo \"\$old -> $CANON\"; fi") \
    || { log "FAIL：$ip current_masters 校正失敗"; exit 1; }
  log "  [$ip] current_masters: $out"
done

# ---- 5.5. 全 6 節點 tserver_master_addrs live flag 校驗（07-09 Stage B 實測發現：
#      conf 校正只影響「下次 restart」，從未重啟過的既有 process（部署以來持續運行的
#      .33/.34）仍帶著部署當下的殘缺清單——各自缺了 1 台其他 IDC peer，疑為原始
#      「.33 postgres 死鎖」懸案的真正成因：leader 一旦漂到自己缺列的那台，
#      該 tserver 就找不到 leader 而卡死。逐台檢查+缺就重啟一次（IDC 一次僅停 1 台，
#      2/3 majority 不失；GCP 無 master 角色，restart 不影響 quorum）----
tserver_master_addrs_of() {
  $SSH root@"$1" "ps aux | grep yb-tserver | grep -v grep | grep -oE 'tserver_master_addrs=[^ ]*'" 2>/dev/null \
    | sed -E 's/^tserver_master_addrs=//'
}
sorted_csv() { echo "$1" | tr ',' '\n' | sort | tr '\n' ','; }
join_target_for() { [[ "$1" == "172.24.40.32" ]] && echo "172.24.40.33" || echo "172.24.40.32"; }

canon_sorted=$(sorted_csv "$CANON")
for ip in "${ALL_NODES[@]}"; do
  live_sorted=$(sorted_csv "$(tserver_master_addrs_of "$ip")")
  if [[ "$live_sorted" == "$canon_sorted" ]]; then
    log "  [$ip] tserver_master_addrs OK"
    continue
  fi
  jt=$(join_target_for "$ip")
  log "  [$ip] tserver_master_addrs 缺漏（live=[$(tserver_master_addrs_of "$ip")]），restart 讀正確 conf（join=$jt）"
  $SSH root@"$ip" "runuser -u yugabyte -- yugabyted stop --base_dir=/var/yugabyte" 2>&1 | tail -2 | sed 's/^/    /' || true
  sleep 3
  $SSH root@"$ip" "runuser -u yugabyte -- yugabyted start --base_dir=/var/yugabyte --advertise_address=$ip --join=$jt" 2>&1 | tail -3 | sed 's/^/    /' || true
  sleep 5
  live2_sorted=$(sorted_csv "$(tserver_master_addrs_of "$ip")")
  [[ "$live2_sorted" == "$canon_sorted" ]] \
    || { log "FAIL：$ip restart 後 tserver_master_addrs 仍不對（live=[$(tserver_master_addrs_of "$ip")]）"; exit 1; }
  log "  [$ip] tserver_master_addrs 修復後 OK"
done

# ---- 6. 全 6 節點 YSQL 健檢（SELECT 1；抓 postgres backend 死鎖類問題）----
check_ysql() {
  $SSH root@"$1" "cd /tmp && timeout 15 runuser -u yugabyte -- ysqlsh -h $1 -p 5433 -U yugabyte -d yugabyte -Atc 'SELECT 1'" 2>/dev/null | grep -qx 1
}
bad_nodes=()
for ip in "${ALL_NODES[@]}"; do
  if check_ysql "$ip"; then log "  [$ip] YSQL OK"; else log "  [$ip] YSQL FAIL"; bad_nodes+=("$ip"); fi
done

if [[ ${#bad_nodes[@]} -gt 0 ]]; then
  if [[ "$REPAIR_RESTART" != "1" ]]; then
    log "FAIL：YSQL 健檢未過（${bad_nodes[*]}），REPAIR_RESTART=0 不嘗試修復"
    exit 1
  fi
  for ip in "${bad_nodes[@]}"; do
    # 先留證據再重啟（postgresql log 是 07-09 未讀到的關鍵檔）
    $SSH root@"$ip" 'tail -120 "$(ls -t /var/yugabyte/data/yb-data/tserver/logs/postgresql-*.log 2>/dev/null | head -1)" 2>/dev/null' \
      > "$DUMP_DIR/ysql-fail-$ip-postgresql.log" || true
    $SSH root@"$ip" "ps aux | grep 'postgres:' | grep -v grep" \
      > "$DUMP_DIR/ysql-fail-$ip-backends.txt" || true
    log "REPAIR：yugabyted stop/start on $ip（conf 已校正，restart 會讀正確 master 位址）"
    $SSH root@"$ip" "runuser -u yugabyte -- yugabyted stop --base_dir=/var/yugabyte" 2>&1 | tail -2 | sed 's/^/  /' || true
    sleep 3
    $SSH root@"$ip" "runuser -u yugabyte -- yugabyted start --base_dir=/var/yugabyte" 2>&1 | tail -3 | sed 's/^/  /' || true
  done
  sleep 15
  still_bad=()
  for ip in "${bad_nodes[@]}"; do
    check_ysql "$ip" || still_bad+=("$ip")
  done
  if [[ ${#still_bad[@]} -gt 0 ]]; then
    log "FAIL：重啟修復後 YSQL 仍 fail（${still_bad[*]}）；證據在 $DUMP_DIR/，整理現場等人工判讀"
    exit 1
  fi
  log "REPAIR 成功：${bad_nodes[*]} 重啟後 YSQL 恢復"
fi

log "quorum gate PASS（raft=3 IDC-only；conf 已校正；6/6 YSQL OK）"
