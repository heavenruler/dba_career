#!/usr/bin/env bash
# phase-crossregion/scripts/relabel-tidb-gcp-zone.sh
#
# codex 審查 §5.6 建議 (2)：TiDB 嚴格 A/B 對照，需要在「GCP TiKV store 與
# tidb-server zone 相符（現況／unified）」與「不相符（07-20 批修法前的
# 同類問題／mismatched）」之間切換，且不能動 VM 重新部署（太貴、且會引入
# 部署差異當混淆變數）。
#
# 做法：只用 pd-ctl（經 tiup ctl:pd）即時改 GCP 側「非 tidb-server 所在」
# 兩台 TiKV store（gcp-dbhost-2/3）的 zone label——pd-ctl 的 label 是
# merge 語意、對已執行中的 TiKV 立即生效，不需重啟（見 PD 官方文件：
# label 用 merge 策略更新，只有 TiKV process 重啟時才會用它自己設定檔的
# label 蓋回來）。tidb-server 自己的 zone label（來自啟動設定，non-live
# changeable）維持不動，全程固定為 gcp-asia-east1——因此本測試不是逐字
# 重現 07-20 批的歷史狀態（當時 tidb-server 自己也是 zone=...-a），而是
# 控制變因更乾淨的版本：只讓「store 是否與 tidb-server 同 zone」這一個
# 變因改變，其餘不動。
#
# mode=unified：gcp-dbhost-2/3 zone 設回 gcp-asia-east1（與 tidb-server
#   所在的 gcp-dbhost-1 相同）——目前正式生效中的設定。
# mode=mismatched：gcp-dbhost-2/3 zone 改成 gcp-asia-east1-b / -c（與
#   tidb-server 不同）——gcp-dbhost-1 不動，因此理論上約 1/3 的 GCP
#   replica（落在 dbhost-1 者）仍算「近」，其餘 2/3 應退化為 leader-read，
#   與 07-20 批「只有 zone=a 算近」同一類機制，但控制變因更單純。
#
# Usage:
#   relabel-tidb-gcp-zone.sh --mode unified|mismatched \
#     [--tidb-host <tidb-entry-for-lookup> --tidb-port 4000] \
#     [--pd-host 172.24.40.32 --pd-port 2379] [--tiup-client root@172.24.40.31]
set -euo pipefail

MODE="" TIDB_HOST="" TIDB_PORT=4000
PD_HOST=172.24.40.32 PD_PORT=2379
TIUP_CLIENT=root@172.24.40.31
while [[ $# -gt 0 ]]; do
  case $1 in
    --mode) MODE=$2; shift 2 ;;
    --tidb-host) TIDB_HOST=$2; shift 2 ;;
    --tidb-port) TIDB_PORT=$2; shift 2 ;;
    --pd-host) PD_HOST=$2; shift 2 ;;
    --pd-port) PD_PORT=$2; shift 2 ;;
    --tiup-client) TIUP_CLIENT=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${MODE:?--mode required (unified|mismatched)}"
: "${TIDB_HOST:?--tidb-host required (any reachable TiDB entry, for store-id lookup)}"

case "$MODE" in
  unified)    ZONE_2="gcp-asia-east1";   ZONE_3="gcp-asia-east1" ;;
  mismatched) ZONE_2="gcp-asia-east1-b"; ZONE_3="gcp-asia-east1-c" ;;
  *) echo "unknown --mode: $MODE (want unified|mismatched)" >&2; exit 1 ;;
esac

echo "[relabel-tidb] 查 GCP TiKV store ID（10.160.152.12 / .13）"
STORE_2=$(mysql -h "$TIDB_HOST" -P "$TIDB_PORT" -u root -N -e \
  "SELECT STORE_ID FROM information_schema.tikv_store_status WHERE ADDRESS LIKE '10.160.152.12:%';")
STORE_3=$(mysql -h "$TIDB_HOST" -P "$TIDB_PORT" -u root -N -e \
  "SELECT STORE_ID FROM information_schema.tikv_store_status WHERE ADDRESS LIKE '10.160.152.13:%';")
[[ -n "$STORE_2" && -n "$STORE_3" ]] || { echo "[relabel-tidb] FAIL: 查無 store id（.12=$STORE_2 .13=$STORE_3）" >&2; exit 1; }
echo "  store(.12)=$STORE_2  store(.13)=$STORE_3"

pd_ctl() {
  ssh -o ConnectTimeout=8 "$TIUP_CLIENT" \
    "/root/.tiup/bin/tiup ctl:pd -u http://$PD_HOST:$PD_PORT $* 2>&1" \
    || ssh -o ConnectTimeout=8 "$TIUP_CLIENT" \
      "/root/.tiup/bin/tiup ctl:v8.5.2 pd -u http://$PD_HOST:$PD_PORT $* 2>&1"
}

echo "[relabel-tidb] mode=$MODE → store($STORE_2).zone=$ZONE_2  store($STORE_3).zone=$ZONE_3"
pd_ctl "store label $STORE_2 zone=$ZONE_2"
pd_ctl "store label $STORE_3 zone=$ZONE_3"

echo "[relabel-tidb] 驗證（PD 回報的目前 label）"
ACTUAL=$(mysql -h "$TIDB_HOST" -P "$TIDB_PORT" -u root -N -e \
  "SELECT STORE_ID, LABEL FROM information_schema.tikv_store_status WHERE ADDRESS LIKE '10.160.152.1%:%';")
echo "$ACTUAL"
if ! echo "$ACTUAL" | grep -q "\"zone\", \"value\": \"$ZONE_2\""; then
  echo "[relabel-tidb] FAIL: store($STORE_2) zone 未變更為 $ZONE_2" >&2
  exit 1
fi
if ! echo "$ACTUAL" | grep -q "\"zone\", \"value\": \"$ZONE_3\""; then
  echo "[relabel-tidb] FAIL: store($STORE_3) zone 未變更為 $ZONE_3" >&2
  exit 1
fi
echo "[relabel-tidb] PASS: mode=$MODE 已生效"
