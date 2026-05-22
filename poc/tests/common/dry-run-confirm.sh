#!/usr/bin/env bash
# Dry-run confirm gate for vm-3node (deploy 後、prepare 前的人工 review anchor).
#
# Per PoC-DESIGN §6.3.2.3: deploy 完 cluster topology / RF / iso preset / health
# 全部 dump 出來，由人工 review 後加 EXECUTE=1 才放行進 prepare。
#
# Usage (runs on the TPC-C client / .31):
#   dry-run-confirm.sh --db <tidb|crdb|ybdb> --sub-topology <1s1r|1s3r|3s1r|3s3r> \
#                      --iso <rc|rr|strict>  --db-host <ip> --ts <timestamp>
#
# Env (Makefile-provided):
#   TPCC_ARTIFACTS (default /tmp/poc-tpcc/artifacts)
#   TIDB/CRDB/YBDB_HOST/PORT/USER  (Makefile passes these)
#
# Exit codes:
#   0 — all checks passed; .dry-run.done written with all_pass=true
#   1 — any check failed; .dry-run.done written with all_pass=false
#
# This script does NOT honor EXECUTE=1; that is enforced by the Makefile gate
# (which decides whether to run prepare phase after this script exits 0).

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" SUB="" ISO="" DB_HOST="" TS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)             DB=$2; shift 2 ;;
    --sub-topology)   SUB=$2; shift 2 ;;
    --iso)            ISO=$2; shift 2 ;;
    --db-host)        DB_HOST=$2; shift 2 ;;
    --ts)             TS=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB" && -n "$SUB" && -n "$ISO" && -n "$DB_HOST" && -n "$TS" ]] || die "missing required args"

case "$SUB" in 1s1r|1s3r|3s1r|3s3r) ;; *) die "invalid sub-topology: $SUB" ;; esac
case "$DB"  in tidb|crdb|ybdb)      ;; *) die "invalid db: $DB" ;; esac

# Expected RF derived from sub-topology suffix:
case "$SUB" in
  1s1r|3s1r) EXPECTED_RF=1 ;;
  1s3r|3s3r) EXPECTED_RF=3 ;;
esac

TOPOLOGY="vm-3node-$SUB"
: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts}"
ROOT=$(artifact_dir "$DB" "$TOPOLOGY" "$ISO" "$TS")
mkdir -p "$ROOT/dry-run"
flock_phase "$ROOT" "dry-run"

DRY="$ROOT/dry-run"
ALL_PASS=true
FAILS=()

info "dry-run-confirm root: $ROOT  (sub=$SUB rf=$EXPECTED_RF iso=$ISO db-host=$DB_HOST)"

remote() {
  ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=5 "root@$DB_HOST" "$@"
}

# --- 1. cluster topology dump ------------------------------------------------
case "$DB" in
  tidb)
    require_cmd mysql
    remote 'PATH=$PATH:/root/.tiup/bin /root/.tiup/bin/tiup cluster display tpcc-tidb-vm3 2>&1' \
      > "$DRY/cluster-topology.txt" || true
    ;;
  crdb)
    require_cmd psql
    remote '/usr/local/bin/cockroach node status --insecure --host=127.0.0.1:26257 --format=tsv 2>&1' \
      > "$DRY/cluster-topology.txt" || true
    ;;
  ybdb)
    require_cmd ysqlsh
    remote '/opt/yugabyte/bin/yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 list_all_tablet_servers 2>&1' \
      > "$DRY/cluster-topology.txt" || true
    ;;
esac

NODE_COUNT=$(grep -cE '(Up|172\.24\.40\.(32|33|34))' "$DRY/cluster-topology.txt" 2>/dev/null || echo 0)
if [[ "${NODE_COUNT:-0}" -lt 3 ]]; then
  warn "cluster topology shows < 3 nodes (node_count=$NODE_COUNT)"
  ALL_PASS=false
  FAILS+=("topology-nodes<3")
fi

# --- 2. replication-factor dump ---------------------------------------------
case "$DB" in
  tidb)
    PORT="${TIDB_PORT:-4000}"; USER="${TIDB_USER:-root}"
    mysql -h "$DB_HOST" -P "$PORT" -u "$USER" -B -N -e \
      "SELECT VALUE FROM information_schema.CLUSTER_CONFIG WHERE TYPE='pd' AND \`KEY\`='replication.max-replicas' LIMIT 1" \
      > "$DRY/replication-factor.txt" 2>&1 || true
    ACTUAL_RF=$(tr -d ' \n\r' < "$DRY/replication-factor.txt" 2>/dev/null || echo "?")
    ;;
  crdb)
    PORT="${CRDB_PORT:-26257}"; USER="${CRDB_USER:-root}"
    remote "/usr/local/bin/cockroach sql --insecure --host=127.0.0.1:26257 --format=tsv -e \"SHOW ZONE CONFIGURATION FROM RANGE default\"" \
      > "$DRY/replication-factor.txt" 2>&1 || true
    ACTUAL_RF=$(grep -oE 'num_replicas = [0-9]+' "$DRY/replication-factor.txt" 2>/dev/null | awk '{print $NF}' | head -1)
    ACTUAL_RF=${ACTUAL_RF:-?}
    ;;
  ybdb)
    remote '/opt/yugabyte/bin/yb-admin --master_addresses=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100 get_universe_config 2>&1' \
      > "$DRY/replication-factor.txt" || true
    ACTUAL_RF=$(grep -oE '"replication_factor"\s*:\s*[0-9]+|num_replicas\s*:\s*[0-9]+' "$DRY/replication-factor.txt" 2>/dev/null | grep -oE '[0-9]+' | head -1)
    ACTUAL_RF=${ACTUAL_RF:-?}
    ;;
esac

if [[ "$ACTUAL_RF" != "$EXPECTED_RF" ]]; then
  warn "RF mismatch (expected=$EXPECTED_RF actual=$ACTUAL_RF)"
  ALL_PASS=false
  FAILS+=("rf-mismatch:expected=$EXPECTED_RF/actual=$ACTUAL_RF")
fi

# --- 3. cluster-health probe -------------------------------------------------
case "$DB" in
  tidb)
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" \
      -e "SELECT 1 AS health" > "$DRY/cluster-health.txt" 2>&1 || ALL_PASS=false
    ;;
  crdb)
    /usr/local/bin/cockroach sql --insecure --host="$DB_HOST":"${CRDB_PORT:-26257}" -e "SELECT 1 AS health" \
      > "$DRY/cluster-health.txt" 2>&1 || ALL_PASS=false
    ;;
  ybdb)
    ysqlsh -h "$DB_HOST" -p "${YBDB_PORT:-5433}" -U "${YBDB_USER:-yugabyte}" -d yugabyte \
      -c "SELECT 1 AS health" > "$DRY/cluster-health.txt" 2>&1 || ALL_PASS=false
    ;;
esac
grep -qE '^(1|health|---|[[:space:]]*1[[:space:]]*$)' "$DRY/cluster-health.txt" 2>/dev/null \
  || { ALL_PASS=false; FAILS+=("cluster-health-no-row"); }

# --- 4. iso preset probe (against default DB, since tpcc not created yet) ----
# Use the same conn-params + transaction-isolation expectation as gate-isolation.sh,
# but connect to default DB (mysql / defaultdb / yugabyte) since prepare hasn't run.
ISO_CONN_PARAMS=$(get_conn_params "$DB" "$ISO")
EXPECTED_ISO=$(expected_iso "$DB" "$ISO")
case "$DB" in
  tidb)
    if [[ "$ISO" == "rc" ]]; then tidb_iso="READ-COMMITTED"; else tidb_iso="REPEATABLE-READ"; fi
    mysql -h "$DB_HOST" -P "${TIDB_PORT:-4000}" -u "${TIDB_USER:-root}" \
      -e "SET SESSION transaction_isolation='${tidb_iso}'; SET SESSION tidb_txn_mode='pessimistic'; BEGIN; SELECT @@transaction_isolation AS transaction_isolation, @@tidb_txn_mode AS tidb_txn_mode; COMMIT;" \
      > "$DRY/iso-preset.txt" 2>&1 || true
    ACTUAL_ISO=$(awk 'NR==2 {print $1}' "$DRY/iso-preset.txt")
    ;;
  crdb)
    psql "postgres://${CRDB_USER:-root}@${DB_HOST}:${CRDB_PORT:-26257}/defaultdb?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At -c "SHOW transaction_isolation" \
      > "$DRY/iso-preset.txt" 2>&1 || true
    ACTUAL_ISO=$(grep -E '^(read committed|repeatable read|serializable)$' "$DRY/iso-preset.txt" | tail -1)
    ;;
  ybdb)
    psql "postgres://${YBDB_USER:-yugabyte}@${DB_HOST}:${YBDB_PORT:-5433}/yugabyte?${ISO_CONN_PARAMS}" \
      -v ON_ERROR_STOP=1 -At \
      -c "SHOW transaction_isolation" \
      -c "SHOW yb_effective_transaction_isolation_level" \
      > "$DRY/iso-preset.txt" 2>&1 || true
    ACTUAL_ISO=$(sed -n '1p' "$DRY/iso-preset.txt")
    YB_EFFECTIVE=$(sed -n '2p' "$DRY/iso-preset.txt")
    if [[ "${YB_EFFECTIVE:-}" != "$EXPECTED_ISO" ]]; then
      warn "YBDB effective iso mismatch (expected=$EXPECTED_ISO effective=${YB_EFFECTIVE:-N/A}) — tserver gflag may be off"
      ALL_PASS=false
      FAILS+=("yb-effective-iso-mismatch")
    fi
    ;;
esac

if [[ "${ACTUAL_ISO:-}" != "$EXPECTED_ISO" ]]; then
  warn "iso preset mismatch (expected=$EXPECTED_ISO actual=${ACTUAL_ISO:-N/A})"
  ALL_PASS=false
  FAILS+=("iso-mismatch:expected=$EXPECTED_ISO/actual=${ACTUAL_ISO:-N/A}")
fi

# --- 5. write expected-vs-actual summary + .dry-run.done --------------------
{
  echo "=== dry-run gate $TOPOLOGY / $DB / $ISO ==="
  echo "expected-node-count = 3        actual = $NODE_COUNT"
  echo "expected-rf         = $EXPECTED_RF        actual = $ACTUAL_RF"
  echo "expected-iso        = $EXPECTED_ISO   actual = ${ACTUAL_ISO:-N/A}"
  echo "yb-effective-iso    = ${YB_EFFECTIVE:-n/a}"
  echo "all_pass            = $ALL_PASS"
  if [[ ${#FAILS[@]} -gt 0 ]]; then
    echo "fails               = ${FAILS[*]}"
  fi
} > "$DRY/expected-vs-actual.txt"

write_phase_done "$ROOT" "dry-run" "$(cat <<JSON
{
  "phase": "dry-run",
  "db": "$DB",
  "topology": "$TOPOLOGY",
  "sub_topology": "$SUB",
  "iso": "$ISO",
  "ts": "$TS",
  "db_host": "$DB_HOST",
  "node_count": ${NODE_COUNT:-0},
  "rf_expected": "$EXPECTED_RF",
  "rf_actual": "${ACTUAL_RF:-?}",
  "iso_expected": "$EXPECTED_ISO",
  "iso_actual": "${ACTUAL_ISO:-N/A}",
  "yb_effective_iso": "${YB_EFFECTIVE:-n/a}",
  "all_pass": $ALL_PASS,
  "fails": "${FAILS[*]:-}"
}
JSON
)"

if $ALL_PASS; then
  info "dry-run-confirm PASSED  (sub=$SUB rf=$ACTUAL_RF iso=$ACTUAL_ISO)"
  info "review: cat $DRY/*.txt"
  info "to execute: re-run the make target with EXECUTE=1 TPCC_TS=$TS"
  exit 0
else
  err "dry-run-confirm FAILED  fails=${FAILS[*]}"
  err "review: cat $DRY/*.txt"
  err "fix deploy first; do NOT set EXECUTE=1 until all_pass=true"
  exit 1
fi
