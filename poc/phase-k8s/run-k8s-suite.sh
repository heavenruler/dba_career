#!/usr/bin/env bash
# phase-k8s/run-k8s-suite.sh — DRY_RUN-only wrapper for phase-1 MVP.
#
# DRY_RUN=1 branch (this MVP):
#   1. env / scope validation
#   2. mkdir $ROOT/dry-run/
#   3. dump-actual.sh → actual.yaml
#   4. diff-check.sh expected.yaml actual.yaml → .diff-pass / diff.txt
#   5. compare-vm.sh actual.yaml vm-baseline.yaml → compare-vm.md
#   6. write $ROOT/.dry-run.done (phase env metadata)
#   7. STOP (no prepare / no run / no collect)
#
# Full chain (DRY_RUN=0) → defer 至 phase-2.
#
# Usage (from .31 / locally):
#   env DRY_RUN=1 TPCC_TS=<ts> \
#     PHASE_NAME=phase-k8s RESULT_SCOPE=S-K8S \
#     BASELINE_ELIGIBLE=true BASELINE_FAMILY=k8s \
#     K3S_HOST=172.24.40.32 K8S_NAMESPACE=tidb-cluster K8S_CLUSTER=tidb-poc \
#     TIDB_HOST=172.24.40.32 TIDB_PORT=30004 \
#     bash run-k8s-suite.sh --db tidb --topology k8s-3node-haproxy-3s3r-unlimit --ts <ts>

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
: "${DRY_RUN:?DRY_RUN required for phase-1 MVP (set DRY_RUN=1)}"

if [[ "$DRY_RUN" != "1" ]]; then
  echo "[run-k8s-suite] phase-1 MVP only supports DRY_RUN=1 — full chain defer 至 phase-2" >&2
  exit 1
fi

: "${PHASE_NAME:?missing}"
: "${RESULT_SCOPE:?missing}"
: "${BASELINE_ELIGIBLE:?missing}"
: "${BASELINE_FAMILY:?missing}"
: "${tuning_profile_id:=default}"

[[ "$PHASE_NAME"     == "phase-k8s" ]] || { echo "PHASE_NAME must be phase-k8s, got $PHASE_NAME" >&2; exit 1; }
[[ "$RESULT_SCOPE"   == "S-K8S"    ]] || { echo "RESULT_SCOPE must be S-K8S, got $RESULT_SCOPE" >&2; exit 1; }
[[ "$BASELINE_FAMILY" == "k8s"     ]] || { echo "BASELINE_FAMILY must be k8s, got $BASELINE_FAMILY" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
POC_ROOT=$(cd "$SCRIPT_DIR/.." && pwd)

ROOT="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts/S-K8S}/${DB}-${TOPOLOGY}-rc-${TS}"
DRY_OUT="$ROOT/dry-run"
mkdir -p "$DRY_OUT"

echo "[wrapper] DRY_RUN=1 dry-run only; ROOT=$ROOT"

# Resolve expected/baseline files
EXPECTED="$SCRIPT_DIR/expected/${DB}-${TOPOLOGY}.yaml"
VMBASE="$SCRIPT_DIR/expected/vm-3node-haproxy-3s3r-${DB}.yaml"
[[ -f "$EXPECTED" ]] || { echo "missing expected file: $EXPECTED" >&2; exit 1; }
[[ -f "$VMBASE"   ]] || { echo "missing vm baseline file: $VMBASE" >&2; exit 1; }

export TOPOLOGY OUT_DIR="$DRY_OUT" \
  PHASE_NAME RESULT_SCOPE BASELINE_ELIGIBLE BASELINE_FAMILY tuning_profile_id

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

# Write .dry-run.done marker (always; compare-vm.md may have deny diffs)
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
  echo "[wrapper] compare-vm FAILED — deny diffs present; see $DRY_OUT/compare-vm.md" >&2
  exit $COMPARE_RC
fi

echo "[wrapper] DRY_RUN PASS — artifact at $ROOT"
echo "[wrapper]   - $DRY_OUT/.diff-pass"
echo "[wrapper]   - $DRY_OUT/compare-vm.md"
echo "[wrapper]   - $ROOT/.dry-run.done"
