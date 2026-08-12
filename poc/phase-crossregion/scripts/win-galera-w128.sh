#!/usr/bin/env bash
# win-galera-w128.sh — Galera × W=128 × N=5 operator-window driver（P-A×A-S 或 P-B×A-A）
#
# 跑在 .31 上（nohup detached），Mac 觸發後即可關機斷線：
#   ssh root@172.24.40.31 "nohup env PLACEMENT=P-A PROFILE=A-S TPCC_TS=<ts> \
#     bash /tmp/poc-tpcc/scripts/crossregion/win-galera-w128.sh \
#     > /tmp/poc-tpcc/logs/win-galera-P-A-<ts>.log 2>&1 < /dev/null &"
#
# 跟 win-tidb-as-w128.sh 的關鍵差異：Galera 沒有 leader/lease/PD scheduler，
# 不需要 freeze/unfreeze、不需要 leader-percentage gate、不需要 leader
# snapshot——這些都是 leader-based 架構才有的步驟（見
# ansible/playbooks/galera-vm6.yml 開頭設計說明）。流程單純只是：
#   PROFILE=A-S → run-vm6-suite.sh；PROFILE=A-A → run-vm6-aa.sh
#
# Markers（$ROOT/ 下）：.window.done = 成功；.window.failed = 失敗（含 exit code）

set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)

: "${PLACEMENT:?PLACEMENT=P-A|P-B required}"
: "${PROFILE:?PROFILE=A-S|A-A required}"
: "${TPCC_TS:?TPCC_TS required}"
[[ "$PLACEMENT" =~ ^(P-A|P-B)$ ]] || { echo "PLACEMENT must be P-A | P-B" >&2; exit 1; }
[[ "$PROFILE" =~ ^(A-S|A-A)$ ]] || { echo "PROFILE must be A-S | A-A" >&2; exit 1; }

: "${GALERA_BENCH_PASSWORD:?missing GALERA_BENCH_PASSWORD}"

# === Suite env（鏡射 Makefile phase-galera-smoke / phase-galera-aa-smoke，W=128 正式參數）===
export PHASE_NAME="${PHASE_NAME:-phase-crossregion}"
export RESULT_SCOPE="${RESULT_SCOPE:-X-CROSS}"
export BASELINE_FAMILY="${BASELINE_FAMILY:-crossregion}"
export tuning_profile_id="${tuning_profile_id:-default}"
export TPCC_TS PLACEMENT PROFILE
export DB=galera
export CLIENT_ZONE="${CLIENT_ZONE:-idc}"
export GATE_SKIP="${GATE_SKIP:-1}"
export GALERA_USER="${GALERA_USER:-tpcc_bench}"
export GALERA_DB="${GALERA_DB:-tpcc}"
export GALERA_HOST="${GALERA_HOST:-172.24.40.32}"
export GALERA_PORT="${GALERA_PORT:-3306}"
export WAREHOUSES="${WAREHOUSES:-128}"
export WARMUP_SEC="${WARMUP_SEC:-1200}"
export ROUNDS="${ROUNDS:-5}"
export THREADS_LIST="${THREADS_LIST:-16 32 64 128}"
export RUN_SEC="${RUN_SEC:-300}"
export ROUND_SLEEP_SEC="${ROUND_SLEEP_SEC:-60}"
export TPCC_ARTIFACTS="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts/X-CROSS}"
export WAN_PROBE_ENABLED="${WAN_PROBE_ENABLED:-1}"
export WAN_PROBE_IPERF="${WAN_PROBE_IPERF:-1}"
export CLUSTER_HOSTS="${CLUSTER_HOSTS:-idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13}"

ISO="${ISO:-rc}"
case "$PROFILE" in
  A-S) TOKEN="" ;;
  A-A) TOKEN="-aa" ;;
esac
ROOT="$TPCC_ARTIFACTS/galera-vm-6node-${PLACEMENT}${TOKEN}-${ISO}-${TPCC_TS}"
mkdir -p "$ROOT"

log() { echo "[win-driver $(date '+%H:%M:%S')] $*"; }

_window_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  printf '{"window":"galera-w128","placement":"%s","profile":"%s","ts":"%s","status":"FAILED","exit_code":%d,"failed_at":"%s"}\n' \
    "$PLACEMENT" "$PROFILE" "$TPCC_TS" "$rc" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$ROOT/.window.failed"
  log ".window.failed written (exit=$rc)"
}
trap '_window_failed' EXIT

log "window start  DB=galera PLACEMENT=$PLACEMENT PROFILE=$PROFILE TS=$TPCC_TS W=$WAREHOUSES N=$ROUNDS threads=[$THREADS_LIST]"

case "$PROFILE" in
  A-S)
    log "step 1: run-vm6-suite.sh (P-A×A-S 單寫 IDC)"
    export DB_HOST="$GALERA_HOST" DB_PORT="$GALERA_PORT"
    bash "$SELF/run-vm6-suite.sh" --db galera --topology "vm-6node-${PLACEMENT}" --ts "$TPCC_TS"
    ;;
  A-A)
    # 2026-08-12 首次真實跑事故修正：run-vm6-aa.sh 內建的 GCP_CLIENT_SSH/PORT
    # 預設值（root@localhost:12215）假設走 IAP tunnel——這個環境不用 IAP，
    # 一律直連 .31→GCP（見 memory feedback_iap_tunnel_avoid）。Makefile 的
    # _aa_smoke_recipe 早就正確覆寫這些值，但這支 win-*-w128.sh wrapper
    # 沒抄到，導致 P-B×A-A W=128 一啟動就因為連不到 localhost:12215 直接
    # fail（"ssh: connect to host localhost port 12215: failure"）。這裡
    # 補上跟 _aa_smoke_recipe 完全一致的直連覆寫。
    export IDC_CLIENT="root@172.24.40.31"
    export GCP_CLIENT_SSH="root@10.160.152.15" GCP_CLIENT_PORT=22 GCP_CLIENT_IP="10.160.152.15"
    export IDC_DB_HOST="$GALERA_HOST" IDC_DB_PORT="$GALERA_PORT"
    export GCP_DB_HOST="10.160.152.11" GCP_DB_PORT="$GALERA_PORT"
    log "step 1: run-vm6-aa.sh (P-B×A-A 雙寫 IDC+GCP，GCP 端直連 .15，不走 IAP)"
    bash "$SELF/run-vm6-aa.sh" --db galera --topology "vm-6node-${PLACEMENT}${TOKEN}" --ts "$TPCC_TS"
    log "step 2: summary-from-stdout.py + summary-gcp-side.py"
    python3 "$SELF/../summary-from-stdout.py" --warehouses "$WAREHOUSES" \
      --phase "$PHASE_NAME" --result-scope "$RESULT_SCOPE" --baseline-family "$BASELINE_FAMILY" "$ROOT"
    python3 "$SELF/summary-gcp-side.py" --profile "$PROFILE" "$ROOT"
    # run-vm6-aa.sh（跟 run-vm6-suite.sh 不同）不會寫 .suite.done——那是
    # tests/common/run.sh 內建的收尾動作，A-A 路徑刻意繞過 run.sh（見
    # run-vm6-aa.sh 開頭「bug 修法 #2」說明）。phase8.5-static-check（destroy
    # 前的共用 schema 檢查）會找這個檔案，故在這裡補寫，格式對齊
    # run-vm6-suite.sh 的 write_phase_done 輸出。
    printf '{"phase":"suite","db":"galera","iso":"rc","topology":"vm-6node-%s%s","ts":"%s","placement":"%s","profile":"%s","completed_at":"%s"}\n' \
      "$PLACEMENT" "$TOKEN" "$TPCC_TS" "$PLACEMENT" "$PROFILE" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$ROOT/.suite.done"
    ;;
esac

log "step 3: wsrep-snapshot (cluster status per node)"
mkdir -p "$ROOT/wsrep-snapshot"
{
  for h in 172.24.40.32 172.24.40.33 172.24.40.34 10.160.152.11 10.160.152.12 10.160.152.13; do
    echo "=== $h ==="
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "root@$h" \
      "MYSQL_PWD='$GALERA_BENCH_PASSWORD' mysql -u$GALERA_USER -N -B -e \"SHOW STATUS LIKE 'wsrep_cluster_size'; SHOW STATUS LIKE 'wsrep_local_state_comment'; SHOW STATUS LIKE 'wsrep_ready';\""
  done
} > "$ROOT/wsrep-snapshot/wsrep-status.txt" 2>&1 || true

trap - EXIT
rm -f "$ROOT/.window.failed" 2>/dev/null || true
printf '{"window":"galera-w128","placement":"%s","profile":"%s","ts":"%s","status":"DONE","completed_at":"%s"}\n' \
  "$PLACEMENT" "$PROFILE" "$TPCC_TS" "$(date '+%Y-%m-%dT%H:%M:%S%z')" > "$ROOT/.window.done"
log "window DONE — $ROOT/.window.done"
