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
#   RESOLVED_HOSTS  array of "<ssh_host>|<id>|<kind>|<region>|<zone>|<node>|<pod>" entries
#                   (use `-` for null fields; pipe `|` as separator to allow `:` in ssh_host like
#                    `localhost:12211` for GCP IAP tunnel hops)
#   FANOUT_ENABLED  "true" / "false"
#
# region/zone/node/pod fields per results/PHASES.md §4 metrics/hosts.json schema.
resolve_hosts() {
  local topo="$1" db_host="$2" override="${3-}"
  local hosts="${override:-${CLUSTER_HOSTS:-}}"

  RESOLVED_HOSTS=()

  if [[ -z "$hosts" ]]; then
    # Backward-compatible path: derive single canonical host from TOPO, NO suffix.
    case "$topo" in
      *haproxy-*) RESOLVED_HOSTS=("172.24.40.32|-|vm|idc|vlan241|-|-") ;;
      *)          RESOLVED_HOSTS=("$db_host|-|vm|idc|vlan241|-|-") ;;
    esac
    FANOUT_ENABLED="false"
    return
  fi

  # Fan-out path: parse CLUSTER_HOSTS as space-separated list.
  # Each entry: "ssh_host" OR "ssh_host=logical_id" OR "logical_id@ssh_host"
  local i=0
  for h in $hosts; do
    i=$((i+1))
    local ssh="" id="" kind="vm" region="-" zone="-" node="-" pod="-"
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

    # Infer kind / region / zone from TOPO + id pattern (best-effort; can be overridden by
    # inventory-driven source in future).
    case "$topo" in
      k8s-*)
        kind="k8s-node"
        region="idc"
        zone="vlan241"
        node="$id"
        ;;
      vm-6node-*)
        kind="crossregion-vm"
        case "$id" in
          idc-*)
            region="idc"
            zone="vlan241"
            ;;
          gcp-*)
            region="gcp"
            zone="asia-east1"
            ;;
        esac
        node="$id"
        ;;
      vm-*)
        kind="vm"
        region="idc"
        zone="vlan241"
        node="$id"
        ;;
    esac

    RESOLVED_HOSTS+=("$ssh|$id|$kind|$region|$zone|$node|$pod")
  done
  FANOUT_ENABLED="true"
}

# _host_field(): extract field N (1-indexed) from a pipe-separated entry.
_host_field() {
  local entry="$1" field="$2"
  echo "$entry" | awk -F'|' -v F="$field" '{print $F}'
}

# write_hosts_manifest(): produce <out_dir>/metrics/hosts.json from RESOLVED_HOSTS.
# Output JSON conforms to results/PHASES.md §4 schema:
#   {phase, result_scope, manifest_sha256, hosts: [{id, kind, region, zone, node, pod, ssh_host, artifact_suffix}]}
# Args:
#   $1  phase           e.g. phase-k8s
#   $2  result_scope    e.g. S-K8S
#   $3  manifest_sha256 sha256 of phase manifest.yaml
#   $4  out_dir         round artifact dir
write_hosts_manifest() {
  local phase="$1" scope="$2" sha="$3" out="$4"
  local target="$out/metrics/hosts.json"
  mkdir -p "$(dirname "$target")"

  _json_str() {
    # Emit JSON value for a host field; "-" → null, otherwise quoted string.
    if [[ "$1" == "-" || -z "$1" ]]; then printf 'null'; else printf '"%s"' "$1"; fi
  }

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
      local ssh id kind region zone node pod
      ssh=$(_host_field "$entry" 1)
      id=$(_host_field "$entry" 2)
      kind=$(_host_field "$entry" 3)
      region=$(_host_field "$entry" 4)
      zone=$(_host_field "$entry" 5)
      node=$(_host_field "$entry" 6)
      pod=$(_host_field "$entry" 7)
      printf '    {\n'
      printf '      "id": %s,\n' "$(_json_str "$id")"
      printf '      "kind": %s,\n' "$(_json_str "$kind")"
      printf '      "region": %s,\n' "$(_json_str "$region")"
      printf '      "zone": %s,\n' "$(_json_str "$zone")"
      printf '      "node": %s,\n' "$(_json_str "$node")"
      printf '      "pod": %s,\n' "$(_json_str "$pod")"
      printf '      "ssh_host": %s,\n' "$(_json_str "$ssh")"
      printf '      "artifact_suffix": %s\n' "$(_json_str "$id")"
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
#   $1  RESOLVED_HOSTS entry (pipe-separated, see resolve_hosts)
host_artifact_suffix() {
  local entry="$1"
  local id; id=$(_host_field "$entry" 2)
  if [[ -n "$id" && "$id" != "-" && "$FANOUT_ENABLED" == "true" ]]; then
    printf -- "-%s" "$id"
  else
    printf ""
  fi
}

# host_ssh_target(): output the SSH host from an entry.
host_ssh_target() {
  local entry="$1"
  _host_field "$entry" 1
}
