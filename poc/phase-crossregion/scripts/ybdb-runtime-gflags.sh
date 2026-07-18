#!/usr/bin/env bash
# ybdb-runtime-gflags.sh — 以 yb-ts-cli set_flag 於 runtime 強制 tserver gflag，
# 並 curl /varz 驗證生效（fail-closed）。
#
# 背景（2026-07-18）：yugabyted start 的 --tserver_flags 對部分 runtime flag
# 不生效——0717/0718 兩批 varz 皆顯示 transaction_rpc_timeout_ms=5000（設 15000）、
# enable_automatic_tablet_splitting=true（設 false），而同串的 memory_limit 等
# 均正常套用。本 script 是 workaround：deploy 後直接 runtime set + 驗證。
# 注意：set_flag 為 volatile——tserver 重啟即還原；suite 期間不重啟則有效。
#
# 跑在 .31（可直連 IDC/GCP 內 IP）；yb-ts-cli 透過 .32 的 /opt/yugabyte 執行。
set -euo pipefail

FLAG_NAME="${FLAG_NAME:-transaction_rpc_timeout_ms}"
FLAG_VALUE="${FLAG_VALUE:-15000}"
TSERVERS="${TSERVERS:-172.24.40.32 172.24.40.33 172.24.40.34 10.160.152.11 10.160.152.12 10.160.152.13}"
YB_HOST="${YB_HOST:-172.24.40.32}"

echo "[ybdb-runtime-gflags] set $FLAG_NAME=$FLAG_VALUE on: $TSERVERS"
for ip in $TSERVERS; do
  ssh -o StrictHostKeyChecking=accept-new "root@$YB_HOST" \
    "/opt/yugabyte/bin/yb-ts-cli --server_address=$ip:9100 set_flag $FLAG_NAME $FLAG_VALUE" \
    || { echo "FAIL: set_flag $ip" >&2; exit 1; }
done

fail=0
for ip in $TSERVERS; do
  v=$(curl -s --max-time 15 "http://$ip:9000/varz" \
      | grep -oE "$FLAG_NAME</td><td >[^<]*" | grep -oE '[^ >]*$' || true)
  if [[ "$v" == "$FLAG_VALUE" ]]; then
    echo "  OK: $ip $FLAG_NAME=$v"
  else
    echo "  FAIL: $ip $FLAG_NAME='$v' (expect $FLAG_VALUE)" >&2
    fail=1
  fi
done
[[ $fail -eq 0 ]] || exit 1
echo "[ybdb-runtime-gflags] PASS: 6/6 tserver $FLAG_NAME=$FLAG_VALUE"
