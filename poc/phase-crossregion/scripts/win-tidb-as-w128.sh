#!/usr/bin/env bash
# win-tidb-as-w128.sh — TiDB × A-S × W=128 × N=5 operator-window driver
#
# 跑在 .31 上（nohup detached），Mac 觸發後即可關機斷線：
#   ssh root@172.24.40.31 "nohup env PLACEMENT=P-A TPCC_TS=<ts> \
#     bash /tmp/poc-tpcc/scripts/crossregion/win-tidb-as-w128.sh \
#     > /tmp/poc-tpcc/logs/win-tidb-as-P-A-<ts>.log 2>&1 < /dev/null &"
#
# 前提（Mac 端 touch 先完成）：phase1/phase2/phase2-gate/phase3-tidb-deploy 已跑完，
# TiDB cluster 起、scripts + freeze/ 已 rsync 到 .31。
#
# 流程：freeze PD → run-vm6-suite.sh（gate/prepare/run/collect + summary + .suite.done）
#       → P-A leader 100% IDC gate（P-B 跳過；spread 由 prepare.sh §6.6 gate 把關）
#       → leader snapshot → unfreeze PD（trap 保證失敗也解凍）→ .window.done
#
# Markers（$ROOT/ 下）：.window.done = 成功；.window.failed = 失敗（含 exit code）

set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)

: "${PLACEMENT:?PLACEMENT=P-A|P-B required}"
: "${TPCC_TS:?TPCC_TS required}"
[[ "$PLACEMENT" =~ ^(P-A|P-B)$ ]] || { echo "PLACEMENT must be P-A | P-B" >&2; exit 1; }

# === Suite env（鏡射 Makefile phase6-tidb-smoke，W=128 正式參數）===
export PHASE_NAME="${PHASE_NAME:-phase-crossregion}"
export RESULT_SCOPE="${RESULT_SCOPE:-X-CROSS}"
export BASELINE_FAMILY="${BASELINE_FAMILY:-crossregion}"
export tuning_profile_id="${tuning_profile_id:-default}"
export TPCC_TS PLACEMENT
export PROFILE="${PROFILE:-A-S}"
export DB=tidb
export CLIENT_ZONE="${CLIENT_ZONE:-idc}"
export GATE_SKIP="${GATE_SKIP:-1}"   # chrony gate 由 Mac touch 的 phase2-gate 先驗
export DB_HOST="${DB_HOST:-172.24.40.32}"
export DB_PORT="${DB_PORT:-4000}"
export WAREHOUSES="${WAREHOUSES:-128}"
export WARMUP_SEC="${WARMUP_SEC:-1200}"
export ROUNDS="${ROUNDS:-5}"
export THREADS_LIST="${THREADS_LIST:-16 32 64 128}"
export RUN_SEC="${RUN_SEC:-300}"
export ROUND_SLEEP_SEC="${ROUND_SLEEP_SEC:-60}"
export TPCC_ARTIFACTS="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts/X-CROSS}"
export WAN_PROBE_ENABLED="${WAN_PROBE_ENABLED:-1}"
export WAN_PROBE_IPERF="${WAN_PROBE_IPERF:-1}"

ISO="${ISO:-rc}"
ROOT="$TPCC_ARTIFACTS/tidb-vm-6node-${PLACEMENT}-${ISO}-${TPCC_TS}"
PD_URL="${PD_URL:-http://172.24.40.32:2379}"
FREEZE_DIR="$SELF/freeze"
mkdir -p "$ROOT"

log() { echo "[win-driver $(date '+%H:%M:%S')] $*"; }

_window_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"tidb-as-w128","placement":"%s","ts":"%s","status":"FAILED","exit_code":%d,"failed_at":"%s"}\n' \
    "$PLACEMENT" "$TPCC_TS" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$ROOT/.window.failed"
  # 失敗也必須解凍 PD，否則 scheduler 永久停擺
  if [[ -f "$FREEZE_DIR/unfreeze-tidb.sh" ]]; then
    log "FAILED (exit=$rc) — unfreeze PD before exit"
    PD_URL="$PD_URL" DUMP_DIR="$ROOT/freeze-state" bash "$FREEZE_DIR/unfreeze-tidb.sh" || true
  fi
  log ".window.failed written (exit=$rc)"
}
trap '_window_failed' EXIT

log "window start  PLACEMENT=$PLACEMENT TS=$TPCC_TS W=$WAREHOUSES N=$ROUNDS threads=[$THREADS_LIST]"

# --- 0. freeze TiDB PD scheduling（steady-state 硬門檻）---
[[ -f "$FREEZE_DIR/freeze-tidb.sh" ]] || { echo "missing $FREEZE_DIR/freeze-tidb.sh（Mac 端 detach target 需先 rsync freeze/）" >&2; exit 1; }
log "step 0: freeze PD scheduling (dump → $ROOT/freeze-state)"
PD_URL="$PD_URL" DUMP_DIR="$ROOT/freeze-state" bash "$FREEZE_DIR/freeze-tidb.sh"

# --- 1. full suite（gate→prepare→placement→run→collect→summary→.suite.done）---
log "step 1: run-vm6-suite.sh (this is the long part: load + warmup + sweep)"
bash "$SELF/run-vm6-suite.sh" --db tidb --topology "vm-6node-${PLACEMENT}" --ts "$TPCC_TS"

# --- 2. P-A only: tpcc leaders 100% IDC gate（P-B 期望 spread，由 prepare.sh §6.6 把關）---
if [[ "$PLACEMENT" == "P-A" ]]; then
  log "step 2: P-A leader gate — wait tpcc region leaders → 100% IDC (max 5 min)"
  converged=0
  for i in $(seq 1 30); do
    pct=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u root -BNe \
      "SELECT IFNULL(SUM(CASE WHEN s.LABEL LIKE '%idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc';" \
      2>/dev/null | tail -1 || true)
    case "$pct" in 100|100.*) log "  tpcc leaders 100% on IDC"; converged=1; break ;; esac
    printf '  %2d/30 tpcc leaders on IDC: %s%%\n' "$i" "$pct"
    sleep 10
  done
  [[ "$converged" == "1" ]] || { echo "gate FAIL: TiDB tpcc leaders not 100% IDC after 5min" >&2; exit 1; }
else
  log "step 2: PLACEMENT=P-B — skip 100%-IDC gate (spread 已由 prepare.sh placement gate fail-closed 把關)"
fi

# --- 3. leader snapshot（兩 placement 都留證據）---
log "step 3: leader snapshot → $ROOT/leader-snapshot/"
mkdir -p "$ROOT/leader-snapshot"
mysql -h "$DB_HOST" -P "$DB_PORT" -u root -e \
  "SELECT p.STORE_ID, s.ADDRESS, s.LABEL, COUNT(*) AS leader_count FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID WHERE p.IS_LEADER=1 GROUP BY p.STORE_ID, s.ADDRESS, s.LABEL;" \
  > "$ROOT/leader-snapshot/leaders-by-store-$(date +%s).txt" 2>&1 || true

# --- 4. unfreeze PD（成功路徑）---
log "step 4: unfreeze PD scheduling"
PD_URL="$PD_URL" DUMP_DIR="$ROOT/freeze-state" bash "$FREEZE_DIR/unfreeze-tidb.sh"

# --- 5. done marker ---
trap - EXIT
rm -f "$ROOT/.window.failed" 2>/dev/null || true
printf '{"window":"tidb-as-w128","placement":"%s","ts":"%s","status":"DONE","completed_at":"%s"}\n' \
  "$PLACEMENT" "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$ROOT/.window.done"
log "window DONE — $ROOT/.window.done"
