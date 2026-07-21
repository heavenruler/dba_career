#!/usr/bin/env bash
# verify-a7-smoke.sh — A7(1)(4) 補強驗證 driver（TiDB→YBDB→CRDB）
#
# 跑在 .31 上（nohup detached）：
#   make verify-a7-detach TPCC_TS=<ts>
#
# 背景：codex 獨立審查（2026-07-22，見 XCROSS-AARO-CLOSING-REPORT-DRAFT.md
# §5.6）建議的後續補做中，(1) 用真實 ORDER_STATUS/STOCK_LEVEL 交易取代
# `LIMIT 1` 單筆查詢重新驗證、(4) 至少重跑一個高併發檔位（t128）並在執行
# 期間採集近讀證據——本 driver 補齊兩項，範圍限於 smoke 規模（W=4 anchor
# 資料，非完整 W=128 全批次；本輪吞吐數字僅供機制驗證，不進報告 §1-§6）。
#
# 每家：deploy → ANCHOR_ONLY prepare（W=4）→
#   A7(1): check-nearread-realtxn.sh（真實交易語句，idle 連線）→
#   A7(4): phase{N}-{db}-aaro-smoke THREADS_LIST=128（前景）＋
#          sample-nearread-loop.sh 同時在背景採樣 →
#   check-aaro-artifacts.py（確認這輪 smoke 本身 0 錯誤，非近讀判定）→
#   teardown-{db}（.31 軟體層 teardown，VM 本身留給下一家/最後 Mac phase9）
#
# 前提（Mac 端先完成）：phase1 + phase2（6 台 VM 已重建）。
#
# Markers（/tmp/poc-tpcc/logs/ 下）：
#   verify-a7-<TS>.done   = 全部成功
#   verify-a7-<TS>.failed = 失敗（含 exit code 與階段）
# 結果彙整：/tmp/poc-tpcc/logs/verify-a7-<TS>-results.md
set -euo pipefail

: "${TPCC_TS:?TPCC_TS required}"
PLACEMENT="${PLACEMENT:-P-A}"
DBS="${DBS:-tidb ybdb crdb}"
POC=/tmp/poc
MK="$POC/phase-crossregion/Makefile"
SCRIPTS="$POC/phase-crossregion/scripts"
LOGDIR=/tmp/poc-tpcc/logs
mkdir -p "$LOGDIR"
DONE="$LOGDIR/verify-a7-$TPCC_TS.done"
FAILED="$LOGDIR/verify-a7-$TPCC_TS.failed"
RESULTS="$LOGDIR/verify-a7-$TPCC_TS-results.md"
STAGE="init"

[[ -f "$MK" ]] || { echo "FATAL: $MK missing — detach target 需先 rsync Makefile" >&2; exit 1; }

GCP_DB_HOST=10.160.152.11
declare -A DB_PORT=([tidb]=4000 [ybdb]=5433 [crdb]=26257)

# 準備階段用小量 W=4；A7(4) 併發階段換 t128 一檔（非全 THREADS_LIST 掃描）
KNOBS_PREP=(WAREHOUSES=4 ROUNDS=1 WARMUP_SEC=30 RUN_SEC=60 THREADS_LIST=16 PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")
KNOBS_LOAD=(WAREHOUSES=4 ROUNDS=1 WARMUP_SEC=30 RUN_SEC=300 THREADS_LIST=128 PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")
UNDERLOAD_DURATION=330   # WARMUP_SEC(30) + RUN_SEC(300)，涵蓋整個 aaro-smoke 執行期間
UNDERLOAD_INTERVAL=12

log() { echo "[verify-a7 $(date '+%H:%M:%S')] $*"; }
run_db() { [[ " $DBS " == *" $1 "* ]]; }
result() { echo "$*" >> "$RESULTS"; }

_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"verify-a7","ts":"%s","status":"FAILED","stage":"%s","exit_code":%d,"failed_at":"%s"}\n' \
    "$TPCC_TS" "$STAGE" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$FAILED"
  log "FAILED at stage=$STAGE (exit=$rc) — marker $FAILED"
}
trap '_failed' EXIT

cd "$POC"
{
  echo "# A7(1)(4) 補強驗證結果（smoke 規模 W=4，TS=$TPCC_TS）"
  echo ""
  echo "回應 codex 獨立審查（07-22）§5.6 建議 (1)(4)。本輪吞吐數字僅供機制"
  echo "驗證，非報告 §1-§6 採用數字（W=4 anchor，非完整 W=128）。"
} > "$RESULTS"

STAGE="bootstrap-gcp-client"
log "=== bootstrap GCP client (.15) go-tpc/tests/common（冪等；VM 剛重建必跑）==="
make -f "$MK" phase2-bootstrap-gcp-client
log "window start TS=$TPCC_TS PLACEMENT=$PLACEMENT DBS=$DBS"

for db in tidb ybdb crdb; do
  run_db "$db" || continue
  PORT="${DB_PORT[$db]}"

  STAGE="$db-deploy"
  log "=== $db: deploy ==="
  case "$db" in
    tidb) make -f "$MK" phase3-tidb-deploy "${KNOBS_PREP[@]}" ;;
    ybdb) make -f "$MK" phase4-ybdb-deploy phase4-ybdb-fix6n "${KNOBS_PREP[@]}" ;;
    crdb) make -f "$MK" phase5-crdb-deploy "${KNOBS_PREP[@]}" ;;
  esac

  STAGE="$db-anchor-prepare"
  log "=== $db: ANCHOR_ONLY prepare（W=4）==="
  case "$db" in
    tidb) make -f "$MK" phase6-tidb-smoke ANCHOR_ONLY=1 "${KNOBS_PREP[@]}" ;;
    ybdb) make -f "$MK" phase7-ybdb-smoke ANCHOR_ONLY=1 "${KNOBS_PREP[@]}" ;;
    crdb) make -f "$MK" phase8-crdb-smoke ANCHOR_ONLY=1 "${KNOBS_PREP[@]}" ;;
  esac

  STAGE="$db-a7-1-realtxn"
  log "=== $db: A7(1) 真實交易近讀檢驗 ==="
  result ""
  result "## $db"
  result ""
  result "### A7(1) 真實 ORDER_STATUS/STOCK_LEVEL 交易（idle 連線）"
  REALTXN_LOG="$LOGDIR/verify-a7-$TPCC_TS-$db-realtxn.log"
  if bash "$SCRIPTS/check-nearread-realtxn.sh" --db "$db" --host "$GCP_DB_HOST" --port "$PORT" --db-name tpcc \
       > "$REALTXN_LOG" 2>&1; then
    result "PASS（詳見 verify-a7-$TPCC_TS-$db-realtxn.log）"
  else
    result "**FAIL**（詳見 verify-a7-$TPCC_TS-$db-realtxn.log）"
  fi
  cat "$REALTXN_LOG" >> "$LOGDIR/verify-a7-$TPCC_TS.log"

  STAGE="$db-a7-4-underload"
  log "=== $db: A7(4) t128 高併發同時採樣 ==="
  SAMPLE_LOG="$LOGDIR/verify-a7-$TPCC_TS-$db-underload.log"
  bash "$SCRIPTS/sample-nearread-loop.sh" --db "$db" --host "$GCP_DB_HOST" --port "$PORT" \
    --duration-sec "$UNDERLOAD_DURATION" --interval-sec "$UNDERLOAD_INTERVAL" --log "$SAMPLE_LOG" &
  SAMPLER_PID=$!

  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/${db}-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  case "$db" in
    tidb) make -f "$MK" phase6-tidb-aaro-smoke "${KNOBS_LOAD[@]}" ;;
    ybdb) make -f "$MK" phase7-ybdb-aaro-smoke "${KNOBS_LOAD[@]}" ;;
    crdb) make -f "$MK" phase8-crdb-aaro-smoke "${KNOBS_LOAD[@]}" ;;
  esac

  wait "$SAMPLER_PID" || true
  PASS_COUNT=$(grep -c ' PASS$' "$SAMPLE_LOG" 2>/dev/null || true)
  FAIL_COUNT=$(grep -c ' FAIL$' "$SAMPLE_LOG" 2>/dev/null || true)
  result "### A7(4) t128 執行期間採樣（每 ${UNDERLOAD_INTERVAL}s 一次，共 ${UNDERLOAD_DURATION}s）"
  result "PASS=$PASS_COUNT FAIL=$FAIL_COUNT（詳見 verify-a7-$TPCC_TS-$db-underload.log / .detail）"
  if [[ "${FAIL_COUNT:-0}" -gt 0 ]]; then
    result "**至少一次取樣 FAIL——負載下近讀曾退化，需人工複核 .detail log**"
  fi

  STAGE="$db-aaro-verify"
  log "=== $db: check-aaro-artifacts.py（本輪 smoke 機制驗證，非近讀判定）==="
  if python3 "$SCRIPTS/check-aaro-artifacts.py" "$ROOT" > "$LOGDIR/verify-a7-$TPCC_TS-$db-artifacts.log" 2>&1; then
    result "本輪 aaro-smoke 本身：check-aaro-artifacts.py PASS（0 錯誤）"
  else
    result "**本輪 aaro-smoke 本身：check-aaro-artifacts.py FAIL——近讀取樣結果可能不可信（workload 本身有問題）**"
    cat "$LOGDIR/verify-a7-$TPCC_TS-$db-artifacts.log"
  fi

  STAGE="$db-teardown"
  log "=== $db: teardown（.31 軟體層，VM 留待下一家/最後 Mac phase9）==="
  case "$db" in
    tidb) make -f "$MK" teardown-tidb "${KNOBS_LOAD[@]}" ;;
    ybdb) make -f "$MK" teardown-ybdb "${KNOBS_LOAD[@]}" ;;
    crdb) make -f "$MK" teardown-crdb "${KNOBS_LOAD[@]}" ;;
  esac
  log "=== $db cell done ==="
done

STAGE="done"
printf '{"window":"verify-a7","ts":"%s","status":"DONE","finished_at":"%s"}\n' \
  "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$DONE"
log "ALL DONE — marker $DONE，結果: $RESULTS"
log "回 Mac 跑 make phase9 (fetch+destroy) TPCC_TS=$TPCC_TS（本 driver 未動 VM 本身）"
