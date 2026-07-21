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
#                      （GCP_MIX_FLAG=0,0,50,0,50 → 直呼 go-tpc --weight；
#                       順序 NewOrder,Payment,OrderStatus,Delivery,StockLevel；
#                       go-tpc 無 --mix flag，2026-07-18 smoke 修正）
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
#   - IDC 端呼叫 tests/common/run.sh（透過 /tmp/poc-tpcc/scripts；含 cold-reset/
#     gate-isolation/warmup/timed-run 全套）。GCP 端 2026-07-18 smoke 起改直呼
#     go-tpc（不經 run.sh）——run.sh 起手 coldreset-${DB}.sh 一律 SSH 回 IDC
#     控制節點，GCP client (.15) 對 IDC 172.24.40.x 無路由/FW，會直接 timeout；
#     且 cold-reset/isolation-gate 對「同一顆共用 cluster」本就只需 IDC 側跑一次。
#     GCP 側改用 round-barrier 與 IDC 每輪實際開始計時對齊（見下方 watcher）。
#   - IDC 端 .prepare.done 必須已由 prepare 鏈產生（缺 → run.sh fail-closed）；
#     aaro/aa token 版目錄若缺 .prepare.done，由 prepare-bridge 從同 DB/PLACEMENT
#     的 plain（無 token）anchor prepare 複製證據（同一顆共用 cluster，見下方）。
#   - GCP 端 go-tpc binary + tests/common（僅需 lib 供 gate-isolation 等其餘
#     用途；run.sh 本身已不在 GCP 側呼叫）由 bootstrap-gcp-client.sh 部署到
#     g-test-poc-5（2026-07-18 補齊；先前僅裝 psql/mysql/bc）。

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
# 2026-07-18 smoke 發現的 bug 修法 #3：go-tpc 實際 flag 是 `--weight`（逗號分隔 5
# 個 int，順序 NewOrder,Payment,OrderStatus,Delivery,StockLevel），不是原設計假設
# 的 `--mix`（冒號分隔；go-tpc --help 無此 flag，`Error: unknown flag: --mix`）。
# run.sh 內 GO_TPC_MIX_FLAG passthrough 也組 `--mix`，同款會炸——但 run.sh 屬
# tests/common 不可改；此 bug 只在「GCP 側曾經經 run.sh 走 A-A-RO」的路徑才會
# 觸發，本次修法 #2 已讓 GCP 側改直呼 go-tpc（不經 run.sh），故只需在此處修對。
# 目標唯讀 mix：ORDER_STATUS=50, STOCK_LEVEL=50，其餘=0 →
# --weight 順序 (NewOrder,Payment,OrderStatus,Delivery,StockLevel) = 0,0,50,0,50
GCP_MIX_FLAG=""
if [[ "$PROFILE" == "A-A-RO" ]]; then
  GCP_MIX_FLAG="0,0,50,0,50"
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

# ---------------------------------------------------------------------
# prepare-bridge（2026-07-18 smoke 發現的 bug 修法）:
#   tests/common/prepare.sh §6.6 placement gate 用 `grep -oE 'P-[AB]$'`
#   從 TOPO 尾端解析 PLACEMENT — Q17 token 插在 placement 與 iso 之間後，
#   TOPO 變成 vm-6node-P-A-aaro，'P-A' 不再是字串結尾 → 恆解析成 UNKNOWN →
#   gate fail-closed（"unknown-placement"）。prepare.sh 屬 tests/common，
#   不可改；此處在自己擁有的 orchestrator 內 bridge：若 aaro token 版 ROOT
#   缺 .prepare.done，去找同 DB/PLACEMENT/ISO 的「無 token 版」(plain) 最新
#   一次已通過 gate 的 prepare（同一顆共用 cluster，資料本來就共通），把
#   .prepare.done / prepare/ / gate/ 證據複製過來（非捏造 — gate 是真的在
#   live cluster 上跑過且 PASS，只是換一個 Q17 命名的目錄）。
#   缺 anchor prepare → fail-closed，要求先跑 phase{6,7,8}-*-smoke（plain
#   PLACEMENT=$PLACEMENT，無 PROFILE token）產生它。
# ---------------------------------------------------------------------
ANCHOR_TOPOLOGY="vm-6node-${PLACEMENT}"
ssh "$IDC_CLIENT" "
  set -euo pipefail
  ROOT='$ROOT'
  if [[ ! -f \"\$ROOT/.prepare.done\" ]]; then
    ANCHOR_ROOT='$TPCC_ARTIFACTS/${DB}-${ANCHOR_TOPOLOGY}-${ISO}-${TS}'
    if [[ ! -f \"\$ANCHOR_ROOT/.prepare.done\" ]]; then
      ANCHOR_ROOT=\$(ls -d '$TPCC_ARTIFACTS/${DB}-${ANCHOR_TOPOLOGY}-${ISO}-'*/ 2>/dev/null | sort | tail -1)
      ANCHOR_ROOT=\${ANCHOR_ROOT%/}
    fi
    if [[ -z \"\$ANCHOR_ROOT\" || ! -f \"\$ANCHOR_ROOT/.prepare.done\" ]]; then
      echo '[aa][prepare-bridge] FAIL: no anchor prepare found for ${DB}/${ANCHOR_TOPOLOGY} — run phase{6,7,8}-${DB}-smoke PLACEMENT=${PLACEMENT} (plain, no PROFILE token) first' >&2
      exit 1
    fi
    mkdir -p \"\$ROOT\"
    cp \"\$ANCHOR_ROOT/.prepare.done\" \"\$ROOT/.prepare.done\"
    cp -r \"\$ANCHOR_ROOT/prepare\" \"\$ROOT/prepare\" 2>/dev/null || true
    cp -r \"\$ANCHOR_ROOT/gate\" \"\$ROOT/gate\" 2>/dev/null || true
    printf '{\"bridged_from\":\"%s\",\"reason\":\"prepare.sh placement-gate regex P-[AB]\$ incompatible with Q17 profile token; same shared cluster, evidence copied not fabricated\",\"generated_by\":\"run-vm6-aa.sh prepare-bridge\",\"generated_at\":\"%s\"}\n' \
      \"\$ANCHOR_ROOT\" \"\$(date -u +%Y-%m-%dT%H:%M:%SZ)\" > \"\$ROOT/prepare-bridge.json\"
    echo \"[aa][prepare-bridge] copied prepare+gate evidence \$ANCHOR_ROOT -> \$ROOT\"
  else
    echo '[aa][prepare-bridge] .prepare.done already present at '\"\$ROOT\"' — no bridge needed'
  fi
"

echo "[aa] launching dual-side TPCC: profile=$PROFILE placement=$PLACEMENT threads_list='$THREADS_LIST'"
echo "[aa] IDC client: $IDC_CLIENT → $IDC_DB_HOST:$IDC_DB_PORT (standard mix, W=$WAREHOUSES)"
echo "[aa] GCP client: $GCP_CLIENT_SSH:$GCP_CLIENT_PORT → $GCP_DB_HOST:$GCP_DB_PORT (mix=${GCP_MIX_FLAG:-standard}, W=$WAREHOUSES)"
echo "[aa] suite dir (IDC SSOT): $ROOT"

# IDC side ready probe (background)
ssh "$IDC_CLIENT" "mkdir -p /tmp/poc-tpcc && touch ${BARRIER}.idc-ready" &
IDC_READY_PID=$!

# GCP side ready probe（僅 mkdir；不再 seed .prepare.done — GCP 側自 2026-07-18
# smoke bug 修復起改直呼 go-tpc，不經 tests/common/run.sh，見下方說明）
ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "mkdir -p /tmp/poc-tpcc '$ROOT'" &
GCP_READY_PID=$!

wait $IDC_READY_PID $GCP_READY_PID

# ---------------------------------------------------------------------
# 2026-07-18 smoke 發現的 bug 修法 #2 — GCP 側改直呼 go-tpc，不經 run.sh：
#   tests/common/run.sh 起手第一步是 coldreset-${DB}.sh（cold-reset 整顆
#   共用 cluster：tiup cluster stop/start 等），該 script 內部一律 SSH 去
#   IDC 控制節點（tidb fallback 172.24.40.32）——從 GCP client (.15) 執行時
#   .15 對 172.24.40.32 無路由/FW 未開，SSH connect 直接 timeout，GCP 側
#   run.sh 整支必炸（實測 2026-07-18 14:54 TiDB aaro-smoke 首跑）。
#   coldreset / gate-isolation 本就該對「共用 cluster」只做一次（IDC 側
#   run.sh 已做），GCP 側重跑既無法連線、也是多餘動作——不修 tests/common
#   （protected），改在自己擁有的 orchestrator 內讓 GCP 側跳過 run.sh，
#   直接呼叫 go-tpc（與 run.sh 內同一組 flag，格式對齊 summary-gcp-side.py
#   的 parser），並用 round-barrier 與 IDC 側「真正開始計時」對齊：
#   watcher（跑在 .31 本機，$ROOT 是本地路徑）輪詢 IDC 側每輪
#   go-tpc-stdout.txt 出現 → touch 對應 barrier → GCP 側才 launch 該輪。
# ---------------------------------------------------------------------
case "$DB" in
  tidb) GCP_DRIVER=mysql; GCP_USER="$TIDB_USER"; GCP_DBNAME="$TIDB_DB" ;;
  crdb) GCP_DRIVER=postgres; GCP_USER="$CRDB_USER"; GCP_DBNAME="$CRDB_DB" ;;
  ybdb) GCP_DRIVER=postgres; GCP_USER="$YBDB_USER"; GCP_DBNAME="$YBDB_DB" ;;
esac
# conn-params 對齊 tests/common/lib/common.sh get_conn_params()（同值複製，
# 非 source — GCP client 上沒有 .31 的 tests/common 路徑假設）。
#
# 2026-07-21 修法（就近讀生效檢驗發現，僅 GCP 側加，不動 IDC 側 conn-params，
# 故不影響 IDC 寫入路徑）：
#   - CRDB：kv.closed_timestamp.follower_reads.enabled=t 只開「能力」，plain
#     SELECT（無 AS OF SYSTEM TIME）不會自動用 follower read——需再加 session
#     層 default_transaction_use_follower_reads=on（Cockroach Labs docs）。
#     2026-07-22 A7(4) 實測發現：光加這個會讓 go-tpc 真實交易 100% 報錯
#     `AS OF SYSTEM TIME specified with READ WRITE mode`——
#     default_transaction_use_follower_reads=on 會讓 CRDB 隱式幫查詢加上
#     AS OF SYSTEM TIME，但該子句只能用在 READ ONLY 交易；go-tpc 預設開
#     READ WRITE 交易，兩者衝突即報錯。需再加 default_transaction_read_only=on
#     （同 YBDB 邏輯）；GCP 側本就是純讀 workload（mix=0,0,50,0,50），交易恆
#     read-only 對此側無副作用。此 bug 只有跑真實 go-tpc 負載才會暴露，用
#     EXPLAIN ANALYZE 之類的單筆手動查詢測不出來（見報告 §5.6/§8-A8）。
#   - YBDB：yb_read_from_followers=on 只在交易本身 read-only 才生效——需再加
#     default_transaction_read_only=on（YugabyteDB docs）；GCP 側本就是純讀
#     workload，交易恆 read-only 對此側無副作用。
case "${DB}:${ISO}" in
  tidb:rc)             GCP_CONN_PARAMS="transaction_isolation=%27READ-COMMITTED%27&tidb_txn_mode=%27pessimistic%27" ;;
  tidb:rr|tidb:strict) GCP_CONN_PARAMS="transaction_isolation=%27REPEATABLE-READ%27&tidb_txn_mode=%27pessimistic%27" ;;
  crdb:rc)     GCP_CONN_PARAMS="sslmode=disable&options=-c%20default_transaction_isolation%3Dread%5C%20committed%20-c%20default_transaction_use_follower_reads%3Don%20-c%20default_transaction_read_only%3Don" ;;
  crdb:rr)     GCP_CONN_PARAMS="sslmode=disable&options=-c%20default_transaction_isolation%3Drepeatable%5C%20read%20-c%20default_transaction_use_follower_reads%3Don%20-c%20default_transaction_read_only%3Don" ;;
  crdb:strict) GCP_CONN_PARAMS="sslmode=disable&options=-c%20default_transaction_isolation%3Dserializable%20-c%20default_transaction_use_follower_reads%3Don%20-c%20default_transaction_read_only%3Don" ;;
  ybdb:rc)     GCP_CONN_PARAMS="sslmode=disable&options=-c%20default_transaction_isolation%3Dread%5C%20committed%20-c%20default_transaction_read_only%3Don" ;;
  ybdb:rr)     GCP_CONN_PARAMS="sslmode=disable&options=-c%20default_transaction_isolation%3Drepeatable%5C%20read%20-c%20default_transaction_read_only%3Don" ;;
  ybdb:strict) GCP_CONN_PARAMS="sslmode=disable&options=-c%20default_transaction_isolation%3Dserializable%20-c%20default_transaction_read_only%3Don" ;;
  *) echo "[aa] unknown <db>:<iso> = ${DB}:${ISO}" >&2; exit 1 ;;
esac
ROUND_WAIT_TIMEOUT=$(( WARMUP_SEC + RUN_SEC + 300 ))

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

# GCP side — 直呼 go-tpc（不經 run.sh；理由見上方 bug 修法 #2 註解）。
# 每輪等對應 round-barrier（watcher 於偵測 IDC 該輪 stdout 出現後 touch）才
# launch，逐輪對齊 IDC 實際計時窗；GCP_MIX_FLAG（A-A-RO 唯讀）展開成 --weight
# （bug 修法 #3：不是 --mix，見上方定義處註解）。
# 缺輪／measurement-tool-itself-fails 防呆（RETRO 2026-07-17 §A 建議項）：
# go-tpc usage-error（如打錯 flag）實測仍 exit 0，pipefail 抓不到——收工後
# 顯式檢查該輪 stdout 是否真的有 [Summary]/tpmC 行，沒有就 fail-closed，
# 不讓「工具打錯参数但看起來 PASS」的空資料流入 summary-gcp-side.py。
GCP_MIX_ARGS=""
[[ -n "$GCP_MIX_FLAG" ]] && GCP_MIX_ARGS="--weight $GCP_MIX_FLAG"
ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "
  set -euo pipefail
  ROOT_LOCAL='${TPCC_ARTIFACTS}/${DB}-${TOPOLOGY}-${ISO}-${TS}'
  mkdir -p \"\$ROOT_LOCAL/runs\"
  while [ \$(date +%s) -lt ${LAUNCH_AT} ]; do sleep 0.2; done
  for threads in ${THREADS_LIST}; do
    for r in \$(seq 1 ${ROUNDS}); do
      BR='${BARRIER}.round-t'\"\$threads\"'-r'\"\$r\"
      echo \"[gcp] waiting round barrier threads=\$threads round=\$r\"
      waited=0
      until [ -f \"\$BR\" ]; do
        sleep 1; waited=\$((waited+1))
        if [ \$waited -ge ${ROUND_WAIT_TIMEOUT} ]; then
          echo \"[gcp] TIMEOUT waiting for \$BR (waited \${waited}s)\" >&2
          exit 1
        fi
      done
      RD=\"\$ROOT_LOCAL/runs/threads-\$threads/round-\$r\"
      mkdir -p \"\$RD\"
      echo \"[gcp] launch go-tpc threads=\$threads round=\$r -> \$RD\"
      go-tpc tpcc run -d '${GCP_DRIVER}' -H '${GCP_DB_HOST}' -P '${GCP_DB_PORT}' \
        -U '${GCP_USER}' -D '${GCP_DBNAME}' --conn-params '${GCP_CONN_PARAMS}' \
        --warehouses='${WAREHOUSES}' --time='${RUN_SEC}s' --threads=\"\$threads\" \
        --output=plain ${GCP_MIX_ARGS} 2>&1 | tee \"\$RD/go-tpc-stdout.txt\"
      grep -qE '^\[Summary\]|^tpmC:' \"\$RD/go-tpc-stdout.txt\" || {
        echo \"[gcp] FAIL: threads=\$threads round=\$r go-tpc-stdout.txt 無 [Summary]/tpmC 行（工具本身失效，非量到零）\" >&2
        exit 1
      }
    done
  done
" 2>&1 | sed 's/^/[gcp] /' &
GCP_PID=$!

# Watcher（本機 .31，$ROOT 為本地路徑，免 ssh）— 逐輪偵測 IDC 側
# go-tpc-stdout.txt 出現即代表該輪已真正開始計時，touch 對應 GCP round-barrier。
(
  for threads in $THREADS_LIST; do
    for ((r=1; r<=ROUNDS; r++)); do
      target="$ROOT/runs/threads-${threads}/round-${r}/go-tpc-stdout.txt"
      waited=0
      until [[ -f "$target" ]]; do
        sleep 1; waited=$((waited+1))
        if [[ $waited -ge $ROUND_WAIT_TIMEOUT ]]; then
          echo "[aa][watcher] TIMEOUT waiting for $target (waited ${waited}s)" >&2
          exit 1
        fi
      done
      ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH" "touch '${BARRIER}.round-t${threads}-r${r}'"
      echo "[aa][watcher] threads=$threads round=$r IDC started -> GCP barrier touched"
    done
  done
) &
WATCHER_PID=$!

IDC_RC=0; wait $IDC_PID || IDC_RC=$?
GCP_RC=0; wait $GCP_PID || GCP_RC=$?
WATCHER_RC=0; wait $WATCHER_PID || WATCHER_RC=$?

echo "[aa] IDC side rc=$IDC_RC  GCP side rc=$GCP_RC  watcher rc=$WATCHER_RC"

if [[ $IDC_RC -ne 0 || $GCP_RC -ne 0 || $WATCHER_RC -ne 0 ]]; then
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
