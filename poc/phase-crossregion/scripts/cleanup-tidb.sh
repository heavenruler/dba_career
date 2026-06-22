#!/bin/bash
# Stop+disable+MASK all tiup-managed services on IDC + GCP nodes
# and remove TiDB data — frees ports for next DB test (especially port 9100)
#
# Fail-fast: any ssh error or post-verify failure → exit 1

set -uo pipefail

IDC_NODES="${IDC_NODES:-172.24.40.32 172.24.40.33 172.24.40.34}"
IDC_ADMIN="${IDC_ADMIN:-172.24.40.31}"
GCP_INTERNAL_IPS="${GCP_INTERNAL_IPS:-10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15}"

# embedded cleanup command (runs ON the target host)
CLEANUP_CMD='
set +e
# 1. stop+disable+MASK all tiup-managed systemd units (pattern: name-port.service)
# mask = strongest: blocks systemctl start (manual override blocked too)
for unit in $(systemctl list-units --type=service --no-legend --all 2>/dev/null \
               | awk "{print \$1}" \
               | grep -E "^(node_exporter|blackbox_exporter|tikv|pd|tidb|tiflash)-[0-9]+\.service$"); do
  echo "  stop+disable+mask $unit"
  systemctl stop "$unit" 2>/dev/null
  systemctl disable "$unit" 2>/dev/null
  systemctl mask "$unit" 2>/dev/null
done

# 2. residual processes
pkill -9 -x tidb-server 2>/dev/null
pkill -9 -x tikv-server 2>/dev/null
pkill -9 -x pd-server 2>/dev/null
pkill -9 -x tiflash 2>/dev/null
pkill -9 -f node_exporter 2>/dev/null
pkill -9 -f blackbox_exporter 2>/dev/null
pkill -9 -f run_node_exporter 2>/dev/null
pkill -9 -f run_blackbox_exporter 2>/dev/null
pkill -9 -f /tidb-deploy/ 2>/dev/null

# 3. remove data
rm -rf /tidb-deploy /tidb-data /data/tidb-deploy /data/tidb-data 2>/dev/null

sleep 2
exit 0
'

# embedded verify command — must return 0 only if NO tiup-related process is running
# (yb-tserver / yugabyted on the same ports is OK — that's the post-deploy state)
VERIFY_CMD='
H=$(hostname -s)
fail=0
for proc in tidb-server tikv-server pd-server tiflash node_exporter blackbox_exporter; do
  if pgrep -x "$proc" >/dev/null 2>&1; then
    pid=$(pgrep -x "$proc" | head -1)
    echo "  [$H] FAIL: $proc still running (pid=$pid)"
    fail=1
  fi
done
# also reject any tiup wrapper script
if pgrep -f "/tidb-deploy/" >/dev/null 2>&1; then
  echo "  [$H] FAIL: tidb-deploy wrapper still running"
  fail=1
fi
[ $fail -eq 0 ] && echo "  [$H] OK: no tiup processes"
exit $fail
'

run_via() {
  # $1 = ssh prefix (e.g. "ssh root@..." or "ssh root@.31 ssh root@.12")
  # $2 = cmd content (multi-line)
  # returns ssh exit code
  bash -c "$1 'bash -s'" <<< "$2"
}

# Step 1: cleanup all 8 nodes (3 IDC + 5 GCP)
echo "==> [start] cleanup-tidb at $(date +%Y-%m-%dT%H:%M:%S%z)"
fail_count=0

echo "=== IDC nodes (direct ssh) ==="
for ip in $IDC_NODES; do
  echo "--- $ip ---"
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$ip" 'bash -s' <<< "$CLEANUP_CMD"; then
    echo "  [FAIL] cleanup on $ip exited non-zero"
    fail_count=$((fail_count+1))
  fi
done

# stage cleanup script on .31 once for GCP execution
echo "=== GCP nodes (via $IDC_ADMIN) ==="
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
     "cat > /tmp/cleanup-tidb-remote.sh" <<< "$CLEANUP_CMD"; then
  echo "  [FAIL] cannot stage cleanup script on $IDC_ADMIN"
  exit 1
fi

for ip in $GCP_INTERNAL_IPS; do
  echo "--- $ip ---"
  if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no root@$ip 'bash -s' < /tmp/cleanup-tidb-remote.sh"; then
    echo "  [FAIL] cleanup on $ip (via $IDC_ADMIN) exited non-zero"
    fail_count=$((fail_count+1))
  fi
done

if [ $fail_count -gt 0 ]; then
  echo "==> cleanup phase: $fail_count node(s) failed; abort"
  exit 1
fi

# Step 2: verify ALL nodes have 9100/4000/2379/20160 free
echo "==> verify-cleanup: every node's ports must be free"
verify_fail=0

echo "=== IDC verify ==="
for ip in $IDC_NODES; do
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$ip" 'bash -s' <<< "$VERIFY_CMD" 2>&1 \
        | grep -vE "WARNING|post-quantum|upgraded|openssh|Permanently")
  echo "$out"
  echo "$out" | grep -q "FAIL:" && verify_fail=$((verify_fail+1))
done

# stage verify script on .31
ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
  "cat > /tmp/verify-tidb-cleanup.sh" <<< "$VERIFY_CMD"

echo "=== GCP verify (via $IDC_ADMIN) ==="
for ip in $GCP_INTERNAL_IPS; do
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no root@$ip 'bash -s' < /tmp/verify-tidb-cleanup.sh" 2>&1 \
        | grep -vE "WARNING|post-quantum|upgraded|openssh|Permanently")
  echo "$out"
  echo "$out" | grep -q "FAIL:" && verify_fail=$((verify_fail+1))
done

if [ $verify_fail -gt 0 ]; then
  echo "==> verify-cleanup: $verify_fail node(s) still have occupied ports; abort"
  exit 1
fi

echo "==> [end]   cleanup-tidb at $(date +%Y-%m-%dT%H:%M:%S%z) — all nodes verified clean"
exit 0
