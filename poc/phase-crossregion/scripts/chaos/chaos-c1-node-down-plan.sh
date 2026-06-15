#!/usr/bin/env bash
# chaos-c1-node-down-plan.sh — planner-only (no execute)
#
# Spec ground truth: phase-crossregion/chaos/C1.md
#   Failure model (task-defined mapping): 1 single DB node failure via `systemctl stop`
#   (Note: C1.md original spec is WAN partition via iptables; REPLAN §6 names this
#    script "node-down". This planner models a single-node stop — closest analog to
#    the "leader / voter dies" sub-case discussed in C1.md timeline §Post-injection.)
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
  tidb) SVC="tidb-server (or tikv-server / pd-server depending on node role)" ;;
  crdb) SVC="cockroach" ;;
  ybdb) SVC="yb-tserver (and/or yb-master)" ;;
esac

TS="$(date +%Y%m%dT%H%M%S)"
PLAN_FILE="chaos-plan-c1-${TS}.txt"
ARTIFACT_DIR="chaos/C1/${TS}"

{
  echo "============================================================"
  echo "chaos-c1-node-down-plan  (PLANNER ONLY — no execution)"
  echo "============================================================"
  echo "generated     : ${TS}"
  echo "db            : ${DB}"
  echo "target-host   : ${TARGET_HOST}"
  echo "duration      : ${DURATION}s"
  echo "service       : ${SVC}"
  echo "spec source   : phase-crossregion/chaos/C1.md"
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
  echo "[5] Expected behaviour (per spec C1.md)"
  echo "------------------------------------------------------------"
  echo "  P-A  : IDC majority survives; if stopped node is GCP voter,"
  echo "         per-shard quorum = 2 IDC voters → write continues at"
  echo "         degraded TPS. If stopped node is IDC leader: leader"
  echo "         election within ~5-15s (DB-family dependent)."
  echo "  P-B  : per-shard voter spread; 1 node stop affects shards"
  echo "         where that node hosts a voter. Surviving voters form"
  echo "         quorum if arbiter placement allows."
  echo
  echo "  Timeline (per C1.md §Post-injection):"
  echo "    t=0    inject (systemctl stop)"
  echo "    t+5s   raft heartbeat timeout"
  echo "    t+10s  leader election kicks in (per-shard)"
  echo "    t+30s  tpmC stabilises at degraded level"
  echo "    t+${DURATION}s end of injection window"
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
