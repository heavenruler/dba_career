#!/usr/bin/env bash
# win-aa-w128.sh — A-A W=128 operator-window driver（TiDB→YBDB→CRDB）
#
# 跑在 .31 上（nohup detached），Mac 觸發後即可關機斷線：
#   make win-aa-detach TPCC_TS=<ts>
#
# 背景：比照 win-aaro-w128.sh（A-A-RO 全輪 driver）改寫，profile 換成
# A-A（兩端皆標準讀寫 mix，全 W=128 重疊，per workload-profiles/A-A.md
# Q5 拍板 max contention）。執行鏈、prepare-bridge、gcp_side 計算口徑
# （summary-gcp-side.py／check-aaro-artifacts.py）皆已支援 A-A profile，
# 無需另立驗證腳本。每家 deploy → ANCHOR_ONLY 快速 prepare（產生 plain
# suite 的 .prepare.done/prepare//gate/，供 prepare-bridge 用）→
# aa-smoke（真正 W=128 workload，兩端標準 mix）→ check-aaro-artifacts.py
# 驗證 → teardown → 歸檔。
#
# 2026-07-31 執行前復盤發現並修復（run-vm6-aa.sh）：GCP 側 conn-params
# 原本對 CRDB/YBDB 無條件加 default_transaction_read_only=on（當初為
# A-A-RO 唯讀場景加），若沿用到 A-A 會讓 GCP 側所有寫入交易 100% 報錯；
# 已改為僅 PROFILE=A-A-RO 才加，A-A 用與 IDC 側相同的 plain 參數。
#
# 前提（Mac 端先完成）：phase1 + phase2（含 phase2-probe-clients）已跑完。
# .15（GCP client）尚未 bootstrap go-tpc 的話，本 driver 會先做一次
# （phase2-bootstrap-gcp-client，冪等）。
#
# Markers（/tmp/poc-tpcc/logs/ 下）：
#   win-aa-<TS>.done   = 全部成功
#   win-aa-<TS>.failed = 失敗（含 exit code 與階段）
set -euo pipefail

: "${TPCC_TS:?TPCC_TS required}"
PLACEMENT="${PLACEMENT:-P-A}"
DBS="${DBS:-tidb ybdb crdb}"   # 空白分隔子集，如 DBS=ybdb 單家重跑
POC=/tmp/poc
MK="$POC/phase-crossregion/Makefile"
LOGDIR=/tmp/poc-tpcc/logs
mkdir -p "$LOGDIR"
DONE="$LOGDIR/win-aa-$TPCC_TS.done"
FAILED="$LOGDIR/win-aa-$TPCC_TS.failed"
STAGE="init"

[[ -f "$MK" ]] || { echo "FATAL: $MK missing — detach target 需先 rsync Makefile" >&2; exit 1; }

# W=128 官方口徑（同 win-3db-w128.sh／win-aaro-w128.sh）
KNOBS=(WAREHOUSES=128 ROUNDS=5 WARMUP_SEC=1200 RUN_SEC=300
       THREADS_LIST='16 32 64 128' PLACEMENT="$PLACEMENT" TPCC_TS="$TPCC_TS")

log() { echo "[win-aa $(date '+%H:%M:%S')] $*"; }
run_db() { [[ " $DBS " == *" $1 "* ]]; }

_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"aa-w128","ts":"%s","status":"FAILED","stage":"%s","exit_code":%d,"failed_at":"%s"}\n' \
    "$TPCC_TS" "$STAGE" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$FAILED"
  log "FAILED at stage=$STAGE (exit=$rc) — marker $FAILED"
}
trap '_failed' EXIT

cd "$POC"
log "window start TS=$TPCC_TS PLACEMENT=$PLACEMENT DBS=$DBS"

STAGE="bootstrap-gcp-client"
log "=== bootstrap GCP client (.15) go-tpc/tests/common（冪等）==="
make -f "$MK" phase2-bootstrap-gcp-client

STAGE="apply-gotpc-patch"
log "=== 套用 go-tpc-readonly-fix.patch 到 GCP client（§8 A8：bootstrap 剛裝回官方"
log "    release binary，未 patch 會讓 CRDB 100% 報錯、YBDB 延遲/吞吐量靜默劣化）==="
bash "$POC/phase-crossregion/scripts/apply-gotpc-patch.sh"

ARCHIVE=/var/lib/poc-tpcc-archive/$TPCC_TS
archive_cell() {  # $1 = suite 目錄名（相對 X-CROSS/）
  mkdir -p "$ARCHIVE"
  rsync -a "/tmp/poc-tpcc/artifacts/X-CROSS/$1" "$ARCHIVE/" \
    || { log "FAIL: 歸檔 $1 → $ARCHIVE 失敗"; exit 1; }
  cp -f "$LOGDIR/win-aa-$TPCC_TS.log" "$ARCHIVE/driver-console.log" 2>/dev/null || true
  log "archived: $1 → $ARCHIVE/"
}

if run_db tidb; then
  STAGE="tidb-deploy"
  log "=== TiDB cell: deploy ==="
  make -f "$MK" phase3-tidb-deploy "${KNOBS[@]}"

  STAGE="tidb-anchor-prepare"
  log "=== TiDB cell: ANCHOR_ONLY prepare（plain, 供 prepare-bridge）==="
  make -f "$MK" phase6-tidb-smoke ANCHOR_ONLY=1 "${KNOBS[@]}"

  STAGE="tidb-aa-smoke"
  log "=== TiDB cell: A-A W=128 ==="
  make -f "$MK" phase6-tidb-aa-smoke "${KNOBS[@]}"

  STAGE="tidb-verify"
  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/tidb-vm-6node-${PLACEMENT}-aa-rc-${TPCC_TS}"
  python3 "$POC/phase-crossregion/scripts/check-aaro-artifacts.py" "$ROOT"

  STAGE="tidb-teardown"
  make -f "$MK" teardown-tidb "${KNOBS[@]}"
  archive_cell "tidb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
  archive_cell "tidb-vm-6node-${PLACEMENT}-aa-rc-${TPCC_TS}"
  log "=== TiDB cell PASS（已歸檔）==="
fi

if run_db ybdb; then
  STAGE="ybdb-deploy"
  log "=== YBDB cell: deploy ==="
  make -f "$MK" phase4-ybdb-deploy phase4-ybdb-fix6n "${KNOBS[@]}"

  STAGE="ybdb-anchor-prepare"
  log "=== YBDB cell: ANCHOR_ONLY prepare（plain, 供 prepare-bridge）==="
  make -f "$MK" phase7-ybdb-smoke ANCHOR_ONLY=1 "${KNOBS[@]}"

  STAGE="ybdb-aa-smoke"
  log "=== YBDB cell: A-A W=128 ==="
  make -f "$MK" phase7-ybdb-aa-smoke "${KNOBS[@]}"

  STAGE="ybdb-verify"
  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/ybdb-vm-6node-${PLACEMENT}-aa-rc-${TPCC_TS}"
  python3 "$POC/phase-crossregion/scripts/check-aaro-artifacts.py" "$ROOT"

  STAGE="ybdb-teardown"
  make -f "$MK" teardown-ybdb "${KNOBS[@]}"
  archive_cell "ybdb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
  archive_cell "ybdb-vm-6node-${PLACEMENT}-aa-rc-${TPCC_TS}"
  log "=== YBDB cell PASS（已歸檔）==="
fi

if run_db crdb; then
  STAGE="crdb-deploy"
  log "=== CRDB cell: deploy ==="
  make -f "$MK" phase5-crdb-deploy "${KNOBS[@]}"

  STAGE="crdb-anchor-prepare"
  log "=== CRDB cell: ANCHOR_ONLY prepare（plain, 供 prepare-bridge）==="
  make -f "$MK" phase8-crdb-smoke ANCHOR_ONLY=1 "${KNOBS[@]}"

  STAGE="crdb-aa-smoke"
  log "=== CRDB cell: A-A W=128 ==="
  make -f "$MK" phase8-crdb-aa-smoke "${KNOBS[@]}"

  STAGE="crdb-verify"
  ROOT="/tmp/poc-tpcc/artifacts/X-CROSS/crdb-vm-6node-${PLACEMENT}-aa-rc-${TPCC_TS}"
  python3 "$POC/phase-crossregion/scripts/check-aaro-artifacts.py" "$ROOT"

  STAGE="crdb-teardown"
  make -f "$MK" teardown-crdb "${KNOBS[@]}"
  archive_cell "crdb-vm-6node-${PLACEMENT}-rc-${TPCC_TS}"
  archive_cell "crdb-vm-6node-${PLACEMENT}-aa-rc-${TPCC_TS}"
  log "=== CRDB cell PASS（已歸檔）==="
fi

STAGE="done"
printf '{"window":"aa-w128","ts":"%s","status":"DONE","finished_at":"%s"}\n' \
  "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$DONE"
log "ALL DONE — marker $DONE；回 Mac 跑 make phase9 (fetch+destroy) TPCC_TS=$TPCC_TS"
