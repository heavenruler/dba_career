#!/usr/bin/env bash
# run-vm6-failover-plan.sh — planner-only (no execute)
#
# Spec ground truth: phase-crossregion/failover/F1.md
# Plan ground truth: phase-crossregion/REPLAN-2026-06-15.md §7 (line 166-183)
# Decision         : phase-crossregion/decisions-2026-06-08.md §Q7 (line 157-186)
#
# Behaviour: print the commands that *would* run + expected artifact paths +
#            monitoring flow. Does NOT execute any kill / quit / step-down.
#
# There is NO --execute flag. Real failover trigger requires PR + DBA review.

set -euo pipefail

DB=""
KILL_TARGET=""

usage() {
  cat <<EOF
Usage: $0 --db tidb|crdb|ybdb --kill-target <ip>|leader-auto

Planner-only. Prints:
  - the kill command that *would* be issued
  - expected artifact paths under runs/F1/<ts>/
  - the monitoring flow (5s polling for new leader; GCP-side first-write probe)

Does NOT execute anything. There is NO --execute flag.
Enabling real failover trigger requires a separate PR + DBA review.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)          DB="$2"; shift 2 ;;
    --kill-target) KILL_TARGET="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

[[ -z "$DB" || -z "$KILL_TARGET" ]] && usage
[[ ! "$DB" =~ ^(tidb|crdb|ybdb)$ ]] && { echo "ERROR: --db must be tidb|crdb|ybdb" >&2; exit 2; }

# IDC host pool reference (from inventory/crossregion.ini.template line 8-10)
IDC_HOST_POOL="172.24.40.32 172.24.40.33 172.24.40.34"

case "$DB" in
  tidb)
    LOOKUP_CMD='tiup ctl:<ver> pd -u http://<pd-host>:2379 member'
    KILL_CMD_TPL='ssh <idc-dbhost-X> "sudo systemctl stop tidb-server@<port>"'
    ALT_CMD='tiup cluster restart <cluster> -N <idc-dbhost-X>     # 更小範圍重啟單節點'
    RESIGN_CMD='tiup ctl:<ver> pd -u http://<pd-host>:2379 member leader resign'
    LEADER_POLL='tiup ctl:<ver> pd -u http://<pd-host>:2379 member  # 觀察新 leader'
    ;;
  crdb)
    LOOKUP_CMD='cockroach node status --insecure --host=<any-host>:26257'
    KILL_CMD_TPL='ssh <idc-dbhost-X> "cockroach quit --insecure --host=localhost:26257"'
    ALT_CMD='cockroach node drain <node-id> --insecure --host=<any-host>:26257   # graceful drain'
    RESIGN_CMD='# CRDB 無顯式 resign；quit / drain 即觸發 lease 轉移'
    LEADER_POLL='cockroach sql --insecure -e "SHOW RANGES FROM TABLE tpcc.new_order"  # 觀察 leaseholder'
    ;;
  ybdb)
    LOOKUP_CMD='yb-admin --master_addresses=<masters> list_all_masters'
    KILL_CMD_TPL='ssh <idc-dbhost-X> "sudo systemctl stop yb-master"   # 如需 tserver: yb-tserver'
    ALT_CMD='ssh <idc-dbhost-X> "sudo systemctl stop yb-tserver"       # tserver 範圍'
    RESIGN_CMD='yb-admin --master_addresses=<masters> master_leader_stepdown'
    LEADER_POLL='yb-admin --master_addresses=<masters> list_all_masters  # 觀察 LEADER role 移轉'
    ;;
esac

TS="$(date +%Y%m%dT%H%M%S)"
PLAN_FILE="failover-plan-${DB}-${TS}.txt"
ARTIFACT_DIR="runs/F1/${TS}"

if [[ "$KILL_TARGET" == "leader-auto" ]]; then
  TARGET_DISPLAY="<auto-detected leader host from lookup step below>"
  KILL_CMD_RENDERED="$KILL_CMD_TPL"
else
  TARGET_DISPLAY="$KILL_TARGET"
  KILL_CMD_RENDERED="${KILL_CMD_TPL//<idc-dbhost-X>/$KILL_TARGET}"
fi

{
  echo "============================================================"
  echo "run-vm6-failover-plan  (PLANNER ONLY — no execution)"
  echo "============================================================"
  echo "generated      : ${TS}"
  echo "db             : ${DB}"
  echo "kill-target    : ${KILL_TARGET}"
  echo "resolved host  : ${TARGET_DISPLAY}"
  echo "idc host pool  : ${IDC_HOST_POOL}   (from inventory/crossregion.ini.template)"
  echo "spec source    : phase-crossregion/failover/F1.md"
  echo
  echo "------------------------------------------------------------"
  echo "[1] Pre-kill — leader lookup (would run — NOT executed)"
  echo "------------------------------------------------------------"
  echo "  ${LOOKUP_CMD}"
  echo "  # 用以確認當前 IDC-side leader host；若 --kill-target 為具體 IP 則跳過此步"
  echo
  echo "------------------------------------------------------------"
  echo "[2] Pre-kill — dump db-config snapshot (would run)"
  echo "------------------------------------------------------------"
  echo "  mkdir -p ${ARTIFACT_DIR}/db-config-snapshot/pre-kill"
  echo "  # dump placement / replicas / leader map 到上述目錄"
  echo
  echo "------------------------------------------------------------"
  echo "[3] Optional graceful resign (would run — NOT executed)"
  echo "------------------------------------------------------------"
  echo "  ${RESIGN_CMD}"
  echo
  echo "------------------------------------------------------------"
  echo "[4] Kill leader process (would run — NOT executed by this planner)"
  echo "------------------------------------------------------------"
  echo "  # t_kill 起算"
  echo "  ${KILL_CMD_RENDERED}"
  echo "  # alt (更小 / 更大範圍):"
  echo "  ${ALT_CMD}"
  echo
  echo "------------------------------------------------------------"
  echo "[5] Monitoring flow (would run — 5s polling, 60s window)"
  echo "------------------------------------------------------------"
  echo "  for i in \$(seq 1 12); do"
  echo "    ${LEADER_POLL}"
  echo "    # 同時 GCP-side client 嘗試 NEW_ORDER；第一筆 commit ack → t_first_write_gcp"
  echo "    sleep 5"
  echo "  done"
  echo "  # 寫入 ${ARTIFACT_DIR}/leader-handover.log"
  echo "  # 寫入 ${ARTIFACT_DIR}/kill.log"
  echo
  echo "------------------------------------------------------------"
  echo "[6] Post-handover — dump db-config + 計算 RTO/RPO (would run)"
  echo "------------------------------------------------------------"
  echo "  mkdir -p ${ARTIFACT_DIR}/db-config-snapshot/post-handover"
  echo "  # rto_sec = t_first_write_gcp - t_kill"
  echo "  # rpo_lost_tx_count = |S_pre - S_post|  (S_pre = kill 前 5s commit 過的 NEW_ORDER)"
  echo "  # 寫入 ${ARTIFACT_DIR}/rto-rpo.json"
  echo
  echo "------------------------------------------------------------"
  echo "[7] Expected artifacts (schema)"
  echo "------------------------------------------------------------"
  echo "  ${ARTIFACT_DIR}/kill.log                       # kill 指令文字 + RFC3339 ms timestamp"
  echo "  ${ARTIFACT_DIR}/leader-handover.log            # 5s polling timeline"
  echo "  ${ARTIFACT_DIR}/rto-rpo.json                   # {rto_sec, rpo_lost_tx_count, db_kind, ...}"
  echo "  ${ARTIFACT_DIR}/db-config-snapshot/pre-kill/"
  echo "  ${ARTIFACT_DIR}/db-config-snapshot/post-handover/"
  echo
  echo "------------------------------------------------------------"
  echo "[8] REMINDER"
  echo "------------------------------------------------------------"
  echo "  This is planner-only output. NO kill / quit / step-down was issued."
  echo "  No SSH / admin CLI call was made by this script."
  echo "  啟用實跑需 PR + DBA review；目前只 planner。"
} | tee "${PLAN_FILE}"

echo
echo "plan written → ${PLAN_FILE}"
echo "REMINDER: 啟用實跑需 PR + DBA review；目前只 planner"
