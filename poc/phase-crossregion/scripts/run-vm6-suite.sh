#!/usr/bin/env bash
# phase-crossregion/scripts/run-vm6-suite.sh
#
# Single-side TPCC suite wrapper for 6-node cross-region cluster
# (mirrors phase-k8s/run-k8s-suite.sh chain：gate → prepare → run → collect).
#
# 適用 profile: A-S (IDC writer only) + A-A-RO (GCP read-only side handled by run-vm6-aa.sh)
# A-A 雙側 RW 由 run-vm6-aa.sh orchestrate (此 script 仍可作為 IDC-side 部分被呼叫)。
#
# Required env (Makefile-provided):
#   PHASE_NAME=phase-crossregion
#   RESULT_SCOPE=X-CROSS
#   BASELINE_FAMILY=crossregion
#   tuning_profile_id=default
#   TPCC_TS=<ts>
#   PLACEMENT=P-A|P-B
#   PROFILE=A-S|A-A-RO|A-A
#   DB=tidb|crdb|ybdb
#
# Args:
#   --db {tidb|crdb|ybdb}  --topology vm-6node-{P-A|P-B}  --ts <ts>
#
# Side: IDC by default (TPCC client = .31)。GCP side 由 run-vm6-aa.sh 啟動。
#
# Safety:
#   - 嚴禁觸碰 tests/common/*.sh, phase-k8s/* (per worktree forbidden list)
#   - 嚴禁修改 .31 上 binary，只 rsync scripts (沿用 bootstrap-tpcc-client)
#   - placement SQL apply 已由 ansible playbook 在 deploy 階段完成；此 script 假設 placement actual == expected

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

: "${DB:?--db required (tidb | crdb | ybdb)}"
: "${TOPOLOGY:?--topology required (vm-6node-P-A | vm-6node-P-B)}"
: "${TS:?--ts required}"

# scope guards
: "${PHASE_NAME:?missing PHASE_NAME=phase-crossregion}"
: "${RESULT_SCOPE:?missing RESULT_SCOPE=X-CROSS}"
: "${BASELINE_FAMILY:?missing BASELINE_FAMILY=crossregion}"
: "${PLACEMENT:?missing PLACEMENT=P-A|P-B}"
: "${PROFILE:?missing PROFILE=A-S|A-A-RO|A-A}"
: "${tuning_profile_id:=default}"

[[ "$PHASE_NAME"      == "phase-crossregion" ]] || { echo "PHASE_NAME must be phase-crossregion" >&2; exit 1; }
[[ "$RESULT_SCOPE"    == "X-CROSS"           ]] || { echo "RESULT_SCOPE must be X-CROSS" >&2; exit 1; }
[[ "$BASELINE_FAMILY" == "crossregion"       ]] || { echo "BASELINE_FAMILY must be crossregion" >&2; exit 1; }
[[ "$PLACEMENT" =~ ^(P-A|P-B)$            ]] || { echo "PLACEMENT must be P-A | P-B" >&2; exit 1; }
[[ "$PROFILE"   =~ ^(A-S|A-A-RO|A-A)$     ]] || { echo "PROFILE must be A-S | A-A-RO | A-A" >&2; exit 1; }
[[ "$DB"        =~ ^(tidb|crdb|ybdb)$     ]] || { echo "DB must be tidb | crdb | ybdb" >&2; exit 1; }

# DB endpoint: IDC haproxy on 172.24.47.20:4000 (Q3 雙 haproxy 配置；IDC 既有 .47.20)
# A-A profile 也可從 GCP haproxy (g-test-poc-4:4000) 出發；本 wrapper 默認走 IDC haproxy。
: "${DB_HOST:=172.24.47.20}"
: "${DB_PORT:=4000}"

# Suite ISO mapping (manifest pins rc-only — phase-crossregion/manifest.yaml)
ISO="${ISO:-rc}"

# Per-DB env required by tests/common/{prepare,run,collect}.sh
case "$DB" in
  tidb) export TIDB_PORT="$DB_PORT" TIDB_USER="${TIDB_USER:-root}" TIDB_DB="${TIDB_DB:-tpcc}" ;;
  crdb) export CRDB_PORT="$DB_PORT" CRDB_USER="${CRDB_USER:-root}" CRDB_DB="${CRDB_DB:-tpcc}" ;;
  ybdb) export YBDB_PORT="$DB_PORT" YBDB_USER="${YBDB_USER:-yugabyte}" YBDB_DB="${YBDB_DB:-tpcc}" ;;
esac

# CLIENT_ZONE 必填（zone-local enforce per §3）
: "${CLIENT_ZONE:?missing CLIENT_ZONE=idc|gcp (zone-local enforce; per REPLAN §3)}"
[[ "$CLIENT_ZONE" =~ ^(idc|gcp)$ ]] || { echo "CLIENT_ZONE must be idc | gcp" >&2; exit 1; }
case "$CLIENT_ZONE" in
  idc)
    [[ "$DB_HOST" =~ ^(172\.24\.47\.20|172\.24\.40\.3[234])$ ]] || \
      { echo "CLIENT_ZONE=idc but DB_HOST=$DB_HOST not in idc-haproxy/.32/.33/.34 — fail-closed" >&2; exit 1; }
    ;;
  gcp)
    [[ "$DB_HOST" =~ ^10\.160\.152\.1[1-5]$ ]] || \
      { echo "CLIENT_ZONE=gcp but DB_HOST=$DB_HOST not in 10.160.152.11-15 — fail-closed" >&2; exit 1; }
    ;;
esac

# Pre-flight: chrony cross-region drift gate (Q10, fail-closed <100ms)
# GATE_SKIP=1: skip if upstream (MAC-side) already verified; suite cannot reach IAP tunnels.
if [[ "${GATE_SKIP:-0}" == "1" ]]; then
  echo "[wrapper] step 0/5 chrony gate SKIP (GATE_SKIP=1)"
else
  echo "[wrapper] step 0/5 chrony-cross-region drift gate"
  bash "$SELF/gate-chrony-cross-region.sh" --ts "$TS" --root-suffix "${DB}-${TOPOLOGY}-${ISO}-${TS}" \
    --result-scope "$RESULT_SCOPE"
fi

# fan-out CLUSTER_HOSTS（wrapper 跑在 .31 → GCP 一律直連內網 IP；
# 舊預設 localhost:1221x 是 IAP 殘留，會讓 per-round GCP metrics 全漏）
: "${CLUSTER_HOSTS:=idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@10.160.152.11 gcp-dbhost-2@10.160.152.12 gcp-dbhost-3@10.160.152.13}"

export CLUSTER_HOSTS DB DB_HOST DB_PORT TOPOLOGY ISO CLIENT_ZONE \
  PHASE_NAME RESULT_SCOPE BASELINE_FAMILY tuning_profile_id PLACEMENT PROFILE

# tests/common deployed location on .31 (bootstrap-tpcc-client target)
COMMON_DIR="${COMMON_DIR:-/tmp/poc-tpcc/scripts}"
TPCC_ARTIFACTS="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts/$RESULT_SCOPE}"
ROOT="$TPCC_ARTIFACTS/${DB}-${TOPOLOGY}-${ISO}-${TS}"
mkdir -p "$ROOT"
export TPCC_ARTIFACTS

echo "[wrapper] DB=$DB TOPOLOGY=$TOPOLOGY PLACEMENT=$PLACEMENT PROFILE=$PROFILE CLIENT_ZONE=$CLIENT_ZONE"
echo "[wrapper] CLUSTER_HOSTS=$CLUSTER_HOSTS"
echo "[wrapper] DB_HOST=$DB_HOST:$DB_PORT"

# =====================================================================
# DRY_RUN=1: only env/scope/chrony/SSH/endpoint/binary/file check, STOP
# =====================================================================
: "${DRY_RUN:=0}"
if [[ "$DRY_RUN" == "1" ]]; then
  DRY_OUT="$ROOT/dry-run"
  mkdir -p "$DRY_OUT"
  echo "[wrapper] DRY_RUN=1 — STOP before gate/prepare/run/collect; only pre-flight checks"

  # 1. SSH connectivity (only check; do not write to .31 production paths)
  echo "[dry-run] step 1/5 SSH connectivity"
  case "$CLIENT_ZONE" in
    idc)
      ssh -o ConnectTimeout=5 -o BatchMode=yes root@172.24.40.31 'true' 2>&1 | tee "$DRY_OUT/ssh-idc-client.txt" \
        || { echo "[dry-run] SSH .31 fail" >&2; echo "ssh-idc-client=FAIL" >> "$DRY_OUT/.dry-run.done.tmp"; }
      ;;
    gcp)
      ssh -o ConnectTimeout=5 -o BatchMode=yes -p 12215 root@localhost 'true' 2>&1 | tee "$DRY_OUT/ssh-gcp-client.txt" \
        || { echo "[dry-run] SSH GCP client (IAP 12215) fail" >&2; echo "ssh-gcp-client=FAIL" >> "$DRY_OUT/.dry-run.done.tmp"; }
      ;;
  esac

  # 2. DB endpoint reachable
  echo "[dry-run] step 2/5 DB endpoint $DB_HOST:$DB_PORT"
  if [[ "$CLIENT_ZONE" == "idc" ]]; then
    ssh -o ConnectTimeout=5 root@172.24.40.31 "nc -zv $DB_HOST $DB_PORT 2>&1 | head -3" \
      | tee "$DRY_OUT/db-endpoint.txt" || true
  else
    ssh -o ConnectTimeout=5 -p 12215 root@localhost "nc -zv $DB_HOST $DB_PORT 2>&1 | head -3" \
      | tee "$DRY_OUT/db-endpoint.txt" || true
  fi

  # 3. COMMON_DIR + go-tpc binary presence
  echo "[dry-run] step 3/5 COMMON_DIR + go-tpc presence"
  if [[ "$CLIENT_ZONE" == "idc" ]]; then
    ssh -o ConnectTimeout=5 root@172.24.40.31 "ls -la $COMMON_DIR 2>&1 | head -5; which go-tpc 2>&1" \
      | tee "$DRY_OUT/binary-check.txt" || true
  else
    ssh -o ConnectTimeout=5 -p 12215 root@localhost "ls -la $COMMON_DIR 2>&1 | head -5; which go-tpc 2>&1" \
      | tee "$DRY_OUT/binary-check.txt" || true
  fi

  # 4. placement SQL file presence (on idc-dbhost-1)
  echo "[dry-run] step 4/5 placement SQL file"
  ssh -o ConnectTimeout=5 root@172.24.40.32 "ls -la /root/tidb-vm6-placement-*.sql 2>&1 | head" \
    | tee "$DRY_OUT/placement-sql-file.txt" || true

  # 5. write .dry-run.done
  cat > "$ROOT/.dry-run.done" <<JSON
{
  "phase": "$PHASE_NAME",
  "result_scope": "$RESULT_SCOPE",
  "db": "$DB",
  "topology": "$TOPOLOGY",
  "placement": "$PLACEMENT",
  "profile": "$PROFILE",
  "client_zone": "$CLIENT_ZONE",
  "db_host": "$DB_HOST",
  "db_port": "$DB_PORT",
  "ts": "$TS",
  "dry_run": true,
  "completed_at": "$(date '+%Y-%m-%dT%H:%M:%S%z')"
}
JSON
  echo "[wrapper] DRY_RUN=1 PASS — see $DRY_OUT/"
  exit 0
fi

# =====================================================================
# DRY_RUN unset/0: FULL chain (gate → prepare → run → collect)
# =====================================================================
echo "[wrapper] FULL chain; DB=$DB TOPOLOGY=$TOPOLOGY PLACEMENT=$PLACEMENT PROFILE=$PROFILE"

[[ -d "$COMMON_DIR" ]] || { echo "[wrapper] missing COMMON_DIR=$COMMON_DIR (tests/common 須先 rsync 至 .31)" >&2; exit 1; }

# F1: write .suite.failed on any error; clean up .suite.done.tmp on exit
_suite_failed() {
  local rc=$?
  [[ $rc -eq 0 ]] && return
  local ts_now; ts_now=$(date '+%Y-%m-%dT%H:%M:%S%z')
  printf '{"phase":"suite","status":"FAILED","db":"%s","topology":"%s","ts":"%s","failed_at":"%s","exit_code":%d}\n' \
    "$DB" "$TOPOLOGY" "$TS" "$ts_now" "$rc" > "$ROOT/.suite.failed"
  rm -f "$ROOT/.suite.done.tmp" 2>/dev/null || true
  # freeze 與 unfreeze 之間失敗 → 兜底解凍（不可留 PD scheduler 永久停擺）
  if [[ -n "${UNFREEZE_SCRIPT:-}" && -f "$ROOT/freeze-state/pd-config-before.json" ]]; then
    echo "[wrapper] failure path: best-effort unfreeze"
    PD_URL="${PD_URL:-http://172.24.40.32:2379}" DUMP_DIR="$ROOT/freeze-state" bash "$UNFREEZE_SCRIPT" || true
  fi
  echo "[wrapper] .suite.failed written (exit=$rc)"
}
trap '_suite_failed' EXIT

echo "[1/4] gate"
bash "$COMMON_DIR/gate.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[2/4] prepare"
# bug #9: prepare.sh 內建 placement gate（§6.6）在 wrapper B0-3 之前開槍，
# 而 prepare 的 DROP DATABASE 會消滅任何先掛的 policy attachment。
# 修法：背景 watcher 等 go-tpc 建完 9 張表就立刻套 placement SQL（tests/common 不可改），
# gate 前還有 load+quiesce+ANALYZE 數分鐘讓 leader 遷移收斂。
PLACEMENT_WATCHER_PID=""
if [[ "$DB" == "tidb" ]]; then
  (
    for i in $(seq 1 300); do
      cnt=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u root -BNe \
        "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='tpcc'" 2>/dev/null || echo 0)
      [[ "$cnt" -ge 9 ]] && break
      sleep 2
    done
    echo "[wrapper] placement watcher: 9 tables present — applying placement SQL (pre-gate)"
    ssh -o ConnectTimeout=5 root@172.24.40.32 \
      "awk '/^-- tpcc database 套用/{p=1}p' /root/tidb-vm6-placement-${PLACEMENT,,}.sql | mysql -h 172.24.40.32 -P 4000 -uroot tpcc" \
      && echo "[wrapper] placement watcher: applied OK" \
      || echo "[wrapper] placement watcher: apply FAILED (gate will fail-closed)" >&2
  ) &
  PLACEMENT_WATCHER_PID=$!
fi
bash "$COMMON_DIR/prepare.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"
[[ -n "$PLACEMENT_WATCHER_PID" ]] && { wait "$PLACEMENT_WATCHER_PID" 2>/dev/null || true; }

# B0-3: prepare 完成 tpcc tables 後的 per-DB post-prepare placement 步驟
# (CREATE POLICY / zone config 已由 ansible deploy 階段做完；本段只跑 table-level 後段)
case "$DB" in
  tidb)
    PLACEMENT_SQL_FILE="/root/tidb-vm6-placement-${PLACEMENT,,}.sql"
    echo "[wrapper] applying table-level placement from $PLACEMENT_SQL_FILE"
    ssh -o ConnectTimeout=5 root@172.24.40.32 "awk '/^-- tpcc database 套用/{p=1}p' $PLACEMENT_SQL_FILE | mysql -h 172.24.40.32 -P 4000 -uroot tpcc" \
      || { echo "[wrapper] placement ALTER fail-closed" >&2; exit 1; }
    ;;
  crdb)
    PLACEMENT_SQL_FILE="/root/crdb-vm6-placement-${PLACEMENT,,}.sql"
    if ssh -o ConnectTimeout=5 root@"$DB_HOST" "test -f $PLACEMENT_SQL_FILE"; then
      echo "[wrapper] post-prepare: apply per-table lease_preferences=IDC (hard leader pin) from $PLACEMENT_SQL_FILE"
      ssh root@"$DB_HOST" "awk '/^-- tpcc database 套用/{p=1}p' $PLACEMENT_SQL_FILE 2>/dev/null | /usr/local/bin/cockroach sql --insecure --host=$DB_HOST:$DB_PORT -d tpcc" \
        || echo "  (warn: per-table CONFIGURE ZONE failed)"
    else
      echo "[wrapper] WARN: $PLACEMENT_SQL_FILE not found on $DB_HOST — skip per-table lease pin"
    fi
    echo "[wrapper] wait CRDB lease holders → IDC region (max 5 min, deterministic gate)"
    converged=0
    for i in $(seq 1 30); do
      pct=$(/usr/local/bin/cockroach sql --insecure --host="$DB_HOST:$DB_PORT" -d tpcc --format=csv -e \
        "SELECT IFNULL(ROUND(SUM(CASE WHEN lease_holder_locality LIKE '%region=idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 1), 0) AS idc_pct FROM [SHOW RANGES FROM DATABASE tpcc WITH TABLES, DETAILS] WHERE table_name IN ('new_order','orders','warehouse','customer','district','history','order_line','item','stock');" \
        2>/dev/null | tail -1 || true)
      case "$pct" in 100|100.*) echo "  CRDB lease holders 100% on IDC"; converged=1; break ;; esac
      printf '  %2d/30 leases on IDC: %s%%\n' "$i" "$pct"
      sleep 10
    done
    [[ "$converged" == "1" ]] || { echo "gate FAIL: CRDB lease holders not 100% IDC after 5min" >&2; exit 1; }
    ;;
  ybdb)
    # ybdb: placement applied at deploy (phase4-ybdb-fix6n); post-prepare = data-move 收斂 + LB freeze
    : "${YB_MASTER_ADDR:=172.24.40.32:7100,172.24.40.33:7100,172.24.40.34:7100}"
    echo "[wrapper] post-prepare: gate on load_move_completion=100% (reliable under read_replica; get_is_load_balancer_idle benign-Idle=0 skipped)"
    converged=0
    for i in $(seq 1 30); do
      out=$(ssh root@"$DB_HOST" "/opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTER_ADDR get_load_move_completion" 2>&1 || true)
      case "$out" in *'Percent complete = 100'*|*'100.'*) echo "  load_move_completion 100% (post-prepare)"; converged=1; break ;; esac
      sleep 10
    done
    [[ "$converged" == "1" ]] || echo "[wrapper] WARN: load_move_completion not 100% after 5min; proceeding (0 tablets remaining = benign)"
    echo "[wrapper] pre-run: freeze YBDB load balancer to prevent tablet leader churn during timed run"
    ssh root@"$DB_HOST" "/opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTER_ADDR set_load_balancer_enabled 0"
    echo "  load balancer disabled"
    ;;
esac

# P-A × tidb: leaders 必須先收斂 100% IDC 才能凍結（bug #8 教訓：
# driver step-0 提早 freeze → leader 無法遷移 → prepare placement gate 必 0% FAIL）
if [[ "$DB" == "tidb" && "$PLACEMENT" == "P-A" ]]; then
  echo "[wrapper] pre-freeze gate: wait tpcc region leaders → 100% IDC (max 5 min)"
  converged=0
  for i in $(seq 1 30); do
    pct=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u root -BNe \
      "SELECT IFNULL(SUM(CASE WHEN s.LABEL LIKE '%idc%' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*),0), 0) FROM information_schema.tikv_region_peers p JOIN information_schema.tikv_store_status s ON p.STORE_ID=s.STORE_ID JOIN information_schema.tikv_region_status r ON p.REGION_ID=r.REGION_ID WHERE p.IS_LEADER=1 AND r.DB_NAME='tpcc';" \
      2>/dev/null | tail -1 || true)
    case "$pct" in 100|100.*) echo "  tpcc leaders 100% on IDC"; converged=1; break ;; esac
    printf '  %2d/30 tpcc leaders on IDC: %s%%\n' "$i" "$pct"
    sleep 10
  done
  [[ "$converged" == "1" ]] || { echo "[wrapper] pre-freeze gate FAIL: leaders not 100% IDC after 5min" >&2; exit 1; }
fi

# steady-state freeze hook（driver 傳入 FREEZE_SCRIPT；此時 placement 已收斂，凍結安全）
if [[ -n "${FREEZE_SCRIPT:-}" ]]; then
  echo "[wrapper] pre-run freeze: $FREEZE_SCRIPT"
  PD_URL="${PD_URL:-http://172.24.40.32:2379}" DUMP_DIR="$ROOT/freeze-state" bash "$FREEZE_SCRIPT"
fi

echo "[3/4] run (warmup + sweep, contains gate-isolation)"
# A-A-RO profile: GCP-side 不參與此 wrapper（read-only follower mix 由 run-vm6-aa.sh 啟）
# A-A profile : 同步雙側由 run-vm6-aa.sh orchestrate；此 wrapper 純 IDC writer
if [[ "$PROFILE" == "A-A-RO" || "$PROFILE" == "A-A" ]]; then
  echo "[wrapper] PROFILE=$PROFILE → IDC writer side only; GCP side handled by run-vm6-aa.sh"
fi
bash "$COMMON_DIR/run.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

# steady-state unfreeze（run 結束即解凍；失敗路徑由 _suite_failed trap 兜底）
if [[ -n "${UNFREEZE_SCRIPT:-}" ]]; then
  echo "[wrapper] post-run unfreeze: $UNFREEZE_SCRIPT"
  PD_URL="${PD_URL:-http://172.24.40.32:2379}" DUMP_DIR="$ROOT/freeze-state" bash "$UNFREEZE_SCRIPT" || true
fi

# ybdb: 對應 B0-3 的 pre-run freeze；run 結束即解凍（同原 phase7 post-run 步驟）
if [[ "$DB" == "ybdb" ]]; then
  echo "[wrapper] post-run: unfreeze YBDB load balancer"
  ssh root@"$DB_HOST" "/opt/yugabyte/bin/yb-admin --master_addresses=$YB_MASTER_ADDR set_load_balancer_enabled 1" || true
fi

echo "[4/4] collect"
bash "$COMMON_DIR/collect.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[4.5/4] summary.json (summary-from-stdout.py --warehouses ${WAREHOUSES:-4})"
python3 "$COMMON_DIR/summary-from-stdout.py" \
  --warehouses "${WAREHOUSES:-4}" \
  --phase "$PHASE_NAME" \
  --result-scope "$RESULT_SCOPE" \
  --baseline-family "$BASELINE_FAMILY" \
  "$ROOT" || echo "[wrapper] WARN: summary-from-stdout.py failed (non-fatal)"

# F1: write .suite.done atomically via tmp → mv; clear failure trap first
trap - EXIT
rm -f "$ROOT/.suite.failed" 2>/dev/null || true

source "$COMMON_DIR/lib/common.sh"
_DONE_PAYLOAD="$(cat <<JSON
{
  "phase": "suite",
  "db": "$DB",
  "iso": "$ISO",
  "topology": "$TOPOLOGY",
  "ts": "$TS",
  "phase_name": "$PHASE_NAME",
  "result_scope": "$RESULT_SCOPE",
  "baseline_family": "$BASELINE_FAMILY",
  "tuning_profile_id": "$tuning_profile_id",
  "placement": "$PLACEMENT",
  "profile": "$PROFILE",
  "completed_at": "$(date '+%Y-%m-%dT%H:%M:%S%z')"
}
JSON
)"
write_phase_done "$ROOT" "suite" "$_DONE_PAYLOAD"
# atomic: write_phase_done writes $ROOT/.suite.done directly; ensure via tmp on same FS
[[ -f "$ROOT/.suite.done" ]] || { echo "[wrapper] ERROR: .suite.done not written" >&2; exit 1; }

echo "[wrapper] FULL chain PASS — $ROOT"
