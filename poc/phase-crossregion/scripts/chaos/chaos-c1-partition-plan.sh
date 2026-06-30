#!/usr/bin/env bash
# chaos-c1-partition-plan.sh — planner-only (no execute)
#
# Spec ground truth: phase-crossregion/chaos/C1.md
#   Failure model: GCP partition — bi-directional iptables DROP on all traffic
#   between IDC (172.24.0.0/16) and GCP (10.160.152.0/24).
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
IDC↔GCP bi-directional full partition + expected artifact paths + expected behaviour.
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

# Per C1.md §注入方式 — IDC and GCP CIDR blocks (full drop, no port filter)
IDC_CIDR="172.24.0.0/16"
GCP_CIDR="10.160.152.0/24"

TS="$(date +%Y%m%dT%H%M%S)"
PLAN_FILE="chaos-plan-c1-${TS}.txt"
ARTIFACT_DIR="chaos/C1/${TS}"

{
  echo "============================================================"
  echo "chaos-c1-partition-plan  (PLANNER ONLY — no execution)"
  echo "============================================================"
  echo "generated     : ${TS}"
  echo "db            : ${DB}"
  echo "target-host   : ${TARGET_HOST}"
  echo "duration      : ${DURATION}s"
  echo "idc cidr      : ${IDC_CIDR}"
  echo "gcp cidr      : ${GCP_CIDR}"
  echo "spec source   : phase-crossregion/chaos/C1.md"
  echo
  echo "------------------------------------------------------------"
  echo "[1] Pre-injection check (would run)"
  echo "------------------------------------------------------------"
  echo "  ping -c 3 10.160.152.11   # GCP host should be reachable"
  echo "  ssh ${TARGET_HOST} 'iptables -L INPUT -n  | head'"
  echo "  ssh ${TARGET_HOST} 'iptables -L OUTPUT -n | head'"
  echo
  echo "------------------------------------------------------------"
  echo "[2] Inject — iptables DROP all IDC↔GCP traffic (would run — NOT executed)"
  echo "------------------------------------------------------------"
  echo "  # On ${TARGET_HOST} (IDC side):"
  echo "  ssh ${TARGET_HOST} \"sudo iptables -A INPUT  -s ${GCP_CIDR} -j DROP\""
  echo "  ssh ${TARGET_HOST} \"sudo iptables -A OUTPUT -d ${GCP_CIDR} -j DROP\""
  echo
  echo "  # Symmetric on GCP side (would also apply; left to operator):"
  echo "  ssh <gcp-host> \"sudo iptables -A INPUT  -s ${IDC_CIDR} -j DROP\""
  echo "  ssh <gcp-host> \"sudo iptables -A OUTPUT -d ${IDC_CIDR} -j DROP\""
  echo
  echo "  sleep ${DURATION}"
  echo
  echo "------------------------------------------------------------"
  echo "[3] Restore (would run after duration)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} \"sudo iptables -D INPUT  -s ${GCP_CIDR} -j DROP\""
  echo "  ssh ${TARGET_HOST} \"sudo iptables -D OUTPUT -d ${GCP_CIDR} -j DROP\""
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
  echo "[5] Expected behaviour (per spec C1.md)"
  echo "------------------------------------------------------------"
  echo "  P-A  : IDC majority retains write; GCP voter becomes minority."
  echo "         GCP-side client via idc-haproxy → fails (route severed)."
  echo "  P-B  : per-shard voter split across 2 regions → after partition"
  echo "         both regions become minority ⇒ cluster-wide write reject"
  echo "         (split-brain prevention engaged)."
  echo
  echo "  Timeline (per C1.md §Post-injection):"
  echo "    t=0    inject iptables DROP (all IDC↔GCP traffic)"
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
