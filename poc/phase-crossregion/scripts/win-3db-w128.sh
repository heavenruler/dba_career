#!/usr/bin/env bash
# win-3db-w128.sh — TiDB→YBDB→CRDB × W=128 operator-window driver（#3 同批三家重跑）
#
# 跑在 .31 上（nohup detached），Mac 觸發後即可關機斷線：
#   make win-3db-detach TPCC_TS=<ts>
#
# 結構同 win-ybdb-crdb-w128.sh（2026-07-14 指揮鏈搬 .31 設計），前面加 TiDB
# cell；每 cell 的 static-check（fail-closed：gcp-replica-gate 證據 + GCP probe
# fail_count==0 + 缺輪斷言 + schema）通過後才進下一家，由 make 依賴序自動保證。
#
# 前提（Mac 端先完成）：phase1 + phase2（含 phase2-probe-clients）已跑完，
# scripts/freeze/Makefile 已 rsync（detach target 代辦）。
#
# Markers（/tmp/poc-tpcc/logs/ 下）：
#   win-3db-<TS>.done   = 全部成功
#   win-3db-<TS>.failed = 失敗（含 exit code 與階段）
set -euo pipefail

: "${TPCC_TS:?TPCC_TS required}"
PLACEMENT="${PLACEMENT:-P-A}"
POC=/tmp/poc
MK="$POC/phase-crossregion/Makefile"
LOGDIR=/tmp/poc-tpcc/logs
mkdir -p "$LOGDIR"
DONE="$LOGDIR/win-3db-$TPCC_TS.done"
FAILED="$LOGDIR/win-3db-$TPCC_TS.failed"
STAGE="init"

[[ -f "$MK" ]] || { echo "FATAL: $MK missing — detach target 需先 rsync Makefile" >&2; exit 1; }

KNOBS=(WAREHOUSES=128 ROUNDS=5 WARMUP_SEC=1200 RUN_SEC=300
       THREADS_LIST='16 32 64 128' PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")

log() { echo "[win-driver $(date '+%H:%M:%S')] $*"; }

_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"3db-w128","ts":"%s","status":"FAILED","stage":"%s","exit_code":%d,"failed_at":"%s"}\n' \
    "$TPCC_TS" "$STAGE" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$FAILED"
  log "FAILED at stage=$STAGE (exit=$rc) — marker $FAILED"
}
trap '_failed' EXIT

cd "$POC"
log "window start TS=$TPCC_TS PLACEMENT=$PLACEMENT"

# 2026-07-17 RETRO Tier1-③：每 cell 完成即刻歸檔第三份到 /tmp 之外（.31 重開機
# 即滅、fetch 前是唯一份），driver log 一併入檔。歸檔失敗 fail-closed。
ARCHIVE=/var/lib/poc-tpcc-archive/$TPCC_TS
archive_cell() {  # $1 = suite 目錄名
  mkdir -p "$ARCHIVE"
  rsync -a "/tmp/poc-tpcc/artifacts/X-CROSS/$1" "$ARCHIVE/" \
    || { log "FAIL: 歸檔 $1 → $ARCHIVE 失敗"; exit 1; }
  cp -f "$LOGDIR/win-3db-$TPCC_TS.log" "$ARCHIVE/driver-console.log" 2>/dev/null || true
  log "archived: $1 → $ARCHIVE/（含 driver console log）"
}

STAGE="tidb-cell"
log "=== TiDB cell: deploy → smoke → result → static-check → teardown ==="
make -f "$MK" phase3-tidb-deploy phase6-tidb-smoke phase6-tidb-result \
     phase8.5-static-check teardown-tidb "${KNOBS[@]}"
archive_cell "tidb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
log "=== TiDB cell PASS（已歸檔）==="

STAGE="ybdb-cell"
log "=== YBDB cell: deploy → fix6n → smoke → result → static-check → teardown ==="
make -f "$MK" phase4-ybdb-deploy phase4-ybdb-fix6n phase7-ybdb-smoke phase7-ybdb-result \
     phase8.5-static-check teardown-ybdb "${KNOBS[@]}"
archive_cell "ybdb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
log "=== YBDB cell PASS（static-check 含 gcp-replica-gate/probe 斷言全綠；已歸檔）==="

STAGE="crdb-cell"
log "=== CRDB cell: deploy → smoke → result → static-check → teardown ==="
make -f "$MK" phase5-crdb-deploy phase8-crdb-smoke phase8-crdb-result \
     phase8.5-static-check teardown-crdb "${KNOBS[@]}"
archive_cell "crdb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
log "=== CRDB cell PASS（已歸檔）==="

STAGE="done"
printf '{"window":"3db-w128","ts":"%s","status":"DONE","finished_at":"%s"}\n' \
  "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$DONE"
log "ALL DONE — marker $DONE；回 Mac 跑 make phase9 (fetch+destroy) TPCC_TS=$TPCC_TS"
