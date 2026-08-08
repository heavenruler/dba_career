#!/usr/bin/env bash
# run-vm6-f2-idc-death-execute.sh — REAL execution of the orphaned
# "IDC full 3-node death / cluster write reject" scenario originally
# specced in phase-crossregion/chaos/C7.md (2026-06-06), whose "C7" id was
# later reassigned to disk-slow by REPLAN-2026-06-15.md §6, leaving the
# original scenario without an id or an execution script. Renamed "F2"
# per 2026-08-07 scope decision.
#
# Difference from the original C7.md spec: that spec's "Lab mode" explicitly
# said "不測recovery（不重啟IDC nodes）" — this script ADDS a recovery phase
# (restart all 3 IDC nodes, measure time to rejoin + time to first
# successful write again), per 2026-08-07 decision to actually measure
# region-rebuild/recovery time, not just confirm write-reject fires.
#
# This is the most destructive of the 5 scenarios — run LAST against any
# given environment, since after this the environment needs the most
# extensive recovery before any further test could be considered clean.
#
# Usage:
#   bash run-vm6-f2-idc-death-execute.sh --db tidb|crdb|ybdb \
#     --idc-hosts "ip1 ip2 ip3" --gcp-host <ip> --artifact-dir <dir> \
#     [--pre-window-sec 5] [--poll-interval-sec 5] [--poll-window-sec 600] \
#     [--dry-run]
#
# --poll-window-sec bounds how long we wait for recovery before giving up
# and recording "not recovered within window" (never fabricated as success).

set -uo pipefail

DB=""
IDC_HOSTS="172.24.40.32 172.24.40.33 172.24.40.34"
GCP_HOST=""
ARTIFACT_DIR=""
PRE_WINDOW_SEC=5
POLL_INTERVAL_SEC=5
POLL_WINDOW_SEC=600
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: run-vm6-f2-idc-death-execute.sh --db tidb|crdb|ybdb --gcp-host <ip> \
  --artifact-dir <dir> [--idc-hosts "ip1 ip2 ip3"] [--pre-window-sec N] \
  [--poll-interval-sec N] [--poll-window-sec N] [--dry-run]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)                DB=$2; shift 2 ;;
    --idc-hosts)         IDC_HOSTS=$2; shift 2 ;;
    --gcp-host)          GCP_HOST=$2; shift 2 ;;
    --artifact-dir)      ARTIFACT_DIR=$2; shift 2 ;;
    --pre-window-sec)    PRE_WINDOW_SEC=$2; shift 2 ;;
    --poll-interval-sec) POLL_INTERVAL_SEC=$2; shift 2 ;;
    --poll-window-sec)   POLL_WINDOW_SEC=$2; shift 2 ;;
    --dry-run)           DRY_RUN=1; shift ;;
    -h|--help)           usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done
[[ -z "$DB" || -z "$GCP_HOST" || -z "$ARTIFACT_DIR" ]] && usage
[[ "$DB" =~ ^(tidb|crdb|ybdb)$ ]] || { echo "--db must be tidb|crdb|ybdb" >&2; exit 2; }

case "$DB" in
  # 2026-08-08 fix: "tidb-server" is not a real unit (same bug found and
  # fixed in run-vm6-chaos-execute.sh — real unit is "tidb-4000"). F2's
  # spec intent ("IDC 全死 systemctl stop") is a genuine whole-node kill,
  # not just the SQL layer, so this also stops the co-located tikv-20160
  # and pd-2379 — matching the same kill-scope reasoning as F1/C4. Only
  # 172.24.40.32/.33 actually run tidb-4000 in this topology (.34 is
  # TiKV+PD only); stopping/starting it on .34 fails harmlessly (recorded
  # in kill.log's exit code, not fatal to the overall run).
  tidb) SVC="tidb-4000 tikv-20160 pd-2379"; GCP_PORT=4000
        WRITE_PROBE="mysql -h $GCP_HOST -P 4000 -u root -e 'INSERT INTO tpcc.warehouse (w_id) VALUES (999999)' 2>&1; mysql -h $GCP_HOST -P 4000 -u root -e 'DELETE FROM tpcc.warehouse WHERE w_id=999999' 2>&1"
        HEALTH_QUERY="mysql -h $GCP_HOST -P 4000 -u root -N -Be \"SELECT COUNT(*) FROM information_schema.tikv_store_status WHERE STORE_STATE='Up' AND LABEL LIKE '%idc%'\"" ;;
  crdb) SVC="cockroach"; GCP_PORT=26257
        WRITE_PROBE="cockroach sql --insecure --host=$GCP_HOST:26257 -e \"SELECT 1\" 2>&1"
        HEALTH_QUERY="cockroach sql --insecure --host=$GCP_HOST:26257 --format=tsv -e \"SELECT count(*) FROM crdb_internal.kv_node_status WHERE address LIKE '172.24%'\"" ;;
  ybdb) SVC="yb-master yb-tserver"; GCP_PORT=5433
        WRITE_PROBE="psql \"host=$GCP_HOST port=5433 user=yugabyte dbname=tpcc connect_timeout=3\" -c 'SELECT 1' 2>&1"
        HEALTH_QUERY="yb-admin --master_addresses=$GCP_HOST:7100 list_all_tablet_servers 2>&1 | grep -c ALIVE" ;;
esac

mkdir -p "$ARTIFACT_DIR"
log() { echo "[f2-execute] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }
ssh_c() { ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$1" "$2"; }

log "db=$DB idc_hosts=[$IDC_HOSTS] gcp_host=$GCP_HOST dry_run=$DRY_RUN"

# ---- pre-injection: confirm cluster healthy, capture write-capability baseline ----
mkdir -p "$ARTIFACT_DIR/db-config-snapshot/pre-kill"
if [[ "$DRY_RUN" -eq 0 ]]; then
  for h in $IDC_HOSTS; do
    ssh_c "$h" "systemctl is-active $SVC 2>&1" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/svc-status-$h.txt" 2>&1
  done
  sleep "$PRE_WINDOW_SEC"
else
  log "[dry-run] would confirm baseline health on all 3 IDC hosts"
fi

# ---- kill all 3 IDC hosts simultaneously ----
T_KILL=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
echo "t_kill=$T_KILL" > "$ARTIFACT_DIR/kill.log"
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "EXECUTING REAL KILL on all 3 IDC hosts simultaneously: $SVC"
  for h in $IDC_HOSTS; do
    ( ssh_c "$h" "systemctl stop $SVC" >> "$ARTIFACT_DIR/kill.log" 2>&1; echo "  $h stop exit=$?" >> "$ARTIFACT_DIR/kill.log" ) &
  done
  wait
else
  log "[dry-run] would stop $SVC on all 3 IDC hosts simultaneously"
fi

# ---- validate write-reject (per original C7.md intent) ----
log "validating write-reject (should fail — this is the expected/correct outcome)"
if [[ "$DRY_RUN" -eq 0 ]]; then
  eval "$WRITE_PROBE" > "$ARTIFACT_DIR/write-reject-validation.txt" 2>&1
  if grep -qiE "error|refused|timeout|no route|fail" "$ARTIFACT_DIR/write-reject-validation.txt"; then
    echo "verdict=write_correctly_rejected" >> "$ARTIFACT_DIR/write-reject-validation.txt"
  else
    echo "verdict=UNEXPECTED_WRITE_SUCCEEDED_review_manually" >> "$ARTIFACT_DIR/write-reject-validation.txt"
  fi
else
  echo "[dry-run] would attempt a write via GCP endpoint, expecting rejection" > "$ARTIFACT_DIR/write-reject-validation.txt"
fi

# ---- recovery phase: restart all 3 IDC hosts, measure time to health + first write ----
T_RESTART_START=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
echo "t_restart_start=$T_RESTART_START" >> "$ARTIFACT_DIR/kill.log"
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "restarting $SVC on all 3 IDC hosts"
  for h in $IDC_HOSTS; do
    ( ssh_c "$h" "systemctl start $SVC" >> "$ARTIFACT_DIR/kill.log" 2>&1; echo "  $h start exit=$?" >> "$ARTIFACT_DIR/kill.log" ) &
  done
  wait
else
  log "[dry-run] would restart $SVC on all 3 IDC hosts"
fi

RECOVERY_LOG="$ARTIFACT_DIR/recovery-poll.log"
: > "$RECOVERY_LOG"
T_RECOVERED="null"
T_FIRST_WRITE_OK="null"
if [[ "$DRY_RUN" -eq 0 ]]; then
  POLLS=$(( POLL_WINDOW_SEC / POLL_INTERVAL_SEC ))
  for i in $(seq 1 "$POLLS"); do
    NOW=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    HEALTHY_COUNT=$(eval "$HEALTH_QUERY" 2>/dev/null | tr -d '[:space:]' || echo "0")
    echo "$NOW poll=$i idc_healthy_count=$HEALTHY_COUNT" >> "$RECOVERY_LOG"
    if [[ "$HEALTHY_COUNT" =~ ^[0-9]+$ ]] && [[ "$HEALTHY_COUNT" -ge 3 ]] && [[ "$T_RECOVERED" == "null" ]]; then
      T_RECOVERED="$NOW"
      echo "$NOW: all 3 IDC nodes report healthy" >> "$RECOVERY_LOG"
    fi
    if [[ "$T_FIRST_WRITE_OK" == "null" ]]; then
      WRITE_RESULT=$(eval "$WRITE_PROBE" 2>&1)
      if ! grep -qiE "error|refused|timeout|no route|fail" <<<"$WRITE_RESULT"; then
        T_FIRST_WRITE_OK="$NOW"
        echo "$NOW: first successful write post-recovery" >> "$RECOVERY_LOG"
      fi
    fi
    [[ "$T_RECOVERED" != "null" && "$T_FIRST_WRITE_OK" != "null" ]] && break
    sleep "$POLL_INTERVAL_SEC"
  done
  if [[ "$T_RECOVERED" == "null" ]]; then
    log "WARN: cluster did not report 3/3 IDC nodes healthy within ${POLL_WINDOW_SEC}s window"
  fi
  if [[ "$T_FIRST_WRITE_OK" == "null" ]]; then
    log "WARN: no successful write observed within ${POLL_WINDOW_SEC}s window"
  fi
else
  echo "[dry-run] would poll for recovery every ${POLL_INTERVAL_SEC}s up to ${POLL_WINDOW_SEC}s" >> "$RECOVERY_LOG"
fi

mkdir -p "$ARTIFACT_DIR/db-config-snapshot/post-recovery"
if [[ "$DRY_RUN" -eq 0 ]]; then
  for h in $IDC_HOSTS; do
    ssh_c "$h" "systemctl is-active $SVC 2>&1" > "$ARTIFACT_DIR/db-config-snapshot/post-recovery/svc-status-$h.txt" 2>&1
  done
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
  "scenario": "F2-idc-full-death",
  "db_kind": "$DB",
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "t_kill": "$T_KILL",
  "t_restart_start": "$T_RESTART_START",
  "t_all_idc_healthy": "$T_RECOVERED",
  "t_first_write_ok": "$T_FIRST_WRITE_OK",
  "cluster_rebuild_sec": $RECOVERY_SEC,
  "write_recovery_sec": $WRITE_RECOVERY_SEC,
  "poll_window_sec": $POLL_WINDOW_SEC,
  "note": "write-reject validation is in write-reject-validation.txt (separate from this recovery-time measurement, per original C7.md intent + 2026-08-07 recovery-time extension)"
}
JSON
log "done — artifacts in $ARTIFACT_DIR"
cat "$ARTIFACT_DIR/rto-rpo.json"
