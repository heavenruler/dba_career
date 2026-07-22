#!/usr/bin/env bash
# phase-crossregion/scripts/check-staleness.sh
#
# codex 審查 §5.6 建議 (3)：三家近讀機制皆涉及「可能讀到過期資料」的語意
# ——CRDB `default_transaction_use_follower_reads=on` 隱式套用
# `AS OF SYSTEM TIME follower_read_timestamp()`（設計上約落後現在
# ~4.8s，取決於 kv.closed_timestamp.target_duration）；YBDB 明確設定
# `yb_follower_read_staleness_ms=30000`（允許讀到 30 秒前的資料）；TiDB
# closest-replicas 理論上不引入額外過期（讀的是已同步到該副本的資料，
# 受 raft 複寫延遲界定，非顯式歷史時間點）。本腳本實測「IDC 端寫入後，
# GCP 端近讀多久才看得到」，核對三家實際落差是否符合各自機制的預期量級，
# 而非僅信任官方文件的設計值。
#
# 方法：IDC（leader）端寫入 item.i_price 唯一 marker 值 → GCP 端用近讀
# session 設定輪詢直到看到新值，記錄延遲；同時用 GCP 端 leader-read（不
# 啟用近讀）做基準對照（預期幾乎即時可見，用來確認寫入/複寫本身沒問題，
# 延遲差異單純來自近讀機制本身）。
#
# Usage:
#   check-staleness.sh --db tidb --idc-host <idc-leader> --idc-port 4000 \
#     --gcp-host <gcp-host> --gcp-port 4000 [--timeout-sec 15]
#   check-staleness.sh --db crdb --idc-host <idc-leader> --idc-port 26257 \
#     --gcp-host <gcp-host> --gcp-port 26257 [--timeout-sec 15]
#   check-staleness.sh --db ybdb --idc-host <idc-leader> --idc-port 5433 \
#     --gcp-host <gcp-host> --gcp-port 5433 [--timeout-sec 40]
#
# 不 fail-closed（探索性量測，非通過/失敗判定）——只印出實測延遲供人工
# 核對是否落在合理量級；若逾時未看到新值才視為異常（exit 1）。
set -uo pipefail

DB="" IDC_HOST="" IDC_PORT="" GCP_HOST="" GCP_PORT="" DBNAME="tpcc" TIMEOUT_SEC=15
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --idc-host) IDC_HOST=$2; shift 2 ;;
    --idc-port) IDC_PORT=$2; shift 2 ;;
    --gcp-host) GCP_HOST=$2; shift 2 ;;
    --gcp-port) GCP_PORT=$2; shift 2 ;;
    --db-name) DBNAME=$2; shift 2 ;;
    --timeout-sec) TIMEOUT_SEC=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${DB:?--db required (tidb|crdb|ybdb)}"
: "${IDC_HOST:?--idc-host required}"
: "${IDC_PORT:?--idc-port required}"
: "${GCP_HOST:?--gcp-host required}"
: "${GCP_PORT:?--gcp-port required}"

I_ID=1

now_ms() { python3 -c 'import time; print(int(time.time()*1000))'; }

poll_until() {  # $1=label $2=read_fn_name（回傳目前 i_price 或空字串）
  local label="$1" fn="$2"
  local start_ms now elapsed val
  start_ms=$(now_ms)
  local deadline=$((start_ms + TIMEOUT_SEC*1000))
  while true; do
    val=$("$fn")
    if [[ "$val" == "$MARKER" ]]; then
      now=$(now_ms)
      elapsed=$((now - start_ms))
      echo "  $label: 可見，延遲 ${elapsed}ms"
      return 0
    fi
    now=$(now_ms)
    if [[ $now -ge $deadline ]]; then
      echo "  $label: TIMEOUT（超過 ${TIMEOUT_SEC}s 仍未看到新值，目前值=$val 預期=$MARKER）" >&2
      return 1
    fi
    sleep 0.1
  done
}

case "$DB" in
  tidb)
    OLD=$(mysql -h "$IDC_HOST" -P "$IDC_PORT" -u root -N -e "SELECT i_price FROM item WHERE i_id=$I_ID;" "$DBNAME")
    MARKER=$(python3 -c "print(round(float('$OLD')+0.01,2))")
    echo "[staleness] TiDB：item.i_price $OLD -> $MARKER（IDC leader 寫入）"
    mysql -h "$IDC_HOST" -P "$IDC_PORT" -u root -e "UPDATE item SET i_price=$MARKER WHERE i_id=$I_ID;" "$DBNAME"
    read_near()   { mysql -h "$GCP_HOST" -P "$GCP_PORT" -u root -N -e "SET SESSION tidb_replica_read='closest-replicas'; SELECT i_price FROM item WHERE i_id=$I_ID;" "$DBNAME" 2>/dev/null | tail -1; }
    read_leader() { mysql -h "$GCP_HOST" -P "$GCP_PORT" -u root -N -e "SET SESSION tidb_replica_read='leader'; SELECT i_price FROM item WHERE i_id=$I_ID;" "$DBNAME" 2>/dev/null | tail -1; }
    ;;
  crdb)
    OLD=$(psql "postgres://root@${IDC_HOST}:${IDC_PORT}/${DBNAME}?sslmode=disable" -tA -c "SELECT i_price FROM item WHERE i_id=$I_ID;")
    MARKER=$(python3 -c "print(round(float('$OLD')+0.01,2))")
    echo "[staleness] CRDB：item.i_price $OLD -> $MARKER（IDC leader 寫入）"
    psql "postgres://root@${IDC_HOST}:${IDC_PORT}/${DBNAME}?sslmode=disable" -c "UPDATE item SET i_price=$MARKER WHERE i_id=$I_ID;" >/dev/null
    read_near()   { psql "postgres://root@${GCP_HOST}:${GCP_PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_use_follower_reads%3Don%20-c%20default_transaction_read_only%3Don" -tA -c "SELECT i_price FROM item WHERE i_id=$I_ID;" 2>/dev/null; }
    read_leader() { psql "postgres://root@${GCP_HOST}:${GCP_PORT}/${DBNAME}?sslmode=disable" -tA -c "SELECT i_price FROM item WHERE i_id=$I_ID;" 2>/dev/null; }
    ;;
  ybdb)
    OLD=$(psql "postgres://yugabyte@${IDC_HOST}:${IDC_PORT}/${DBNAME}?sslmode=disable" -tA -c "SELECT i_price FROM item WHERE i_id=$I_ID;")
    MARKER=$(python3 -c "print(round(float('$OLD')+0.01,2))")
    echo "[staleness] YBDB：item.i_price $OLD -> $MARKER（IDC leader 寫入）"
    psql "postgres://yugabyte@${IDC_HOST}:${IDC_PORT}/${DBNAME}?sslmode=disable" -c "UPDATE item SET i_price=$MARKER WHERE i_id=$I_ID;" >/dev/null
    read_near()   { psql "postgres://yugabyte@${GCP_HOST}:${GCP_PORT}/${DBNAME}?sslmode=disable&options=-c%20default_transaction_read_only%3Don%20-c%20yb_read_from_followers%3Don%20-c%20yb_follower_read_staleness_ms%3D30000" -tA -c "SELECT i_price FROM item WHERE i_id=$I_ID;" 2>/dev/null; }
    read_leader() { psql "postgres://yugabyte@${GCP_HOST}:${GCP_PORT}/${DBNAME}?sslmode=disable&options=-c%20yb_read_from_followers%3Doff" -tA -c "SELECT i_price FROM item WHERE i_id=$I_ID;" 2>/dev/null; }
    ;;
  *) echo "unknown --db: $DB" >&2; exit 1 ;;
esac

echo "[staleness] 基準線（GCP leader-read，預期近乎即時可見，用於確認寫入/複寫本身無異常）："
poll_until "GCP leader-read" read_leader
LEADER_RC=$?

echo "[staleness] 近讀（GCP near-read，此為本測試真正關心的數字）："
poll_until "GCP near-read" read_near
NEAR_RC=$?

if [[ $LEADER_RC -ne 0 ]]; then
  echo "[staleness] WARN: leader-read 基準線也逾時——可能是複寫本身有問題，非近讀機制的過期讀取語意，near-read 的數字在此情況下不可信" >&2
fi
if [[ $NEAR_RC -ne 0 ]]; then
  echo "[staleness] FAIL: near-read 逾時未看到新值（>${TIMEOUT_SEC}s）" >&2
  exit 1
fi
echo "[staleness] 完成"
