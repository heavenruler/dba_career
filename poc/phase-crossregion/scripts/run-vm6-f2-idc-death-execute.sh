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
        INSERT_PROBE="mysql -h $GCP_HOST -P 4000 -u root -e 'INSERT INTO tpcc.warehouse (w_id) VALUES (999999)' 2>&1"
        DELETE_PROBE="mysql -h $GCP_HOST -P 4000 -u root -e 'DELETE FROM tpcc.warehouse WHERE w_id=999999' 2>&1"
        HEALTH_QUERY="mysql -h $GCP_HOST -P 4000 -u root -N -Be \"SELECT COUNT(*) FROM information_schema.tikv_store_status WHERE STORE_STATE='Up' AND LABEL LIKE '%idc%'\"" ;;
  crdb) SVC="cockroach"; GCP_PORT=26257
        # 2026-08-08 fix: same class of bug as the ybdb WRITE_PROBE fix —
        # this was a bare "SELECT 1", not an actual write, so it could never
        # validate write-REJECT under quorum loss. Confirmed real schema
        # (only w_id is NOT NULL on warehouse) and tested this exact
        # insert+delete live before wiring it in.
        # 2026-08-10 fix (audit finding F-006): INSERT and DELETE used to be
        # concatenated into one WRITE_PROBE string with combined output,
        # which (a) let a naive "contains error" grep classify CRDB's own
        # "ERROR: result is ambiguous ... lost quorum" response as a clean
        # write_correctly_rejected — CRDB is explicitly telling us it does
        # NOT know whether the write committed, which is a materially
        # different outcome from a clean reject, and (b) meant an INSERT
        # that actually committed followed by a DELETE that merely failed
        # to connect would ALSO be misclassified as "correctly rejected"
        # (the real failure — a write got through — hidden by grep matching
        # the later command's unrelated connection error). Split into
        # separate INSERT_PROBE/DELETE_PROBE so the verdict logic below can
        # inspect the INSERT's own result in isolation.
        INSERT_PROBE="cockroach sql --insecure --host=$GCP_HOST:26257 -d tpcc -e \"INSERT INTO warehouse (w_id) VALUES (999999)\" 2>&1"
        DELETE_PROBE="cockroach sql --insecure --host=$GCP_HOST:26257 -d tpcc -e \"DELETE FROM warehouse WHERE w_id=999999\" 2>&1"
        # 2026-08-08 fix: crdb_internal.kv_node_status is access-restricted
        # on v26.2 ("ERROR: Access to crdb_internal and system is
        # restricted... set allow_unsafe_internals") — this query always
        # failed, so idc_healthy_count was permanently 0 and the poll loop
        # burned the full 600s window every time regardless of how fast the
        # cluster/write-probe actually recovered. `cockroach node status`
        # is unrestricted and gives the same is_available signal per node;
        # cut+grep (no backslash escapes) sidesteps this string surviving
        # two rounds of shell parsing (assignment here, then eval later).
        HEALTH_QUERY="cockroach node status --insecure --host=$GCP_HOST:26257 --format=tsv 2>/dev/null | cut -f2,9 | grep -c '^172.24.*true\$'" ;;
  ybdb) SVC="yb-master yb-tserver"; GCP_PORT=5433
        # 2026-08-08 fix: this was a bare "SELECT 1" — not an actual write,
        # so it could never validate write-REJECT (a read-only query can
        # succeed via a surviving replica while writes fail on quorum loss,
        # or vice versa; it simply doesn't exercise the code path F2 exists
        # to test). Confirmed real schema (only w_id is NOT NULL) and tested
        # this insert+delete live before wiring it in.
        INSERT_PROBE="psql \"host=$GCP_HOST port=5433 user=yugabyte dbname=tpcc connect_timeout=3\" -c 'INSERT INTO warehouse (w_id) VALUES (999999)' 2>&1"
        DELETE_PROBE="psql \"host=$GCP_HOST port=5433 user=yugabyte dbname=tpcc connect_timeout=3\" -c 'DELETE FROM warehouse WHERE w_id=999999' 2>&1"
        # 2026-08-08 fix: $GCP_HOST:7100 is not a valid master address list —
        # yb-admin needs all 3 IDC master addresses (masters only run on IDC
        # in this P-A topology, confirmed via list_all_masters). Also fixed
        # in run-vm6-chaos-execute.sh's ybdb case for the same reason.
        HEALTH_QUERY="yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 list_all_tablet_servers 2>&1 | grep -c ALIVE" ;;
esac

# 2026-08-08 fix: YBDB runs under `yugabyted` (a supervisor spawning
# yb-master/yb-tserver as children), not systemd — "systemctl stop/start
# $SVC" fails immediately for ybdb (no such unit). Introduced per-DB
# STATUS_CMD/STOP_CMD/START_CMD templates so tidb/crdb keep using systemctl
# (verified real units) while ybdb uses `yugabyted stop/start --base_dir=`.
case "$DB" in
  ybdb)
    STATUS_CMD="yugabyted status --base_dir=/var/yugabyte 2>&1"
    STOP_CMD="yugabyted stop --base_dir=/var/yugabyte"
    START_CMD="yugabyted start --base_dir=/var/yugabyte"
    ;;
  *)
    STATUS_CMD="systemctl is-active $SVC 2>&1"
    STOP_CMD="systemctl stop $SVC"
    START_CMD="systemctl start $SVC"
    ;;
esac

mkdir -p "$ARTIFACT_DIR"
log() { echo "[f2-execute] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }
ssh_c() { ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$1" "$2"; }

log "db=$DB idc_hosts=[$IDC_HOSTS] gcp_host=$GCP_HOST dry_run=$DRY_RUN"

# ---- pre-injection: confirm cluster healthy, capture write-capability baseline ----
mkdir -p "$ARTIFACT_DIR/db-config-snapshot/pre-kill"
if [[ "$DRY_RUN" -eq 0 ]]; then
  for h in $IDC_HOSTS; do
    ssh_c "$h" "$STATUS_CMD" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/svc-status-$h.txt" 2>&1
  done
  sleep "$PRE_WINDOW_SEC"
  # Ensure the sentinel row is absent before injection (best-effort, while
  # cluster is healthy) — a leftover row from a prior run/manual test would
  # otherwise make the post-kill write-reject INSERT fail with a duplicate-key
  # error instead of a genuine unavailability error, misclassifying the
  # verdict as write_correctly_rejected for the wrong reason.
  eval "$DELETE_PROBE" >/dev/null 2>&1 || true
else
  log "[dry-run] would confirm baseline health on all 3 IDC hosts"
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

# ---- validate write-reject (per original C7.md intent) ----
log "validating write-reject (should fail — this is the expected/correct outcome)"
if [[ "$DRY_RUN" -eq 0 ]]; then
  # 2026-08-10 fix (audit finding F-006): verdict is now derived from the
  # INSERT's own output ONLY (not the combined INSERT+DELETE text), and
  # distinguishes three outcomes instead of two — a naive "contains error"
  # match previously classified CRDB's "result is ambiguous ... lost
  # quorum" response (which means CRDB itself cannot say whether the write
  # committed) as a clean write_correctly_rejected, and would have done the
  # same for a committed INSERT followed by a merely-disconnected DELETE.
  INSERT_RESULT=$(eval "$INSERT_PROBE" 2>&1)
  {
    echo "--- INSERT_PROBE output ---"
    echo "$INSERT_RESULT"
  } > "$ARTIFACT_DIR/write-reject-validation.txt"
  if grep -qiE "ambiguous" <<<"$INSERT_RESULT"; then
    VERDICT="ambiguous_result_manual_review_required"
  elif grep -qiE "error|refused|timeout|no route|fail" <<<"$INSERT_RESULT"; then
    VERDICT="write_correctly_rejected"
  else
    VERDICT="UNEXPECTED_WRITE_SUCCEEDED_review_manually"
  fi
  echo "verdict=$VERDICT" >> "$ARTIFACT_DIR/write-reject-validation.txt"
  # Best-effort cleanup regardless of verdict: if the INSERT actually
  # committed (ambiguous or unexpected-success case), don't leave the
  # sentinel row behind. Failure here is expected/harmless when the
  # cluster is genuinely still down or the INSERT never committed.
  {
    echo "--- cleanup DELETE_PROBE output (best-effort, not used for verdict) ---"
    eval "$DELETE_PROBE" 2>&1
  } >> "$ARTIFACT_DIR/write-reject-validation.txt"
else
  echo "[dry-run] would attempt a write via GCP endpoint, expecting rejection" > "$ARTIFACT_DIR/write-reject-validation.txt"
fi

# ---- recovery phase: restart all 3 IDC hosts, measure time to health + first write ----
T_RESTART_START=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
echo "t_restart_start=$T_RESTART_START" >> "$ARTIFACT_DIR/kill.log"
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "restarting: $START_CMD on all 3 IDC hosts"
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
    HEALTHY_COUNT=$(eval "$HEALTH_QUERY" 2>/dev/null | tr -d '[:space:]' || echo "0")
    echo "$NOW poll=$i idc_healthy_count=$HEALTHY_COUNT" >> "$RECOVERY_LOG"
    if [[ "$HEALTHY_COUNT" =~ ^[0-9]+$ ]] && [[ "$HEALTHY_COUNT" -ge 3 ]] && [[ "$T_RECOVERED" == "null" ]]; then
      T_RECOVERED="$NOW"
      echo "$NOW: all 3 IDC nodes report healthy" >> "$RECOVERY_LOG"
    fi
    if [[ "$T_FIRST_WRITE_OK" == "null" ]]; then
      # 2026-08-10 fix (audit finding F-006): use INSERT_PROBE's own result
      # to decide recovery, not a combined INSERT+DELETE string. An
      # "ambiguous" result (CRDB, mid quorum-recovery) means we still don't
      # know if a write went through — keep polling rather than declaring
      # recovery on an uncertain outcome.
      # 2026-08-10 fix (real re-run finding): the pre-recovery INSERT_PROBE
      # above can itself have committed despite reporting "ambiguous" (CRDB
      # confirmed case — the sentinel row existed after recovery even though
      # its own cleanup DELETE_PROBE also failed ambiguous/poisoned-latch
      # during the outage). Without this, every poll's INSERT then fails
      # with a duplicate-key error, which contains "error" and is
      # indistinguishable from "still down" — recovery is never detected
      # even after the cluster is fully healthy. Make each poll idempotent
      # by clearing the sentinel row first (best-effort; a no-op delete on a
      # still-down cluster or a not-yet-existing row is expected/harmless).
      eval "$DELETE_PROBE" >/dev/null 2>&1 || true
      INSERT_RESULT=$(eval "$INSERT_PROBE" 2>&1)
      if grep -qiE "ambiguous" <<<"$INSERT_RESULT"; then
        : # inconclusive — do not declare recovered, retry next poll
      elif ! grep -qiE "error|refused|timeout|no route|fail" <<<"$INSERT_RESULT"; then
        eval "$DELETE_PROBE" >/dev/null 2>&1 || true  # best-effort cleanup
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
    ssh_c "$h" "$STATUS_CMD" > "$ARTIFACT_DIR/db-config-snapshot/post-recovery/svc-status-$h.txt" 2>&1
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
