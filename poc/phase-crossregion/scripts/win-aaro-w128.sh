#!/usr/bin/env bash
# win-aaro-w128.sh — A-A-RO W=128 operator-window driver（TiDB→YBDB→CRDB）
#
# 跑在 .31 上（nohup detached），Mac 觸發後即可關機斷線：
#   make win-aaro-detach TPCC_TS=<ts>
#
# 背景（2026-07-19，A-A-RO 全輪拍板）：07-18 smoke（W=4 t16）已證明 A-A-RO
# 執行鏈、GCP 側直呼 go-tpc、prepare-bridge、gcp_side 計算口徑全部正確
# （見 SMOKE-AARO-SUMMARY.md）。全輪缺的是「無人值守調度」本身——本 driver
# 補齊：每家 deploy → ANCHOR_ONLY 快速 prepare（產生 plain suite 的
# .prepare.done/prepare//gate/，供 prepare-bridge 用，不需重跑一次完整
# baseline）→ aaro-smoke（真正 W=128 workload）→ 自訂 schema 驗證
# （check-aaro-artifacts.py；既有 check-static-artifacts.py 假設 4 檔位
# runs/+probe json，anchor 目錄本身沒有這些、aaro 側也無 near-read probe
# json，故另立驗證腳本）→ teardown → 歸檔。
#
# 前提（Mac 端先完成）：phase1 + phase2（含 phase2-probe-clients）已跑完。
# .15（GCP client）尚未 bootstrap go-tpc 的話，本 driver 會先做一次
# （phase2-bootstrap-gcp-client，冪等）。
#
# Markers（/tmp/poc-tpcc/logs/ 下）：
#   win-aaro-<TS>.done   = 全部成功
#   win-aaro-<TS>.failed = 失敗（含 exit code 與階段）
set -euo pipefail

: "${TPCC_TS:?TPCC_TS required}"
PLACEMENT="${PLACEMENT:-P-A}"
DBS="${DBS:-tidb ybdb crdb}"   # 空白分隔子集，如 DBS=ybdb 單家重跑
POC=/tmp/poc
MK="$POC/phase-crossregion/Makefile"
LOGDIR=/tmp/poc-tpcc/logs
mkdir -p "$LOGDIR"
DONE="$LOGDIR/win-aaro-$TPCC_TS.done"
FAILED="$LOGDIR/win-aaro-$TPCC_TS.failed"
STAGE="init"

[[ -f "$MK" ]] || { echo "FATAL: $MK missing — detach target 需先 rsync Makefile" >&2; exit 1; }

# W=128 官方口徑（同 win-3db-w128.sh）
KNOBS=(WAREHOUSES=128 ROUNDS=5 WARMUP_SEC=1200 RUN_SEC=300
       THREADS_LIST='16 32 64 128' PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")

log() { echo "[win-aaro $(date '+%H:%M:%S')] $*"; }
run_db() { [[ " $DBS " == *" $1 "* ]]; }

_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"aaro-w128","ts":"%s","status":"FAILED","stage":"%s","exit_code":%d,"failed_at":"%s"}\n' \
    "$TPCC_TS" "$STAGE" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$FAILED"
  log "FAILED at stage=$STAGE (exit=$rc) — marker $FAILED"
}
trap '_failed' EXIT

cd "$POC"
log "window start TS=$TPCC_TS PLACEMENT=$PLACEMENT DBS=$DBS"

STAGE="bootstrap-gcp-client"
log "=== bootstrap GCP client (.15) go-tpc/tests/common（冪等）==="
make -f "$MK" phase2-bootstrap-gcp-client

ARCHIVE=/var/lib/poc-tpcc-archive/$TPCC_TS
archive_cell() {  # $1 = suite 目錄名（相對 X-CROSS/）
  mkdir -p "$ARCHIVE"
  rsync -a "/tmp/poc-tpcc/artifacts/X-CROSS/$1" "$ARCHIVE/" \
    || { log "FAIL: 歸檔 $1 → $ARCHIVE 失敗"; exit 1; }
  cp -f "$LOGDIR/win-aaro-$TPCC_TS.log" "$ARCHIVE/driver-console.log" 2>/dev/null || true
  log "archived: $1 → $ARCHIVE/"
}

if run_db tidb; then
  STAGE="tidb-deploy"
  log "=== TiDB cell: deploy ==="
  make -f "$MK" phase3-tidb-deploy "${KNOBS[@]}"

  STAGE="tidb-anchor-prepare"
  log "=== TiDB cell: ANCHOR_ONLY prepare（plain, 供 prepare-bridge）==="
  make -f "$MK" phase6-tidb-smoke ANCHOR_ONLY=1 "${KNOBS[@]}"

  STAGE="tidb-aaro-smoke"
  log "=== TiDB cell: A-A-RO W=128 ==="
  make -f "$MK" phase6-tidb-aaro-smoke "${KNOBS[@]}"

  STAGE="tidb-verify"
  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/tidb-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  python3 "$POC/phase-crossregion/scripts/check-aaro-artifacts.py" "$ROOT"

  STAGE="tidb-teardown"
  make -f "$MK" teardown-tidb "${KNOBS[@]}"
  archive_cell "tidb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
  archive_cell "tidb-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  log "=== TiDB cell PASS（已歸檔）==="
fi

if run_db ybdb; then
  STAGE="ybdb-deploy"
  log "=== YBDB cell: deploy ==="
  make -f "$MK" phase4-ybdb-deploy phase4-ybdb-fix6n "${KNOBS[@]}"

  STAGE="ybdb-anchor-prepare"
  log "=== YBDB cell: ANCHOR_ONLY prepare（plain, 供 prepare-bridge）==="
  make -f "$MK" phase7-ybdb-smoke ANCHOR_ONLY=1 "${KNOBS[@]}"

  STAGE="ybdb-aaro-smoke"
  log "=== YBDB cell: A-A-RO W=128 ==="
  make -f "$MK" phase7-ybdb-aaro-smoke "${KNOBS[@]}"

  STAGE="ybdb-verify"
  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  python3 "$POC/phase-crossregion/scripts/check-aaro-artifacts.py" "$ROOT"

  STAGE="ybdb-teardown"
  make -f "$MK" teardown-ybdb "${KNOBS[@]}"
  archive_cell "ybdb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
  archive_cell "ybdb-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  log "=== YBDB cell PASS（已歸檔）==="
fi

if run_db crdb; then
  STAGE="crdb-deploy"
  log "=== CRDB cell: deploy ==="
  make -f "$MK" phase5-crdb-deploy "${KNOBS[@]}"

  STAGE="crdb-anchor-prepare"
  log "=== CRDB cell: ANCHOR_ONLY prepare（plain, 供 prepare-bridge）==="
  make -f "$MK" phase8-crdb-smoke ANCHOR_ONLY=1 "${KNOBS[@]}"

  STAGE="crdb-aaro-smoke"
  log "=== CRDB cell: A-A-RO W=128 ==="
  make -f "$MK" phase8-crdb-aaro-smoke "${KNOBS[@]}"

  STAGE="crdb-verify"
  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/crdb-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  python3 "$POC/phase-crossregion/scripts/check-aaro-artifacts.py" "$ROOT"

  STAGE="crdb-teardown"
  make -f "$MK" teardown-crdb "${KNOBS[@]}"
  archive_cell "crdb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
  archive_cell "crdb-vm-6node-${PLACEMENT}-aaro-rc-${TPCC_TS}"
  log "=== CRDB cell PASS（已歸檔）==="
fi

STAGE="done"
printf '{"window":"aaro-w128","ts":"%s","status":"DONE","finished_at":"%s"}\n' \
  "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$DONE"
log "ALL DONE — marker $DONE；回 Mac 跑 make phase9 (fetch+destroy) TPCC_TS=$TPCC_TS"
