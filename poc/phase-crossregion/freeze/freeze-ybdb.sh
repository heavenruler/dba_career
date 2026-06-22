#!/usr/bin/env bash
# freeze-ybdb.sh — disable YugabyteDB load balancer before timed rounds
# Usage: YB_MASTER_ADDR=10.x.x.x:7100 IDC_NODES_HEAD=10.x.x.x DUMP_DIR=/tmp/freeze-state ./freeze-ybdb.sh
set -euo pipefail

: "${YB_MASTER_ADDR:?YB_MASTER_ADDR is required (e.g. 10.x.x.x:7100)}"
: "${IDC_NODES_HEAD:?IDC_NODES_HEAD is required}"
: "${DUMP_DIR:?DUMP_DIR is required}"

mkdir -p "$DUMP_DIR"

SSH="ssh -o ConnectTimeout=5 -o BatchMode=yes root@${IDC_NODES_HEAD}"
YB_ADMIN="/opt/yugabyte/bin/yb-admin --master_addresses=${YB_MASTER_ADDR}"

# HIGH 3: rollback trap — 若 freeze 中途失敗，自動還原 lb 狀態
_lb_orig_state=""
_rollback() {
  local rc=$?
  if [ $rc -ne 0 ] && [ -n "$_lb_orig_state" ]; then
    echo "[freeze-ybdb][ROLLBACK] restoring lb state to: $_lb_orig_state" >&2
    local target
    case "$_lb_orig_state" in
      enabled|true|1)  target=1 ;;
      disabled|false|0) target=0 ;;
      *) echo "[freeze-ybdb][ROLLBACK] unknown state '$_lb_orig_state'; enabling lb as safe default" >&2; target=1 ;;
    esac
    $SSH "$YB_ADMIN set_load_balancer_enabled $target" 2>&1 | sed 's/^/[freeze-ybdb][ROLLBACK] /' >&2 || true
  fi
  exit $rc
}
trap _rollback EXIT

# HIGH 4: dump 不可覆寫 — backup existing dump files before overwriting
_backup_if_exists() {
  local f="$1"
  if [ -f "$f" ]; then
    mv "$f" "${f}.bak-$(date +%s)"
    echo "[freeze-ybdb] existing $f backed up"
  fi
}

echo "[freeze-ybdb] dumping universe config..."
_backup_if_exists "$DUMP_DIR/yb-universe-before.txt"
$SSH "$YB_ADMIN get_universe_config" > "$DUMP_DIR/yb-universe-before.txt"

# HIGH 2 (freeze side): dump lb enabled state before disabling
echo "[freeze-ybdb] dumping load balancer enabled state..."
_backup_if_exists "$DUMP_DIR/yb-lb-state-before.txt"
$SSH "$YB_ADMIN get_load_balancer_state" > "$DUMP_DIR/yb-lb-state-before.txt"
_lb_orig_state=$(cat "$DUMP_DIR/yb-lb-state-before.txt")

echo "[freeze-ybdb] disabling load balancer..."
$SSH "$YB_ADMIN set_load_balancer_enabled 0"

# HIGH 1: fail-closed idle confirmation (30 retries x 5s = 150s)
echo "[freeze-ybdb] waiting for load balancer to become idle (max 150s)..."
idle=0
for i in $(seq 1 30); do
  out=$($SSH "$YB_ADMIN get_is_load_balancer_idle" 2>&1)
  case "$out" in *"Idle = 1"*) idle=1; break;; *) idle=0;; esac
  sleep 5
done
[ "$idle" = "1" ] || { echo "FAIL: load_balancer not idle after 150s"; exit 1; }
echo "[freeze-ybdb] confirmed: load balancer idle"

echo "[freeze-ybdb] YBDB frozen at $(date)"
