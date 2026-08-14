#!/usr/bin/env bash
# run-vm6-g3-dualwrite-conflict-execute.sh — Galera-specific chaos scenario
# G3: dual-write conflict storm (P-B×A-A only).
#
# Why this has no equivalent in the TiDB/CRDB/YBDB framework: those three use
# either a single leader (TiDB/YBDB, writes serialize through one Raft
# leader — no cross-node write-write conflict is possible by construction)
# or pessimistic locking (CockroachDB defaults) — none of them can produce
# this failure mode. Galera's synchronous multi-master certification is
# unique among the four DBs in this PoC, so this scenario has no reusable
# skeleton to adapt from; it is genuinely new.
#
# Purpose: close the gap repeatedly flagged in DISTRIBUTED-DB-SCORING.md
# §3.2.2/§3.2.3/§3.6 — every prior wsrep_local_cert_failures/bf_aborts number
# was a single post-run snapshot, never a before/after delta tied to a
# specific injection window. This script captures both.
#
# Method: concurrently hammer a SMALL set of hot warehouse rows from BOTH
# the IDC side (local, this script runs on .31) and the GCP side (via ssh to
# the GCP client host) for a short fixed duration — maximizing the chance
# that writesets from both regions certify against each other on the same
# rows. Captures per-node wsrep counters immediately before and after.
#
# Usage:
#   bash run-vm6-g3-dualwrite-conflict-execute.sh \
#     --idc-db-host <ip> --gcp-db-host <ip> --gcp-client-ssh <user@host> \
#     [--gcp-client-port 22] [--hot-warehouse-count 2] [--duration-sec 30] \
#     --artifact-dir <dir> [--dry-run]
#
# Env required: GALERA_BENCH_PASSWORD.
#
# This scenario is inherently non-destructive to cluster membership (no
# node is killed) — safe to run before or after G1/G2/G4/G5, but per-run
# `w_ytd`/`w_id` sentinel state should be cleaned up regardless (idempotent,
# handled below).

set -uo pipefail

IDC_DB_HOST=""
GCP_DB_HOST=""
GCP_CLIENT_SSH=""
GCP_CLIENT_PORT=22
HOT_WAREHOUSE_COUNT=2
DURATION_SEC=30
ARTIFACT_DIR=""
DRY_RUN=0
# 6 節點固定清單（跨區 vm-6node topology 既有慣例）
ALL_NODES="idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13"

usage() {
  cat <<'EOF'
Usage: run-vm6-g3-dualwrite-conflict-execute.sh --idc-db-host <ip> \
  --gcp-db-host <ip> --gcp-client-ssh <user@host> --artifact-dir <dir> \
  [--gcp-client-port N] [--hot-warehouse-count N] [--duration-sec N] [--dry-run]
EOF
  exit 2
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --idc-db-host)        IDC_DB_HOST=$2; shift 2 ;;
    --gcp-db-host)        GCP_DB_HOST=$2; shift 2 ;;
    --gcp-client-ssh)     GCP_CLIENT_SSH=$2; shift 2 ;;
    --gcp-client-port)    GCP_CLIENT_PORT=$2; shift 2 ;;
    --hot-warehouse-count) HOT_WAREHOUSE_COUNT=$2; shift 2 ;;
    --duration-sec)       DURATION_SEC=$2; shift 2 ;;
    --artifact-dir)       ARTIFACT_DIR=$2; shift 2 ;;
    --dry-run)            DRY_RUN=1; shift ;;
    -h|--help)            usage ;;
    *) echo "unknown arg: $1" >&2; usage ;;
  esac
done
[[ -z "$IDC_DB_HOST" || -z "$GCP_DB_HOST" || -z "$GCP_CLIENT_SSH" || -z "$ARTIFACT_DIR" ]] && usage
: "${GALERA_BENCH_PASSWORD:?missing GALERA_BENCH_PASSWORD}"

mkdir -p "$ARTIFACT_DIR/wsrep-snapshot"
log() { echo "[g3-dualwrite-conflict] $(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ') $*"; }

log "idc_db_host=$IDC_DB_HOST gcp_db_host=$GCP_DB_HOST gcp_client=$GCP_CLIENT_SSH:$GCP_CLIENT_PORT hot_warehouses=$HOT_WAREHOUSE_COUNT duration=${DURATION_SEC}s dry_run=$DRY_RUN"

wsrep_snapshot() {  # wsrep_snapshot <label>
  local label=$1 outdir="$ARTIFACT_DIR/wsrep-snapshot"
  {
    for entry in $ALL_NODES; do
      local ip=${entry#*@}
      echo "=== $entry ==="
      ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "root@$ip" \
        "MYSQL_PWD='$GALERA_BENCH_PASSWORD' mysql -utpcc_bench -N -B -e \"SHOW STATUS LIKE 'wsrep_local_cert_failures'; SHOW STATUS LIKE 'wsrep_local_bf_aborts'; SHOW STATUS LIKE 'wsrep_local_commits'; SHOW STATUS LIKE 'wsrep_flow_control_paused';\""
    done
  } > "$outdir/wsrep-status-${label}.txt" 2>&1
}

# ---- 0. 清乾淨可能殘留的 sentinel 狀態（idempotent，不影響其他 warehouse） ----
CLEAR_SQL=""
for ((w=1; w<=HOT_WAREHOUSE_COUNT; w++)); do
  CLEAR_SQL+="UPDATE warehouse SET w_ytd=0 WHERE w_id=${w};"
done
if [[ "$DRY_RUN" -eq 0 ]]; then
  MYSQL_PWD="$GALERA_BENCH_PASSWORD" mysql -h "$IDC_DB_HOST" -P 3306 -u tpcc_bench tpcc -e "$CLEAR_SQL" 2>/dev/null || true
fi

# ---- 1. before snapshot ----
log "capturing wsrep before-snapshot (6 nodes)"
if [[ "$DRY_RUN" -eq 0 ]]; then
  wsrep_snapshot "before"
else
  echo "[dry-run] would snapshot 6 nodes' wsrep status" > "$ARTIFACT_DIR/wsrep-snapshot/wsrep-status-before.txt"
fi

# ---- 2. concurrent hot-row hammer, IDC + GCP simultaneously ----
IDC_COUNT_FILE="$ARTIFACT_DIR/idc-injector-counts.txt"
GCP_COUNT_FILE="$ARTIFACT_DIR/gcp-injector-counts.txt"

idc_injector() {
  local ok=0 err=0 t_end=$(( $(date +%s) + DURATION_SEC ))
  while [[ $(date +%s) -lt $t_end ]]; do
    local w=$(( (RANDOM % HOT_WAREHOUSE_COUNT) + 1 ))
    if MYSQL_PWD="$GALERA_BENCH_PASSWORD" mysql -h "$IDC_DB_HOST" -P 3306 -u tpcc_bench tpcc \
        -e "UPDATE warehouse SET w_ytd=w_ytd+1 WHERE w_id=$w" >/dev/null 2>>"$ARTIFACT_DIR/idc-injector-errors.log"; then
      ok=$((ok+1))
    else
      err=$((err+1))
    fi
  done
  echo "ok=$ok err=$err" > "$IDC_COUNT_FILE"
}

log "starting concurrent IDC+GCP hot-row hammer for ${DURATION_SEC}s (w_id=1..$HOT_WAREHOUSE_COUNT)"
if [[ "$DRY_RUN" -eq 0 ]]; then
  T_INJECT_START=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
  idc_injector &
  IDC_PID=$!
  # 密碼不透過 ssh argv 傳遞（會落在本機 ps aux）；GCP client host 上須已有
  # /root/.galera-secrets.env（比照 .31 的既有安全模式，部署時一併放置）。
  ssh -o ConnectTimeout=5 -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" \
    "GCP_DB_HOST='$GCP_DB_HOST' HOT_WAREHOUSE_COUNT='$HOT_WAREHOUSE_COUNT' DURATION_SEC='$DURATION_SEC' bash -s" \
    > "$GCP_COUNT_FILE" 2>"$ARTIFACT_DIR/gcp-injector-errors.log" <<'REMOTE' &
    source /root/.galera-secrets.env
    ok=0; err=0; t_end=$(( $(date +%s) + DURATION_SEC ))
    while [[ $(date +%s) -lt $t_end ]]; do
      w=$(( (RANDOM % HOT_WAREHOUSE_COUNT) + 1 ))
      if MYSQL_PWD="$GALERA_BENCH_PASSWORD" mysql -h "$GCP_DB_HOST" -P 3306 -u tpcc_bench tpcc \
          -e "UPDATE warehouse SET w_ytd=w_ytd+1 WHERE w_id=$w" >/dev/null 2>&1; then
        ok=$((ok+1))
      else
        err=$((err+1))
      fi
    done
    echo "ok=$ok err=$err"
REMOTE
  GCP_PID=$!
  wait "$IDC_PID" "$GCP_PID"
  T_INJECT_END=$(date -u '+%Y-%m-%dT%H:%M:%S.%3NZ')
else
  echo "[dry-run] would run ${DURATION_SEC}s concurrent hammer" > "$IDC_COUNT_FILE"
  echo "[dry-run] would run ${DURATION_SEC}s concurrent hammer" > "$GCP_COUNT_FILE"
  T_INJECT_START="null"; T_INJECT_END="null"
fi

# ---- 3. after snapshot ----
log "capturing wsrep after-snapshot (6 nodes)"
if [[ "$DRY_RUN" -eq 0 ]]; then
  wsrep_snapshot "after"
else
  echo "[dry-run] would snapshot 6 nodes' wsrep status" > "$ARTIFACT_DIR/wsrep-snapshot/wsrep-status-after.txt"
fi

# ---- 4. cleanup sentinel state ----
if [[ "$DRY_RUN" -eq 0 ]]; then
  MYSQL_PWD="$GALERA_BENCH_PASSWORD" mysql -h "$IDC_DB_HOST" -P 3306 -u tpcc_bench tpcc -e "$CLEAR_SQL" 2>/dev/null || true
fi

# ---- 5. compute per-node deltas + assemble JSON ----
python3 - "$ARTIFACT_DIR/wsrep-snapshot/wsrep-status-before.txt" "$ARTIFACT_DIR/wsrep-snapshot/wsrep-status-after.txt" > "$ARTIFACT_DIR/wsrep-delta.json" <<'PYEOF'
import sys, json, re

def parse(path):
    nodes = {}
    cur = None
    for line in open(path):
        m = re.match(r'=== (\S+) ===', line)
        if m:
            cur = m.group(1)
            nodes[cur] = {}
            continue
        parts = line.strip().split()
        if cur and len(parts) == 2:
            nodes[cur][parts[0]] = parts[1]
    return nodes

before = parse(sys.argv[1])
after = parse(sys.argv[2])
metrics = ["wsrep_local_cert_failures", "wsrep_local_bf_aborts", "wsrep_local_commits"]
result = {}
totals = {m: 0 for m in metrics}
for node in before:
    node_delta = {}
    for m in metrics:
        try:
            b = int(before.get(node, {}).get(m, 0))
            a = int(after.get(node, {}).get(m, 0))
            d = a - b
        except (ValueError, TypeError):
            d = None
        node_delta[m] = d
        if isinstance(d, int):
            totals[m] += d
    node_delta["wsrep_flow_control_paused_after"] = after.get(node, {}).get("wsrep_flow_control_paused")
    result[node] = node_delta
print(json.dumps({"per_node_delta": result, "cluster_total_delta": totals}, indent=2))
PYEOF

IDC_RESULT=$(cat "$IDC_COUNT_FILE" 2>/dev/null || echo "ok=null err=null")
GCP_RESULT=$(cat "$GCP_COUNT_FILE" 2>/dev/null || echo "ok=null err=null")

cat > "$ARTIFACT_DIR/g3-summary.json" <<JSON
{
  "scenario": "g3-dualwrite-conflict",
  "db_kind": "galera",
  "dry_run": $([ "$DRY_RUN" -eq 1 ] && echo true || echo false),
  "hot_warehouse_count": $HOT_WAREHOUSE_COUNT,
  "duration_sec": $DURATION_SEC,
  "t_inject_start": "$T_INJECT_START",
  "t_inject_end": "$T_INJECT_END",
  "idc_injector_result": "$IDC_RESULT",
  "gcp_injector_result": "$GCP_RESULT",
  "wsrep_delta_file": "wsrep-delta.json",
  "note": "wsrep counter delta is per-node before/after this injection window specifically (not a post-run single-point snapshot spanning the whole suite, unlike prior §3.2/§3.6 measurements)"
}
JSON
log "done — artifacts: $ARTIFACT_DIR/g3-summary.json + wsrep-delta.json"
cat "$ARTIFACT_DIR/g3-summary.json"
