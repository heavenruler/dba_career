#!/usr/bin/env bash
# gcp-replica-gate.sh — fail-closed 驗證「IDC 資料確實有副本同步到 GCP」
#
# 背景（2026-07-13）：w128 首輪 CRDB/YBDB 的 GCP 節點零 tpcc 資料
# （CRDB constraints list-form 矛盾、YBDB RR placement_uuid 永不匹配），
# 但既有 gate 只驗 leader/lease 在 IDC，GCP 副本缺失靜默通過。
# 本 gate 在 post-prepare（placement 收斂後、freeze/benchmark 前）開槍：
#   tidb : tpcc region 的 follower 必須有 >0 落在 region=gcp store，且 gcp leader=0
#   crdb : tpcc 每個 range 的 replica_localities 必須含 region=gcp，且 lease 全 idc
#   ybdb : universe live placement 含 gcp block，且 ≥1 台 GCP tserver SST > 0
# 證據一律落 $OUT_DIR（預設 $ROOT/gate/）供 artifact 追溯。
#
# Usage: gcp-replica-gate.sh --db {tidb|crdb|ybdb} --db-host <ip> --db-port <port> --out-dir <dir>
# Env  : YB_MASTER_ADDR（ybdb 用，預設 3 IDC masters）
set -euo pipefail

DB="" DB_HOST="" DB_PORT="" OUT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --db-host) DB_HOST=$2; shift 2 ;;
    --db-port) DB_PORT=$2; shift 2 ;;
    --out-dir) OUT_DIR=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$DB" && -n "$DB_HOST" && -n "$DB_PORT" && -n "$OUT_DIR" ]] || { echo "missing args" >&2; exit 2; }
mkdir -p "$OUT_DIR"
EV="$OUT_DIR/gcp-replica-gate-$DB.txt"
log() { echo "[gcp-replica-gate $(date +%H:%M:%S)] $*" | tee -a "$EV"; }
: > "$EV"

TPCC_TABLES="'new_order','orders','warehouse','customer','district','history','order_line','item','stock'"

case "$DB" in
  tidb)
    # follower（IS_LEADER=0）落在 gcp store 的 tpcc region peer 數
    Q_BASE="FROM information_schema.tikv_region_peers p \
      JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID \
      JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID \
      WHERE r.DB_NAME='tpcc'"
    gcp_followers=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u root -BNe \
      "SELECT COUNT(*) $Q_BASE AND p.IS_LEADER=0 AND s.LABEL LIKE '%gcp%';" | tail -1)
    gcp_leaders=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u root -BNe \
      "SELECT COUNT(*) $Q_BASE AND p.IS_LEADER=1 AND s.LABEL LIKE '%gcp%';" | tail -1)
    # 證據：tpcc-scoped 全 peer 分布（含 follower，補 leader-snapshot 只存 leader 的缺口）
    mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e \
      "SELECT s.ADDRESS, s.LABEL, p.IS_LEADER, COUNT(*) AS peer_count $Q_BASE \
       GROUP BY s.ADDRESS, s.LABEL, p.IS_LEADER ORDER BY s.ADDRESS, p.IS_LEADER;" >> "$EV"
    log "tidb: gcp_followers=$gcp_followers gcp_leaders=$gcp_leaders"
    [[ "$gcp_followers" -gt 0 ]] || { log "FAIL: tpcc 在 GCP store 的 follower=0（資料未同步 GCP）"; exit 1; }
    [[ "$gcp_leaders" -eq 0 ]]   || { log "FAIL: tpcc leader 出現在 GCP store（違反 P-A）"; exit 1; }
    ;;
  crdb)
    CR=/usr/local/bin/cockroach
    RANGES="[SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS]"
    missing_gcp=$($CR sql --insecure --host="$DB_HOST:$DB_PORT" -d tpcc --format=csv -e \
      "SELECT count(*) FROM $RANGES WHERE table_name IN ($TPCC_TABLES) \
       AND array_to_string(replica_localities,',') NOT LIKE '%region=gcp%';" | tail -1)
    gcp_lease=$($CR sql --insecure --host="$DB_HOST:$DB_PORT" -d tpcc --format=csv -e \
      "SELECT count(*) FROM $RANGES WHERE table_name IN ($TPCC_TABLES) \
       AND lease_holder_locality LIKE '%region=gcp%';" | tail -1)
    $CR sql --insecure --host="$DB_HOST:$DB_PORT" -d tpcc --format=tsv -e \
      "SELECT lease_holder_locality, array_to_string(replica_localities,'|') AS replicas, count(*) \
       FROM $RANGES WHERE table_name IN ($TPCC_TABLES) GROUP BY 1,2 ORDER BY 3 DESC;" >> "$EV"
    log "crdb: ranges_missing_gcp_replica=$missing_gcp gcp_leaseholders=$gcp_lease"
    [[ "$missing_gcp" -eq 0 ]] || { log "FAIL: $missing_gcp 個 tpcc range 沒有 GCP 副本（constraints 未生效）"; exit 1; }
    [[ "$gcp_lease" -eq 0 ]]   || { log "FAIL: $gcp_lease 個 tpcc range 的 lease 在 GCP（違反 P-A）"; exit 1; }
    ;;
  ybdb)
    : "${YB_MASTER_ADDR:=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100}"
    YB="ssh -n -o ConnectTimeout=5 -o BatchMode=yes root@$DB_HOST /opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTER_ADDR"
    # 1) universe live placement 必須含 gcp block
    $YB get_universe_config > "$OUT_DIR/gcp-replica-gate-ybdb-universe.json" 2>&1
    grep -q '"placementRegion":"gcp"' "$OUT_DIR/gcp-replica-gate-ybdb-universe.json" \
      || { log "FAIL: universe live placement 不含 gcp block"; exit 1; }
    # 2) GCP tserver（資料同步後）SST 必須 > 0；SST 欄格式「10.72 GB」/「0 B」
    #    flush 可能落後 load 數十秒 → retry 最多 12×10s
    ok=0
    for i in $(seq 1 12); do
      $YB list_all_tablet_servers > "$OUT_DIR/gcp-replica-gate-ybdb-tservers.txt" 2>&1 || true
      gcp_with_data=$(awk '/10\.160\.152\./ { for (j=1;j<=NF;j++) if ($j=="B"||$j=="KB"||$j=="MB"||$j=="GB") { if (!($(j-1)==0 && $j=="B")) print; break } }' \
        "$OUT_DIR/gcp-replica-gate-ybdb-tservers.txt" | wc -l | tr -d ' ')
      [[ "$gcp_with_data" -gt 0 ]] && { ok=1; break; }
      log "  $i/12 GCP tserver SST 仍全為 0 B，等 flush…"
      sleep 10
    done
    cat "$OUT_DIR/gcp-replica-gate-ybdb-tservers.txt" >> "$EV"
    log "ybdb: gcp_tservers_with_sst=$gcp_with_data"
    [[ "$ok" == "1" ]] || { log "FAIL: 全部 GCP tserver SST=0B（tablet 副本未實體化，資料未同步 GCP）"; exit 1; }
    ;;
  *) echo "unsupported db: $DB" >&2; exit 2 ;;
esac

log "PASS: $DB GCP 副本存在且 leader/lease 全在 IDC（證據 $EV）"
