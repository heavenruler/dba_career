#!/usr/bin/env bash
# chaos-c4-network-partition-plan.sh — planner-only (no execute)
#
# Spec ground truth: phase-crossregion/chaos/C4.md
#   Failure model (task-defined mapping): network partition between IDC and GCP
#   via iptables DROP on raft port for N seconds.
#   (Note: C4.md original spec is IDC leader die via systemctl stop; REPLAN §6
#    names this script "network-partition". This planner models the WAN-drop
#    described in C1.md but scoped to raft port only.)
#
# Behaviour: print the iptables DROP commands that *would* run + recover
#            commands + expected artifact paths. Does NOT touch netfilter.
# No --execute flag. Real injection requires PR + DBA review.

set -euo pipefail

DB=""
TARGET_HOST=""
DURATION=""

usage() {
  cat <<EOF
Usage: $0 --db tidb|crdb|ybdb --target-host <ip> --duration <sec>

Planner-only: prints the iptables commands that *would* be run for an
IDC↔GCP raft-port partition + expected artifact paths + expected behaviour.
Does NOT execute anything.

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

# raft port per DB family (defaults; real cluster config overrides)
case "$DB" in
  tidb) RAFT_PORT="20160"  ; PORT_NOTE="TiKV peer raft (default 20160)" ;;
  crdb) RAFT_PORT="26257"  ; PORT_NOTE="CRDB inter-node + SQL (26257)" ;;
  ybdb) RAFT_PORT="9100"   ; PORT_NOTE="yb-tserver RPC (9100); yb-master RPC=7100" ;;
esac

# Per C1.md §注入方式 — IDC and GCP CIDR blocks
IDC_CIDR="172.24.0.0/16"
GCP_CIDR="10.160.152.0/24"

TS="$(date +%Y%m%dT%H%M%S)"
PLAN_FILE="chaos-plan-c4-${TS}.txt"
ARTIFACT_DIR="chaos/C4/${TS}"

{
  echo "============================================================"
  echo "chaos-c4-network-partition-plan  (PLANNER ONLY — no execution)"
  echo "============================================================"
  echo "generated     : ${TS}"
  echo "db            : ${DB}"
  echo "target-host   : ${TARGET_HOST}"
  echo "duration      : ${DURATION}s"
  echo "raft port     : ${RAFT_PORT}  (${PORT_NOTE})"
  echo "idc cidr      : ${IDC_CIDR}"
  echo "gcp cidr      : ${GCP_CIDR}"
  echo "spec source   : phase-crossregion/chaos/C4.md (+ C1.md timeline)"
  echo
  echo "------------------------------------------------------------"
  echo "[1] Pre-injection check (would run)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} 'nc -zv ${GCP_CIDR%/*} ${RAFT_PORT}'  # raft port reachable"
  echo "  ssh ${TARGET_HOST} 'iptables -L INPUT -n  | head'"
  echo "  ssh ${TARGET_HOST} 'iptables -L OUTPUT -n | head'"
  echo
  echo "------------------------------------------------------------"
  echo "[2] Inject — iptables DROP on raft port (would run — NOT executed)"
  echo "------------------------------------------------------------"
  echo "  # On ${TARGET_HOST} (assumed IDC side):"
  echo "  ssh ${TARGET_HOST} \"sudo iptables -A INPUT  -s ${GCP_CIDR} -p tcp --dport ${RAFT_PORT} -j DROP\""
  echo "  ssh ${TARGET_HOST} \"sudo iptables -A OUTPUT -d ${GCP_CIDR} -p tcp --dport ${RAFT_PORT} -j DROP\""
  echo
  echo "  # Symmetric on GCP side (would also apply; left to operator):"
  echo "  ssh <gcp-host> \"sudo iptables -A INPUT  -s ${IDC_CIDR} -p tcp --dport ${RAFT_PORT} -j DROP\""
  echo "  ssh <gcp-host> \"sudo iptables -A OUTPUT -d ${IDC_CIDR} -p tcp --dport ${RAFT_PORT} -j DROP\""
  echo
  echo "  sleep ${DURATION}"
  echo
  echo "------------------------------------------------------------"
  echo "[3] Restore (would run after duration)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} \"sudo iptables -D INPUT  -s ${GCP_CIDR} -p tcp --dport ${RAFT_PORT} -j DROP\""
  echo "  ssh ${TARGET_HOST} \"sudo iptables -D OUTPUT -d ${GCP_CIDR} -p tcp --dport ${RAFT_PORT} -j DROP\""
  echo "  # (mirror on GCP side)"
  echo
  echo "------------------------------------------------------------"
  echo "[4] Expected artifacts"
  echo "------------------------------------------------------------"
  echo "  ${ARTIFACT_DIR}/tpmc-1s.txt                  # tpmC drop curve, 1s resolution"
  echo "  ${ARTIFACT_DIR}/error-rate-by-sec.txt        # client error rate per sec"
  echo "  ${ARTIFACT_DIR}/leader-redist-trace.txt      # leader redistribution events"
  echo "  ${ARTIFACT_DIR}/iptables-rules-before.txt    # iptables -L snapshot pre-inject"
  echo "  ${ARTIFACT_DIR}/iptables-rules-after.txt     # iptables -L snapshot post-restore"
  echo "  ${ARTIFACT_DIR}/go-tpc-stdout.txt            # go-tpc raw stdout"
  echo "  ${ARTIFACT_DIR}/plan.txt                     # copy of this plan file"
  echo
  echo "------------------------------------------------------------"
  echo "[5] Expected behaviour (per spec C1.md / C4.md)"
  echo "------------------------------------------------------------"
  echo "  P-A  : IDC majority retains write; GCP voter becomes minority."
  echo "         GCP-side client via idc-haproxy → fails (route severed)."
  echo "  P-B  : per-shard voter split across 2 regions → after partition"
  echo "         both regions become minority ⇒ cluster-wide write reject"
  echo "         (split-brain prevention engaged)."
  echo
  echo "  Timeline (per C1.md §Post-injection):"
  echo "    t=0    inject iptables DROP on port ${RAFT_PORT}"
  echo "    t+5s   raft heartbeat timeout"
  echo "    t+10s  leader election attempted per-shard"
  echo "    t+30s  tpmC stabilises (degraded or zero depending on P-A/P-B)"
  echo "    t+${DURATION}s end of injection window"
  echo
  echo "------------------------------------------------------------"
  echo "[6] REMINDER"
  echo "------------------------------------------------------------"
  echo "  This is planner-only output. NO iptables call was made."
  echo "  Enabling real injection requires PR + DBA review."
  echo "  Currently: planner only."
} | tee "${PLAN_FILE}"

echo
echo "plan written → ${PLAN_FILE}"
echo "REMINDER: 啟用實跑需 PR + DBA review；目前只 planner"
