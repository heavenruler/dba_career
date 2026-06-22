#!/bin/bash
# Stop all yugabyted/yb-master/yb-tserver on all 6 nodes (3 IDC + 3 GCP via .31)
# and remove /var/yugabyte — frees ports + state for next DB test

set -uo pipefail

IDC_NODES="${IDC_NODES:-172.24.40.32 172.24.40.33 172.24.40.34}"
IDC_ADMIN="${IDC_ADMIN:-172.24.40.31}"
GCP_INTERNAL_IPS="${GCP_INTERNAL_IPS:-10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15}"

remote_cleanup() {
  local ssh_target="$1"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "$ssh_target" 'bash -s' <<'REMOTE'
set +e
pkill -9 -x yb-master 2>/dev/null
pkill -9 -x yb-tserver 2>/dev/null
pkill -9 -x yugabyted-ui 2>/dev/null
# kill python3 yugabyted wrapper
for pid in $(pgrep -x python3 2>/dev/null); do
  cmd=$(tr '\0' ' ' < /proc/$pid/cmdline 2>/dev/null)
  case "$cmd" in *bin/yugabyted*) kill -9 $pid 2>/dev/null;; esac
done
rm -rf /var/yugabyte 2>/dev/null
sleep 1
echo -n "  $(hostname -s) 5433: "; ss -lntp 2>/dev/null | grep -E ":5433\b" || echo "none"
echo -n "  $(hostname -s) 7100: "; ss -lntp 2>/dev/null | grep -E ":7100\b" || echo "none"
exit 0
REMOTE
}

echo "==> [start] cleanup-ybdb at $(date +%Y-%m-%dT%H:%M:%S%z)"
echo "=== IDC nodes (direct) ==="
for ip in $IDC_NODES; do
  echo "--- $ip ---"
  remote_cleanup "root@$ip"
done
echo "=== GCP nodes (via $IDC_ADMIN) ==="
for ip in $GCP_INTERNAL_IPS; do
  echo "--- $ip ---"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
    "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no root@$ip 'bash -c \"
      pkill -9 -x yb-master 2>/dev/null
      pkill -9 -x yb-tserver 2>/dev/null
      pkill -9 -x yugabyted-ui 2>/dev/null
      rm -rf /var/yugabyte 2>/dev/null
      sleep 1
      echo -n \\\"  $(hostname -s) 5433: \\\"; ss -lntp 2>/dev/null | grep -E ':5433\\b' || echo none
    \"'"
done
echo "==> [end]   cleanup-ybdb at $(date +%Y-%m-%dT%H:%M:%S%z)"
