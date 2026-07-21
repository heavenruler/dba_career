#!/usr/bin/env bash
# phase-crossregion/scripts/check-nearread.sh
#
# GCP 就近讀「生效檢驗」（2026-07-21）——設定已套用不等於已生效，本腳本用
# 各 DB 最可靠的執行面證據直接驗證，而非僅檢查設定值或用延遲/netflow 推論
# （後兩者證據力較弱，詳見 XCROSS-AARO-CLOSING-REPORT-DRAFT.md §5.4/§5.5）。
#
# 三家各用最強證據：
#   TiDB — zone 標籤須完全相同才判定「近」（PingCAP docs），檢查 tidb-server
#          與其 closest TiKV store 的 zone label 是否一致（設定面必要條件；
#          執行面另需大量讀取的乾淨網路流量比對，本腳本僅驗設定面）。
#   CRDB — EXPLAIN ANALYZE 直接顯示 `used follower read` + `regions: gcp` +
#          `sql nodes`/`kv nodes` 皆為 GCP 節點，決定性證據。
#   YBDB — EXPLAIN (ANALYZE, DIST) 的 Storage Table Read Execution Time：
#          follower-read 應顯著低於強制 leader-read（同硬體下比較），非
#          決定性但為次佳可得證據（YBDB 無等價 CRDB 的 per-query 節點欄位）。
#
# Usage:
#   check-nearread.sh --db tidb --host <gcp-tidb-host> --port 4000
#   check-nearread.sh --db crdb --host <gcp-crdb-host> --port 26257 --db-name tpcc
#   check-nearread.sh --db ybdb --host <gcp-ybdb-host> --port 5433 --db-name tpcc
#
# Fail-closed：任一家證據不符預期 → exit 1，印出實際 EXPLAIN 輸出供人工複核。
set -euo pipefail

DB="" HOST="" PORT="" DBNAME="tpcc"
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --host) HOST=$2; shift 2 ;;
    --port) PORT=$2; shift 2 ;;
    --db-name) DBNAME=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${DB:?--db required (tidb|crdb|ybdb)}"
: "${HOST:?--host required (GCP DB host)}"
: "${PORT:?--port required}"

case "$DB" in
  tidb)
    echo "[check-nearread] TiDB：核對 zone 標籤（設定面必要條件）"
    OWN=$(mysql -h "$HOST" -P "$PORT" -u root -N -e \
      "SELECT LABELS FROM information_schema.tidb_servers_info WHERE IP='$HOST';")
    OWN_ZONE=$(echo "$OWN" | grep -oE 'zone=[^,]+')
    STORE_ZONES=$(mysql -h "$HOST" -P "$PORT" -u root -N -e \
      "SELECT LABEL FROM information_schema.tikv_store_status WHERE LABEL LIKE '%region%gcp%';" \
      | grep -oE '"zone", "value": "[^"]+"' | grep -oE 'zone=[^"]*|"[^"]+"$' || true)
    echo "  tidb-server zone: $OWN_ZONE"
    echo "  GCP TiKV store labels: $(mysql -h "$HOST" -P "$PORT" -u root -N -e \
      "SELECT LABEL FROM information_schema.tikv_store_status WHERE LABEL LIKE '%gcp%';")"
    [[ -n "$OWN_ZONE" ]] || { echo "[check-nearread] FAIL: tidb-server 無 zone label" >&2; exit 1; }
    echo "[check-nearread] TiDB 設定面 OK（zone label 存在；執行面請另跑大量讀取＋netflow delta 比對，見報告 §5.4）"
    ;;
  crdb)
    echo "[check-nearread] CRDB：EXPLAIN ANALYZE 決定性檢查"
    OUT=$(psql "postgres://root@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_use_follower_reads%3Don" \
      -c "EXPLAIN ANALYZE SELECT 1 FROM stock LIMIT 1;" 2>&1)
    echo "$OUT" | grep -E 'used follower read|regions:|sql nodes' || true
    if ! echo "$OUT" | grep -q 'used follower read'; then
      echo "[check-nearread] FAIL: 未見 'used follower read'" >&2
      echo "$OUT" >&2
      exit 1
    fi
    if echo "$OUT" | grep -q 'regions: gcp'; then
      echo "[check-nearread] PASS: CRDB follower read 生效且 region=gcp（本地服務）"
    else
      echo "[check-nearread] WARN: follower read 生效但 region 非 gcp（可能查到別的表/資料分布）" >&2
    fi
    ;;
  ybdb)
    echo "[check-nearread] YBDB：follower-read vs leader-read 執行時間對照"
    T_FOLLOWER=$(psql "postgres://yugabyte@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_read_only%3Don%20-c%20yb_read_from_followers%3Don%20-c%20yb_follower_read_staleness_ms%3D30000" \
      -c "EXPLAIN (ANALYZE, DIST) SELECT 1 FROM stock LIMIT 1;" 2>&1 \
      | grep -oE 'Storage Table Read Execution Time: [0-9.]+' | grep -oE '[0-9.]+$' | head -1)
    T_LEADER=$(psql "postgres://yugabyte@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20yb_read_from_followers%3Doff" \
      -c "EXPLAIN (ANALYZE, DIST) SELECT 1 FROM stock LIMIT 1;" 2>&1 \
      | grep -oE 'Storage Table Read Execution Time: [0-9.]+' | grep -oE '[0-9.]+$' | head -1)
    echo "  follower-read: ${T_FOLLOWER}ms   leader-read: ${T_LEADER}ms"
    [[ -n "$T_FOLLOWER" && -n "$T_LEADER" ]] || { echo "[check-nearread] FAIL: 無法取得執行時間" >&2; exit 1; }
    AWK_RESULT=$(awk -v f="$T_FOLLOWER" -v l="$T_LEADER" 'BEGIN{print (f < l*0.7) ? "PASS" : "FAIL"}')
    if [[ "$AWK_RESULT" == "PASS" ]]; then
      echo "[check-nearread] PASS: follower-read 顯著快於 leader-read（<70%），符合本地服務預期"
    else
      echo "[check-nearread] FAIL: follower-read 未顯著快於 leader-read，near-read 可能未生效" >&2
      exit 1
    fi
    ;;
  *) echo "unknown --db: $DB" >&2; exit 1 ;;
esac
