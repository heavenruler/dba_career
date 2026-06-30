#!/usr/bin/env bash
# chaos-c4-node-down-plan.sh — planner-only (no execute)
#
# Spec ground truth: phase-crossregion/chaos/C4.md
#   Failure model: IDC leader die — stop IDC leader node via systemctl stop
#   to observe leader election RTO per DB family.
#
# Behaviour: print the commands that *would* run + expected artifact paths +
#            expected post-failure behaviour. Does NOT execute any systemctl call.
# No --execute flag. Not allowed. Real injection requires PR + DBA review.

set -euo pipefail

DB=""
TARGET_HOST=""
DURATION=""

usage() {
  cat <<EOF
Usage: $0 --db tidb|crdb|ybdb --target-host <ip> --duration <sec>

Planner-only: prints the commands that *would* be run + expected artifact
paths + expected behaviour. Does NOT execute anything.

There is NO --execute flag. Enabling real injection requires a separate
PR + DBA review.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)          DB="$2"; shift 2 ;;
    --target-host) TARGET_HOST="$2"; shift 2 ;;
    --duration)    DURATION="$2"; shift 2 ;;
    -h|--help)     usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

[[ -z "$DB" || -z "$TARGET_HOST" || -z "$DURATION" ]] && usage
[[ ! "$DB" =~ ^(tidb|crdb|ybdb)$ ]] && { echo "ERROR: --db must be tidb|crdb|ybdb" >&2; exit 2; }
[[ ! "$DURATION" =~ ^[0-9]+$ ]] && { echo "ERROR: --duration must be integer seconds" >&2; exit 2; }

case "$DB" in
  tidb) SVC="tikv-server (or pd-server for PD leader)" ; RTO_NOTE="~10s (raft-election-timeout = 10 ticks × 1s)" ;;
  crdb) SVC="cockroach"                                ; RTO_NOTE="~9s (range lease re-election)" ;;
  ybdb) SVC="yb-tserver (and/or yb-master)"           ; RTO_NOTE="~5-15s (raft heartbeat-based)" ;;
esac

TS="$(date +%Y%m%dT%H%M%S)"
PLAN_FILE="chaos-plan-c4-${TS}.txt"
ARTIFACT_DIR="chaos/C4/${TS}"

{
  echo "============================================================"
  echo "chaos-c4-node-down-plan  (PLANNER ONLY — no execution)"
  echo "============================================================"
  echo "generated     : ${TS}"
  echo "db            : ${DB}"
  echo "target-host   : ${TARGET_HOST} (assumed IDC leader node)"
  echo "duration      : ${DURATION}s"
  echo "service       : ${SVC}"
  echo "expected RTO  : ${RTO_NOTE}"
  echo "spec source   : phase-crossregion/chaos/C4.md"
  echo
  echo "------------------------------------------------------------"
  echo "[1] Pre-injection check (would run)"
  echo "------------------------------------------------------------"
  echo "  ping -c 3 ${TARGET_HOST}"
  echo "  ssh ${TARGET_HOST} 'systemctl is-active ${SVC%% *}'"
  echo
  echo "------------------------------------------------------------"
  echo "[2] Inject (would run — NOT executed by this planner)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} 'sudo systemctl stop ${SVC%% *}'"
  echo "  # node down for ${DURATION}s"
  echo "  sleep ${DURATION}"
  echo
  echo "------------------------------------------------------------"
  echo "[3] Restore (would run after duration)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} 'sudo systemctl start ${SVC%% *}'"
  echo "  ssh ${TARGET_HOST} 'systemctl is-active ${SVC%% *}'"
  echo
  echo "------------------------------------------------------------"
  echo "[4] Expected artifacts"
  echo "------------------------------------------------------------"
  echo "  ${ARTIFACT_DIR}/tpmc-1s.txt              # tpmC drop curve, 1s resolution"
  echo "  ${ARTIFACT_DIR}/error-rate-by-sec.txt    # client error rate per sec"
  echo "  ${ARTIFACT_DIR}/leader-redist-trace.txt  # leader redistribution events"
  echo "  ${ARTIFACT_DIR}/go-tpc-stdout.txt        # go-tpc raw stdout (retry count derived)"
  echo "  ${ARTIFACT_DIR}/plan.txt                 # copy of this plan file"
  echo
  echo "------------------------------------------------------------"
  echo "[5] Expected behaviour (per spec C4.md)"
  echo "------------------------------------------------------------"
  echo "  P-A  : IDC majority; leader node dies → 1 IDC voter + 1 GCP voter = quorum;"
  echo "         leader election within ${RTO_NOTE}; new leader typically IDC."
  echo "  P-B  : per-shard voter spread; stopping IDC node affects only shards"
  echo "         where that node hosted the leader. Other shards (GCP leader) unaffected."
  echo
  echo "  Timeline (per C4.md):"
  echo "    t=0    inject (systemctl stop)"
  echo "    t+5s   raft heartbeat timeout detected by peers"
  echo "    t+10s  leader election kicks in (per-shard)"
  echo "    t+30s  tpmC stabilises at degraded level"
  echo "    t+${DURATION}s end of injection window"
  echo
  echo "  Key metric: Leader election RTO = timestamp diff:"
  echo "    last write before stop → first write after election"
  echo
  echo "------------------------------------------------------------"
  echo "[6] REMINDER"
  echo "------------------------------------------------------------"
  echo "  This is planner-only output. NO systemctl call was made."
  echo "  Enabling real injection requires PR + DBA review."
  echo "  Currently: planner only."
} | tee "${PLAN_FILE}"

echo
echo "plan written → ${PLAN_FILE}"
echo "REMINDER: 啟用實跑需 PR + DBA review；目前只 planner"
