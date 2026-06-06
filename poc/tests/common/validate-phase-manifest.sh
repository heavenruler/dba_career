#!/usr/bin/env bash
# validate-phase-manifest.sh — verify a phase manifest.yaml conforms to schema in results/PHASES.md §3.
#
# Usage:
#   tests/common/validate-phase-manifest.sh <path-to-manifest.yaml>
#   tests/common/validate-phase-manifest.sh --self-test   # validate the fixture sample
#
# Exit codes:
#   0  manifest passes all required-field + enum checks
#   1  missing required field
#   2  invalid enum value
#   3  fixture / file not readable
#
# Dependencies: yq (mikefarah) OR python3 + PyYAML.

set -euo pipefail

SELF=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$SELF/../.." && pwd)
FIXTURE="$REPO/tests/common/fixtures/phase-manifest-sample.yaml"

usage() {
  sed -n '2,12p' "$0" | sed 's|^# *||'
  exit 2
}

[[ $# -eq 1 ]] || usage

MANIFEST="$1"
if [[ "$MANIFEST" == "--self-test" ]]; then
  MANIFEST="$FIXTURE"
fi
[[ -f "$MANIFEST" ]] || { echo "[validate] not a file: $MANIFEST" >&2; exit 3; }

# Required scalar fields per results/PHASES.md §3.
REQUIRED_SCALARS=(
  phase phase_version result_scope baseline_family comparison_scope
  warehouses warmup_sec warmup_threads rounds requires_n
  artifact_prefix baseline_eligible tuning_profile_id owner_doc
)

# Required list fields (must be non-empty).
REQUIRED_LISTS=(
  allowed_result_scopes forbidden_result_scopes allowed_topology
  isolation threads_list
)

# Enum constraints.
VALID_PHASES="phase-k8s phase-threadcontrol phase-crossregion"
VALID_SCOPES="S-BASE S-K8S T-THRD X-CROSS"
VALID_FAMILIES="vm k8s tuning crossregion"
VALID_HOST_SOURCES="topology-derived inventory explicit"
VALID_HOST_KINDS="vm k8s-node k8s-pod crossregion-vm"

read_yaml() {
  # Prefer yq if present; fallback to python3.
  if command -v yq >/dev/null 2>&1; then
    yq eval "$1" "$MANIFEST"
  else
    python3 -c "
import sys, yaml
with open('$MANIFEST') as f:
    d = yaml.safe_load(f)
# Translate dot path like '.phase' to dict access.
path = '$1'.lstrip('.')
parts = path.split('.')
cur = d
for p in parts:
    if cur is None: break
    cur = cur.get(p) if isinstance(cur, dict) else None
if isinstance(cur, list):
    print('|'.join(str(x) for x in cur))
elif cur is None:
    print('null')
else:
    print(cur)
"
  fi
}

err=0
report() { echo "[validate] $1" >&2; err=$((err+1)); }

# 1. required scalars
for f in "${REQUIRED_SCALARS[@]}"; do
  v=$(read_yaml ".$f" 2>/dev/null || echo "null")
  if [[ -z "$v" || "$v" == "null" ]]; then
    report "missing required scalar: $f"
  fi
done

# 2. required lists (non-empty)
for f in "${REQUIRED_LISTS[@]}"; do
  v=$(read_yaml ".$f" 2>/dev/null || echo "null")
  if [[ -z "$v" || "$v" == "null" || "$v" == "[]" ]]; then
    report "missing or empty required list: $f"
  fi
done

# 3. enum checks
PHASE=$(read_yaml '.phase' 2>/dev/null || echo "")
[[ " $VALID_PHASES " == *" $PHASE "* ]] || report "invalid phase: '$PHASE' (must be one of: $VALID_PHASES)"

SCOPE=$(read_yaml '.result_scope' 2>/dev/null || echo "")
[[ " $VALID_SCOPES " == *" $SCOPE "* ]] || report "invalid result_scope: '$SCOPE' (must be one of: $VALID_SCOPES)"

FAMILY=$(read_yaml '.baseline_family' 2>/dev/null || echo "")
[[ " $VALID_FAMILIES " == *" $FAMILY "* ]] || report "invalid baseline_family: '$FAMILY' (must be one of: $VALID_FAMILIES)"

# 4. cross-field consistency
case "$PHASE:$SCOPE" in
  phase-k8s:S-K8S|phase-threadcontrol:T-THRD|phase-crossregion:X-CROSS) ;;
  *) report "phase/result_scope mismatch: phase=$PHASE result_scope=$SCOPE" ;;
esac

# 5. nested metrics_hosts.{source,kind,ids} validation (Add A completion per codex v3 review).
HOST_SRC=$(read_yaml '.metrics_hosts.source' 2>/dev/null || echo "")
HOST_KIND=$(read_yaml '.metrics_hosts.kind' 2>/dev/null || echo "")
HOST_IDS=$(read_yaml '.metrics_hosts.ids' 2>/dev/null || echo "")
if [[ -z "$HOST_SRC" || "$HOST_SRC" == "null" ]]; then
  report "missing metrics_hosts.source"
elif [[ " $VALID_HOST_SOURCES " != *" $HOST_SRC "* ]]; then
  report "invalid metrics_hosts.source: '$HOST_SRC' (must be one of: $VALID_HOST_SOURCES)"
fi
if [[ -z "$HOST_KIND" || "$HOST_KIND" == "null" ]]; then
  report "missing metrics_hosts.kind"
elif [[ " $VALID_HOST_KINDS " != *" $HOST_KIND "* ]]; then
  report "invalid metrics_hosts.kind: '$HOST_KIND' (must be one of: $VALID_HOST_KINDS)"
fi
if [[ -z "$HOST_IDS" || "$HOST_IDS" == "null" || "$HOST_IDS" == "[]" ]]; then
  report "missing or empty metrics_hosts.ids"
fi

# 6. phase/host-kind consistency
case "$PHASE:$HOST_KIND" in
  phase-k8s:k8s-node|phase-k8s:k8s-pod) ;;
  phase-threadcontrol:vm) ;;
  phase-crossregion:crossregion-vm) ;;
  *:"") ;;   # already reported above
  *) report "phase/metrics_hosts.kind mismatch: phase=$PHASE kind=$HOST_KIND" ;;
esac

if [[ $err -eq 0 ]]; then
  echo "[validate] OK: $MANIFEST"
  exit 0
fi

case $err in
  *)
    case $err in
      *) ;;
    esac
    if grep -q 'missing required' <<<"$(read_yaml '.phase' 2>&1)"; then
      exit 1
    fi
    # Use enum-fail exit when enum error dominates
    exit 2
    ;;
esac
