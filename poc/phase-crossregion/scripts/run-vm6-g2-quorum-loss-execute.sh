#!/usr/bin/env bash
# run-vm6-g2-quorum-loss-execute.sh — Galera-specific chaos scenario G2:
# kill all 3 IDC nodes simultaneously, then restart and measure recovery.
#
# Why this is a DIFFERENT scenario from TiDB/CRDB/YBDB's F2 (run-vm6-f2-idc-
# death-execute.sh), even though the injection mechanism is copied almost
# verbatim: for TiDB/CRDB/YBDB, killing 3 IDC nodes out of 6 is a REGIONAL
# FAILOVER test — the surviving 3 GCP nodes retain PD/Raft quorum arbitration
# and (for a correctly configured cluster) can keep serving. For Galera,
# 6-node majority = 4; losing 3 nodes leaves only 3/6, which is NOT a
# majority. The correct, expected outcome is that the ENTIRE cluster
# (including the 3 surviving GCP nodes) becomes non-Primary and refuses ALL
# writes — this is Galera's quorum algorithm correctly preventing a real
# split-brain, not a failover to survivors. Do not read a G2 "recovery" as
# "Galera survived IDC death" — it means "Galera correctly went read-only/
# non-Primary and then correctly reformed quorum once IDC nodes came back."
#
# Recovery is measured on two axes:
#   1. cluster_rebuild_sec  — time until wsrep_cluster_size=6 AND
#      wsrep_cluster_status=Primary again (queried via GCP_HOST, which stays
#      reachable throughout — only its wsrep state changes, not its network
#      reachability)
#   2. write_recovery_sec   — time until a write against GCP_HOST succeeds
#      again (this should closely track #1, since Galera requires Primary
#      state to accept writes at all — any material gap between the two is
#      itself an interesting finding)
#
# Usage:
#   bash run-vm6-g2-quorum-loss-execute.sh --gcp-host <ip> \
#     --artifact-dir <dir> [--idc-hosts "ip1 ip2 ip3"] [--pre-window-sec 5] \
#     [--poll-interval-sec 5] [--poll-window-sec 600] [--dry-run]
#
# Env required: GALERA_BENCH_PASSWORD.
#
# --poll-window-sec bounds how long we wait for recovery before giving up
# and recording "not recovered within window" (never fabricated as success).
# This is the most destructive of the 5 G-scenarios — run LAST.

set -uo pipefail

IDC_HOSTS="172.24.40.32 172.24.40.33 172.24.40.34"
GCP_HOST=""
GCP_PORT=3306
ARTIFACT_DIR=""
PRE_WINDOW_SEC=5
POLL_INTERVAL_SEC=5
POLL_WINDOW_SEC=600
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: run-vm6-g2-quorum-loss-execute.sh --gcp-host <ip> --artifact-dir <dir> \
  [--idc-hosts "ip1 ip2 ip3"] [--pre-window-sec N] [--poll-interval-sec N] \
  [--poll-window-sec N] [--dry-run]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --idc-hosts)         IDC_HOSTS=$2; shift 2 ;;
    --gcp-host)          GCP_HOST=$2; shift 2 ;;
    --gcp-port)          GCP_PORT=$2; shift 2 ;;
    --artifact-dir)      ARTIFACT_DIR=$2; shift 2 ;;
    --pre-window-sec)    PRE_WINDOW_SEC=$2; shift 2 ;;
    --poll-interval-sec) POLL_INTERVAL_SEC=$2; shift 2 ;;
    --poll-window-sec)   POLL_WINDOW_SEC=$2; shift 2 ;;
    --dry-run)           DRY_RUN=1; shift ;;
    -h|--help)           usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done
[[ -z "$GCP_HOST" || -z "$ARTIFACT_DIR" ]] && usage
: "${GALERA_BENCH_PASSWORD:?missing GALERA_BENCH_PASSWORD}"

STATUS_CMD="systemctl is-active mysql 2>&1"
STOP_CMD="systemctl stop mysql"
START_CMD="systemctl start mysql"
INSERT_PROBE="MYSQL_PWD='${GALERA_BENCH_PASSWORD}' mysql -h $GCP_HOST -P $GCP_PORT -u tpcc_bench tpcc -e 'INSERT INTO warehouse (w_id) VALUES (999999)' 2>&1"
DELETE_PROBE="MYSQL_PWD='${GALERA_BENCH_PASSWORD}' mysql -h $GCP_HOST -P $GCP_PORT -u tpcc_bench tpcc -e 'DELETE FROM warehouse WHERE w_id=999999' 2>&1"
# 查詢對象固定 GCP_HOST（整段過程網路可達，只是 wsrep 狀態會變，不是連線
# 問題）；輸出兩行 "wsrep_cluster_size\t6"／"wsrep_cluster_status\tPrimary"，
# 由呼叫端用 grep 判斷是否兩者同時成立（quorum 重組）。
QUORUM_QUERY="MYSQL_PWD='${GALERA_BENCH_PASSWORD}' mysql -h $GCP_HOST -P $GCP_PORT -u tpcc_bench -N -B -e \"SHOW STATUS LIKE 'wsrep_cluster_size'; SHOW STATUS LIKE 'wsrep_cluster_status';\" 2>/dev/null"
is_quorate() { echo "$1" | grep -q "wsrep_cluster_size	6" && echo "$1" | grep -q "wsrep_cluster_status	Primary"; }

mkdir -p "$ARTIFACT_DIR"
log() { echo "[g2-quorum-loss] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }
ssh_c() { ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$1" "$2"; }

log "idc_hosts=[$IDC_HOSTS] gcp_host=$GCP_HOST:$GCP_PORT dry_run=$DRY_RUN"

# ---- pre-injection: confirm cluster healthy, clear any leftover sentinel ----
mkdir -p "$ARTIFACT_DIR/db-config-snapshot/pre-kill"
if [[ "$DRY_RUN" -eq 0 ]]; then
  for h in $IDC_HOSTS; do
    ssh_c "$h" "$STATUS_CMD" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/svc-status-$h.txt" 2>&1
  done
  eval "$QUORUM_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/quorum-query.txt" 2>&1
  sleep "$PRE_WINDOW_SEC"
  eval "$DELETE_PROBE" >/dev/null 2>&1 || true
else
  log "[dry-run] would confirm baseline health on all 3 IDC hosts + quorum query"
fi

# ---- kill all 3 IDC hosts simultaneously ----
T_KILL=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
echo "t_kill=$T_KILL" > "$ARTIFACT_DIR/kill.log"
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "EXECUTING REAL KILL on all 3 IDC hosts simultaneously: $STOP_CMD"
  for h in $IDC_HOSTS; do
    ( ssh_c "$h" "$STOP_CMD" >> "$ARTIFACT_DIR/kill.log" 2>&1; echo "  $h stop exit=$?" >> "$ARTIFACT_DIR/kill.log" ) &
  done
  wait
else
  log "[dry-run] would run: $STOP_CMD on all 3 IDC hosts simultaneously"
fi

# ---- validate write-reject: whole 6-node cluster should refuse writes now ----
log "validating write-reject (should fail cluster-wide — quorum lost, 3/6 remaining)"
if [[ "$DRY_RUN" -eq 0 ]]; then
  INSERT_RESULT=$(eval "$INSERT_PROBE" 2>&1)
  {
    echo "--- INSERT_PROBE output ---"
    echo "$INSERT_RESULT"
  } > "$ARTIFACT_DIR/write-reject-validation.txt"
  if grep -qiE "ambiguous" <<<"$INSERT_RESULT"; then
    VERDICT="ambiguous_result_manual_review_required"
  elif grep -qiE "error|refused|timeout|no route|fail|unknown mysql server host" <<<"$INSERT_RESULT"; then
    VERDICT="write_correctly_rejected"
  else
    VERDICT="UNEXPECTED_WRITE_SUCCEEDED_review_manually"
  fi
  echo "verdict=$VERDICT" >> "$ARTIFACT_DIR/write-reject-validation.txt"
  {
    echo "--- cleanup DELETE_PROBE output (best-effort, not used for verdict) ---"
    eval "$DELETE_PROBE" 2>&1
  } >> "$ARTIFACT_DIR/write-reject-validation.txt"
else
  echo "[dry-run] would attempt a write via GCP endpoint, expecting cluster-wide rejection" > "$ARTIFACT_DIR/write-reject-validation.txt"
fi

# ---- recovery phase: restart all 3 IDC hosts, measure time to quorum + first write ----
T_RESTART_START=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
echo "t_restart_start=$T_RESTART_START" >> "$ARTIFACT_DIR/kill.log"
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "restarting: $START_CMD on all 3 IDC hosts (rejoin via IST/SST)"
  for h in $IDC_HOSTS; do
    ( ssh_c "$h" "$START_CMD" >> "$ARTIFACT_DIR/kill.log" 2>&1; echo "  $h start exit=$?" >> "$ARTIFACT_DIR/kill.log" ) &
  done
  wait
else
  log "[dry-run] would run: $START_CMD on all 3 IDC hosts"
fi

RECOVERY_LOG="$ARTIFACT_DIR/recovery-poll.log"
: > "$RECOVERY_LOG"
T_RECOVERED="null"
T_FIRST_WRITE_OK="null"
if [[ "$DRY_RUN" -eq 0 ]]; then
  POLLS=$(( POLL_WINDOW_SEC / POLL_INTERVAL_SEC ))
  for i in $(seq 1 "$POLLS"); do
    NOW=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    QUORUM_OUT=$(eval "$QUORUM_QUERY" 2>/dev/null || echo "")
    if is_quorate "$QUORUM_OUT"; then QUORATE=1; else QUORATE=0; fi
    echo "$NOW poll=$i quorate=$QUORATE" >> "$RECOVERY_LOG"
    if [[ "$QUORATE" == "1" && "$T_RECOVERED" == "null" ]]; then
      T_RECOVERED="$NOW"
      echo "$NOW: wsrep_cluster_size=6 wsrep_cluster_status=Primary (quorum reformed)" >> "$RECOVERY_LOG"
    fi
    if [[ "$T_FIRST_WRITE_OK" == "null" ]]; then
      eval "$DELETE_PROBE" >/dev/null 2>&1 || true  # idempotent: clear sentinel before each attempt
      INSERT_RESULT=$(eval "$INSERT_PROBE" 2>&1)
      if grep -qiE "ambiguous" <<<"$INSERT_RESULT"; then
        : # inconclusive — do not declare recovered, retry next poll
      elif ! grep -qiE "error|refused|timeout|no route|fail|unknown mysql server host" <<<"$INSERT_RESULT"; then
        eval "$DELETE_PROBE" >/dev/null 2>&1 || true  # best-effort cleanup
        T_FIRST_WRITE_OK="$NOW"
        echo "$NOW: first successful write post-recovery" >> "$RECOVERY_LOG"
      fi
    fi
    [[ "$T_RECOVERED" != "null" && "$T_FIRST_WRITE_OK" != "null" ]] && break
    sleep "$POLL_INTERVAL_SEC"
  done
  [[ "$T_RECOVERED" == "null" ]] && log "WARN: quorum did not reform within ${POLL_WINDOW_SEC}s window"
  [[ "$T_FIRST_WRITE_OK" == "null" ]] && log "WARN: no successful write observed within ${POLL_WINDOW_SEC}s window"
else
  echo "[dry-run] would poll for recovery every ${POLL_INTERVAL_SEC}s up to ${POLL_WINDOW_SEC}s" >> "$RECOVERY_LOG"
fi

mkdir -p "$ARTIFACT_DIR/db-config-snapshot/post-recovery"
if [[ "$DRY_RUN" -eq 0 ]]; then
  for h in $IDC_HOSTS; do
    ssh_c "$h" "$STATUS_CMD" > "$ARTIFACT_DIR/db-config-snapshot/post-recovery/svc-status-$h.txt" 2>&1
  done
  eval "$QUORUM_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/post-recovery/quorum-query.txt" 2>&1
fi

# ---- compute recovery_sec (only if both timestamps are real, never fabricated) ----
RECOVERY_SEC="null"
WRITE_RECOVERY_SEC="null"
if [[ "$T_RECOVERED" != "null" ]]; then
  RECOVERY_SEC=$(python3 -c "
from datetime import datetime
a=datetime.strptime('$T_KILL'.rstrip('Z'), '%Y-%m-%dT%H:%M:%S.%f')
b=datetime.strptime('$T_RECOVERED'.rstrip('Z'), '%Y-%m-%dT%H:%M:%S.%f')
print(round((b-a).total_seconds(),3))
" 2>/dev/null || echo "null")
fi
if [[ "$T_FIRST_WRITE_OK" != "null" ]]; then
  WRITE_RECOVERY_SEC=$(python3 -c "
from datetime import datetime
a=datetime.strptime('$T_KILL'.rstrip('Z'), '%Y-%m-%dT%H:%M:%S.%f')
b=datetime.strptime('$T_FIRST_WRITE_OK'.rstrip('Z'), '%Y-%m-%dT%H:%M:%S.%f')
print(round((b-a).total_seconds(),3))
" 2>/dev/null || echo "null")
fi

cat > "$ARTIFACT_DIR/rto-rpo.json" <<JSON
{
  "scenario": "g2-quorum-loss",
  "db_kind": "galera",
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "t_kill": "$T_KILL",
  "t_restart_start": "$T_RESTART_START",
  "t_quorum_reformed": "$T_RECOVERED",
  "t_first_write_ok": "$T_FIRST_WRITE_OK",
  "cluster_rebuild_sec": $RECOVERY_SEC,
  "write_recovery_sec": $WRITE_RECOVERY_SEC,
  "poll_window_sec": $POLL_WINDOW_SEC,
  "note": "killing 3/6 nodes breaks Galera majority (need 4/6) — expected correct outcome is cluster-wide write-reject, not regional failover survival; write-reject-validation.txt holds that verdict separately from this recovery-time measurement"
}
JSON
log "done — artifacts in $ARTIFACT_DIR"
cat "$ARTIFACT_DIR/rto-rpo.json"
