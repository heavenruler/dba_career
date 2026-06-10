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

# DB endpoint: IDC haproxy on 172.24.40.20:4000 (Q3 雙 haproxy 配置；IDC 既有 .20)
# A-A profile 也可從 GCP haproxy (g-test-poc-4:4000) 出發；本 wrapper 默認走 IDC haproxy。
: "${DB_HOST:=172.24.40.20}"
: "${DB_PORT:=4000}"

# Suite ISO mapping (manifest pins rc-only — phase-crossregion/manifest.yaml)
ISO="${ISO:-rc}"

# Per-DB env required by tests/common/{prepare,run,collect}.sh
case "$DB" in
  tidb) export TIDB_PORT="$DB_PORT" TIDB_USER="${TIDB_USER:-root}" TIDB_DB="${TIDB_DB:-tpcc}" ;;
esac

# Pre-flight: chrony cross-region drift gate (Q10, fail-closed <100ms)
echo "[wrapper] step 0/5 chrony-cross-region drift gate"
bash "$SELF/gate-chrony-cross-region.sh" --ts "$TS" --root-suffix "${DB}-${TOPOLOGY}-${ISO}-${TS}" \
  --result-scope "$RESULT_SCOPE"

# fan-out CLUSTER_HOSTS (logical_id@addr:port)
: "${CLUSTER_HOSTS:=idc-dbhost-1@172.24.40.32 idc-dbhost-2@172.24.40.33 idc-dbhost-3@172.24.40.34 gcp-dbhost-1@localhost:12211 gcp-dbhost-2@localhost:12212 gcp-dbhost-3@localhost:12213}"

export CLUSTER_HOSTS DB DB_HOST DB_PORT TOPOLOGY ISO \
  PHASE_NAME RESULT_SCOPE BASELINE_FAMILY tuning_profile_id PLACEMENT PROFILE

# tests/common deployed location on .31 (bootstrap-tpcc-client target)
COMMON_DIR="${COMMON_DIR:-/tmp/poc-tpcc/scripts}"
TPCC_ARTIFACTS="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts/$RESULT_SCOPE}"
ROOT="$TPCC_ARTIFACTS/${DB}-${TOPOLOGY}-${ISO}-${TS}"
mkdir -p "$ROOT"
export TPCC_ARTIFACTS

echo "[wrapper] FULL chain; DB=$DB TOPOLOGY=$TOPOLOGY PLACEMENT=$PLACEMENT PROFILE=$PROFILE"
echo "[wrapper] CLUSTER_HOSTS=$CLUSTER_HOSTS"
echo "[wrapper] DB_HOST=$DB_HOST:$DB_PORT"

[[ -d "$COMMON_DIR" ]] || { echo "[wrapper] missing COMMON_DIR=$COMMON_DIR (tests/common 須先 rsync 至 .31)" >&2; exit 1; }

echo "[1/4] gate"
bash "$COMMON_DIR/gate.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[2/4] prepare"
bash "$COMMON_DIR/prepare.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

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
