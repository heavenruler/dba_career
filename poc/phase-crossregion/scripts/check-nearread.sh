#!/usr/bin/env bash
# phase-crossregion/scripts/check-nearread.sh
#
# GCP 就近讀「生效檢驗」（2026-07-21 初版；2026-07-22 依 codex 獨立審查修正
# 為真正 fail-closed——初版 TiDB 分支算出 zone 集合卻從未比對、CRDB 分支
# 非 gcp 只 WARN 不 FAIL，皆已修正）。設定已套用不等於已生效，本腳本用各 DB
# 較可靠的執行面證據直接驗證，而非僅檢查設定值或用延遲/netflow 推論（後兩者
# 證據力較弱，詳見 XCROSS-AARO-CLOSING-REPORT-DRAFT.md §5.4/§5.5/§5.6）。
#
# 證據強度誠實標注（勿宣稱「決定性」，見 §5.6 codex 審查）：
#   TiDB — 驗證 tidb-server 與所有 GCP TiKV store 的 zone label 是否完全
#          相同（closest-replicas 必要條件，PingCAP docs）；仍非決定性，
#          執行面另需大量讀取的乾淨網路流量比對（見報告 §5.5）。
#   CRDB — EXPLAIN ANALYZE 顯示 `used follower read` + `regions: gcp` +
#          `sql nodes`/`kv nodes` 皆為 GCP 節點，近乎決定性（對受測查詢
#          本身），但僅測單一查詢型態，非完整交易。
#   YBDB — EXPLAIN (ANALYZE, DIST) 的 Storage Table Read Execution Time：
#          follower-read 應顯著低於強制 leader-read（同硬體下比較，多次
#          取樣降低單次抖動影響），非決定性，YBDB 無等價 CRDB 的
#          per-query 節點欄位可用。
#
# Usage:
#   check-nearread.sh --db tidb --host <gcp-tidb-host> --port 4000
#   check-nearread.sh --db crdb --host <gcp-crdb-host> --port 26257 --db-name tpcc
#   check-nearread.sh --db ybdb --host <gcp-ybdb-host> --port 5433 --db-name tpcc
#
# Fail-closed：任一家證據不符預期 → exit 1，印出實際輸出供人工複核。
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
    echo "[check-nearread] TiDB：核對 tidb-server 與 GCP TiKV store 的 zone label 是否完全相同（closest-replicas 必要條件）"
    OWN_ZONE=$(mysql -h "$HOST" -P "$PORT" -u root -N -e \
      "SELECT LABELS FROM information_schema.tidb_servers_info WHERE IP='$HOST';" \
      | grep -oE 'zone=[^,]+' | cut -d= -f2)
    [[ -n "$OWN_ZONE" ]] || { echo "[check-nearread] FAIL: tidb-server 無 zone label" >&2; exit 1; }
    echo "  tidb-server zone: $OWN_ZONE"

    STORE_ZONES=$(mysql -h "$HOST" -P "$PORT" -u root -N -e \
      "SELECT LABEL FROM information_schema.tikv_store_status WHERE LABEL LIKE '%\"gcp\"%';" \
      | grep -oE '"zone", "value": "[^"]+"' | grep -oE '[^"]+"$' | tr -d '"')
    echo "  GCP TiKV store zones: $(echo "$STORE_ZONES" | tr '\n' ' ')"
    [[ -n "$STORE_ZONES" ]] || { echo "[check-nearread] FAIL: 查無 GCP TiKV store" >&2; exit 1; }

    MISMATCH=0
    while IFS= read -r z; do
      [[ "$z" == "$OWN_ZONE" ]] || MISMATCH=1
    done <<< "$STORE_ZONES"
    if [[ "$MISMATCH" -eq 1 ]]; then
      echo "[check-nearread] FAIL: 至少一台 GCP TiKV store 的 zone 與 tidb-server（$OWN_ZONE）不相同——closest-replicas 對該 store 會 fallback 回 leader" >&2
      exit 1
    fi
    echo "[check-nearread] PASS: tidb-server 與所有 GCP TiKV store 的 zone label 完全相同（closest-replicas 必要條件成立；非決定性，執行面請另跑大量讀取＋netflow delta 比對，見報告 §5.5）"
    ;;
  crdb)
    echo "[check-nearread] CRDB：EXPLAIN ANALYZE 檢查（近乎決定性，非完整交易覆蓋）"
    OUT=$(psql "postgres://root@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_use_follower_reads%3Don" \
      -c "EXPLAIN ANALYZE SELECT 1 FROM stock LIMIT 1;" 2>&1)
    echo "$OUT" | grep -E 'used follower read|regions:|sql nodes|kv nodes' || true
    if ! echo "$OUT" | grep -q 'used follower read'; then
      echo "[check-nearread] FAIL: 未見 'used follower read'" >&2
      echo "$OUT" >&2
      exit 1
    fi
    # fail-closed：regions 欄位必須「恰為」gcp（不得混雜 idc），且不得出現任何
    # idc 節點；07-22 codex 審查前的版本在非 gcp 時只 WARN、不 FAIL，已修正。
    if ! echo "$OUT" | grep -qE 'regions: gcp$'; then
      echo "[check-nearread] FAIL: regions 欄位非純 gcp（可能混雜 idc 節點或查到非預期資料分布）" >&2
      echo "$OUT" >&2
      exit 1
    fi
    if echo "$OUT" | grep -E 'sql nodes|kv nodes' | grep -qiE 'idc'; then
      echo "[check-nearread] FAIL: sql/kv nodes 出現 idc 節點" >&2
      echo "$OUT" >&2
      exit 1
    fi
    echo "[check-nearread] PASS: CRDB follower read 生效、regions=gcp、sql/kv nodes 皆非 idc（僅驗證本查詢，非完整交易）"
    ;;
  ybdb)
    echo "[check-nearread] YBDB：follower-read vs leader-read 執行時間對照（多次交錯取樣，非決定性）"
    N=5
    declare -a T_FOLLOWER_ARR T_LEADER_ARR
    for i in $(seq 1 $N); do
      t=$(psql "postgres://yugabyte@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_read_only%3Don%20-c%20yb_read_from_followers%3Don%20-c%20yb_follower_read_staleness_ms%3D30000" \
        -c "EXPLAIN (ANALYZE, DIST) SELECT 1 FROM stock LIMIT 1;" 2>&1 \
        | grep -oE 'Storage Table Read Execution Time: [0-9.]+' | grep -oE '[0-9.]+$' | head -1)
      T_FOLLOWER_ARR+=("$t")
      t=$(psql "postgres://yugabyte@${HOST}:${PORT}/${DBNAME}?sslmode=disable&options=-c%20yb_read_from_followers%3Doff" \
        -c "EXPLAIN (ANALYZE, DIST) SELECT 1 FROM stock LIMIT 1;" 2>&1 \
        | grep -oE 'Storage Table Read Execution Time: [0-9.]+' | grep -oE '[0-9.]+$' | head -1)
      T_LEADER_ARR+=("$t")
    done
    echo "  follower-read samples (ms): ${T_FOLLOWER_ARR[*]}"
    echo "  leader-read samples (ms):   ${T_LEADER_ARR[*]}"
    T_FOLLOWER_MED=$(printf '%s\n' "${T_FOLLOWER_ARR[@]}" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}')
    T_LEADER_MED=$(printf '%s\n' "${T_LEADER_ARR[@]}" | sort -n | awk '{a[NR]=$1} END{print a[int((NR+1)/2)]}')
    echo "  median follower=${T_FOLLOWER_MED}ms  median leader=${T_LEADER_MED}ms"
    [[ -n "$T_FOLLOWER_MED" && -n "$T_LEADER_MED" ]] || { echo "[check-nearread] FAIL: 無法取得執行時間" >&2; exit 1; }
    AWK_RESULT=$(awk -v f="$T_FOLLOWER_MED" -v l="$T_LEADER_MED" 'BEGIN{print (f < l*0.7) ? "PASS" : "FAIL"}')
    if [[ "$AWK_RESULT" == "PASS" ]]; then
      echo "[check-nearread] PASS: follower-read 中位數顯著快於 leader-read（<70%），符合本地服務預期（非決定性）"
    else
      echo "[check-nearread] FAIL: follower-read 中位數未顯著快於 leader-read，near-read 可能未生效" >&2
      exit 1
    fi
    ;;
  *) echo "unknown --db: $DB" >&2; exit 1 ;;
esac
