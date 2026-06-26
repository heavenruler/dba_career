#!/usr/bin/env bash
# phase-crossregion/scripts/gate-placement-p-b.sh
#
# P-B placement actual gate — verify per-shard leaders are spread across IDC + GCP,
# fail-closed if leaders are co-located (= degraded to P-A, voids P-B test semantics).
#
# Ground truth:
#   - topology/P-B.md (§驗證 gate)
#   - decisions-2026-06-08.md Q9
#   - RTO-RPO-methodology.md §3.3 (leader-transfer 偵測指令)
#
# Scope:
#   - read-only admin queries; no DDL / DML
#   - does not modify cluster state
#   - planner-safe — does not require --execute opt-in
#
# Pre-requisite:
#   - placement-p-b.sql already applied (see ansible playbook or manual apply)
#   - YBDB/CRDB ssh keys present at $GCP_SSH_KEY / $IDC_SSH_KEY (default ~/.ssh/id_rsa)
#
# Usage:
#   gate-placement-p-b.sh --db {tidb|crdb|ybdb} --out-dir <path>
#
# Output (per-DB):
#   <out-dir>/p-b-gate-<db>.json     ← structured verdict
#   <out-dir>/p-b-gate-<db>.txt      ← raw admin query output
#   <out-dir>/p-b-gate-<db>.failed   ← stamp file iff fail-closed
#
# Exit:
#   0  pass — leaders span ≥ 2 regions (idc + gcp)
#   1  fail — leaders co-located OR query failed (fail-closed)

set -euo pipefail

DB=""
OUT_DIR=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --out-dir) OUT_DIR=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${DB:?--db required (tidb|crdb|ybdb)}"
: "${OUT_DIR:?--out-dir required}"
mkdir -p "$OUT_DIR"

# DB endpoints (default IDC haproxy / GCP master per phase-crossregion convention)
: "${TIDB_HAPROXY:=172.24.47.20}"     ; : "${TIDB_PORT:=4000}"     ; : "${TIDB_USER:=root}"
: "${CRDB_HOST:=172.24.40.32}"        ; : "${CRDB_PORT:=26257}"    ; : "${CRDB_USER:=root}"
: "${YBDB_MASTERS:=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100}"
: "${IDC_SSH_USER:=root}"             ; : "${IDC_SSH_KEY:=$HOME/.ssh/id_rsa}"
: "${TPCC_DB:=tpcc}"

RAW="$OUT_DIR/p-b-gate-$DB.txt"
JSON="$OUT_DIR/p-b-gate-$DB.json"
FAILED="$OUT_DIR/p-b-gate-$DB.failed"
rm -f "$FAILED"

# Region tagging — host → region map (compile-time constant for this PoC; matches
# topology/P-A.md + P-B.md voter table; update if cluster layout changes).
host_region() {
  case "$1" in
    172.24.40.32|172.24.40.33|172.24.40.34|idc-dbhost-*) echo "idc" ;;
    *gcp*|asia-east1-*|10.140.*|*-gcp*)                  echo "gcp" ;;
    *) echo "unknown" ;;
  esac
}

# Sample TPCC tables for shard leader spread check.
# warehouse / district / customer are the 3 hottest in TPCC; sufficient for spread verification.
SAMPLE_TABLES=("warehouse" "district" "customer" "orders" "new_order")

idc_count=0
gcp_count=0
unknown_count=0
total_shards=0

case "$DB" in
  tidb)
    # TiDB: tikv_region_peers + tikv_store_status join → host per leader peer.
    # 注意：region 是 TiKV 內部 shard 單位（非 tpcc table 直接對應），
    # 用 information_schema 過濾到 tpcc 命名空間的 region。
    mysql -h "$TIDB_HAPROXY" -P "$TIDB_PORT" -u "$TIDB_USER" -B -N -e "
      SELECT s.ADDRESS
      FROM information_schema.TIKV_REGION_PEERS p
      JOIN information_schema.TIKV_STORE_STATUS s ON p.STORE_ID = s.STORE_ID
      JOIN information_schema.TIKV_REGION_STATUS r ON p.REGION_ID = r.REGION_ID
      WHERE p.IS_LEADER = 1
        AND r.DB_NAME = '$TPCC_DB'
      LIMIT 200;
    " > "$RAW" 2>&1 || { echo "query-failed" > "$FAILED"; }
    ;;

  crdb)
    # CRDB: SHOW RANGES FROM TABLE ... WITH DETAILS → lease_holder + lease_holder_locality
    : > "$RAW"
    for t in "${SAMPLE_TABLES[@]}"; do
      ssh -i "$IDC_SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 \
          "${IDC_SSH_USER}@${CRDB_HOST}" \
          "/usr/local/bin/cockroach sql --insecure --host=127.0.0.1:$CRDB_PORT --format=tsv -e \
           \"SHOW RANGES FROM TABLE ${TPCC_DB}.${t} WITH DETAILS\" 2>/dev/null \
           | awk -F'\\t' 'NR>1 {print \$0}' " \
          >> "$RAW" 2>>"$RAW" || { echo "query-failed:$t" > "$FAILED"; }
    done
    ;;

  ybdb)
    # YBDB: yb-admin list_tablets <table> → leader uuid + leader host
    : > "$RAW"
    for t in "${SAMPLE_TABLES[@]}"; do
      ssh -i "$IDC_SSH_KEY" -o BatchMode=yes -o ConnectTimeout=5 \
          "${IDC_SSH_USER}@$(echo "$YBDB_MASTERS" | cut -d, -f1 | cut -d: -f1)" \
          "/opt/yugabyte/bin/yb-admin --master_addresses=$YBDB_MASTERS \
           list_tablets ysql.${TPCC_DB} ${t} 2>/dev/null" \
          >> "$RAW" 2>>"$RAW" || { echo "query-failed:$t" > "$FAILED"; }
    done
    ;;

  *)
    echo "unsupported db: $DB" >&2
    exit 1
    ;;
esac

if [[ -f "$FAILED" ]]; then
  cat > "$JSON" <<EOF
{
  "db": "$DB",
  "verdict": "fail-closed",
  "reason": "admin-query-failed",
  "fail_marker": "$(cat "$FAILED")",
  "raw": "$RAW"
}
EOF
  echo "[gate-placement-p-b] $DB FAIL — admin query failed; see $RAW" >&2
  exit 1
fi

# Parse RAW for leader host strings; bucket by region.
# Tolerant parsing: per-DB output formats differ; just count region tokens.
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  # Extract host-like token: IP or hostname; per-DB customisations below.
  host=$(echo "$line" \
    | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}|idc-dbhost-[0-9]+|gcp-dbhost-[0-9]+|asia-east1-[a-z]' \
    | head -1)
  [[ -z "$host" ]] && continue
  total_shards=$((total_shards + 1))
  reg=$(host_region "$host")
  case "$reg" in
    idc) idc_count=$((idc_count + 1)) ;;
    gcp) gcp_count=$((gcp_count + 1)) ;;
    *)   unknown_count=$((unknown_count + 1)) ;;
  esac
done < "$RAW"

# Spread judgement:
#   PASS  := total_shards >= 3 AND idc_count >= 1 AND gcp_count >= 1
#   FAIL  := otherwise (leaders co-located = P-A degraded)
verdict="fail-closed"
reason=""
if [[ "$total_shards" -lt 3 ]]; then
  reason="insufficient-shard-samples (total=$total_shards, need ≥3)"
elif [[ "$idc_count" -lt 1 ]]; then
  reason="no-idc-leader (degraded to GCP-only)"
elif [[ "$gcp_count" -lt 1 ]]; then
  reason="no-gcp-leader (degraded to P-A behaviour)"
else
  verdict="pass"
  reason="leaders-spread idc=$idc_count gcp=$gcp_count unknown=$unknown_count"
fi

cat > "$JSON" <<EOF
{
  "db": "$DB",
  "verdict": "$verdict",
  "reason": "$reason",
  "total_shards_sampled": $total_shards,
  "idc_leader_count": $idc_count,
  "gcp_leader_count": $gcp_count,
  "unknown_region_count": $unknown_count,
  "sample_tables": "$(IFS=,; echo "${SAMPLE_TABLES[*]}")",
  "raw": "$RAW",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

if [[ "$verdict" == "pass" ]]; then
  echo "[gate-placement-p-b] $DB PASS — $reason"
  exit 0
else
  echo "$reason" > "$FAILED"
  echo "[gate-placement-p-b] $DB FAIL — $reason; see $JSON" >&2
  exit 1
fi
