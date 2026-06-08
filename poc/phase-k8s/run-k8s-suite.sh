#!/usr/bin/env bash
# phase-k8s/run-k8s-suite.sh — DRY_RUN-only wrapper.
# Supports TiDB / CRDB / YBDB.
#
# DRY_RUN=1 branch:
#   1. env / scope validation + DB-aware default port
#   2. mkdir $ROOT/dry-run/
#   3. dump-actual.sh → actual.yaml (DB-aware dispatch inside script)
#   4. diff-check.sh expected.yaml actual.yaml → .diff-pass / diff.txt
#   5. compare-vm.sh actual.yaml vm-baseline.yaml → compare-vm.md
#   6. write $ROOT/.dry-run.done
#   7. STOP
#
# Usage:
#   env DRY_RUN=1 TPCC_TS=<ts> \
#     PHASE_NAME=phase-k8s RESULT_SCOPE=S-K8S \
#     BASELINE_ELIGIBLE=true BASELINE_FAMILY=k8s \
#     K3S_HOST=<ip> K8S_NAMESPACE=<ns> K8S_CLUSTER=<name> \
#     [DB_HOST=<ip>] [DB_PORT=<port>] \
#     bash run-k8s-suite.sh --db {tidb,crdb,ybdb} --topology <topo> --ts <ts>

set -euo pipefail

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
: "${DRY_RUN:=0}"        # default 0 = full v4.7 chain; set DRY_RUN=1 for dump/diff/compare only

: "${PHASE_NAME:?missing}"
: "${RESULT_SCOPE:?missing}"
: "${BASELINE_ELIGIBLE:?missing}"
: "${BASELINE_FAMILY:?missing}"
: "${tuning_profile_id:=default}"
: "${K3S_HOST:?missing}"
: "${K8S_NAMESPACE:?missing}"
: "${K8S_CLUSTER:?missing}"

[[ "$PHASE_NAME"     == "phase-k8s" ]] || { echo "PHASE_NAME must be phase-k8s" >&2; exit 1; }
[[ "$RESULT_SCOPE"   == "S-K8S"    ]] || { echo "RESULT_SCOPE must be S-K8S" >&2; exit 1; }
[[ "$BASELINE_FAMILY" == "k8s"     ]] || { echo "BASELINE_FAMILY must be k8s" >&2; exit 1; }

# DB-aware default port + host
case "$DB" in
  tidb) : "${DB_HOST:=$K3S_HOST}"; : "${DB_PORT:=30004}" ;;
  crdb) : "${DB_HOST:=$K3S_HOST}"; : "${DB_PORT:=30007}" ;;
  ybdb) : "${DB_HOST:=$K3S_HOST}"; : "${DB_PORT:=30005}" ;;
  *) echo "unknown DB=$DB" >&2; exit 1 ;;
esac

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
COMMON_DIR="${COMMON_DIR:-/tmp/poc-tpcc/scripts}"   # tests/common deployed location on .31

# CLUSTER_HOSTS for fan-out metrics (k8s-node-1/2/3)
: "${CLUSTER_HOSTS:=172.24.40.32 172.24.40.33 172.24.40.34}"

# Suite ISO mapping (single-iso phase: RC only)
ISO="${ISO:-rc}"

# Per-DB env required by prepare.sh / run.sh / collect.sh
case "$DB" in
  tidb) export TIDB_PORT="$DB_PORT" TIDB_USER="${TIDB_USER:-root}" TIDB_DB="${TIDB_DB:-tpcc}" ;;
  crdb) export CRDB_PORT="$DB_PORT" CRDB_USER="${CRDB_USER:-root}" CRDB_DB="${CRDB_DB:-tpcc}" ;;
  ybdb) export YBDB_PORT="$DB_PORT" YBDB_USER="${YBDB_USER:-yugabyte}" YBDB_DB="${YBDB_DB:-tpcc}" YBDB_NAMESPACE="$K8S_NAMESPACE" ;;
esac

export CLUSTER_HOSTS K3S_HOST K8S_NAMESPACE K8S_CLUSTER DB DB_HOST DB_PORT TOPOLOGY \
  PHASE_NAME RESULT_SCOPE BASELINE_ELIGIBLE BASELINE_FAMILY tuning_profile_id

ROOT="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts/S-K8S}/${DB}-${TOPOLOGY}-${ISO}-${TS}"
mkdir -p "$ROOT"

# --------------------------------------------------------------------
# DRY_RUN=1: dump + diff + compare-vm + STOP (no prepare/run/collect)
# --------------------------------------------------------------------
if [[ "$DRY_RUN" == "1" ]]; then
  DRY_OUT="$ROOT/dry-run"
  mkdir -p "$DRY_OUT"
  echo "[wrapper] DRY_RUN=1 dry-run only; DB=$DB ROOT=$ROOT"

  EXPECTED="$SCRIPT_DIR/expected/${DB}-${TOPOLOGY}.yaml"
  VMBASE="$SCRIPT_DIR/expected/vm-3node-haproxy-3s3r-${DB}.yaml"
  [[ -f "$EXPECTED" ]] || { echo "missing expected: $EXPECTED" >&2; exit 1; }
  [[ -f "$VMBASE"   ]] || { echo "missing vm baseline: $VMBASE" >&2; exit 1; }

  export OUT_DIR="$DRY_OUT"

  echo "[wrapper] step 1/3 dump-actual.sh"
  bash "$SCRIPT_DIR/dump-actual.sh"

  echo "[wrapper] step 2/3 diff-check.sh"
  if ! bash "$SCRIPT_DIR/diff-check.sh" "$EXPECTED" "$DRY_OUT/actual.yaml" "$DRY_OUT"; then
    echo "[wrapper] diff-check FAILED — see $DRY_OUT/diff.txt" >&2
    exit 1
  fi

  echo "[wrapper] step 3/3 compare-vm.sh"
  COMPARE_RC=0
  bash "$SCRIPT_DIR/compare-vm.sh" "$DRY_OUT/actual.yaml" "$VMBASE" "$DRY_OUT" || COMPARE_RC=$?

  cat > "$ROOT/.dry-run.done" <<JSON
{
  "phase": "${PHASE_NAME}",
  "result_scope": "${RESULT_SCOPE}",
  "baseline_eligible": ${BASELINE_ELIGIBLE},
  "baseline_family": "${BASELINE_FAMILY}",
  "tuning_profile_id": "${tuning_profile_id}",
  "db": "${DB}",
  "topology": "${TOPOLOGY}",
  "ts": "${TS}",
  "dry_run": true,
  "diff_pass": $([[ -f "$DRY_OUT/.diff-pass" ]] && echo true || echo false),
  "compare_vm_deny_count": ${COMPARE_RC}
}
JSON

  if [[ $COMPARE_RC -ne 0 ]]; then
    echo "[wrapper] compare-vm FAIL — deny diffs; see $DRY_OUT/compare-vm.md" >&2
    exit $COMPARE_RC
  fi
  echo "[wrapper] DRY_RUN PASS — $ROOT"
  exit 0
fi

# --------------------------------------------------------------------
# DRY_RUN unset / 0: FULL v4.7 suite chain (gate → prepare → run → collect)
# Artifact format mirrors S-BASE (tests/common/run.sh / prepare.sh / etc.)
# --------------------------------------------------------------------
echo "[wrapper] FULL chain; DB=$DB TOPOLOGY=$TOPOLOGY ROOT=$ROOT"
echo "[wrapper] CLUSTER_HOSTS=$CLUSTER_HOSTS"
[[ -d "$COMMON_DIR" ]] || { echo "[wrapper] missing COMMON_DIR=$COMMON_DIR (tests/common 須先 rsync 至 .31)" >&2; exit 1; }

echo "[1/4] gate"
bash "$COMMON_DIR/gate.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[2/4] prepare"
bash "$COMMON_DIR/prepare.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[3/4] run (warmup + sweep, contains gate-isolation)"
bash "$COMMON_DIR/run.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

echo "[4/4] collect"
bash "$COMMON_DIR/collect.sh" --db "$DB" --iso "$ISO" --topology "$TOPOLOGY" --db-host "$DB_HOST" --ts "$TS"

# write .suite.done (mirror run-vm1-suite.sh format)
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
  "baseline_eligible": $BASELINE_ELIGIBLE,
  "baseline_family": "$BASELINE_FAMILY",
  "tuning_profile_id": "$tuning_profile_id",
  "completed_at": "$(date '+%Y-%m-%dT%H:%M:%S%z')"
}
JSON
)"

echo "[wrapper] FULL chain PASS — $ROOT"
