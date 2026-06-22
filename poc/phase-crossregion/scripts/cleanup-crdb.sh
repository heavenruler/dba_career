#!/bin/bash
# Stop CockroachDB + remove data on all 6 cluster nodes (3 IDC + 3 GCP)
# Pair with cleanup-tidb.sh / cleanup-ybdb.sh for serial DB testing chain
#
# Fail-fast: any ssh error logs but continues to next node

set -uo pipefail

IDC_NODES="${IDC_NODES:-172.24.40.32 172.24.40.33 172.24.40.34}"
IDC_ADMIN="${IDC_ADMIN:-172.24.40.31}"
GCP_INTERNAL_IPS="${GCP_INTERNAL_IPS:-10.160.152.11 10.160.152.12 10.160.152.13}"

CLEANUP_CMD='
set +e
# 1. stop+disable+mask cockroach systemd unit (if exists)
for unit in cockroach.service cockroach-26257.service; do
  if systemctl list-unit-files 2>/dev/null | grep -q "^$unit"; then
    echo "  stop+mask $unit"
    systemctl stop "$unit" 2>/dev/null
    systemctl disable "$unit" 2>/dev/null
    systemctl mask "$unit" 2>/dev/null
  fi
done
# 2. kill remaining cockroach processes
pkill -9 -x cockroach 2>/dev/null
sleep 1
# 3. remove data
rm -rf /var/lib/cockroach /var/cockroach /opt/cockroach/data 2>/dev/null
exit 0
'

VERIFY_CMD='
H=$(hostname -s)
if pgrep -x cockroach >/dev/null 2>&1; then
  echo "  [$H] FAIL: cockroach still running (pid=$(pgrep -x cockroach | head -1))"
  exit 1
fi
echo "  [$H] OK: no cockroach process"
exit 0
'

echo "==> [start] cleanup-crdb at $(date +%Y-%m-%dT%H:%M:%S%z)"
fail_count=0

echo "=== IDC nodes ==="
for ip in $IDC_NODES; do
  echo "--- $ip ---"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$ip" 'bash -s' <<< "$CLEANUP_CMD" || fail_count=$((fail_count+1))
done

ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
  "cat > /tmp/cleanup-crdb-remote.sh" <<< "$CLEANUP_CMD"

echo "=== GCP nodes (via $IDC_ADMIN) ==="
for ip in $GCP_INTERNAL_IPS; do
  echo "--- $ip ---"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
    "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no root@$ip 'bash -s' < /tmp/cleanup-crdb-remote.sh" || fail_count=$((fail_count+1))
done

# verify
echo "==> verify-cleanup: no cockroach process anywhere"
verify_fail=0
for ip in $IDC_NODES; do
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$ip" 'bash -s' <<< "$VERIFY_CMD" 2>&1 | grep -vE "WARNING|post-quantum|upgraded|openssh|Permanently")
  echo "$out"
  echo "$out" | grep -q "FAIL:" && verify_fail=$((verify_fail+1))
done

ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
  "cat > /tmp/verify-crdb.sh" <<< "$VERIFY_CMD"

for ip in $GCP_INTERNAL_IPS; do
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no "root@$IDC_ADMIN" \
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=no root@$ip 'bash -s' < /tmp/verify-crdb.sh" 2>&1 | grep -vE "WARNING|post-quantum|upgraded|openssh|Permanently")
  echo "$out"
  echo "$out" | grep -q "FAIL:" && verify_fail=$((verify_fail+1))
done

if [ $verify_fail -gt 0 ]; then
  echo "==> verify-cleanup: $verify_fail node(s) still have cockroach; abort"
  exit 1
fi

echo "==> [end]   cleanup-crdb at $(date +%Y-%m-%dT%H:%M:%S%z) — all nodes verified clean (fail_count=$fail_count)"
exit 0
