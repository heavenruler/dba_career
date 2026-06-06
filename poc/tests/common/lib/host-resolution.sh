#!/usr/bin/env bash
# host-resolution.sh — derive metrics host list + logical id mapping.
#
# Backward-compatible:
#   - If $CLUSTER_HOSTS unset → output single-host (existing behavior, suffix="")
#   - If $CLUSTER_HOSTS set → output multi-host (logical ids, suffix=id)
#
# Output: writes <round-dir>/metrics/hosts.json + sets bash array RESOLVED_HOSTS=("ssh:id" ...).
#
# Used by tests/common/run.sh. Do NOT change existing run-vm1-* / run-vm3-* artifacts unless
# CLUSTER_HOSTS is explicitly set.

# resolve_hosts(): populate global RESOLVED_HOSTS array
# Args:
#   $1  TOPO        e.g. vm-1node, vm-3node-haproxy-3s3r, k8s-3node-limit
#   $2  DB_HOST     fallback when CLUSTER_HOSTS empty (existing behavior)
#   $3  CLUSTER_HOSTS_OVERRIDE (optional, "" = use env $CLUSTER_HOSTS)
#
# Sets globals:
#   RESOLVED_HOSTS  array of "<ssh_host>:<artifact_suffix>:<kind>" entries
#   FANOUT_ENABLED  "true" / "false"
resolve_hosts() {
  local topo="$1" db_host="$2" override="${3-}"
  local hosts="${override:-${CLUSTER_HOSTS:-}}"

  RESOLVED_HOSTS=()

  if [[ -z "$hosts" ]]; then
    # Backward-compatible path: derive single canonical host from TOPO, NO suffix.
    case "$topo" in
      *haproxy-*) RESOLVED_HOSTS=("172.24.40.32::vm") ;;
      *)          RESOLVED_HOSTS=("$db_host::vm") ;;
    esac
    FANOUT_ENABLED="false"
    return
  fi

  # Fan-out path: parse CLUSTER_HOSTS as space-separated list.
  # Each entry: "ssh_host" OR "ssh_host=logical_id" OR "logical_id@ssh_host"
  local i=0
  for h in $hosts; do
    i=$((i+1))
    local ssh="" id="" kind="vm"
    if [[ "$h" == *"@"* ]]; then
      id="${h%@*}"; ssh="${h#*@}"
    elif [[ "$h" == *"="* ]]; then
      ssh="${h%=*}"; id="${h#*=}"
    else
      ssh="$h"
      # Derive id from TOPO kind.
      case "$topo" in
        k8s-*)        id="k8s-node-$i"; kind="k8s-node" ;;
        vm-6node-*)   id="dbhost-$i";   kind="crossregion-vm" ;;
        *)            id="dbhost-$i";   kind="vm" ;;
      esac
    fi
    RESOLVED_HOSTS+=("$ssh:$id:$kind")
  done
  FANOUT_ENABLED="true"
}

# write_hosts_manifest(): produce <out_dir>/metrics/hosts.json from RESOLVED_HOSTS.
# Args:
#   $1  phase           e.g. phase-k8s
#   $2  result_scope    e.g. S-K8S
#   $3  manifest_sha256 sha256 of phase manifest.yaml
#   $4  out_dir         round artifact dir
write_hosts_manifest() {
  local phase="$1" scope="$2" sha="$3" out="$4"
  local target="$out/metrics/hosts.json"
  mkdir -p "$(dirname "$target")"

  # Build JSON via printf (no jq dependency).
  {
    printf '{\n'
    printf '  "phase": "%s",\n' "$phase"
    printf '  "result_scope": "%s",\n' "$scope"
    printf '  "manifest_sha256": "%s",\n' "$sha"
    printf '  "hosts": [\n'
    local i=0 n=${#RESOLVED_HOSTS[@]}
    for entry in "${RESOLVED_HOSTS[@]}"; do
      i=$((i+1))
      local ssh="${entry%%:*}"; local rest="${entry#*:}"
      local id="${rest%%:*}";   local kind="${rest##*:}"
      printf '    {\n'
      printf '      "id": "%s",\n' "$id"
      printf '      "kind": "%s",\n' "$kind"
      printf '      "ssh_host": "%s",\n' "$ssh"
      printf '      "artifact_suffix": "%s"\n' "$id"
      if [[ $i -lt $n ]]; then
        printf '    },\n'
      else
        printf '    }\n'
      fi
    done
    printf '  ]\n'
    printf '}\n'
  } > "$target"
}

# host_artifact_suffix(): output "-<id>" if fan-out, else "" (backward-compat).
# Args:
#   $1  RESOLVED_HOSTS entry "<ssh>:<id>:<kind>"
host_artifact_suffix() {
  local entry="$1"
  local id="${entry#*:}"; id="${id%%:*}"
  if [[ -n "$id" && "$FANOUT_ENABLED" == "true" ]]; then
    printf -- "-%s" "$id"
  else
    printf ""
  fi
}

# host_ssh_target(): output the SSH host from an entry.
host_ssh_target() {
  local entry="$1"
  printf "%s" "${entry%%:*}"
}
