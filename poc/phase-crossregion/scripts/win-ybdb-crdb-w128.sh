#!/usr/bin/env bash
# win-ybdb-crdb-w128.sh — YBDB→CRDB × W=128 operator-window driver
#
# 跑在 .31 上（nohup detached），Mac 觸發後即可關機斷線：
#   make win-ybdb-crdb-detach TPCC_TS=<ts>
#
# 設計（2026-07-14）：指揮鏈搬 .31 —— 先前 Mac 端 make 經 live ssh 指揮，
# Mac 斷網/休眠即全滅（07-13/07-14 兩度中斷）。本 driver 直接在 .31 以
# make 跑同一套 target（Makefile 由 detach target rsync 到 /tmp/poc/），
# 零邏輯複製；YBDB cell 的 static-check（fail-closed：gcp-replica-gate
# 證據 + GCP probe fail_count==0 + schema）通過後才會進 CRDB cell，
# 即「YBDB 驗證完畢才跑 CRDB」由 make 依賴序自動保證。
#
# 前提（Mac 端先完成）：phase1 + phase2（含 phase2-probe-clients）已跑完，
# scripts/freeze/Makefile 已 rsync（detach target 代辦）。
#
# Markers（/tmp/poc-tpcc/logs/ 下）：
#   win-ybdb-crdb-<TS>.done   = 全部成功
#   win-ybdb-crdb-<TS>.failed = 失敗（含 exit code 與階段）
set -euo pipefail

: "${TPCC_TS:?TPCC_TS required}"
PLACEMENT="${PLACEMENT:-P-A}"
POC=/tmp/poc
MK="$POC/phase-crossregion/Makefile"
LOGDIR=/tmp/poc-tpcc/logs
mkdir -p "$LOGDIR"
DONE="$LOGDIR/win-ybdb-crdb-$TPCC_TS.done"
FAILED="$LOGDIR/win-ybdb-crdb-$TPCC_TS.failed"
STAGE="init"

[[ -f "$MK" ]] || { echo "FATAL: $MK missing — detach target 需先 rsync Makefile" >&2; exit 1; }

KNOBS=(WAREHOUSES=128 ROUNDS=5 WARMUP_SEC=1200 RUN_SEC=300
       THREADS_LIST='16 32 64 128' PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")

log() { echo "[win-driver $(date '+%H:%M:%S')] $*"; }

_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"ybdb-crdb-w128","ts":"%s","status":"FAILED","stage":"%s","exit_code":%d,"failed_at":"%s"}\n' \
    "$TPCC_TS" "$STAGE" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$FAILED"
  log "FAILED at stage=$STAGE (exit=$rc) — marker $FAILED"
}
trap '_failed' EXIT

cd "$POC"
log "window start TS=$TPCC_TS PLACEMENT=$PLACEMENT"

# 2026-07-17 RETRO Tier1-③：/tmp 的 artifacts 在 .31 重開機即滅、fetch 前是唯一份，
# 且 console 證據曾實際遺失一次——每 cell 完成即刻歸檔第三份到 /tmp 之外，
# driver log 一併入檔。歸檔失敗 fail-closed（保不住證據就不該繼續燒機時）。
ARCHIVE=/var/lib/poc-tpcc-archive/$TPCC_TS
archive_cell() {  # $1 = suite 目錄名
  mkdir -p "$ARCHIVE"
  rsync -a "/tmp/poc-tpcc/artifacts/X-CROSS/$1" "$ARCHIVE/" \
    || { log "FAIL: 歸檔 $1 → $ARCHIVE 失敗"; exit 1; }
  cp -f "$LOGDIR/win-ybdb-crdb-$TPCC_TS.log" "$ARCHIVE/driver-console.log" 2>/dev/null || true
  log "archived: $1 → $ARCHIVE/（含 driver console log）"
}

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
printf '{"window":"ybdb-crdb-w128","ts":"%s","status":"DONE","finished_at":"%s"}\n' \
  "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$DONE"
log "ALL DONE — marker $DONE；回 Mac 跑 make phase9 (fetch+destroy) TPCC_TS=$TPCC_TS"
