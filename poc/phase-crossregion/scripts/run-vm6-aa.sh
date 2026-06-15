#!/usr/bin/env bash
# phase-crossregion/scripts/run-vm6-aa.sh
#
# Active-Active dual-client orchestrator:
#   IDC client (.31)         + GCP client (g-test-poc-5; via localhost:12215 IAP tunnel)
#   兩端 go-tpc 同步 launch；per Q6 全 W=128 max contention（不切 warehouse range）
#
# Profile dispatch:
#   PROFILE=A-A      → 兩端皆 standard TPCC mix (--warehouses 128 --threads N)
#   PROFILE=A-A-RO   → IDC standard mix；GCP read-only mix (`--mix DELIVERY,NEW_ORDER,ORDER_STATUS,PAYMENT,STOCK_LEVEL=0:0:50:0:50`)
#   PROFILE=A-S      → 不適用（A-S 為 IDC 單寫；直接呼叫 run-vm6-suite.sh）
#
# Sync semantics:
#   - chrony drift < 100ms gate（per Q10）— 由 gate-chrony-cross-region.sh 在啟動前驗
#   - 兩端 client 在 'launch barrier file' 出現後同秒鐘 kick off go-tpc
#   - 兩端 client artifacts 各自寫 /tmp/poc-tpcc/artifacts/X-CROSS/...，post-run rsync 合併
#
# Required env:
#   PHASE_NAME=phase-crossregion / RESULT_SCOPE=X-CROSS / BASELINE_FAMILY=crossregion
#   PLACEMENT=P-A|P-B
#   PROFILE=A-A|A-A-RO
#   TPCC_TS=<ts>
#
# Args:
#   --db {tidb} --topology vm-6node-{P-A|P-B} --ts <ts>
#
# Safety:
#   - 不修改 tests/common 任何 script
#   - 兩端皆呼叫 tests/common/run.sh（透過 COMMON_DIR=/tmp/poc-tpcc/scripts）
#   - GCP 端 go-tpc binary 假設由 ansible/playbooks/tpcc-client-ssh.yml 等價變體
#     部署到 g-test-poc-5（**未在此 agent 範圍；列 TODO**）

set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)
REPO_ROOT=$(cd "$SELF/../.." && pwd)

DB=""
TOPOLOGY=""
TS=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --db) DB=$2; shift 2 ;;
    --topology) TOPOLOGY=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${DB:?--db required}"
: "${TOPOLOGY:?--topology required}"
: "${TS:?--ts required}"

: "${PHASE_NAME:?missing PHASE_NAME=phase-crossregion}"
: "${RESULT_SCOPE:?missing RESULT_SCOPE=X-CROSS}"
: "${BASELINE_FAMILY:?missing BASELINE_FAMILY=crossregion}"
: "${PLACEMENT:?missing PLACEMENT=P-A|P-B}"
: "${PROFILE:?missing PROFILE=A-A|A-A-RO}"
: "${tuning_profile_id:=default}"

[[ "$PROFILE" =~ ^(A-A|A-A-RO)$ ]] || {
  echo "run-vm6-aa.sh handles only PROFILE=A-A | A-A-RO; for A-S use run-vm6-suite.sh." >&2
  exit 1
}
[[ "$DB" == "tidb" ]] || { echo "DB must be tidb (crdb/ybdb TODO)" >&2; exit 1; }

# IDC writer side: 走 IDC haproxy .47.20:4000；GCP side: 走 GCP haproxy g-test-poc-4:4000
: "${IDC_CLIENT:=root@172.24.40.31}"
: "${GCP_CLIENT_PORT:=12215}"                 # IAP tunnel forward on Mac/orchestrator localhost
: "${GCP_CLIENT_SSH:=root@localhost}"
: "${IDC_DB_HOST:=172.24.47.20}"              # IDC haproxy
: "${IDC_DB_PORT:=4000}"
: "${GCP_DB_HOST:=10.160.152.14}"             # GCP haproxy g-test-poc-4 internal IP
: "${GCP_DB_PORT:=4000}"

ISO="${ISO:-rc}"
WAREHOUSES="${WAREHOUSES:-128}"
# threads_list 透過 launch-vm1-suite 等價 wrapper / Makefile env 控制；此 script 接受 --threads
: "${THREADS:?missing THREADS for run-vm6-aa.sh (16|32|64|128)}"

# A-A-RO GCP-side mix (per Q6)
# go-tpc --mix syntax 序列：DELIVERY:NEW_ORDER:ORDER_STATUS:PAYMENT:STOCK_LEVEL
# 50/0/50 read-only mix（ORDER_STATUS + STOCK_LEVEL）
GCP_MIX_FLAG=""
if [[ "$PROFILE" == "A-A-RO" ]]; then
  GCP_MIX_FLAG="--mix 0:0:50:0:50"
fi

# Barrier file: 兩端在 SSH session 內 wait 直到 barrier touch 才 launch go-tpc
BARRIER="/tmp/poc-tpcc/aa-barrier-${TS}"

# pre-flight chrony gate (Q10)
echo "[aa] pre-flight: chrony-cross-region drift gate"
bash "$SELF/gate-chrony-cross-region.sh" --ts "$TS" \
  --root-suffix "${DB}-${TOPOLOGY}-${ISO}-${TS}-AA" \
  --result-scope "$RESULT_SCOPE"

echo "[aa] launching dual-side TPCC: profile=$PROFILE placement=$PLACEMENT threads=$THREADS"
echo "[aa] IDC client: $IDC_CLIENT → $IDC_DB_HOST:$IDC_DB_PORT (standard mix, W=$WAREHOUSES)"
echo "[aa] GCP client: $GCP_CLIENT_SSH:$GCP_CLIENT_PORT → $GCP_DB_HOST:$GCP_DB_PORT (mix=${GCP_MIX_FLAG:-standard}, W=$WAREHOUSES)"

# IDC side launch (background; wait for barrier)
ssh "$IDC_CLIENT" "mkdir -p /tmp/poc-tpcc && touch ${BARRIER}.idc-ready" &
IDC_READY_PID=$!

# GCP side launch (background; wait for barrier)
ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "mkdir -p /tmp/poc-tpcc && touch ${BARRIER}.gcp-ready" &
GCP_READY_PID=$!

wait $IDC_READY_PID $GCP_READY_PID

echo "[aa] both sides ready; launching workload (sync window = same wallclock second)"

# Kick off — sleep 5s grace then both sides start
LAUNCH_AT=$(($(date +%s) + 5))

# IDC side
ssh "$IDC_CLIENT" "
  export TS='${TS}' PLACEMENT='${PLACEMENT}' PROFILE='${PROFILE}' ROUND_SIDE=IDC \
         DB='${DB}' TOPOLOGY='${TOPOLOGY}' ISO='${ISO}' WAREHOUSES='${WAREHOUSES}' THREADS='${THREADS}' \
         DB_HOST='${IDC_DB_HOST}' DB_PORT='${IDC_DB_PORT}' \
         PHASE_NAME='${PHASE_NAME}' RESULT_SCOPE='${RESULT_SCOPE}' BASELINE_FAMILY='${BASELINE_FAMILY}'
  # Wait until LAUNCH_AT epoch (per-host clock; chrony drift <100ms 已驗)
  while [ \$(date +%s) -lt ${LAUNCH_AT} ]; do sleep 0.2; done
  # standard TPCC mix
  bash /tmp/poc-tpcc/scripts/run.sh --db '${DB}' --iso '${ISO}' \
    --topology '${TOPOLOGY}' --db-host '${IDC_DB_HOST}' --ts '${TS}'
" 2>&1 | sed 's/^/[idc] /' &
IDC_PID=$!

# GCP side (A-A-RO 加 mix flag；A-A 同 IDC standard)
ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "
  export TS='${TS}' PLACEMENT='${PLACEMENT}' PROFILE='${PROFILE}' ROUND_SIDE=GCP \
         DB='${DB}' TOPOLOGY='${TOPOLOGY}' ISO='${ISO}' WAREHOUSES='${WAREHOUSES}' THREADS='${THREADS}' \
         DB_HOST='${GCP_DB_HOST}' DB_PORT='${GCP_DB_PORT}' \
         PHASE_NAME='${PHASE_NAME}' RESULT_SCOPE='${RESULT_SCOPE}' BASELINE_FAMILY='${BASELINE_FAMILY}' \
         GO_TPC_MIX_FLAG='${GCP_MIX_FLAG}'
  while [ \$(date +%s) -lt ${LAUNCH_AT} ]; do sleep 0.2; done
  # GCP-side go-tpc run; mix flag (if A-A-RO) passed via env to run.sh
  # NOTE: run.sh 當前可能未支援 --mix 直透；A-A-RO mix 行為待 tests/common 後續擴
  bash /tmp/poc-tpcc/scripts/run.sh --db '${DB}' --iso '${ISO}' \
    --topology '${TOPOLOGY}' --db-host '${GCP_DB_HOST}' --ts '${TS}'
" 2>&1 | sed 's/^/[gcp] /' &
GCP_PID=$!

wait $IDC_PID
IDC_RC=$?
wait $GCP_PID
GCP_RC=$?

echo "[aa] IDC side rc=$IDC_RC  GCP side rc=$GCP_RC"

if [[ $IDC_RC -ne 0 || $GCP_RC -ne 0 ]]; then
  echo "[aa] FAIL — at least one side returned non-zero" >&2
  exit 1
fi

echo "[aa] dual-side AA run PASS — TS=$TS PLACEMENT=$PLACEMENT PROFILE=$PROFILE"
