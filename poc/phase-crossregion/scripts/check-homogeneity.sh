#!/usr/bin/env bash
# phase-crossregion/scripts/check-homogeneity.sh
# Homogeneity gate: all 6 nodes same OS kernel / nproc / disk.
# Exits 0 (WARN on mismatch, not fail — gate is advisory).
set -euo pipefail

: "${IDC_NODES:=172.24.40.32 172.24.40.33 172.24.40.34}"
: "${GCP_NODES:=10.160.152.11 10.160.152.12 10.160.152.13}"
: "${PROXY:=root@172.24.40.31}"
SSH_OPTS="-o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new -o BatchMode=yes"

ssh_one() {
  local host=$1 cmd=$2 proxy=${3:-}
  if [[ -n "$proxy" ]]; then
    ssh $SSH_OPTS -o ProxyJump="$proxy" "root@$host" "$cmd" 2>/dev/null || echo "ERR"
  else
    ssh $SSH_OPTS "root@$host" "$cmd" 2>/dev/null || echo "ERR"
  fi
}

printf "  %-20s %-24s %-6s %s\n" "host" "kernel" "nproc" "disk"
printf "  %s\n" "$(printf -- '-%.0s' {1..68})"

KERNELS=(); NPROCS=(); DISKS=()

collect() {
  local ip=$1 proxy=${2:-}
  local k n d
  k=$(ssh_one "$ip" "uname -r"                               "$proxy")
  n=$(ssh_one "$ip" "nproc"                                  "$proxy")
  d=$(ssh_one "$ip" "df -BG / | awk 'NR==2{print \$2}'"     "$proxy")
  printf "  %-20s %-24s %-6s %s\n" "$ip" "$k" "$n" "$d"
  KERNELS+=("$k"); NPROCS+=("$n"); DISKS+=("$d")
}

for ip in $IDC_NODES; do collect "$ip"; done
for ip in $GCP_NODES; do collect "$ip" "$PROXY"; done

check_unique() {
  local name=$1; shift
  local vals
  vals=$(printf '%s\n' "$@" | grep -v '^ERR$' | sort -u)
  local cnt; cnt=$(printf '%s\n' "$vals" | grep -c .)
  if [[ "$cnt" -gt 1 ]]; then
    echo "WARN: $name heterogeneous: $(printf '%s\n' "$vals" | tr '\n' ' ')"
    return 1
  fi
  return 0
}

fail=0
check_unique "kernel" "${KERNELS[@]}" || fail=1
check_unique "nproc"  "${NPROCS[@]}"  || fail=1
check_unique "disk"   "${DISKS[@]}"   || fail=1

if [[ $fail -eq 1 ]]; then
  echo "phase1-homogeneity: WARN (heterogeneous nodes — proceed with caution)"
else
  echo "phase1-homogeneity: PASS (all nodes homogeneous)"
fi
exit 0
