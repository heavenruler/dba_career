#!/usr/bin/env bash
# unfreeze-ybdb.sh — restore YugabyteDB load balancer state after timed rounds
# Usage: YB_MASTER_ADDR=10.x.x.x:7100 IDC_NODES_HEAD=10.x.x.x DUMP_DIR=/tmp/freeze-state ./unfreeze-ybdb.sh
set -euo pipefail

: "${YB_MASTER_ADDR:?YB_MASTER_ADDR is required}"
: "${IDC_NODES_HEAD:?IDC_NODES_HEAD is required}"
: "${DUMP_DIR:?DUMP_DIR is required}"

SSH="ssh -o ConnectTimeout=5 -o BatchMode=yes root@${IDC_NODES_HEAD}"
YB_ADMIN="/opt/yugabyte/bin/yb-admin --master_addresses=${YB_MASTER_ADDR}"

# HIGH 2: restore original lb state dumped by freeze-ybdb.sh
STATE_FILE="$DUMP_DIR/yb-lb-state-before.txt"
if [ ! -f "$STATE_FILE" ]; then
  echo "FAIL: state file not found: $STATE_FILE (was freeze-ybdb.sh run?)"
  exit 1
fi

orig=$(cat "$STATE_FILE")
case "$orig" in
  enabled|true|1)   target=1 ;;
  disabled|false|0) target=0 ;;
  *) echo "FAIL: invalid state '$orig' in $STATE_FILE"; exit 1 ;;
esac

echo "[unfreeze-ybdb] restoring load balancer to original state: $orig (target=$target)..."
$SSH "$YB_ADMIN set_load_balancer_enabled $target"

echo "[unfreeze-ybdb] YBDB unfrozen at $(date)"
