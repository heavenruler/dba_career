#!/usr/bin/env bash
# chaos-c7-disk-slow-plan.sh — planner-only (no execute)
#
# Spec ground truth: phase-crossregion/chaos/C7.md
#   Failure model (task-defined mapping): disk slow via cgroup
#   blkio.throttle.read_bps_device  (or alternative tc qdisc tbf for
#   network-side egress throttle when blkio is unavailable).
#   (Note: C7.md original spec is "IDC全死 systemctl stop" — write-reject
#    validation. REPLAN §6 names this script "disk-slow"; this planner models
#    a single-host slow-disk degradation. The write-reject scenario in C7.md
#    is out-of-scope for this planner.)
#
# Behaviour: print the cgroup / tc commands that *would* run + recover
#            commands + expected artifact paths. Does NOT touch cgroup or tc.
# No --execute flag. Real injection requires PR + DBA review.

set -euo pipefail

DB=""
TARGET_HOST=""
DURATION=""

usage() {
  cat <<EOF
Usage: $0 --db tidb|crdb|ybdb --target-host <ip> --duration <sec>

Planner-only: prints the cgroup blkio.throttle / tc qdisc tbf commands
that *would* be run + expected artifact paths + expected behaviour.
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

case "$DB" in
  tidb) DATA_DIR="/opt/tidb/data"        ; SVC="tikv-server" ;;
  crdb) DATA_DIR="/var/lib/cockroach"    ; SVC="cockroach" ;;
  ybdb) DATA_DIR="/var/yugabyte"         ; SVC="yb-tserver" ;;
esac

# throttle target: 1 MB/s read = 1048576 B/s (illustrative; operator overrides)
THROTTLE_BPS="1048576"
# tc tbf rate (alternative)
TC_RATE="1mbit"

TS="$(date +%Y%m%dT%H%M%S)"
PLAN_FILE="chaos-plan-c7-${TS}.txt"
ARTIFACT_DIR="chaos/C7/${TS}"

{
  echo "============================================================"
  echo "chaos-c7-disk-slow-plan  (PLANNER ONLY — no execution)"
  echo "============================================================"
  echo "generated      : ${TS}"
  echo "db             : ${DB}"
  echo "target-host    : ${TARGET_HOST}"
  echo "duration       : ${DURATION}s"
  echo "data dir       : ${DATA_DIR}"
  echo "service        : ${SVC}"
  echo "throttle bps   : ${THROTTLE_BPS} (1 MB/s; illustrative)"
  echo "spec source    : phase-crossregion/chaos/C7.md"
  echo
  echo "------------------------------------------------------------"
  echo "[1] Pre-injection check (would run)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} \"df -h ${DATA_DIR}\""
  echo "  ssh ${TARGET_HOST} \"lsblk -o NAME,MAJ:MIN,MOUNTPOINT | grep -F ${DATA_DIR}\""
  echo "  ssh ${TARGET_HOST} \"mount | grep -F ${DATA_DIR}\""
  echo "  # operator must read MAJ:MIN of the data-dir block device"
  echo
  echo "------------------------------------------------------------"
  echo "[2] Inject — Option A: cgroup v1 blkio.throttle (would run — NOT executed)"
  echo "------------------------------------------------------------"
  echo "  ssh ${TARGET_HOST} <<'CG'"
  echo "    sudo mkdir -p /sys/fs/cgroup/blkio/chaos-c7"
  echo "    # write '<MAJ:MIN> <bytes_per_sec>' — replace MAJ:MIN with real device:"
  echo "    echo '<MAJ:MIN> ${THROTTLE_BPS}'  | sudo tee /sys/fs/cgroup/blkio/chaos-c7/blkio.throttle.read_bps_device"
  echo "    echo '<MAJ:MIN> ${THROTTLE_BPS}'  | sudo tee /sys/fs/cgroup/blkio/chaos-c7/blkio.throttle.write_bps_device"
  echo "    pgrep -f ${SVC} | sudo tee /sys/fs/cgroup/blkio/chaos-c7/cgroup.procs"
  echo "CG"
  echo
  echo "  # cgroup v2 alternative (io.max):"
  echo "  #   echo '<MAJ:MIN> rbps=${THROTTLE_BPS} wbps=${THROTTLE_BPS}' \\"
  echo "  #     | sudo tee /sys/fs/cgroup/chaos-c7.slice/io.max"
  echo
  echo "------------------------------------------------------------"
  echo "[3] Inject — Option B: tc qdisc tbf (egress shaping, fallback)"
  echo "------------------------------------------------------------"
  echo "  # Use only if blkio cgroup unavailable. Network shaping is a"
  echo "  # weaker proxy for disk-slow but acceptable when storage is remote."
  echo "  ssh ${TARGET_HOST} \"sudo tc qdisc add dev <iface> root tbf rate ${TC_RATE} burst 32kbit latency 400ms\""
  echo
  echo "  sleep ${DURATION}"
  echo
  echo "------------------------------------------------------------"
  echo "[4] Restore (would run after duration)"
  echo "------------------------------------------------------------"
  echo "  # Option A restore:"
  echo "  ssh ${TARGET_HOST} \"sudo rmdir /sys/fs/cgroup/blkio/chaos-c7\""
  echo "  # Option B restore:"
  echo "  ssh ${TARGET_HOST} \"sudo tc qdisc del dev <iface> root\""
  echo
  echo "------------------------------------------------------------"
  echo "[5] Expected artifacts"
  echo "------------------------------------------------------------"
  echo "  ${ARTIFACT_DIR}/tpmc-1s.txt                # tpmC drop curve, 1s resolution"
  echo "  ${ARTIFACT_DIR}/io-latency-p99.txt         # iostat / node_exporter disk p99 latency"
  echo "  ${ARTIFACT_DIR}/blkio-throttle-state.txt   # cat blkio.throttle.* before/after"
  echo "  ${ARTIFACT_DIR}/tc-qdisc-state.txt         # tc -s qdisc show (if Option B)"
  echo "  ${ARTIFACT_DIR}/go-tpc-stdout.txt          # go-tpc raw stdout"
  echo "  ${ARTIFACT_DIR}/plan.txt                   # copy of this plan file"
  echo
  echo "------------------------------------------------------------"
  echo "[6] Expected behaviour"
  echo "------------------------------------------------------------"
  echo "  - ${SVC} on ${TARGET_HOST} sees disk read/write bandwidth"
  echo "    capped at ~${THROTTLE_BPS} B/s during the ${DURATION}s window."
  echo "  - WAL fsync latency rises → raft log replication slows on the"
  echo "    affected node only."
  echo "  - Raft layer may demote this node out of quorum if heartbeat"
  echo "    deadline is missed (depends on election timeout per C4.md)."
  echo "  - tpmC dips while throttle active; recovers after restore"
  echo "    (LSM compaction / WAL drain may extend tail)."
  echo "  - Other nodes carry quorum if voter count permits."
  echo
  echo "------------------------------------------------------------"
  echo "[7] REMINDER"
  echo "------------------------------------------------------------"
  echo "  This is planner-only output. NO cgroup / tc call was made."
  echo "  Enabling real injection requires PR + DBA review."
  echo "  Currently: planner only."
} | tee "${PLAN_FILE}"

echo
echo "plan written → ${PLAN_FILE}"
echo "REMINDER: 啟用實跑需 PR + DBA review；目前只 planner"
