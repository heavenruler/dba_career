#!/usr/bin/env bash
# run-vm6-g1-node-kill-execute.sh — Galera-specific chaos scenario G1: kill ONE
# node, region = idc|gcp (IDC 172.24.40.32/.33/.34, GCP 10.160.152.11/.12/.13).
#
# Why a new scenario instead of reusing F1/C4 (run-vm6-chaos-execute.sh):
# Galera is synchronous multi-master — every node is a symmetric writer, there
# is no leader to resign and no follower to compare against. F1/C4's entire
# design (--kill-role leader|follower, RESIGN_CMD, LEADER_QUERY against
# tikv_region_peers/lease_holder/yb-admin) is leader-dependent and does not
# translate. G1 keeps F1/C4's graceful-vs-ungraceful kill axis (still
# meaningful for Galera: a clean `systemctl stop mysql` tells the group
# immediately via a normal EVS leave message, vs SIGKILL requiring
# evs.suspect_timeout/evs.inactive_timeout to elapse before the group notices)
# but replaces the leader/follower axis with an IDC/GCP region axis (per
# GALERA-EXECUTION-PLAN.md Stage 5 idea #1).
#
# Reuses existing, already-built, DB-agnostic primitives unchanged:
#   probe-rto-driver.sh (galera branch added 2026-08-13) — independent probe loop
#   wall-clock-wrapper.sh    — t_incident / t_first_ok stamping + RTO calc
#   gate-chrony-cross-region.sh — NTP/chrony precondition (no --db arg, host-list based)
#
# RTO/RPO definitions unchanged from RTO-RPO-methodology.md (§1.1/§1.2) — the
# formulas themselves are generic ("first successful write after incident");
# only the per-DB queries feeding them differ, and here there is only one DB.
#
# Usage:
#   bash run-vm6-g1-node-kill-execute.sh \
#     --node-region idc|gcp --kill-mode graceful|crash \
#     --kill-target <ip> --query-endpoint <ip> [--query-port 3306] \
#     --artifact-dir <dir> [--poll-window-sec 60] [--poll-interval-sec 5] \
#     [--post-settle-sec 30] [--pre-window-sec 5] [--skip-chrony-gate] [--dry-run]
#
# --node-region: label only (idc|gcp) — records which region the killed node
#   belongs to; does not change kill mechanics (Galera treats all nodes
#   symmetrically — this is purely so results can be grouped by region).
# --kill-mode: graceful (systemctl stop mysql — normal EVS leave) or crash
#   (pkill -9 mysqld — group must time out evs.inactive_timeout to notice).
# --kill-target: the node IP to kill.
# --query-endpoint: a DIFFERENT, surviving node IP to run S_pre/S_post/
#   membership queries against (must not equal --kill-target).
#
# Env required: GALERA_BENCH_PASSWORD (tpcc_bench password; never passed via
# CLI arg — read from env only, matching this repo's established secret
# handling discipline).
#
# --dry-run: full orchestration logic, skips the actual ssh kill and DB writes.

set -euo pipefail

NODE_REGION=""
KILL_MODE=""
KILL_TARGET=""
QUERY_ENDPOINT=""
QUERY_PORT=3306
ARTIFACT_DIR=""
POLL_WINDOW_SEC=60
POLL_INTERVAL_SEC=5
POST_SETTLE_SEC=30
PRE_WINDOW_SEC=5
SKIP_CHRONY_GATE=0
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: run-vm6-g1-node-kill-execute.sh --node-region idc|gcp \
  --kill-mode graceful|crash --kill-target <ip> --query-endpoint <ip> \
  --artifact-dir <dir> [options] [--dry-run]

See file header for full design notes.
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --node-region)        NODE_REGION=$2; shift 2 ;;
    --kill-mode)          KILL_MODE=$2; shift 2 ;;
    --kill-target)        KILL_TARGET=$2; shift 2 ;;
    --query-endpoint)     QUERY_ENDPOINT=$2; shift 2 ;;
    --query-port)         QUERY_PORT=$2; shift 2 ;;
    --artifact-dir)       ARTIFACT_DIR=$2; shift 2 ;;
    --poll-window-sec)    POLL_WINDOW_SEC=$2; shift 2 ;;
    --poll-interval-sec)  POLL_INTERVAL_SEC=$2; shift 2 ;;
    --post-settle-sec)    POST_SETTLE_SEC=$2; shift 2 ;;
    --pre-window-sec)     PRE_WINDOW_SEC=$2; shift 2 ;;
    --skip-chrony-gate)   SKIP_CHRONY_GATE=1; shift ;;
    --dry-run)            DRY_RUN=1; shift ;;
    -h|--help)            usage ;;
    *) echo "ERROR: unknown arg: $1" >&2; usage ;;
  esac
done

[[ -z "$NODE_REGION" || -z "$KILL_MODE" || -z "$KILL_TARGET" || -z "$QUERY_ENDPOINT" || -z "$ARTIFACT_DIR" ]] && usage
[[ "$NODE_REGION" =~ ^(idc|gcp)$ ]] || { echo "ERROR: --node-region must be idc|gcp" >&2; exit 2; }
[[ "$KILL_MODE" =~ ^(graceful|crash)$ ]] || { echo "ERROR: --kill-mode must be graceful|crash" >&2; exit 2; }
[[ "$KILL_TARGET" != "$QUERY_ENDPOINT" ]] || { echo "ERROR: --query-endpoint must be a different (surviving) node from --kill-target" >&2; exit 2; }
: "${GALERA_BENCH_PASSWORD:?missing GALERA_BENCH_PASSWORD}"

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$ARTIFACT_DIR/db-config-snapshot/pre-kill" "$ARTIFACT_DIR/db-config-snapshot/post-handover"

log() { echo "[g1-node-kill] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }

log "node_region=$NODE_REGION kill_mode=$KILL_MODE kill_target=$KILL_TARGET query_endpoint=$QUERY_ENDPOINT:$QUERY_PORT artifact_dir=$ARTIFACT_DIR dry_run=$DRY_RUN"

# ---- 0. Preconditions ----
if [[ "$SKIP_CHRONY_GATE" -eq 0 && "$DRY_RUN" -eq 0 ]]; then
  log "running chrony/NTP gate"
  bash "$SELF_DIR/gate-chrony-cross-region.sh" || { log "FATAL: chrony gate failed — aborting before any real chaos"; exit 1; }
fi

MYSQL_Q() {  # MYSQL_Q <host> <sql>  — 用 tpcc_bench，密碼只走 env，不進 argv
  MYSQL_PWD="$GALERA_BENCH_PASSWORD" mysql -h "$1" -P "$QUERY_PORT" -u tpcc_bench -N -B -e "$2"
}

case "$KILL_MODE" in
  graceful) KILL_CMD="ssh -o StrictHostKeyChecking=accept-new root@${KILL_TARGET} 'systemctl stop mysql'" ;;
  crash)    KILL_CMD="ssh -o StrictHostKeyChecking=accept-new root@${KILL_TARGET} 'pkill -9 -x mysqld'" ;;
esac

MEMBERSHIP_QUERY="MYSQL_PWD='${GALERA_BENCH_PASSWORD}' mysql -h ${QUERY_ENDPOINT} -P ${QUERY_PORT} -u tpcc_bench -N -B -e \"SHOW STATUS LIKE 'wsrep_cluster_size'; SHOW STATUS LIKE 'wsrep_cluster_status'; SHOW STATUS LIKE 'wsrep_local_state_comment'; SHOW STATUS LIKE 'wsrep_ready';\""
S_QUERY="MYSQL_PWD='${GALERA_BENCH_PASSWORD}' mysql -h ${QUERY_ENDPOINT} -P ${QUERY_PORT} -u tpcc_bench -N -B tpcc -e \"SELECT o_w_id, MAX(o_id) FROM orders GROUP BY o_w_id;\""

# ---- 1. Pre-kill snapshot ----
log "dumping pre-kill membership snapshot"
if [[ "$DRY_RUN" -eq 0 ]]; then
  eval "$MEMBERSHIP_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/membership-query.txt" 2>&1 || \
    log "WARN: pre-kill membership query failed (non-fatal, recorded in file)"
else
  echo "[dry-run] would run: $MEMBERSHIP_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/pre-kill/membership-query.txt"
fi

# ---- 2. S_pre — real TPCC row snapshot for RPO ----
S_PRE_FILE="$ARTIFACT_DIR/s_pre.txt"
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "capturing S_pre (pre-window ${PRE_WINDOW_SEC}s settle before snapshot)"
  sleep "$PRE_WINDOW_SEC"
  eval "$S_QUERY" > "$S_PRE_FILE" 2>&1 || { log "FATAL: S_pre capture failed — aborting, cannot measure RPO safely"; exit 1; }
else
  echo "[dry-run] would run: $S_QUERY" > "$S_PRE_FILE"
fi

# ---- 3. Start probe-rto-driver in background (surviving query-endpoint) ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "starting probe-rto-driver.sh (background, query-endpoint)"
  # PROBE_USER/PROBE_PASS 用 bash 原生 VAR=value 前綴（不是 `env VAR=value`）
  # 傳給 nohup 的子行程——`env` 指令本身的 argv 會把值印進 ps aux，這種前綴
  # 寫法不會（值只進 nohup/probe-rto-driver.sh 行程的環境變數，不進 argv）。
  PROBE_USER=tpcc_bench PROBE_PASS="$GALERA_BENCH_PASSWORD" \
    nohup bash "$SELF_DIR/probe-rto-driver.sh" --db galera --artifact-dir "$ARTIFACT_DIR" \
    --host "$QUERY_ENDPOINT" --port "$QUERY_PORT" > "$ARTIFACT_DIR/probe-driver.log" 2>&1 &
  PROBE_PID=$!
  log "probe-rto-driver pid=$PROBE_PID"
  sleep 2
else
  log "[dry-run] would start probe-rto-driver.sh in background"
fi

# ---- 4. Stamp t_incident, THEN kill ----
{
  echo "node_region=$NODE_REGION kill_mode=$KILL_MODE kill_target=$KILL_TARGET"
  echo "kill_cmd=$KILL_CMD"
} >> "$ARTIFACT_DIR/kill.log"

if [[ "$DRY_RUN" -eq 0 ]]; then
  bash "$SELF_DIR/wall-clock-wrapper.sh" --stamp-incident --artifact-dir "$ARTIFACT_DIR"
  echo "t_kill_start=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')" >> "$ARTIFACT_DIR/kill.log"
  log "EXECUTING REAL KILL ($KILL_MODE): $KILL_CMD"
  if eval "$KILL_CMD" >> "$ARTIFACT_DIR/kill.log" 2>&1; then
    echo "kill_ssh_exit=0" >> "$ARTIFACT_DIR/kill.log"
  else
    echo "kill_ssh_exit=$?" >> "$ARTIFACT_DIR/kill.log"
    log "WARN: kill command returned non-zero (recorded, may still have taken effect)"
  fi
  STILL_RUNNING=1
  for _ in 1 2 3 4 5; do
    if ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 root@"$KILL_TARGET" "pgrep -x mysqld" >> "$ARTIFACT_DIR/kill.log" 2>&1; then
      sleep 1
    else
      STILL_RUNNING=0
      break
    fi
  done
  if [[ "$STILL_RUNNING" -eq 1 ]]; then
    log "FATAL: post-kill verification shows mysqld STILL RUNNING on $KILL_TARGET after 5s of retries — kill did not take effect, aborting (refusing to report a fabricated RTO/RPO)"
    exit 1
  else
    echo "post_kill_verify=process_confirmed_down" >> "$ARTIFACT_DIR/kill.log"
    log "post-kill verification: mysqld confirmed down on $KILL_TARGET"
  fi
else
  echo "[dry-run] would execute: $KILL_CMD (NOT executed)" >> "$ARTIFACT_DIR/kill.log"
  log "[dry-run] kill command not executed"
fi

# ---- 5. Poll membership ----
MEMBERSHIP_LOG="$ARTIFACT_DIR/membership-poll.log"
: > "$MEMBERSHIP_LOG"
POLLS=$(( POLL_WINDOW_SEC / POLL_INTERVAL_SEC ))
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "polling membership for ${POLL_WINDOW_SEC}s (every ${POLL_INTERVAL_SEC}s)"
  for i in $(seq 1 "$POLLS"); do
    TS=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
    OUT=$(eval "$MEMBERSHIP_QUERY" 2>&1 | tr '\n' ';' || echo "query_failed")
    echo "${TS} poll=${i} ${OUT}" >> "$MEMBERSHIP_LOG"
    sleep "$POLL_INTERVAL_SEC"
  done
else
  echo "[dry-run] would poll membership every ${POLL_INTERVAL_SEC}s for ${POLL_WINDOW_SEC}s" >> "$MEMBERSHIP_LOG"
fi

# ---- 6. Stop probe, stamp t_first_ok, compute RTO ----
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

# ---- 7. Post-settle wait, post-handover snapshot ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  log "post-settle wait ${POST_SETTLE_SEC}s before S_post capture"
  sleep "$POST_SETTLE_SEC"
  eval "$MEMBERSHIP_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/post-handover/membership-query.txt" 2>&1 || \
    log "WARN: post-handover membership query failed (recorded)"
else
  echo "[dry-run] would run: $MEMBERSHIP_QUERY" > "$ARTIFACT_DIR/db-config-snapshot/post-handover/membership-query.txt"
fi

# ---- 8. S_post capture + RPO computation ----
S_POST_FILE="$ARTIFACT_DIR/s_post.txt"
if [[ "$DRY_RUN" -eq 0 ]]; then
  eval "$S_QUERY" > "$S_POST_FILE" 2>&1 || { log "WARN: S_post capture failed — RPO cannot be computed"; }
  if [[ -s "$S_POST_FILE" && -s "$S_PRE_FILE" ]]; then
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
  echo "[dry-run] would run: $S_QUERY" > "$S_POST_FILE"
  RPO_LOST="null"
fi

# ---- 9. Assemble final rto-rpo.json ----
RTO_SEC="null"
if [[ "$RTO_JSON_OK" -eq 1 && -f "$ARTIFACT_DIR/rto-wall-clock.json" ]]; then
  RTO_SEC=$(python3 -c "import json; print(json.load(open('$ARTIFACT_DIR/rto-wall-clock.json'))['rto_sec'])" 2>/dev/null || echo "null")
fi
T_KILL=$(python3 -c "import json; print(json.load(open('$ARTIFACT_DIR/t_incident.txt'))['ts_rfc3339'])" 2>/dev/null || echo "null")
T_FIRST_OK="null"
[[ -f "$ARTIFACT_DIR/t_first_ok.txt" ]] && T_FIRST_OK=$(python3 -c "import json; print(json.load(open('$ARTIFACT_DIR/t_first_ok.txt'))['ts_rfc3339'])" 2>/dev/null || echo "null")

cat > "$ARTIFACT_DIR/rto-rpo.json" <<JSON
{
  "db_kind": "galera",
  "scenario": "g1-node-kill",
  "node_region": "$NODE_REGION",
  "kill_mode": "$KILL_MODE",
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "rto_sec": $RTO_SEC,
  "rpo_lost_tx_count": $RPO_LOST,
  "rpo_method": "simplified: per-warehouse max(o_id) high-water-mark check, not full driver-hooked FIFO buffer",
  "kill_target": "$KILL_TARGET",
  "query_endpoint": "$QUERY_ENDPOINT",
  "kill_cmd": "$KILL_CMD",
  "t_kill": "$T_KILL",
  "t_first_write": "$T_FIRST_OK",
  "poll_window_sec": $POLL_WINDOW_SEC,
  "post_settle_sec": $POST_SETTLE_SEC,
  "generated_at": "$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')"
}
JSON

log "done — artifact: $ARTIFACT_DIR/rto-rpo.json"
cat "$ARTIFACT_DIR/rto-rpo.json"
