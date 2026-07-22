#!/usr/bin/env bash
# verify-a8-batch-smoke.sh — codex §5.6 (2)(3) 補強驗證 driver（TiDB→YBDB→CRDB）
#
# 跑在 .31 上（nohup detached）：
#   make verify-a8-detach TPCC_TS=<ts>
#
# 背景：A7(1)(4)（見 verify-a7-smoke.sh／§5.7）已完成，意外抓到 go-tpc
# 結構性 bug 並修復。本輪補 codex §5.6 剩餘建議中的 (2)(3)：
#   (2) TiDB 嚴格 A/B：同資料/查詢/順序，unified／mismatched zone 各自搭配
#       closest-replicas／leader 四組對照（見 relabel-tidb-gcp-zone.sh／
#       verify-tidb-zone-ab.sh），取代 07-21 單一 unified 數字缺乏 before/
#       after 對照的缺口。
#   (3) staleness/freshness：IDC 寫入後 GCP 近讀多久可見（見
#       check-staleness.sh），核對是否符合三家近讀機制各自的預期量級。
# 額外補 YBDB go-tpc 反事實（A8 §8 遺留缺口）：套用 go-tpc patch 前後，
# 用真實 go-tpc aaro-smoke 流量的 netflow 比值對照，直接驗證 YBDB 拿掉
# patch 是否也會像 CRDB 一樣近讀實質失效（CRDB 會報錯，YBDB 依官方文件
# 是靜默 fallback，不會報錯，故用 netflow 而非錯誤率判定）。
# (5)（統一 zone 對 P-B/未來 GCP replica 數的故障域衝擊）不在本輪範圍——
# 只影響 P-B，本輪與後續 aaro#2 都是 P-A，見報告 §8 討論。
#
# 前提（Mac 端先完成）：phase1 + phase2（6 台 VM 已重建，用修好 SSH 重試
# 的版本）。GO_TPC_PATCHED_BIN 環境變數指向已 rsync 到 .31 的 patched
# go-tpc linux/amd64 binary（本地 Mac 上用 patches/go-tpc-readonly-fix.patch
# 預先 build，見 SESSION-HISTORY，避免 detached 執行期間依賴對外網路
# clone github）。
#
# Markers（/tmp/poc-tpcc/logs/ 下）：
#   verify-a8-<TS>.done   = 全部成功
#   verify-a8-<TS>.failed = 失敗（含 exit code 與階段）
# 結果彙整：/tmp/poc-tpcc/logs/verify-a8-<TS>-results.md
set -euo pipefail

: "${TPCC_TS:?TPCC_TS required}"
PLACEMENT="${PLACEMENT:-P-A}"
DBS="${DBS:-tidb ybdb crdb}"
POC=/tmp/poc
MK="$POC/phase-crossregion/Makefile"
SCRIPTS="$POC/phase-crossregion/scripts"
LOGDIR=/tmp/poc-tpcc/logs
mkdir -p "$LOGDIR"
DONE="$LOGDIR/verify-a8-$TPCC_TS.done"
FAILED="$LOGDIR/verify-a8-$TPCC_TS.failed"
RESULTS="$LOGDIR/verify-a8-$TPCC_TS-results.md"
STAGE="init"

: "${GO_TPC_PATCHED_BIN:?GO_TPC_PATCHED_BIN required — patched go-tpc linux/amd64 binary path on .31}"
[[ -f "$MK" ]] || { echo "FATAL: $MK missing — detach target 需先 rsync Makefile" >&2; exit 1; }
[[ -f "$GO_TPC_PATCHED_BIN" ]] || { echo "FATAL: $GO_TPC_PATCHED_BIN missing" >&2; exit 1; }

GCP_DB_HOST=10.160.152.11
GCP_CLIENT=root@10.160.152.15
IDC_ADMIN=172.24.40.31
declare -A DB_PORT=([tidb]=4000 [ybdb]=5433 [crdb]=26257)
declare -A IDC_HOST=([tidb]=172.24.40.32 [ybdb]=172.24.40.32 [crdb]=172.24.40.32)

KNOBS_PREP=(WAREHOUSES=4 ROUNDS=1 WARMUP_SEC=30 RUN_SEC=60 THREADS_LIST=16 PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")
# YBDB 反事實用的短跑（足夠產生可判讀的 netflow 量級，非正式吞吐量測）。
# 沿用同一個 TPCC_TS（不可用不同 TS 後綴）——prepare-bridge（run-vm6-aa.sh）
# 靠「同 TS」比對 plain anchor 目錄與 aaro 目錄，TS 不符會找不到已 prepare
# 的資料。兩輪（未套 patch／已套 patch）因此會寫入同一個 artifact 目錄
# （後者覆蓋前者）——這裡不需要分開保存原始 artifact，錯誤行數改從本腳本
# 自己存的 stdout log（$LOGDIR/verify-a8-$TPCC_TS-ybdb-{nopatch,patched}-run.log）
# 取得，netflow ratio 本來就用不同 --label 分開存，不受影響。
KNOBS_COUNTERFACTUAL=(WAREHOUSES=4 ROUNDS=1 WARMUP_SEC=10 RUN_SEC=60 THREADS_LIST=32 PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")

log() { echo "[verify-a8 $(date '+%H:%M:%S')] $*"; }
run_db() { [[ " $DBS " == *" $1 "* ]]; }
result() { echo "$*" >> "$RESULTS"; }

_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"verify-a8","ts":"%s","status":"FAILED","stage":"%s","exit_code":%d,"failed_at":"%s"}\n' \
    "$TPCC_TS" "$STAGE" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$FAILED"
  log "FAILED at stage=$STAGE (exit=$rc) — marker $FAILED"
}
trap '_failed' EXIT

netflow_ratio() {  # $1=out-dir $2=label $3=host -> prints "delta_gcp delta_idc ratio"
  python3 - "$1/netflow-pre-$2.json" "$1/netflow-post-$2.json" "$3" <<'PYEOF'
import json, sys
try:
    pre = json.load(open(sys.argv[1]))["hosts"][sys.argv[3]]["traffic_bytes"]
    post = json.load(open(sys.argv[2]))["hosts"][sys.argv[3]]["traffic_bytes"]
    d_gcp = post["iptables_to_gcp_bytes"] - pre["iptables_to_gcp_bytes"]
    d_idc = post["iptables_to_idc_bytes"] - pre["iptables_to_idc_bytes"]
    ratio = "N/A" if d_gcp <= 0 else f"{d_idc*100.0/d_gcp:.1f}"
    print(f"{d_gcp} {d_idc} {ratio}")
except Exception as e:
    print(f"ERROR ERROR {e}")
PYEOF
}

cd "$POC"
{
  echo "# codex §5.6 (2)(3) 補強驗證結果（smoke 規模 W=4，TS=$TPCC_TS）"
  echo ""
  echo "回應 codex §5.6 剩餘建議 (2) TiDB 嚴格 A/B、(3) staleness/freshness，"
  echo "外加 YBDB go-tpc 反事實。(5) 不在本輪範圍（僅影響 P-B）。"
} > "$RESULTS"
log "window start TS=$TPCC_TS PLACEMENT=$PLACEMENT DBS=$DBS"

STAGE="bootstrap-gcp-client"
log "=== bootstrap GCP client (.15) go-tpc/tests/common（冪等；VM 剛重建必跑）==="
make -f "$MK" phase2-bootstrap-gcp-client

if run_db tidb; then
  STAGE="tidb-deploy"
  log "=== TiDB: deploy ==="
  make -f "$MK" phase3-tidb-deploy "${KNOBS_PREP[@]}"

  STAGE="tidb-anchor-prepare"
  log "=== TiDB: ANCHOR_ONLY prepare（W=4）==="
  make -f "$MK" phase6-tidb-smoke ANCHOR_ONLY=1 "${KNOBS_PREP[@]}"

  STAGE="tidb-staleness"
  log "=== TiDB: staleness/freshness (§5.6-3) ==="
  result "" ; result "## TiDB"
  result "### (3) staleness/freshness"
  STALE_LOG="$LOGDIR/verify-a8-$TPCC_TS-tidb-staleness.log"
  bash "$SCRIPTS/check-staleness.sh" --db tidb \
    --idc-host "${IDC_HOST[tidb]}" --idc-port "${DB_PORT[tidb]}" \
    --gcp-host "$GCP_DB_HOST" --gcp-port "${DB_PORT[tidb]}" --timeout-sec 15 \
    > "$STALE_LOG" 2>&1 && result "完成（詳見 $(basename "$STALE_LOG")）" \
    || result "**異常**（詳見 $(basename "$STALE_LOG")）"
  cat "$STALE_LOG" >> "$LOGDIR/verify-a8-$TPCC_TS.log"

  STAGE="tidb-zone-ab"
  log "=== TiDB: 嚴格 A/B（§5.6-2）==="
  result "### (2) TiDB 嚴格 A/B（unified/mismatched × closest/leader）"
  AB_LOG="$LOGDIR/verify-a8-$TPCC_TS-tidb-zone-ab.log"
  {
    bash "$SCRIPTS/relabel-tidb-gcp-zone.sh" --mode unified --tidb-host "${IDC_HOST[tidb]}"
    bash "$SCRIPTS/verify-tidb-zone-ab.sh" --label unified-closest --host "$GCP_DB_HOST" --replica-read closest-replicas
    bash "$SCRIPTS/verify-tidb-zone-ab.sh" --label unified-leader  --host "$GCP_DB_HOST" --replica-read leader
    bash "$SCRIPTS/relabel-tidb-gcp-zone.sh" --mode mismatched --tidb-host "${IDC_HOST[tidb]}"
    bash "$SCRIPTS/verify-tidb-zone-ab.sh" --label mismatched-closest --host "$GCP_DB_HOST" --replica-read closest-replicas
    bash "$SCRIPTS/verify-tidb-zone-ab.sh" --label mismatched-leader  --host "$GCP_DB_HOST" --replica-read leader
  } > "$AB_LOG" 2>&1
  echo "  4 組 ratio（見 $(basename "$AB_LOG") 內 RESULT 行）：" >> "$RESULTS"
  grep '^\[zone-ab\] RESULT' "$AB_LOG" | sed 's/^/  - /' >> "$RESULTS" || true
  cat "$AB_LOG" >> "$LOGDIR/verify-a8-$TPCC_TS.log"

  STAGE="tidb-teardown"
  make -f "$MK" teardown-tidb "${KNOBS_PREP[@]}"
  log "=== TiDB done ==="
fi

if run_db ybdb; then
  STAGE="ybdb-deploy"
  log "=== YBDB: deploy ==="
  make -f "$MK" phase4-ybdb-deploy phase4-ybdb-fix6n "${KNOBS_PREP[@]}"

  STAGE="ybdb-anchor-prepare"
  log "=== YBDB: ANCHOR_ONLY prepare（W=4）==="
  make -f "$MK" phase7-ybdb-smoke ANCHOR_ONLY=1 "${KNOBS_PREP[@]}"

  STAGE="ybdb-staleness"
  log "=== YBDB: staleness/freshness (§5.6-3) ==="
  result "" ; result "## YBDB"
  result "### (3) staleness/freshness"
  STALE_LOG="$LOGDIR/verify-a8-$TPCC_TS-ybdb-staleness.log"
  bash "$SCRIPTS/check-staleness.sh" --db ybdb \
    --idc-host "${IDC_HOST[ybdb]}" --idc-port "${DB_PORT[ybdb]}" \
    --gcp-host "$GCP_DB_HOST" --gcp-port "${DB_PORT[ybdb]}" --timeout-sec 40 \
    > "$STALE_LOG" 2>&1 && result "完成（詳見 $(basename "$STALE_LOG")）" \
    || result "**異常**（詳見 $(basename "$STALE_LOG")）"
  cat "$STALE_LOG" >> "$LOGDIR/verify-a8-$TPCC_TS.log"

  # go-tpc GCP-side stdout（ORDER_STATUS_ERR/STOCK_LEVEL_ERR 的 [Summary] 行）
  # 經 run-vm6-aa.sh 的 ssh 連線串流回 .31、被下面 make 呼叫的 stdout 捕捉，
  # 故直接從本腳本存的 log grep 即可，不需另外讀 artifact 目錄裡的原始檔。
  count_err() {  # $1=logfile -> 印出 ORDER_STATUS_ERR + STOCK_LEVEL_ERR 加總
    # 實際觀測（22:53）：go-tpc GCP 側輸出前面帶 "[gcp] " 前綴（如
    # "[gcp] [Summary] ORDER_STATUS - ..."），且 0 錯誤時根本不印 _ERR
    # 摘要行（非印 Count: 0）——故 grep 找不到東西是正常情況，不能讓
    # pipefail 把「0 錯誤」誤判成腳本錯誤而觸發 set -e 中止整個 driver。
    grep -E '\[Summary\] (ORDER_STATUS|STOCK_LEVEL)_ERR - ' "$1" 2>/dev/null \
      | grep -oE 'Count:\s+[0-9]+' | grep -oE '[0-9]+' \
      | awk '{s+=$1} END{print s+0}'
    return 0
  }

  STAGE="ybdb-counterfactual-nopatch"
  log "=== YBDB: go-tpc 反事實（未套 patch，stock go-tpc，真實負載 netflow）==="
  result "### YBDB go-tpc 反事實（額外，非 codex 原始 5 項）"
  NF_DIR=$(mktemp -d)
  NOPATCH_LOG="$LOGDIR/verify-a8-$TPCC_TS-ybdb-nopatch-run.log"
  bash "$POC/tests/common/netflow-snapshot.sh" --out-dir "$NF_DIR" --label pre-nopatch --hosts "$GCP_DB_HOST"
  make -f "$MK" phase7-ybdb-aaro-smoke "${KNOBS_COUNTERFACTUAL[@]}" \
    > "$NOPATCH_LOG" 2>&1 || true
  bash "$POC/tests/common/netflow-snapshot.sh" --out-dir "$NF_DIR" --label post-nopatch --hosts "$GCP_DB_HOST"
  read -r D_GCP_NOPATCH D_IDC_NOPATCH RATIO_NOPATCH <<< "$(netflow_ratio "$NF_DIR" nopatch "$GCP_DB_HOST")"
  ERR_NOPATCH=$(count_err "$NOPATCH_LOG")
  result "- 未套 patch：ratio=${RATIO_NOPATCH}%（delta_gcp=${D_GCP_NOPATCH}B delta_idc=${D_IDC_NOPATCH}B）ORDER_STATUS/STOCK_LEVEL 錯誤數=${ERR_NOPATCH:-0}"

  STAGE="ybdb-apply-patch"
  log "=== YBDB: 套用 go-tpc patch 到 GCP client ==="
  ssh "$GCP_CLIENT" "cp -f /usr/local/bin/go-tpc /usr/local/bin/go-tpc.orig 2>/dev/null || true"
  scp -o ProxyJump="root@$IDC_ADMIN" "$GO_TPC_PATCHED_BIN" "$GCP_CLIENT:/usr/local/bin/go-tpc" \
    || scp "$GO_TPC_PATCHED_BIN" "$GCP_CLIENT:/usr/local/bin/go-tpc"
  ssh "$GCP_CLIENT" "chmod +x /usr/local/bin/go-tpc; /usr/local/bin/go-tpc --version 2>&1 || true"

  STAGE="ybdb-counterfactual-patched"
  log "=== YBDB: go-tpc 反事實（已套 patch，真實負載 netflow）==="
  PATCHED_LOG="$LOGDIR/verify-a8-$TPCC_TS-ybdb-patched-run.log"
  bash "$POC/tests/common/netflow-snapshot.sh" --out-dir "$NF_DIR" --label pre-patched --hosts "$GCP_DB_HOST"
  make -f "$MK" phase7-ybdb-aaro-smoke "${KNOBS_COUNTERFACTUAL[@]}" \
    > "$PATCHED_LOG" 2>&1 || true
  bash "$POC/tests/common/netflow-snapshot.sh" --out-dir "$NF_DIR" --label post-patched --hosts "$GCP_DB_HOST"
  read -r D_GCP_PATCHED D_IDC_PATCHED RATIO_PATCHED <<< "$(netflow_ratio "$NF_DIR" patched "$GCP_DB_HOST")"
  ERR_PATCHED=$(count_err "$PATCHED_LOG")
  result "- 已套 patch：ratio=${RATIO_PATCHED}%（delta_gcp=${D_GCP_PATCHED}B delta_idc=${D_IDC_PATCHED}B）ORDER_STATUS/STOCK_LEVEL 錯誤數=${ERR_PATCHED:-0}"
  rm -rf "$NF_DIR"

  STAGE="ybdb-teardown"
  make -f "$MK" teardown-ybdb "${KNOBS_PREP[@]}"
  log "=== YBDB done ==="
fi

if run_db crdb; then
  STAGE="crdb-deploy"
  log "=== CRDB: deploy ==="
  make -f "$MK" phase5-crdb-deploy "${KNOBS_PREP[@]}"

  STAGE="crdb-anchor-prepare"
  log "=== CRDB: ANCHOR_ONLY prepare（W=4）==="
  make -f "$MK" phase8-crdb-smoke ANCHOR_ONLY=1 "${KNOBS_PREP[@]}"

  STAGE="crdb-staleness"
  log "=== CRDB: staleness/freshness (§5.6-3) ==="
  result "" ; result "## CRDB"
  result "### (3) staleness/freshness"
  STALE_LOG="$LOGDIR/verify-a8-$TPCC_TS-crdb-staleness.log"
  bash "$SCRIPTS/check-staleness.sh" --db crdb \
    --idc-host "${IDC_HOST[crdb]}" --idc-port "${DB_PORT[crdb]}" \
    --gcp-host "$GCP_DB_HOST" --gcp-port "${DB_PORT[crdb]}" --timeout-sec 15 \
    > "$STALE_LOG" 2>&1 && result "完成（詳見 $(basename "$STALE_LOG")）" \
    || result "**異常**（詳見 $(basename "$STALE_LOG")）"
  cat "$STALE_LOG" >> "$LOGDIR/verify-a8-$TPCC_TS.log"

  STAGE="crdb-teardown"
  make -f "$MK" teardown-crdb "${KNOBS_PREP[@]}"
  log "=== CRDB done ==="
fi

STAGE="done"
printf '{"window":"verify-a8","ts":"%s","status":"DONE","finished_at":"%s"}\n' \
  "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$DONE"
log "ALL DONE — marker $DONE，結果: $RESULTS"
log "回 Mac 跑 make phase9 (fetch+destroy) TPCC_TS=$TPCC_TS（本 driver 未動 VM 本身）"
