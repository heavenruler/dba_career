#!/usr/bin/env bash
# phase-crossregion/scripts/run-vm6-aa.sh
#
# Active-Active dual-client orchestrator:
#   IDC client (.31) + GCP client (g-test-poc-5)
#   兩端 go-tpc 同步 launch；per Q6 全 W=128 max contention（不切 warehouse range）
#
# Profile dispatch:
#   PROFILE=A-A      → 兩端皆 standard TPCC mix (--warehouses 128 --threads N)
#   PROFILE=A-A-RO   → IDC standard mix；GCP read-only mix
#                      （GO_TPC_MIX_FLAG=0:0:50:0:50 → run.sh 自行展開成 --mix；
#                       序列 DELIVERY:NEW_ORDER:ORDER_STATUS:PAYMENT:STOCK_LEVEL）
#   PROFILE=A-S      → 不適用（A-S 為 IDC 單寫；直接呼叫 run-vm6-suite.sh）
#
# Artifact 佈局（Q17 + G3，2026-07-15 拍板）:
#   - 目錄名帶 profile token：{db}-vm-6node-{P}-{aa|aaro}-{iso}-{ts}
#     （token 藏 topology 段 → tests/common 零改動）
#   - IDC 端 suite 目錄為 SSOT；GCP 端每輪 stdout 由 merge-gcp-stdout.sh 在 run 結束後
#     精確落位到 runs/threads-N/round-M/go-tpc-stdout-gcp.txt（與 IDC go-tpc-stdout.txt 並排）
#   - gcp_side 彙整由 summary-gcp-side.py 注入 summary.json（Makefile 收尾步驟；G2）
#
# Sync semantics:
#   - chrony drift < 100ms gate（per Q10）；GATE_SKIP=1 可跳（上游 phase2-gate 已驗，
#     同 run-vm6-suite.sh 語意 — .31 上跑時 gate 無法走 IAP tunnel）
#   - 兩端 client 同 wallclock 秒 kick off go-tpc（LAUNCH_AT epoch barrier）
#
# Required env:
#   PHASE_NAME=phase-crossregion / RESULT_SCOPE=X-CROSS / BASELINE_FAMILY=crossregion
#   PLACEMENT=P-A|P-B
#   PROFILE=A-A|A-A-RO
#   THREADS_LIST（或單值 THREADS）
#
# Args:
#   --db {tidb|crdb|ybdb} --topology vm-6node-{P-A|P-B}-{aa|aaro} --ts <ts>
#
# Safety:
#   - 不修改 tests/common 任何 script
#   - 兩端皆呼叫 tests/common/run.sh（透過 /tmp/poc-tpcc/scripts）
#   - IDC 端 .prepare.done 必須已由 prepare 鏈產生（缺 → run.sh fail-closed）；
#     GCP 端只 seed marker（prepare 由 IDC 端完成，同一 cluster）
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
[[ "$DB" =~ ^(tidb|crdb|ybdb)$ ]] || { echo "DB must be tidb | crdb | ybdb" >&2; exit 1; }

# Q17: topology 必須帶 profile token（-aa / -aaro，插在 placement 與 iso 之間）— fail-closed
case "$PROFILE" in
  A-A)    _EXPECT_TOPO="vm-6node-${PLACEMENT}-aa" ;;
  A-A-RO) _EXPECT_TOPO="vm-6node-${PLACEMENT}-aaro" ;;
esac
[[ "$TOPOLOGY" == "$_EXPECT_TOPO" ]] || {
  echo "[aa] TOPOLOGY=$TOPOLOGY 與 PROFILE=$PROFILE / PLACEMENT=$PLACEMENT 不符（Q17 預期 $_EXPECT_TOPO）— fail-closed" >&2
  exit 1
}

# §3 zone-local enforce: A-A / A-A-RO 是雙 client orchestration, 兩端都需 zone-local
# IDC client → idc-haproxy (.47.20) 或 IDC node；GCP client → GCP haproxy / GCP node
# 違反 zone-local（如 IDC client 連 GCP haproxy）→ fail-closed
# (REPLAN-2026-06-15 §3; manifest client_locality_enforce: true)

# per-DB 預設 writer port（IDC/GCP 兩端同 port；host 可由 env 覆寫）
case "$DB" in
  tidb) _DEF_PORT=4000 ;;
  crdb) _DEF_PORT=26257 ;;
  ybdb) _DEF_PORT=5433 ;;
esac

# IDC writer side: 預設走 IDC haproxy .47.20；GCP side: 預設走 GCP haproxy g-test-poc-4
# （Makefile aa targets 覆寫為 .32 / .11 直連 + GCP client 走 .31→.15 直連，per Q16）
: "${IDC_CLIENT:=root@172.24.40.31}"
: "${GCP_CLIENT_PORT:=12215}"                 # IAP tunnel forward on Mac/orchestrator localhost
: "${GCP_CLIENT_SSH:=root@localhost}"
: "${GCP_CLIENT_IP:=10.160.152.15}"           # g-test-poc-5 內網 IP（.31 直連用；merge 走此路徑）
: "${IDC_DB_HOST:=172.24.47.20}"              # IDC haproxy (zone-local for IDC client)
: "${IDC_DB_PORT:=$_DEF_PORT}"
: "${GCP_DB_HOST:=10.160.152.14}"             # GCP haproxy g-test-poc-4 internal IP (zone-local for GCP client)
: "${GCP_DB_PORT:=$_DEF_PORT}"

# Zone-local fail-closed checks
[[ "$IDC_DB_HOST" =~ ^(172\.24\.47\.20|172\.24\.40\.3[234])$ ]] || \
  { echo "[zone-local enforce] IDC_DB_HOST=$IDC_DB_HOST 不在 IDC zone (預期 .47.20 或 .32/.33/.34) — fail-closed" >&2; exit 1; }
[[ "$GCP_DB_HOST" =~ ^10\.160\.152\.1[1-5]$ ]] || \
  { echo "[zone-local enforce] GCP_DB_HOST=$GCP_DB_HOST 不在 GCP zone (預期 10.160.152.11-15) — fail-closed" >&2; exit 1; }
[[ "$GCP_CLIENT_IP" =~ ^10\.160\.152\.1[1-5]$ ]] || \
  { echo "[zone-local enforce] GCP_CLIENT_IP=$GCP_CLIENT_IP 不在 GCP zone — fail-closed" >&2; exit 1; }

ISO="${ISO:-rc}"
WAREHOUSES="${WAREHOUSES:-128}"

# sweep 參數：接受 THREADS_LIST（run.sh 實際吃這個）或舊介面單值 THREADS
if [[ -z "${THREADS_LIST:-}" && -z "${THREADS:-}" ]]; then
  echo "missing THREADS_LIST (or THREADS) for run-vm6-aa.sh (e.g. '16' or '16 32 64 128')" >&2
  exit 1
fi
: "${THREADS_LIST:=${THREADS:-}}"
# run.sh 其餘 knobs（預設對齊 tests/common/run.sh；Makefile smoke 會覆寫）
: "${ROUNDS:=5}"
: "${WARMUP_SEC:=1200}"
: "${RUN_SEC:=300}"
: "${ROUND_SLEEP_SEC:=60}"
: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts/$RESULT_SCOPE}"
# per-round DB-host 指標 fan-out（僅 IDC 端跑；GCP 端 client 未 prime 對 IDC nodes 的 SSH）
: "${CLUSTER_HOSTS:=idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13}"
: "${WAN_PROBE_ENABLED:=0}"
: "${WAN_PROBE_IPERF:=0}"
: "${GCP_PROBE_DB_HOST:=10.160.152.14}"
# per-DB client 認證（run.sh 依 --db 挑用；三家全帶無副作用）
: "${TIDB_USER:=root}";     : "${TIDB_DB:=tpcc}"
: "${CRDB_USER:=root}";     : "${CRDB_DB:=tpcc}"
: "${YBDB_USER:=yugabyte}"; : "${YBDB_DB:=tpcc}"
# .31 上的 crossregion scripts（phase2-bootstrap rsync 目的地；merge 步驟用）
: "${CROSS_SCRIPTS_REMOTE:=/tmp/poc-tpcc/scripts/crossregion}"

# G3: suite 目錄（IDC 端 = SSOT；GCP 端本地同名目錄僅為 run.sh 過程檔）
ROOT="$TPCC_ARTIFACTS/${DB}-${TOPOLOGY}-${ISO}-${TS}"

# A-A-RO GCP-side read-only mix (per Q6)
# 值只放比例（run.sh 的 GO_TPC_MIX_FLAG passthrough 會自行加上 --mix 前綴）
# 序列 DELIVERY:NEW_ORDER:ORDER_STATUS:PAYMENT:STOCK_LEVEL → 0:0:50:0:50（純 read）
GCP_MIX_FLAG=""
if [[ "$PROFILE" == "A-A-RO" ]]; then
  GCP_MIX_FLAG="0:0:50:0:50"
fi

# Barrier file: 兩端在 SSH session 內 wait 直到 barrier touch 才 launch go-tpc
BARRIER="/tmp/poc-tpcc/aa-barrier-${TS}"

# pre-flight chrony gate (Q10)；GATE_SKIP=1 → 上游（phase2-gate）已驗，跳過
if [[ "${GATE_SKIP:-0}" == "1" ]]; then
  echo "[aa] pre-flight: chrony gate SKIP (GATE_SKIP=1)"
else
  echo "[aa] pre-flight: chrony-cross-region drift gate"
  bash "$SELF/gate-chrony-cross-region.sh" --ts "$TS" \
    --root-suffix "${DB}-${TOPOLOGY}-${ISO}-${TS}-AA" \
    --result-scope "$RESULT_SCOPE"
fi

echo "[aa] launching dual-side TPCC: profile=$PROFILE placement=$PLACEMENT threads_list='$THREADS_LIST'"
echo "[aa] IDC client: $IDC_CLIENT → $IDC_DB_HOST:$IDC_DB_PORT (standard mix, W=$WAREHOUSES)"
echo "[aa] GCP client: $GCP_CLIENT_SSH:$GCP_CLIENT_PORT → $GCP_DB_HOST:$GCP_DB_PORT (mix=${GCP_MIX_FLAG:-standard}, W=$WAREHOUSES)"
echo "[aa] suite dir (IDC SSOT): $ROOT"

# IDC side ready probe (background)
ssh "$IDC_CLIENT" "mkdir -p /tmp/poc-tpcc && touch ${BARRIER}.idc-ready" &
IDC_READY_PID=$!

# GCP side ready probe + seed（run.sh fail-closed 需要 .prepare.done；prepare 實際由
# IDC 端 suite 鏈完成 — 同一 cluster，GCP 端只 seed 佐證 marker，不跑 prepare）
ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "mkdir -p /tmp/poc-tpcc '$ROOT' && touch ${BARRIER}.gcp-ready && \
  printf '%s\n' '{\"phase\":\"prepare\",\"seeded_by\":\"run-vm6-aa.sh\",\"note\":\"prepare done on IDC side; same cluster\",\"ts\":\"${TS}\"}' > '$ROOT/.prepare.done'" &
GCP_READY_PID=$!

wait $IDC_READY_PID $GCP_READY_PID

echo "[aa] both sides ready; launching workload (sync window = same wallclock second)"

# Kick off — sleep 5s grace then both sides start
LAUNCH_AT=$(($(date +%s) + 5))

# IDC side
ssh "$IDC_CLIENT" "
  export TS='${TS}' PLACEMENT='${PLACEMENT}' PROFILE='${PROFILE}' ROUND_SIDE=IDC \
         DB='${DB}' TOPOLOGY='${TOPOLOGY}' ISO='${ISO}' WAREHOUSES='${WAREHOUSES}' \
         THREADS_LIST='${THREADS_LIST}' ROUNDS='${ROUNDS}' WARMUP_SEC='${WARMUP_SEC}' \
         RUN_SEC='${RUN_SEC}' ROUND_SLEEP_SEC='${ROUND_SLEEP_SEC}' \
         TPCC_ARTIFACTS='${TPCC_ARTIFACTS}' CLUSTER_HOSTS='${CLUSTER_HOSTS}' \
         WAN_PROBE_ENABLED='${WAN_PROBE_ENABLED}' WAN_PROBE_IPERF='${WAN_PROBE_IPERF}' \
         GCP_PROBE_DB_HOST='${GCP_PROBE_DB_HOST}' \
         DB_HOST='${IDC_DB_HOST}' DB_PORT='${IDC_DB_PORT}' \
         TIDB_PORT='${IDC_DB_PORT}' TIDB_USER='${TIDB_USER}' TIDB_DB='${TIDB_DB}' \
         CRDB_PORT='${IDC_DB_PORT}' CRDB_USER='${CRDB_USER}' CRDB_DB='${CRDB_DB}' \
         YBDB_PORT='${IDC_DB_PORT}' YBDB_USER='${YBDB_USER}' YBDB_DB='${YBDB_DB}' \
         PHASE_NAME='${PHASE_NAME}' RESULT_SCOPE='${RESULT_SCOPE}' BASELINE_FAMILY='${BASELINE_FAMILY}' \
         tuning_profile_id='${tuning_profile_id}'
  # Wait until LAUNCH_AT epoch (per-host clock; chrony drift <100ms 已驗)
  while [ \$(date +%s) -lt ${LAUNCH_AT} ]; do sleep 0.2; done
  # standard TPCC mix
  bash /tmp/poc-tpcc/scripts/run.sh --db '${DB}' --iso '${ISO}' \
    --topology '${TOPOLOGY}' --db-host '${IDC_DB_HOST}' --ts '${TS}'
" 2>&1 | sed 's/^/[idc] /' &
IDC_PID=$!

# GCP side (A-A-RO 帶 GO_TPC_MIX_FLAG read-only mix；A-A 同 IDC standard)
# WAN probe / cluster fan-out 只在 IDC 端跑（避免雙端重複採樣互擾、GCP→IDC SSH 未 prime）
ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "
  export TS='${TS}' PLACEMENT='${PLACEMENT}' PROFILE='${PROFILE}' ROUND_SIDE=GCP \
         DB='${DB}' TOPOLOGY='${TOPOLOGY}' ISO='${ISO}' WAREHOUSES='${WAREHOUSES}' \
         THREADS_LIST='${THREADS_LIST}' ROUNDS='${ROUNDS}' WARMUP_SEC='${WARMUP_SEC}' \
         RUN_SEC='${RUN_SEC}' ROUND_SLEEP_SEC='${ROUND_SLEEP_SEC}' \
         TPCC_ARTIFACTS='${TPCC_ARTIFACTS}' \
         WAN_PROBE_ENABLED=0 WAN_PROBE_IPERF=0 \
         DB_HOST='${GCP_DB_HOST}' DB_PORT='${GCP_DB_PORT}' \
         TIDB_PORT='${GCP_DB_PORT}' TIDB_USER='${TIDB_USER}' TIDB_DB='${TIDB_DB}' \
         CRDB_PORT='${GCP_DB_PORT}' CRDB_USER='${CRDB_USER}' CRDB_DB='${CRDB_DB}' \
         YBDB_PORT='${GCP_DB_PORT}' YBDB_USER='${YBDB_USER}' YBDB_DB='${YBDB_DB}' \
         PHASE_NAME='${PHASE_NAME}' RESULT_SCOPE='${RESULT_SCOPE}' BASELINE_FAMILY='${BASELINE_FAMILY}' \
         tuning_profile_id='${tuning_profile_id}' \
         GO_TPC_MIX_FLAG='${GCP_MIX_FLAG}'
  while [ \$(date +%s) -lt ${LAUNCH_AT} ]; do sleep 0.2; done
  # GCP-side go-tpc run; read-only mix (if A-A-RO) 由 run.sh GO_TPC_MIX_FLAG passthrough 展開
  bash /tmp/poc-tpcc/scripts/run.sh --db '${DB}' --iso '${ISO}' \
    --topology '${TOPOLOGY}' --db-host '${GCP_DB_HOST}' --ts '${TS}'
" 2>&1 | sed 's/^/[gcp] /' &
GCP_PID=$!

IDC_RC=0; wait $IDC_PID || IDC_RC=$?
GCP_RC=0; wait $GCP_PID || GCP_RC=$?

echo "[aa] IDC side rc=$IDC_RC  GCP side rc=$GCP_RC"

if [[ $IDC_RC -ne 0 || $GCP_RC -ne 0 ]]; then
  echo "[aa] FAIL — at least one side returned non-zero" >&2
  exit 1
fi

# G3（2026-07-15 拍板）: GCP 端每輪 go-tpc stdout 精確落位到 IDC suite 目錄
# runs/threads-N/round-M/go-tpc-stdout-gcp.txt（與 IDC 檔並排；merge 在 .31 上執行，
# .31 → GCP client 走內網直連，不走 IAP）。缺檔 / 空檔 → fail-closed。
echo "[aa] G3 merge: GCP-side per-round stdout → $ROOT (go-tpc-stdout-gcp.txt)"
ssh "$IDC_CLIENT" "bash '${CROSS_SCRIPTS_REMOTE}/merge-gcp-stdout.sh' --root '$ROOT' --gcp-host '$GCP_CLIENT_IP'"

echo "[aa] dual-side AA run PASS — TS=$TS PLACEMENT=$PLACEMENT PROFILE=$PROFILE"
echo "[aa] next: summary-from-stdout.py（IDC 主表）→ summary-gcp-side.py（gcp_side 注入）— 由 Makefile 收尾步驟執行"
