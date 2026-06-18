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
#   DB=tidb (this round; crdb / ybdb TODO)
#
# Args:
#   --db {tidb}  --topology vm-6node-{P-A|P-B}  --ts <ts>
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

: "${DB:?--db required (tidb only this round; crdb/ybdb TODO)}"
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
[[ "$DB"        =~ ^tidb$                 ]] || { echo "DB must be tidb (crdb/ybdb TODO this agent)" >&2; exit 1; }

# DB endpoint: IDC haproxy on 172.24.47.20:4000 (Q3 雙 haproxy 配置；IDC 既有 .47.20)
# A-A profile 也可從 GCP haproxy (g-test-poc-4:4000) 出發；本 wrapper 默認走 IDC haproxy。
: "${DB_HOST:=172.24.47.20}"
: "${DB_PORT:=4000}"

# Suite ISO mapping (manifest pins rc-only — phase-crossregion/manifest.yaml)
ISO="${ISO:-rc}"

# Per-DB env required by tests/common/{prepare,run,collect}.sh
case "$DB" in
  tidb) export TIDB_PORT="$DB_PORT" TIDB_USER="${TIDB_USER:-root}" TIDB_DB="${TIDB_DB:-tpcc}" ;;
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

# fan-out CLUSTER_HOSTS (logical_id@addr:port)
: "${CLUSTER_HOSTS:=idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@localhost:12211 gcp-dbhost-2@localhost:12212 gcp-dbhost-3@localhost:12213}"

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

echo "[1/4] gate"
bash "$COMMON_DIR/gate.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[2/4] prepare"
bash "$COMMON_DIR/prepare.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

# B0-3: prepare 完成 tpcc tables 後，才套 ALTER DATABASE + ALTER TABLE 部分
# (CREATE POLICY 已由 ansible deploy 階段做完；本段只跑 SQL 檔的 "-- tpcc database 套用" 後段)
if [[ "$DB" == "tidb" ]]; then
  PLACEMENT_SQL_FILE="/root/tidb-vm6-placement-${PLACEMENT,,}.sql"
  echo "[wrapper] applying table-level placement from $PLACEMENT_SQL_FILE"
  ssh -o ConnectTimeout=5 root@172.24.40.32 "awk '/^-- tpcc database 套用/{p=1}p' $PLACEMENT_SQL_FILE | mysql -h 172.24.40.32 -P 4000 -uroot tpcc" \
    || { echo "[wrapper] placement ALTER fail-closed" >&2; exit 1; }
fi

echo "[3/4] run (warmup + sweep, contains gate-isolation)"
# A-A-RO profile: GCP-side 不參與此 wrapper（read-only follower mix 由 run-vm6-aa.sh 啟）
# A-A profile : 同步雙側由 run-vm6-aa.sh orchestrate；此 wrapper 純 IDC writer
if [[ "$PROFILE" == "A-A-RO" || "$PROFILE" == "A-A" ]]; then
  echo "[wrapper] PROFILE=$PROFILE → IDC writer side only; GCP side handled by run-vm6-aa.sh"
fi
bash "$COMMON_DIR/run.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[4/4] collect"
bash "$COMMON_DIR/collect.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

# write .suite.done
source "$COMMON_DIR/lib/common.sh"
write_phase_done "$ROOT" "suite" "$(cat <<JSON
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

echo "[wrapper] FULL chain PASS — $ROOT"
