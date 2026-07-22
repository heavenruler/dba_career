#!/usr/bin/env bash
# phase-crossregion/scripts/verify-tidb-zone-ab.sh
#
# codex 審查 §5.6 建議 (2)：同一份資料、同一組查詢、同一執行順序，在不同
# zone 設定（見 relabel-tidb-gcp-zone.sh）與不同 tidb_replica_read session
# 設定下重測 netflow 比值，取代 07-21 單一 unified-zone 數字缺乏 before/
# after 對照的缺口。
#
# 用真實 ORDER_STATUS/STOCK_LEVEL 交易（同 check-nearread-realtxn.sh 的
# TiDB burst 邏輯）+ netflow byte delta，而非單筆 point lookup。
#
# Usage:
#   verify-tidb-zone-ab.sh --label <unified-closest|unified-leader|mismatched-closest> \
#     --host <gcp-tidb-host> --port 4000 --replica-read closest-replicas|leader \
#     [--db-name tpcc] [--queries 200]
set -uo pipefail

LABEL="" HOST="" PORT=4000 DBNAME="tpcc" REPLICA_READ="closest-replicas" N=200
while [[ $# -gt 0 ]]; do
  case $1 in
    --label) LABEL=$2; shift 2 ;;
    --host) HOST=$2; shift 2 ;;
    --port) PORT=$2; shift 2 ;;
    --db-name) DBNAME=$2; shift 2 ;;
    --replica-read) REPLICA_READ=$2; shift 2 ;;
    --queries) N=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done
: "${LABEL:?--label required}"
: "${HOST:?--host required}"

SAMPLES=("1 3 500" "2 7 1200" "3 1 2999" "4 10 42")

NETFLOW_SH="$(cd "$(dirname "$0")/../.." && pwd)/tests/common/netflow-snapshot.sh"
SNAP_DIR=$(mktemp -d)
LABEL_SAFE=$(echo "$LABEL" | tr -c 'a-zA-Z0-9' '-')

echo "[zone-ab] label=$LABEL replica_read=$REPLICA_READ host=$HOST queries=$N"
bash "$NETFLOW_SH" --out-dir "$SNAP_DIR" --label "pre-$LABEL_SAFE" --hosts "$HOST" \
  || echo "  WARN: netflow pre snapshot 失敗"

for i in $(seq 1 "$N"); do
  s="${SAMPLES[$((i % 4))]}"
  read -r w d c <<< "$s"
  mysql -h "$HOST" -P "$PORT" -u root -N -e "
    SET SESSION tidb_replica_read='$REPLICA_READ';
    SELECT c_balance, c_first, c_middle, c_last FROM customer WHERE c_w_id=$w AND c_d_id=$d AND c_id=$c;
    SELECT o_id, o_carrier_id, o_entry_d FROM orders WHERE o_w_id=$w AND o_d_id=$d AND o_c_id=$c ORDER BY o_id DESC LIMIT 1;
    SELECT d_next_o_id FROM district WHERE d_w_id=$w AND d_id=$d;
  " "$DBNAME" >/dev/null 2>&1
done

bash "$NETFLOW_SH" --out-dir "$SNAP_DIR" --label "post-$LABEL_SAFE" --hosts "$HOST" \
  || echo "  WARN: netflow post snapshot 失敗"

if [[ -s "$SNAP_DIR/netflow-pre-$LABEL_SAFE.json" && -s "$SNAP_DIR/netflow-post-$LABEL_SAFE.json" ]]; then
  python3 - "$SNAP_DIR/netflow-pre-$LABEL_SAFE.json" "$SNAP_DIR/netflow-post-$LABEL_SAFE.json" "$HOST" "$LABEL" <<'PYEOF'
import json, sys
pre_f, post_f, host, label = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
pre = json.load(open(pre_f))["hosts"][host]["traffic_bytes"]
post = json.load(open(post_f))["hosts"][host]["traffic_bytes"]
d_gcp = post["iptables_to_gcp_bytes"] - pre["iptables_to_gcp_bytes"]
d_idc = post["iptables_to_idc_bytes"] - pre["iptables_to_idc_bytes"]
ratio = "N/A" if d_gcp <= 0 else f"{d_idc*100.0/d_gcp:.1f}"
print(f"[zone-ab] RESULT label={label} delta_to_gcp={d_gcp}B delta_to_idc={d_idc}B ratio={ratio}%")
PYEOF
else
  echo "[zone-ab] WARN: netflow snapshot 檔案缺失，無法計算 ratio（label=$LABEL）" >&2
fi
rm -rf "$SNAP_DIR"
