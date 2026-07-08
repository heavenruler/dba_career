#!/usr/bin/env bash
# check-gcp-via-31.sh — verify all 5 GCP nodes are READY by ssh-ing through .31
# Bypass IAP tunnel; uses IDC admin (.31) → GCP internal IPs directly.
#
# Env vars:
#   MAX_WAIT_SEC    (default 600)
#   RETRY_INTERVAL  (default 10)
#   IDC_ADMIN       (default 172.24.40.31)
#
# Exit 0 = all 5 READY; Exit 1 = timeout or partial failure.

set -euo pipefail

MAX_WAIT_SEC="${MAX_WAIT_SEC:-600}"
RETRY_INTERVAL="${RETRY_INTERVAL:-10}"
IDC_ADMIN="${IDC_ADMIN:-172.24.40.31}"

GCP_IPS=(10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15)
TOTAL=${#GCP_IPS[@]}

check_all_ready() {
  local results
  results=$(ssh \
    -o LogLevel=ERROR \
    -o StrictHostKeyChecking=accept-new \
    -o ConnectTimeout=10 \
    -o BatchMode=yes \
    root@"${IDC_ADMIN}" \
    "$(cat <<'REMOTE'
for ip in 10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15; do
  printf "%s: " "$ip"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@$ip \
    'test -f /var/lib/startup-done && echo READY || echo NOTREADY; hostname -s' 2>/dev/null \
    || echo "UNREACHABLE"
done
REMOTE
)" 2>/dev/null) || return 1

  echo "$results"
  # Return 0 only if every line contains READY (not NOTREADY / UNREACHABLE)
  local not_ready
  not_ready=$(echo "$results" | grep -v ": READY" | grep -E "NOTREADY|UNREACHABLE" || true)
  if [[ -z "$not_ready" ]] && [[ $(echo "$results" | grep -c ": READY") -eq $TOTAL ]]; then
    return 0
  fi
  return 1
}

echo "==> check-gcp-via-31: waiting up to ${MAX_WAIT_SEC}s for ${TOTAL} GCP nodes (via ${IDC_ADMIN})"

elapsed=0
while true; do
  echo "--- elapsed=${elapsed}s ---"
  if check_all_ready; then
    echo "==> all ${TOTAL} GCP nodes READY (elapsed=${elapsed}s)"
    exit 0
  fi

  if [[ $elapsed -ge $MAX_WAIT_SEC ]]; then
    echo "[ERROR] timeout after ${MAX_WAIT_SEC}s — some nodes still NOTREADY/UNREACHABLE"
    # Final diagnostic run to show which IPs failed
    ssh \
      -o LogLevel=ERROR \
      -o StrictHostKeyChecking=accept-new \
      -o ConnectTimeout=10 \
      -o BatchMode=yes \
      root@"${IDC_ADMIN}" \
      "$(cat <<'REMOTE'
for ip in 10.160.152.11 10.160.152.12 10.160.152.13 10.160.152.14 10.160.152.15; do
  printf "%s: " "$ip"
  ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new root@$ip \
    'test -f /var/lib/startup-done && echo READY || echo NOTREADY; hostname -s' 2>/dev/null \
    || echo "UNREACHABLE"
done
REMOTE
)" 2>/dev/null || true
    exit 1
  fi

  sleep "${RETRY_INTERVAL}"
  elapsed=$(( elapsed + RETRY_INTERVAL ))
done
