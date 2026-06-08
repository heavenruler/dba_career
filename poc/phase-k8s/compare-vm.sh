#!/usr/bin/env bash
# phase-k8s/compare-vm.sh — actual.yaml vs VM baseline.yaml.
# Uses allow/warn/deny field path SSOT (codex v14 NB #3).
#
# Field classification:
#   ALLOW (platform diff, log only):
#     network.nodeport, network.client_proto, k8s.*, vm.*,
#     db_config.tikv_block_cache_capacity_*, phase_env.tuning_profile_id
#   WARN (drift logged for codex review):
#     db_config.tikv_readpool_*, db_config.pd_max_replicas,
#     db_config.tidb_version, split.expected_shards_per_table
#   DENY (drift → exit 1):
#     phase_env.BASELINE_ELIGIBLE, workload.*, isolation.*,
#     split.strategy, split.expected_tables
#   PLATFORM-DERIVED (mapping, not raw eq):
#     phase_env.PHASE_NAME, phase_env.RESULT_SCOPE, phase_env.BASELINE_FAMILY
#
# Usage:
#   compare-vm.sh <actual.yaml> <vm-baseline.yaml> <out_dir>
# Writes:
#   $OUT_DIR/compare-vm.md
# Exit:
#   0 = no deny diff; 1 = deny diff present

set -euo pipefail

ACTUAL=$1
VMBASE=$2
OUT_DIR=$3

if [[ ! -f "$ACTUAL" ]]; then echo "missing actual.yaml: $ACTUAL" >&2; exit 1; fi
if [[ ! -f "$VMBASE" ]]; then echo "missing vm-baseline.yaml: $VMBASE" >&2; exit 1; fi

mkdir -p "$OUT_DIR"

ACT_JSON=$(yq -o=json 'sort_keys(..)' "$ACTUAL")
VM_JSON=$(yq -o=json 'sort_keys(..)' "$VMBASE")

classify_path() {
  local p=$1
  case "$p" in
    .network.nodeport|.network.client_proto|.network.haproxy_*|.k8s.*|.vm.*|.phase_env.tuning_profile_id|.db_config.tikv_block_cache_capacity_*|.split.*)
      # split.* ALLOW: dry-run no prepare → split is intent-only spec
      echo "ALLOW" ;;
    .db_config.tikv_readpool_*|.db_config.pd_max_replicas|.db_config.*_version|.db_config.kv_range_split_by_load_enabled)
      echo "WARN" ;;
    .phase_env.PHASE_NAME|.phase_env.RESULT_SCOPE|.phase_env.BASELINE_FAMILY|.topology|.db)
      echo "PLATFORM" ;;
    .phase_env.BASELINE_ELIGIBLE|.workload*|.isolation*|.db_config.replication_factor|.db_config.enable_automatic_tablet_splitting|.db_config.yb_enable_read_committed_isolation|.db_config.default_transaction_isolation)
      echo "DENY" ;;
    *)
      # Unknown path defaults to DENY for safety; user can extend allow list.
      echo "DENY" ;;
  esac
}

# Collect every leaf path + value from both files.
collect_leaves() {
  local json=$1
  echo "$json" | jq -r '
    paths(scalars) as $p
    | "\($p | map("\(.)") | join(".") | "." + .)\t\(getpath($p))"
  '
}

ACT_LEAVES=$(collect_leaves "$ACT_JSON")
VM_LEAVES=$(collect_leaves "$VM_JSON")

ALLOW_LINES=()
WARN_LINES=()
DENY_LINES=()
PLATFORM_LINES=()

while IFS=$'\t' read -r path act_val; do
  vm_val=$(echo "$VM_LEAVES" | awk -F'\t' -v p="$path" '$1==p{print $2; exit}')
  [[ -z "$vm_val" ]] && vm_val="<absent>"
  if [[ "$act_val" == "$vm_val" ]]; then
    continue   # no diff
  fi
  class=$(classify_path "$path")
  case "$class" in
    ALLOW)    ALLOW_LINES+=("$path: k8s=$act_val vm=$vm_val") ;;
    WARN)     WARN_LINES+=("$path: k8s=$act_val vm=$vm_val") ;;
    PLATFORM) PLATFORM_LINES+=("$path: k8s=$act_val vm=$vm_val") ;;
    DENY)     DENY_LINES+=("$path: k8s=$act_val vm=$vm_val") ;;
  esac
done <<< "$ACT_LEAVES"

# Also catch keys present in VM baseline but absent in K8s actual.
while IFS=$'\t' read -r path vm_val; do
  found=$(echo "$ACT_LEAVES" | awk -F'\t' -v p="$path" '$1==p{print $2; exit}')
  if [[ -z "$found" ]]; then
    class=$(classify_path "$path")
    case "$class" in
      ALLOW)    ALLOW_LINES+=("$path: k8s=<absent> vm=$vm_val") ;;
      WARN)     WARN_LINES+=("$path: k8s=<absent> vm=$vm_val") ;;
      PLATFORM) PLATFORM_LINES+=("$path: k8s=<absent> vm=$vm_val") ;;
      DENY)     DENY_LINES+=("$path: k8s=<absent> vm=$vm_val") ;;
    esac
  fi
done <<< "$VM_LEAVES"

{
  echo "# compare-vm.md — phase-k8s actual vs VM baseline"
  echo ""
  echo "Sources:"
  echo "- actual: $ACTUAL"
  echo "- vm baseline: $VMBASE"
  echo ""
  echo "## ❌ DENY (exit 1 if any)"
  if [[ ${#DENY_LINES[@]} -eq 0 ]]; then
    echo "- (none)"
  else
    printf -- "- %s\n" "${DENY_LINES[@]}"
  fi
  echo ""
  echo "## ⚠️ WARN (codex review)"
  if [[ ${#WARN_LINES[@]} -eq 0 ]]; then
    echo "- (none)"
  else
    printf -- "- %s\n" "${WARN_LINES[@]}"
  fi
  echo ""
  echo "## ✅ ALLOW (platform diff)"
  if [[ ${#ALLOW_LINES[@]} -eq 0 ]]; then
    echo "- (none)"
  else
    printf -- "- %s\n" "${ALLOW_LINES[@]}"
  fi
  echo ""
  echo "## 🔀 PLATFORM-DERIVED (mapping)"
  if [[ ${#PLATFORM_LINES[@]} -eq 0 ]]; then
    echo "- (none)"
  else
    printf -- "- %s\n" "${PLATFORM_LINES[@]}"
  fi
} > "$OUT_DIR/compare-vm.md"

if [[ ${#DENY_LINES[@]} -gt 0 ]]; then
  echo "[compare-vm] FAIL — ${#DENY_LINES[@]} deny diff(s):" >&2
  printf -- "  %s\n" "${DENY_LINES[@]}" >&2
  exit 1
fi

echo "[compare-vm] PASS (deny=0, warn=${#WARN_LINES[@]}, allow=${#ALLOW_LINES[@]}, platform=${#PLATFORM_LINES[@]})"
exit 0
