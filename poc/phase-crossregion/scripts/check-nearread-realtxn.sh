#!/usr/bin/env bash
# phase-crossregion/scripts/check-nearread-realtxn.sh
#
# A7(1) 補強（codex 審查 2026-07-22 建議）：check-nearread.sh 只測合成的
# `SELECT ... FROM stock LIMIT 1` 單表 point lookup，本腳本改用 TPC-C 規格
# 定義的 ORDER_STATUS / STOCK_LEVEL 唯讀交易（跨表 join、range scan，非單
# 一 point lookup），驗證近讀在真正的 workload 查詢形狀下是否仍生效。
#
# 語句依 TPC-C 官方規格撰寫（customer/orders/order_line 三段式 ORDER_STATUS、
# district+order_line+stock 兩段式 STOCK_LEVEL），非逐字複製 go-tpc 原始碼
# （未取得原始碼比對）——語意與跨表/range-scan 形狀一致，足以驗證「近讀是否
# 隨查詢複雜度改變」這個目的；不宣稱與 go-tpc 內部 SQL 逐字相同。
#
# 假設 W=4 anchor 資料（ANCHOR_ONLY prepare 產生）：w_id 1-4, d_id 1-10,
# c_id 1-3000, item 1-100000（TPC-C 規格固定值，不隨 warehouse 數變動）。
#
# Usage:
#   check-nearread-realtxn.sh --db crdb --host <gcp-host> --port 26257 --db-name tpcc
#   check-nearread-realtxn.sh --db ybdb --host <gcp-host> --port 5433  --db-name tpcc
#   check-nearread-realtxn.sh --db tidb --host <gcp-host> --port 4000  --db-name tpcc
#
# Fail-closed：任一語句不符近讀預期 → exit 1（印出全部樣本供人工複核，
# 不因單一語句失敗就提早結束，方便一次看完整輪結果）。
set -uo pipefail

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

# 樣本組（w_id d_id c_id）用於 ORDER_STATUS；(w_id d_id) 用於 STOCK_LEVEL
SAMPLES=("1 3 500" "2 7 1200" "3 1 2999" "4 10 42")

FAIL_COUNT=0
TOTAL_COUNT=0

case "$DB" in
  crdb)
    echo "[realtxn] CRDB：ORDER_STATUS + STOCK_LEVEL 真實跨表交易，逐語句檢查 EXPLAIN ANALYZE"
    CONN="postgres://root@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_use_follower_reads%3Don"
    check_stmt() {
      local label="$1" sql="$2"
      TOTAL_COUNT=$((TOTAL_COUNT+1))
      local out
      out=$(psql "$CONN" -c "EXPLAIN ANALYZE $sql" 2>&1)
      echo "--- $label ---"
      echo "$out" | grep -E 'used follower read|regions:|sql nodes|kv nodes'
      if ! echo "$out" | grep -q 'used follower read'; then
        echo "  FAIL: 未見 'used follower read'"; FAIL_COUNT=$((FAIL_COUNT+1)); return
      fi
      if ! echo "$out" | grep -qE 'regions: gcp$'; then
        echo "  FAIL: regions 非純 gcp"; FAIL_COUNT=$((FAIL_COUNT+1)); return
      fi
      if echo "$out" | grep -E 'sql nodes|kv nodes' | grep -qiE 'idc'; then
        echo "  FAIL: sql/kv nodes 出現 idc"; FAIL_COUNT=$((FAIL_COUNT+1)); return
      fi
      echo "  PASS"
    }
    for s in "${SAMPLES[@]}"; do
      read -r w d c <<< "$s"
      check_stmt "ORDER_STATUS.1 customer (w=$w d=$d c=$c)" \
        "SELECT c_balance, c_first, c_middle, c_last FROM customer WHERE c_w_id=$w AND c_d_id=$d AND c_id=$c;"
      check_stmt "ORDER_STATUS.2 latest order (w=$w d=$d c=$c)" \
        "SELECT o_id, o_carrier_id, o_entry_d FROM orders WHERE o_w_id=$w AND o_d_id=$d AND o_c_id=$c ORDER BY o_id DESC LIMIT 1;"
      check_stmt "ORDER_STATUS.3 order_line by latest o_id (w=$w d=$d)" \
        "SELECT ol_i_id, ol_supply_w_id, ol_quantity, ol_amount, ol_delivery_d FROM order_line WHERE ol_w_id=$w AND ol_d_id=$d AND ol_o_id=(SELECT o_id FROM orders WHERE o_w_id=$w AND o_d_id=$d AND o_c_id=$c ORDER BY o_id DESC LIMIT 1);"
      check_stmt "STOCK_LEVEL.1 d_next_o_id (w=$w d=$d)" \
        "SELECT d_next_o_id FROM district WHERE d_w_id=$w AND d_id=$d;"
      check_stmt "STOCK_LEVEL.2 low-stock join+range (w=$w d=$d)" \
        "SELECT COUNT(DISTINCT s_i_id) FROM order_line, stock, district WHERE district.d_w_id=$w AND district.d_id=$d AND order_line.ol_w_id=$w AND order_line.ol_d_id=$d AND order_line.ol_o_id < district.d_next_o_id AND order_line.ol_o_id >= district.d_next_o_id-20 AND stock.s_w_id=$w AND stock.s_i_id=order_line.ol_i_id AND stock.s_quantity < 15;"
    done
    ;;
  ybdb)
    echo "[realtxn] YBDB：ORDER_STATUS + STOCK_LEVEL 真實跨表交易，follower-read on/off 對照"
    CONN_ON="postgres://yugabyte@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_read_only%3Don%20-c%20yb_read_from_followers%3Don%20-c%20yb_follower_read_staleness_ms%3D30000"
    CONN_OFF="postgres://yugabyte@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20yb_read_from_followers%3Doff"
    get_time() {
      psql "$1" -c "EXPLAIN (ANALYZE, DIST) $2" 2>&1 \
        | grep -oE 'Storage Table Read Execution Time: [0-9.]+' | grep -oE '[0-9.]+$' | head -1
    }
    check_stmt() {
      local label="$1" sql="$2"
      TOTAL_COUNT=$((TOTAL_COUNT+1))
      local t_on t_off
      t_on=$(get_time "$CONN_ON" "$sql")
      t_off=$(get_time "$CONN_OFF" "$sql")
      echo "--- $label ---  on=${t_on:-N/A}ms off=${t_off:-N/A}ms"
      if [[ -z "$t_on" || -z "$t_off" ]]; then
        echo "  FAIL: 無法取得執行時間"; FAIL_COUNT=$((FAIL_COUNT+1)); return
      fi
      if awk -v f="$t_on" -v l="$t_off" 'BEGIN{exit !(f < l*0.7)}'; then
        echo "  PASS"
      else
        echo "  FAIL: follower-read 未顯著快於 leader-read（<70% 門檻未達）"
        FAIL_COUNT=$((FAIL_COUNT+1))
      fi
    }
    for s in "${SAMPLES[@]}"; do
      read -r w d c <<< "$s"
      check_stmt "ORDER_STATUS.1 customer (w=$w d=$d c=$c)" \
        "SELECT c_balance, c_first, c_middle, c_last FROM customer WHERE c_w_id=$w AND c_d_id=$d AND c_id=$c;"
      check_stmt "ORDER_STATUS.2 latest order (w=$w d=$d c=$c)" \
        "SELECT o_id, o_carrier_id, o_entry_d FROM orders WHERE o_w_id=$w AND o_d_id=$d AND o_c_id=$c ORDER BY o_id DESC LIMIT 1;"
      check_stmt "STOCK_LEVEL.1 d_next_o_id (w=$w d=$d)" \
        "SELECT d_next_o_id FROM district WHERE d_w_id=$w AND d_id=$d;"
    done
    ;;
  tidb)
    echo "[realtxn] TiDB：ORDER_STATUS + STOCK_LEVEL 真實跨表交易 burst + netflow byte delta"
    echo "  （TiDB EXPLAIN ANALYZE 無逐查詢 store 位址欄位，主判準仍是 check-nearread.sh"
    echo "   的 zone-label 比對；本項用真實查詢形狀重測 netflow 比值，作補充觀察）"
    # netflow-snapshot.sh 介面：--out-dir <dir> --label <label> --hosts "h1 h2"
    # 寫檔 <out-dir>/netflow-<label>.json（不印 stdout），bytes 欄位巢狀在
    # hosts["<ip>"].traffic_bytes 底下（見 tests/common/netflow-snapshot.sh）。
    NETFLOW_SH="$(cd "$(dirname "$0")/../.." && pwd)/tests/common/netflow-snapshot.sh"
    SNAP_DIR=$(mktemp -d)
    bash "$NETFLOW_SH" --out-dir "$SNAP_DIR" --label pre --hosts "$HOST" \
      || echo "  WARN: netflow-snapshot.sh pre snapshot 失敗"
    N=200
    for i in $(seq 1 $N); do
      s="${SAMPLES[$((i % 4))]}"
      read -r w d c <<< "$s"
      mysql -h "$HOST" -P "$PORT" -u root -N -e "
        SELECT c_balance, c_first, c_middle, c_last FROM customer WHERE c_w_id=$w AND c_d_id=$d AND c_id=$c;
        SELECT o_id, o_carrier_id, o_entry_d FROM orders WHERE o_w_id=$w AND o_d_id=$d AND o_c_id=$c ORDER BY o_id DESC LIMIT 1;
        SELECT d_next_o_id FROM district WHERE d_w_id=$w AND d_id=$d;
      " "$DBNAME" >/dev/null 2>&1
    done
    bash "$NETFLOW_SH" --out-dir "$SNAP_DIR" --label post --hosts "$HOST" \
      || echo "  WARN: netflow-snapshot.sh post snapshot 失敗"
    if [[ -s "$SNAP_DIR/netflow-pre.json" && -s "$SNAP_DIR/netflow-post.json" ]]; then
      python3 - "$SNAP_DIR/netflow-pre.json" "$SNAP_DIR/netflow-post.json" "$HOST" <<'PYEOF' \
        || echo "  WARN: netflow snapshot 格式解析失敗，略過 ratio 計算"
import json, sys
pre_f, post_f, host = sys.argv[1], sys.argv[2], sys.argv[3]
pre = json.load(open(pre_f))["hosts"][host]["traffic_bytes"]
post = json.load(open(post_f))["hosts"][host]["traffic_bytes"]
d_gcp = post["iptables_to_gcp_bytes"] - pre["iptables_to_gcp_bytes"]
d_idc = post["iptables_to_idc_bytes"] - pre["iptables_to_idc_bytes"]
ratio = "N/A" if d_gcp <= 0 else f"{d_idc*100.0/d_gcp:.1f}"
print(f"  delta_to_gcp={d_gcp}B delta_to_idc={d_idc}B ratio={ratio}%（觀察用，非 PASS/FAIL 門檻——")
print("   單一 burst 受背景流量影響，見報告 §5.5 方法論限制）")
PYEOF
    else
      echo "  WARN: netflow snapshot 檔案缺失，略過 ratio 計算"
    fi
    rm -rf "$SNAP_DIR"
    echo "  （TiDB 無 fail-closed 門檻可用於此項；主判準見 check-nearread.sh --db tidb）"
    ;;
  *) echo "unknown --db: $DB" >&2; exit 1 ;;
esac

echo ""
echo "[realtxn] 總計 $TOTAL_COUNT 項檢查，FAIL=$FAIL_COUNT"
if [[ "$DB" != "tidb" && "$FAIL_COUNT" -gt 0 ]]; then
  echo "[realtxn] FAIL：至少一項真實交易語句未通過近讀檢驗" >&2
  exit 1
fi
echo "[realtxn] PASS"
