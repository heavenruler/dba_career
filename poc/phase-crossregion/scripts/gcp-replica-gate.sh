#!/usr/bin/env bash
# gcp-replica-gate.sh — fail-closed 驗證「IDC 資料確實有副本同步到 GCP」
#
# 背景（2026-07-13）：w128 首輪 CRDB/YBDB 的 GCP 節點零 tpcc 資料
# （CRDB constraints list-form 矛盾、YBDB RR placement_uuid 永不匹配），
# 但既有 gate 只驗 leader/lease 在 IDC，GCP 副本缺失靜默通過。
# 本 gate 在 post-prepare（placement 收斂後、freeze/benchmark 前）開槍：
#   tidb : tpcc region 的 follower 必須有 >0 落在 region=gcp store，且 leader 合 PLACEMENT 語意
#   crdb : tpcc 每個 range 的 replica_localities 必須含 region=gcp，且 lease 合 PLACEMENT 語意
#   ybdb : universe live placement 含 gcp block，≥N 台 GCP tserver SST > 0，
#          且 transaction status tablet leader 合 PLACEMENT 語意（O1 補強，2026-07-17：
#          堵「gate 只驗 tpcc 表、系統層 status tablet leader 落 GCP 漏網」盲區）
# PLACEMENT 語意（2026-07-17 參數化；非法值 fail-closed）：
#   P-A（default）: leader/lease 全在 IDC（含 ybdb status tablet，違者 leader_stepdown 修復）
#   P-B           : leader/lease 跨區散布——idc 占比 30-70%（與 tests/common/prepare.sh
#                   P-B gate 同口徑）；GCP 副本存在檢查與 ybdb SST 檢查兩種 placement 照舊
# 證據一律落 $OUT_DIR（預設 $ROOT/gate/）供 artifact 追溯。
#
# Usage: gcp-replica-gate.sh --db {tidb|crdb|ybdb} --db-host <ip> --db-port <port> --out-dir <dir>
# Env  : YB_MASTER_ADDR（ybdb 用，預設 3 IDC masters）；PLACEMENT=P-A|P-B（預設 P-A）
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
# PLACEMENT 判準參數化（S2）：default P-A；值域外一律 fail-closed
: "${PLACEMENT:=P-A}"
[[ "$PLACEMENT" =~ ^(P-A|P-B)$ ]] || { echo "PLACEMENT must be P-A | P-B (got: $PLACEMENT)" >&2; exit 2; }
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
    if [[ "$PLACEMENT" == "P-A" ]]; then
      [[ "$gcp_leaders" -eq 0 ]] || { log "FAIL: tpcc leader 出現在 GCP store（違反 P-A）"; exit 1; }
    else
      # P-B：leader 應跨區散布——idc 占比 30-70%（與 prepare.sh P-B gate 同口徑）
      idc_leaders=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u root -BNe \
        "SELECT COUNT(*) $Q_BASE AND p.IS_LEADER=1 AND s.LABEL LIKE '%idc%';" | tail -1)
      total_leaders=$((idc_leaders + gcp_leaders))
      [[ "$total_leaders" -gt 0 ]] || { log "FAIL: tpcc leader 總數=0（無法判定 P-B spread）"; exit 1; }
      idc_pct=$(( idc_leaders * 100 / total_leaders ))
      log "tidb: P-B leader spread idc=$idc_leaders/$total_leaders (${idc_pct}%)"
      [[ "$idc_pct" -ge 30 && "$idc_pct" -le 70 ]] \
        || { log "FAIL: P-B leader spread idc_pct=${idc_pct}% 不在 30-70%（leader 未跨區散布）"; exit 1; }
    fi
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
    if [[ "$PLACEMENT" == "P-A" ]]; then
      [[ "$gcp_lease" -eq 0 ]] || { log "FAIL: $gcp_lease 個 tpcc range 的 lease 在 GCP（違反 P-A）"; exit 1; }
    else
      # P-B：lease 應跨區散布——idc 占比 30-70%（與 prepare.sh P-B gate 同口徑）
      idc_lease=$($CR sql --insecure --host="$DB_HOST:$DB_PORT" -d tpcc --format=csv -e \
        "SELECT count(*) FROM $RANGES WHERE table_name IN ($TPCC_TABLES) \
         AND lease_holder_locality LIKE '%region=idc%';" | tail -1)
      total_lease=$((idc_lease + gcp_lease))
      [[ "$total_lease" -gt 0 ]] || { log "FAIL: tpcc lease 總數=0（無法判定 P-B spread）"; exit 1; }
      idc_pct=$(( idc_lease * 100 / total_lease ))
      log "crdb: P-B lease spread idc=$idc_lease/$total_lease (${idc_pct}%)"
      [[ "$idc_pct" -ge 30 && "$idc_pct" -le 70 ]] \
        || { log "FAIL: P-B lease spread idc_pct=${idc_pct}% 不在 30-70%（lease 未跨區散布）"; exit 1; }
    fi
    ;;
  ybdb)
    : "${YB_MASTER_ADDR:=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100}"
    YB="ssh -n -o ConnectTimeout=5 -o BatchMode=yes root@$DB_HOST /opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTER_ADDR"
    # 1) universe live placement 必須含 gcp block
    $YB get_universe_config > "$OUT_DIR/gcp-replica-gate-ybdb-universe.json" 2>&1
    grep -q '"placementRegion":"gcp"' "$OUT_DIR/gcp-replica-gate-ybdb-universe.json" \
      || { log "FAIL: universe live placement 不含 gcp block"; exit 1; }
    # 2) GCP tserver（資料同步後）SST 必須 > 0；SST 欄格式「10.72 GB」/「0 B」
    #    GCP 三台統一 placement_zone（07-13）→ LB 應把 tablet 副本分散 3 台，
    #    預設要求 3/3 都有資料（GCP_MIN_TS_WITH_DATA 可調）；flush 落後 → retry 12×10s
    : "${GCP_MIN_TS_WITH_DATA:=3}"
    ok=0
    for i in $(seq 1 12); do
      $YB list_all_tablet_servers > "$OUT_DIR/gcp-replica-gate-ybdb-tservers.txt" 2>&1 || true
      gcp_with_data=$(awk '/10\.160\.152\./ { for (j=1;j<=NF;j++) if ($j=="B"||$j=="KB"||$j=="MB"||$j=="GB") { if (!($(j-1)==0 && $j=="B")) print; break } }' \
        "$OUT_DIR/gcp-replica-gate-ybdb-tservers.txt" | wc -l | tr -d ' ')
      [[ "$gcp_with_data" -ge "$GCP_MIN_TS_WITH_DATA" ]] && { ok=1; break; }
      log "  $i/12 GCP tserver 有資料 $gcp_with_data/$GCP_MIN_TS_WITH_DATA，等 flush/LB…"
      sleep 10
    done
    cat "$OUT_DIR/gcp-replica-gate-ybdb-tservers.txt" >> "$EV"
    log "ybdb: gcp_tservers_with_sst=$gcp_with_data (require >= $GCP_MIN_TS_WITH_DATA)"
    [[ "$ok" == "1" ]] || { log "FAIL: GCP tserver 有資料台數 $gcp_with_data < $GCP_MIN_TS_WITH_DATA（tablet 副本未分散/未實體化）"; exit 1; }
    # 3) transaction status tablet leader 檢查（O1 gate 補強，2026-07-17）
    #    第六問題（SESSION-HISTORY 2026-07-14 續）：status tablet 屬系統層，
    #    tpcc-scoped 檢查漏網——leader 落 GCP 時 UpdateTransaction RPC
    #    （transaction_rpc_timeout_ms=5000 default）跨 WAN 逾時，
    #    造成 0.011-0.03% 交易錯誤。本步把系統層納入 gate 視野。
    ST_EV="$OUT_DIR/gcp-replica-gate-ybdb-status-tablets.txt"
    : > "$ST_EV"
    # transaction status table = YCQL system keyspace 的 transactions 表。
    # yb-admin list_tablets 的 keyspace 寫法跨版本容錯：「system」（不帶前綴預設
    # ycql）與「ycql.system」逐一嘗試；原始輸出一律附掛 $ST_EV 留證據。
    # max_tablets=0 = 全列不截斷；資料行以 32-hex tablet uuid 開頭、leader 為 ip:port。
    list_status_tablets() {
      local form out
      for form in "system transactions" "ycql.system transactions"; do
        echo "== [$(date +%H:%M:%S)] try: list_tablets $form 0" >> "$ST_EV"
        if out=$($YB list_tablets $form 0 2>&1); then
          echo "$out" >> "$ST_EV"
          # 有解析到 tablet 資料行才算成功（防「指令成功但輸出空/格式異常」）
          grep -qE '^[0-9a-f]{32}' <<<"$out" && { echo "$out"; return 0; }
        else
          echo "$out" >> "$ST_EV"
        fi
      done
      return 1
    }
    # $1=list_tablets 輸出 → 設定 st_total/st_idc/st_gcp/st_gcp_tablets
    # （leader IP 判區：172.24.40.x=IDC、10.160.152.x=GCP；其他不計入、留 raw 供查）
    st_summary() {
      st_gcp_tablets=$(awk '/^[0-9a-f]{32}/ && /10\.160\.152\./ {print $1}' <<<"$1")
      st_idc=$(grep -cE '^[0-9a-f]{32}.*172\.24\.40\.' <<<"$1" || true)
      st_gcp=$(grep -cE '^[0-9a-f]{32}.*10\.160\.152\.' <<<"$1" || true)
      st_total=$((st_idc + st_gcp))
    }
    if [[ "$PLACEMENT" == "P-A" ]]; then
      # P-A：status tablet leader 必須全在 IDC；在 GCP → leader_stepdown（不指定
      # 目標，raft 自選新 leader）後重查，最多 6×10s；仍不合 → fail-closed。
      st_ok=0
      for i in $(seq 1 6); do
        raw=$(list_status_tablets) \
          || { log "FAIL: 無法列出 transaction status tablets（fail-closed；證據 $ST_EV）"; exit 1; }
        st_summary "$raw"
        [[ "$st_total" -gt 0 ]] || { log "FAIL: status tablet leader 解析 0 筆（格式異常？證據 $ST_EV）"; exit 1; }
        [[ "$st_gcp" -gt 0 ]] || { st_ok=1; break; }
        log "  $i/6 status tablet leader 在 GCP $st_gcp/$st_total → leader_stepdown 修復"
        for tid in $st_gcp_tablets; do
          echo "== [$(date +%H:%M:%S)] leader_stepdown $tid" >> "$ST_EV"
          $YB leader_stepdown "$tid" >> "$ST_EV" 2>&1 || true
        done
        sleep 10
      done
      log "ybdb: status_tablet_leaders idc=$st_idc gcp=$st_gcp total=$st_total (P-A require gcp=0)"
      [[ "$st_ok" == "1" ]] \
        || { log "FAIL: transaction status tablet leader 仍在 GCP（stepdown 6 次未收斂）— commit 協調將跨 WAN"; exit 1; }
    else
      # P-B：leader 本就允許跨區，status tablet 不強制——跳過 stepdown，只記錄分布供追溯
      if raw=$(list_status_tablets); then
        st_summary "$raw"
        log "ybdb: status_tablet_leaders idc=$st_idc gcp=$st_gcp total=$st_total (P-B 僅記錄不斷言)"
      else
        log "WARN: 無法列出 transaction status tablets（P-B 僅記錄；證據 $ST_EV）"
      fi
    fi
    ;;
  *) echo "unsupported db: $DB" >&2; exit 2 ;;
esac

if [[ "$PLACEMENT" == "P-A" ]]; then
  log "PASS: $DB GCP 副本存在且 leader/lease 全在 IDC（P-A；證據 $EV）"
else
  log "PASS: $DB GCP 副本存在且 leader/lease 跨區散布合格（P-B；證據 $EV）"
fi
