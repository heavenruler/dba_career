#!/usr/bin/env bash
# run-vm6-chaos-execute.sh — REAL execution wrapper for F1 (planned failover) /
# C4 (IDC leader die chaos), scoped to P-A×A-S and P-B×A-A per 2026-08 DBA
# authorization (see phase-crossregion/decisions-2026-06-08.md Q19 note in
# EXECUTE-AUTHORIZATION.md and commit message of this file's introduction).
#
# This is a NEW file — it does not modify run-vm6-failover-plan.sh (still
# planner-only, per project rule "不要在現有 planner 加 --execute").
#
# Spec ground truth (unchanged design, only execution layer is new):
#   phase-crossregion/failover/F1.md
#   phase-crossregion/chaos/C4.md
#   phase-crossregion/failover/RTO-RPO-methodology.md §3 (RTO), §4 (RPO)
#
# Reuses existing, already-built primitives (per methodology §9 items 2-4,
# already satisfied):
#   probe-rto-driver.sh      — independent 100ms probe loop (§3.2)
#   wall-clock-wrapper.sh    — t_incident / t_first_ok stamping + RTO calc (§7.3)
#   gate-chrony-cross-region.sh — NTP/chrony precondition (§7.2)
#
# What this script adds (the missing orchestration layer):
#   1. Real kill command execution (ssh) — was planner-only before
#   2. Pre/post db-config-snapshot dump (per-DB leader/placement query)
#   3. RPO measurement via real TPCC row check (S_pre/S_post), per §4.2
#      SIMPLIFIED: uses existing `oorder` rows' (w_id,d_id,o_id) queried via
#      SQL immediately before/after incident, NOT a custom driver-level
#      NEW_ORDER commit-ack hook (§4.2's full FIFO-buffer design would require
#      wrapping/modifying the go-tpc binary — out of scope for this pass).
#      This is a real, honest measurement of "were already-committed rows
#      still readable after failover" — just a narrower implementation than
#      the full methodology spec envisions. Documented explicitly in output.
#   4. Assembles final rto-rpo.json per F1.md's schema (§8.1: "本方法論不擴充
#      schema，沿用" — i.e. this script targets that exact schema)
#
# Explicitly NOT changed: kill commands, RTO formula, RPO defintion, lab-mode
# assumptions (5-round no-restore, etc.) — all per existing F1.md/C4.md spec.
#
# Usage:
#   bash run-vm6-chaos-execute.sh \
#     --scenario f1|c4 --db tidb|crdb|ybdb --placement P-A|P-B \
#     --kill-target <idc-dbhost-ip> --gcp-host <ip> [--gcp-port <port>] \
#     --artifact-dir <dir> [--poll-window-sec 60] [--poll-interval-sec 5] \
#     [--post-settle-sec 30] [--pre-window-sec 5] [--skip-chrony-gate] \
#     [--dry-run]
#
# --dry-run: runs the full orchestration logic but skips the actual ssh kill
#            command and skips touching probe/DB state — used for schema
#            sanity-check per RTO-RPO-methodology.md §9 item 6. Produces a
#            rto-rpo.json with "dry_run": true and null timing fields, never
#            fabricated numbers.
#
# Authorization: real (non-dry-run) execution requires the operator to have
# read and accepted phase-crossregion/chaos/README.md's "PR + DBA review"
# rule. This script does not enforce that (it's a human process, not
# something a script can gate), but every real run writes the invoking
# operator context into kill.log for audit traceability.

set -euo pipefail

SCENARIO=""
DB=""
PLACEMENT=""
KILL_TARGET=""
GCP_HOST="10.160.152.14"
GCP_PORT=""
ARTIFACT_DIR=""
POLL_WINDOW_SEC=60
POLL_INTERVAL_SEC=5
POST_SETTLE_SEC=30
PRE_WINDOW_SEC=5
SKIP_CHRONY_GATE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: run-vm6-chaos-execute.sh --scenario f1|c4 --db tidb|crdb|ybdb \
  --placement P-A|P-B --kill-target <ip> --gcp-host <ip> \
  --artifact-dir <dir> [options] [--dry-run]

See file header for full option list and design notes.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --scenario)          SCENARIO=$2; shift 2 ;;
    --db)                DB=$2; shift 2 ;;
    --placement)         PLACEMENT=$2; shift 2 ;;
    --kill-target)       KILL_TARGET=$2; shift 2 ;;
    --gcp-host)          GCP_HOST=$2; shift 2 ;;
    --gcp-port)          GCP_PORT=$2; shift 2 ;;
    --artifact-dir)      ARTIFACT_DIR=$2; shift 2 ;;
    --poll-window-sec)   POLL_WINDOW_SEC=$2; shift 2 ;;
    --poll-interval-sec) POLL_INTERVAL_SEC=$2; shift 2 ;;
    --post-settle-sec)   POST_SETTLE_SEC=$2; shift 2 ;;
    --pre-window-sec)    PRE_WINDOW_SEC=$2; shift 2 ;;
    --skip-chrony-gate)  SKIP_CHRONY_GATE=1; shift ;;
    --dry-run)           DRY_RUN=1; shift ;;
    -h|--help)           usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

[[ -z "$SCENARIO" || -z "$DB" || -z "$PLACEMENT" || -z "$KILL_TARGET" || -z "$ARTIFACT_DIR" ]] && usage
[[ "$SCENARIO" =~ ^(f1|c4)$ ]] || { echo "ERROR: --scenario must be f1|c4" >&2; exit 2; }
[[ "$DB" =~ ^(tidb|crdb|ybdb)$ ]] || { echo "ERROR: --db must be tidb|crdb|ybdb" >&2; exit 2; }
[[ "$PLACEMENT" =~ ^(P-A|P-B)$ ]] || { echo "ERROR: --placement must be P-A|P-B" >&2; exit 2; }

case "$DB" in
  tidb) GCP_PORT="${GCP_PORT:-4000}" ;;
  crdb) GCP_PORT="${GCP_PORT:-26257}" ;;
  ybdb) GCP_PORT="${GCP_PORT:-5433}" ;;
esac

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$ARTIFACT_DIR/db-config-snapshot/pre-kill" "$ARTIFACT_DIR/db-config-snapshot/post-handover"

log() { echo "[chaos-execute] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }

log "scenario=$SCENARIO db=$DB placement=$PLACEMENT kill_target=$KILL_TARGET gcp=$GCP_HOST:$GCP_PORT artifact_dir=$ARTIFACT_DIR dry_run=$DRY_RUN"

# ---- 0. Preconditions ----
if [[ "$SKIP_CHRONY_GATE" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
  log "running chrony/NTP gate (RTO-RPO-methodology.md §7.2)"
  bash "$SELF_DIR/gate-chrony-cross-region.sh" || { log "FATAL: chrony gate failed — aborting before any real chaos"; exit 1; }
fi

# ---- 1. Per-DB command templates (unchanged from run-vm6-failover-plan.sh / F1.md / C4.md) ----
# 2026-08-07 fix: F1.md's TiDB row specifies a graceful sequence — PD leader
# resign FIRST, then `systemctl stop tidb-server` — but this script
# previously only did the stop, making F1 and C4 issue identical commands.
# F1.md's literal command is `tiup ctl:<ver> pd -u http://<pd-host>:2379
# member leader resign`; tiup/pd-ctl are not installed anywhere in this
# environment (checked on .31 and .32), so this uses PD's documented HTTP
# API equivalent (POST /pd/api/v1/leader/resign) against $KILL_TARGET's own
# co-located pd-server (all 6 DB hosts run pd-server in this topology) —
# same resign semantics, no extra binary needed. RESIGN_CMD is empty for
# c4 (and for crdb/ybdb, whose F1.md rows use a DB-native drain/stepdown
# command instead of PD resign) so it's a strict no-op there.
RESIGN_CMD=""
case "$DB" in
  tidb)
    if [[ "$SCENARIO" == "f1" ]]; then
      RESIGN_CMD="curl -s -m 5 -X POST http://${KILL_TARGET}:2379/pd/api/v1/leader/resign"
    fi
    # 2026-08-07 fix: real unit is "tidb-4000.service" (confirmed via
    # `systemctl list-units` on 172.24.40.32), not "tidb-server" — the
    # original command silently failed every time ("Unit tidb-server.service
    # not loaded", kill_ssh_exit=5) and NEVER actually stopped the process,
    # making the first real F1 run's RTO/RPO entirely bogus (no incident
    # ever occurred). Port is fixed at 4000 for the SQL layer throughout
    # this topology (static host map), matching the tikv-20160 unit's own
    # fixed-port naming.
    KILL_CMD="ssh -o StrictHostKeyChecking=accept-new root@${KILL_TARGET} 'systemctl stop tidb-4000'"
    # 2026-08-07 fix: tikv_region_status has no store_id/is_leader columns in
    # this TiDB version (confirmed via DESC) — leader info lives in
    # tikv_region_peers (STORE_ID, IS_LEADER), joined back to
    # tikv_region_status only to filter by DB_NAME. The original query would
    # have errored on every pre-kill/poll/post-handover call.
    LEADER_QUERY="mysql -h ${GCP_HOST} -P ${GCP_PORT} -u root -N -B -e \"SELECT p.STORE_ID, count(*) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_region_status s ON p.REGION_ID = s.REGION_ID WHERE s.DB_NAME='tpcc' AND p.IS_LEADER=1 GROUP BY p.STORE_ID;\""
    ;;
  crdb)
    KILL_CMD="ssh -o StrictHostKeyChecking=accept-new root@${KILL_TARGET} 'cockroach quit --insecure --host=localhost:26257'"
    LEADER_QUERY="cockroach sql --insecure --host=${GCP_HOST}:${GCP_PORT} --format=tsv -e \"SELECT range_id, lease_holder FROM [SHOW RANGES FROM TABLE tpcc.warehouse] LIMIT 5;\""
    ;;
  ybdb)
    KILL_CMD="ssh -o StrictHostKeyChecking=accept-new root@${KILL_TARGET} 'yb-admin --master_addresses=${GCP_HOST}:7100 master_leader_stepdown; systemctl stop yb-master; systemctl stop yb-tserver'"
    LEADER_QUERY="yb-admin --master_addresses=${GCP_HOST}:7100 list_all_masters"
    ;;
esac

# ---- 2. Pre-kill snapshot ----
log "dumping pre-kill db-config-snapshot"
if [[ "$DRY_RUN" -eq 0 ]]; then
  eval "$LEADER_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/leader-query.txt" 2>&1 || \
    log "WARN: pre-kill leader query failed (non-fatal, recorded in file)"
else
  echo "[dry-run] would run: $LEADER_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/leader-query.txt"
fi

# ---- 3. S_pre — real TPCC row snapshot for RPO (SIMPLIFIED, see header) ----
S_PRE_FILE="$ARTIFACT_DIR/s_pre.txt"
case "$DB" in
  tidb) S_PRE_QUERY="mysql -h ${GCP_HOST} -P ${GCP_PORT} -u root -N -B tpcc -e \"SELECT o_w_id, MAX(o_id) FROM orders GROUP BY o_w_id;\"" ;;
  crdb) S_PRE_QUERY="cockroach sql --insecure --host=${GCP_HOST}:${GCP_PORT} -d tpcc --format=tsv -e \"SELECT o_w_id, MAX(o_id) FROM oorder GROUP BY o_w_id;\"" ;;
  ybdb) S_PRE_QUERY="psql \"host=${GCP_HOST} port=${GCP_PORT} user=yugabyte dbname=tpcc connect_timeout=5\" -At -c \"SELECT o_w_id, MAX(o_id) FROM oorder GROUP BY o_w_id;\"" ;;
esac

if [[ "$DRY_RUN" -eq 0 ]]; then
  log "capturing S_pre (pre-window ${PRE_WINDOW_SEC}s settle before snapshot)"
  sleep "$PRE_WINDOW_SEC"
  eval "$S_PRE_QUERY" > "$S_PRE_FILE" 2>&1 || { log "FATAL: S_pre capture failed — aborting, cannot measure RPO safely"; exit 1; }
else
  echo "[dry-run] would run: $S_PRE_QUERY" > "$S_PRE_FILE"
fi

# ---- 4. Start probe-rto-driver in background (GCP-side, per F1.md monitoring flow step 4) ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "starting probe-rto-driver.sh (background, GCP endpoint)"
  nohup bash "$SELF_DIR/probe-rto-driver.sh" --db "$DB" --artifact-dir "$ARTIFACT_DIR" \
    --host "$GCP_HOST" --port "$GCP_PORT" > "$ARTIFACT_DIR/probe-driver.log" 2>&1 &
  PROBE_PID=$!
  log "probe-rto-driver pid=$PROBE_PID"
  sleep 2  # let probe table setup complete before incident
else
  log "[dry-run] would start probe-rto-driver.sh in background"
fi

# ---- 5. Graceful pre-kill step (F1 only), THEN stamp t_incident, THEN kill ----
# 2026-08-07 fix: t_incident must be stamped immediately before the actual
# disruptive action (systemctl stop), not before the graceful resign step.
# Resign is a controlled, non-disruptive preparation — stamping t_incident
# ahead of it left a ~2.5s window (resign + its settle sleep) during which
# nothing had actually failed yet, but any probe 'ok' in that window still
# counted as "post-incident" under the ts > t_incident filter, producing a
# near-zero RTO that measured nothing real (confirmed on the first real F1
# run: RTO=53ms while the kill itself had actually failed silently — see
# the tidb-4000 unit-name fix above — so this ordering bug was masked by a
# separate bug, but would have produced a bogus artificially-low RTO even
# once the kill itself works correctly).
{
  echo "scenario=$SCENARIO db=$DB placement=$PLACEMENT kill_target=$KILL_TARGET"
  echo "resign_cmd=${RESIGN_CMD:-<none>}"
  echo "kill_cmd=$KILL_CMD"
} >> "$ARTIFACT_DIR/kill.log"

if [[ -n "$RESIGN_CMD" ]]; then
  if [[ "$DRY_RUN" -eq 0 ]]; then
    log "EXECUTING GRACEFUL PD LEADER RESIGN (F1 pre-kill step, BEFORE t_incident): $RESIGN_CMD"
    RESIGN_OUT=$(eval "$RESIGN_CMD" 2>&1) && RESIGN_EXIT=0 || RESIGN_EXIT=$?
    echo "resign_output=${RESIGN_OUT} resign_exit=${RESIGN_EXIT}" >> "$ARTIFACT_DIR/kill.log"
    [[ "$RESIGN_EXIT" -ne 0 ]] && log "WARN: PD leader resign returned non-zero (recorded, proceeding with kill regardless — resign is best-effort per F1.md, not a precondition for the kill step)"
    sleep 2  # let the PD leader re-election settle BEFORE the timed incident window starts
  else
    echo "[dry-run] would execute: $RESIGN_CMD (NOT executed)" >> "$ARTIFACT_DIR/kill.log"
    log "[dry-run] PD leader resign not executed"
  fi
fi

if [[ "$DRY_RUN" -eq 0 ]]; then
  bash "$SELF_DIR/wall-clock-wrapper.sh" --stamp-incident --artifact-dir "$ARTIFACT_DIR"
  echo "t_kill_start=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" >> "$ARTIFACT_DIR/kill.log"
  log "EXECUTING REAL KILL: $KILL_CMD"
  if eval "$KILL_CMD" >> "$ARTIFACT_DIR/kill.log" 2>&1; then
    echo "kill_ssh_exit=0" >> "$ARTIFACT_DIR/kill.log"
  else
    echo "kill_ssh_exit=$?" >> "$ARTIFACT_DIR/kill.log"
    log "WARN: kill command returned non-zero (recorded, may still have taken effect — e.g. cockroach quit / connection drop on stop)"
  fi
  # 2026-08-07: objective post-kill verification, independent of the ssh
  # exit code above — a wrong unit/process name can make systemctl fail
  # (caught) or, in principle, succeed without the process actually dying;
  # checking pgrep on the target directly is the only way to know for sure
  # the incident really happened (this caught the tidb-4000 unit-name bug).
  case "$DB" in
    tidb) PROC_PATTERN="tidb-server" ;;
    crdb) PROC_PATTERN="cockroach" ;;
    ybdb) PROC_PATTERN="yb-master|yb-tserver" ;;
  esac
  if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$KILL_TARGET" "pgrep -f '$PROC_PATTERN'" >> "$ARTIFACT_DIR/kill.log" 2>&1; then
    log "FATAL: post-kill verification shows the process is STILL RUNNING on $KILL_TARGET — kill did not take effect, aborting (no real incident occurred, refusing to report a fabricated RTO/RPO)"
    exit 1
  else
    echo "post_kill_verify=process_confirmed_down" >> "$ARTIFACT_DIR/kill.log"
    log "post-kill verification: process confirmed down on $KILL_TARGET"
  fi
else
  echo "[dry-run] would execute: $KILL_CMD (NOT executed)" >> "$ARTIFACT_DIR/kill.log"
  log "[dry-run] kill command not executed"
fi

# ---- 6. Poll leader-handover.log ----
LEADER_LOG="$ARTIFACT_DIR/leader-handover.log"
: > "$LEADER_LOG"
POLLS=$(( POLL_WINDOW_SEC / POLL_INTERVAL_SEC ))
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "polling leader for ${POLL_WINDOW_SEC}s (every ${POLL_INTERVAL_SEC}s)"
  for i in $(seq 1 "$POLLS"); do
    TS=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    OUT=$(eval "$LEADER_QUERY" 2>&1 | tr '\n' ';' || echo "query_failed")
    echo "${TS} poll=${i} ${OUT}" >> "$LEADER_LOG"
    sleep "$POLL_INTERVAL_SEC"
  done
else
  echo "[dry-run] would poll leader every ${POLL_INTERVAL_SEC}s for ${POLL_WINDOW_SEC}s" >> "$LEADER_LOG"
fi

# ---- 7. Stop probe, stamp t_first_ok, compute RTO ----
# 2026-08-07 fix: the old pre-check `grep -q '^[0-9]+ ok ' probe.txt` matches
# ANY 'ok' line in the whole file — including the pre-incident 'ok' lines
# written during probe-rto-driver's ~2s warm-up before the kill, which are
# always present regardless of whether the cluster ever actually recovered.
# That made this branch always take the "recovered" path even on a genuine
# unrecovered-within-window outcome. Now: always call stamp-first-ok (which
# itself only looks past t_incident, per the wall-clock-wrapper.sh fix
# above) and only trust its result as a real RTO if it reports
# source=probe — source=manual means it found no post-incident 'ok' at all
# and fell back to "now", which must NOT be treated as a measured RTO.
if [[ "$DRY_RUN" -eq 0 ]]; then
  touch "$ARTIFACT_DIR/.probe.stop"
  sleep 1
  bash "$SELF_DIR/wall-clock-wrapper.sh" --stamp-first-ok --artifact-dir "$ARTIFACT_DIR" --probe-file "$ARTIFACT_DIR/probe.txt"
  if grep -q '"source":"probe"' "$ARTIFACT_DIR/t_first_ok.txt" 2>/dev/null; then
    bash "$SELF_DIR/wall-clock-wrapper.sh" --compute-rto --artifact-dir "$ARTIFACT_DIR"
    RTO_JSON_OK=1
  else
    log "WARN: no post-incident 'ok' probe result found within poll window — RTO cannot be computed, marking as unrecovered-within-window"
    RTO_JSON_OK=0
  fi
else
  echo '{"dry_run":true}' > "$ARTIFACT_DIR/rto-wall-clock.json"
  RTO_JSON_OK=0
fi

# ---- 8. Post-settle wait, post-handover snapshot ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "post-settle wait ${POST_SETTLE_SEC}s before S_post capture (per methodology §4.2 Step B)"
  sleep "$POST_SETTLE_SEC"
  eval "$LEADER_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/post-handover/leader-query.txt" 2>&1 || \
    log "WARN: post-handover leader query failed (recorded)"
else
  echo "[dry-run] would run: $LEADER_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/post-handover/leader-query.txt"
fi

# ---- 9. S_post capture + RPO computation ----
S_POST_FILE="$ARTIFACT_DIR/s_post.txt"
if [[ "$DRY_RUN" -eq 0 ]]; then
  eval "$S_PRE_QUERY" > "$S_POST_FILE" 2>&1 || { log "WARN: S_post capture failed — RPO cannot be computed"; }
  if [[ -s "$S_POST_FILE" && -s "$S_PRE_FILE" ]]; then
    # rpo_lost_tx_count: warehouses whose max(o_id) DECREASED post-incident
    # (i.e. previously-committed high-water-mark no longer visible) — a
    # necessary (not sufficient) real-data check that S_pre rows survived.
    RPO_LOST=$(python3 - "$S_PRE_FILE" "$S_POST_FILE" <<'PYEOF'
import sys
def load(path):
    d = {}
    for line in open(path):
        parts = line.strip().split()
        if len(parts) == 2:
            try:
                d[parts[0]] = int(parts[1])
            except ValueError:
                pass
    return d
pre = load(sys.argv[1])
post = load(sys.argv[2])
lost = sum(1 for w, o in pre.items() if post.get(w, -1) < o)
print(lost)
PYEOF
)
  else
    RPO_LOST="null"
  fi
else
  echo "[dry-run] would run: $S_PRE_QUERY" > "$S_POST_FILE"
  RPO_LOST="null"
fi

# ---- 10. Assemble final rto-rpo.json (F1.md schema, §8.1: schema unchanged) ----
RTO_SEC="null"
if [[ "$RTO_JSON_OK" -eq 1 && -f "$ARTIFACT_DIR/rto-wall-clock.json" ]]; then
  RTO_SEC=$(python3 -c "import json; print(json.load(open('$ARTIFACT_DIR/rto-wall-clock.json'))['rto_sec'])" 2>/dev/null || echo "null")
fi
T_KILL=$(python3 -c "import json; print(json.load(open('$ARTIFACT_DIR/t_incident.txt'))['ts_rfc3339'])" 2>/dev/null || echo "null")
T_FIRST_OK="null"
[[ -f "$ARTIFACT_DIR/t_first_ok.txt" ]] && T_FIRST_OK=$(python3 -c "import json; print(json.load(open('$ARTIFACT_DIR/t_first_ok.txt'))['ts_rfc3339'])" 2>/dev/null || echo "null")

cat > "$ARTIFACT_DIR/rto-rpo.json" <<JSON
{
  "db_kind": "$DB",
  "scenario": "$SCENARIO",
  "placement": "$PLACEMENT",
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "rto_sec": $RTO_SEC,
  "rpo_lost_tx_count": $RPO_LOST,
  "rpo_method": "simplified: per-warehouse max(o_id) high-water-mark check, not full driver-hooked FIFO buffer (see script header)",
  "kill_target": "$KILL_TARGET",
  "graceful_resign_cmd": "${RESIGN_CMD:-null}",
  "kill_cmd": "$KILL_CMD",
  "t_kill": "$T_KILL",
  "t_first_write_gcp": "$T_FIRST_OK",
  "poll_window_sec": $POLL_WINDOW_SEC,
  "post_settle_sec": $POST_SETTLE_SEC,
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')"
}
JSON

log "done — artifact: $ARTIFACT_DIR/rto-rpo.json"
cat "$ARTIFACT_DIR/rto-rpo.json"
