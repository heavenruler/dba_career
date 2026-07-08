#!/bin/bash
# Stop all yugabyted/yb-master/yb-tserver on all 6 nodes (3 IDC + 3 GCP via .31)
# and remove /var/yugabyte — frees ports + state for next DB test
# Pair with cleanup-tidb.sh / cleanup-crdb.sh for serial DB testing chain
#
# Fail-fast: any ssh error logs but continues to next node

set -uo pipefail

IDC_NODES="${IDC_NODES:-172.24.40.32 172.24.40.33 172.24.40.34}"
IDC_ADMIN="${IDC_ADMIN:-172.24.40.31}"
GCP_INTERNAL_IPS="${GCP_INTERNAL_IPS:-10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15}"

CLEANUP_CMD='
set +e
pkill -9 -x yb-master 2>/dev/null
pkill -9 -x yb-tserver 2>/dev/null
pkill -9 -x yugabyted-ui 2>/dev/null
# kill python3 yugabyted wrapper
for pid in $(pgrep -x python3 2>/dev/null); do
  cmd=$(tr "\0" " " < /proc/$pid/cmdline 2>/dev/null)
  case "$cmd" in *bin/yugabyted*) kill -9 $pid 2>/dev/null;; esac
done
rm -rf /var/yugabyte 2>/dev/null
sleep 1
exit 0
'

VERIFY_CMD='
H=$(hostname -s)
fail=0
if pgrep -x yb-master >/dev/null 2>&1; then
  echo "  [$H] FAIL: yb-master still running (pid=$(pgrep -x yb-master | head -1))"
  fail=1
fi
if pgrep -x yb-tserver >/dev/null 2>&1; then
  echo "  [$H] FAIL: yb-tserver still running (pid=$(pgrep -x yb-tserver | head -1))"
  fail=1
fi
[ $fail -eq 0 ] && echo "  [$H] OK: no yb-master/yb-tserver process"
exit $fail
'

echo "==> [start] cleanup-ybdb at $(date +%Y-%m-%dT%H:%M:%S%z)"
fail_count=0

echo "=== IDC nodes ==="
for ip in $IDC_NODES; do
  echo "--- $ip ---"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$ip" 'bash -s' <<< "$CLEANUP_CMD" || fail_count=$((fail_count+1))
done

ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$IDC_ADMIN" \
  "cat > /tmp/cleanup-ybdb-remote.sh" <<< "$CLEANUP_CMD"

echo "=== GCP nodes (via $IDC_ADMIN) ==="
for ip in $GCP_INTERNAL_IPS; do
  echo "--- $ip ---"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$IDC_ADMIN" \
    "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@$ip 'bash -s' < /tmp/cleanup-ybdb-remote.sh" || fail_count=$((fail_count+1))
done

# verify
echo "==> verify-cleanup: no yb-master/yb-tserver process anywhere"
verify_fail=0
for ip in $IDC_NODES; do
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$ip" 'bash -s' <<< "$VERIFY_CMD" 2>&1 | grep -vE "WARNING|post-quantum|upgraded|openssh|Permanently")
  echo "$out"
  echo "$out" | grep -q "FAIL:" && verify_fail=$((verify_fail+1))
done

ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$IDC_ADMIN" \
  "cat > /tmp/verify-ybdb.sh" <<< "$VERIFY_CMD"

for ip in $GCP_INTERNAL_IPS; do
  out=$(ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new "root@$IDC_ADMIN" \
        "ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@$ip 'bash -s' < /tmp/verify-ybdb.sh" 2>&1 | grep -vE "WARNING|post-quantum|upgraded|openssh|Permanently")
  echo "$out"
  echo "$out" | grep -q "FAIL:" && verify_fail=$((verify_fail+1))
done

if [ $verify_fail -gt 0 ]; then
  echo "==> verify-cleanup: $verify_fail node(s) still have yb-master/yb-tserver; abort"
  exit 1
fi

echo "==> [end]   cleanup-ybdb at $(date +%Y-%m-%dT%H:%M:%S%z) — all nodes verified clean (fail_count=$fail_count)"
exit 0
