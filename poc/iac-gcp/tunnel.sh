#!/bin/bash
# 啟動 GCP IAP SSH tunnels for dev env
# Usage: ./tunnel.sh [start|stop]
#
# 2026-06-22 fix: gcloud children redirect stdout/stderr 到 per-tunnel log，
#   並 closed-stdin + disown，避免繼承 make 的 stdout/stderr 導致 tee 永不關閉

PROJECT="lab-service-project-dba"
LOG_DIR="/tmp"

_start_tunnel() {
  local name="$1" port="$2" zone="$3" tag="$4"
  local logf="${LOG_DIR}/iap-tunnel-${tag}.log"
  local pidf="${LOG_DIR}/iap-tunnel-${tag}.pid"
  # 全脫離 parent: stdin /dev/null、stdout/stderr 重導向 log、disown
  gcloud compute start-iap-tunnel "$name" 22 \
    --local-host-port="localhost:${port}" \
    --project="$PROJECT" \
    --zone="$zone" \
    >>"$logf" 2>&1 </dev/null &
  local pid=$!
  echo "$pid" > "$pidf"
  disown "$pid" 2>/dev/null || true
}

# 等 IAP 對所有 5 個 instance metadata 都可解析 (避免 terraform apply 後 race)
_wait_iap_ready() {
  local max_wait=120 elapsed=0 sleep_n=5
  while [ $elapsed -lt $max_wait ]; do
    local fail=0
    for name in g-test-poc-1 g-test-poc-2 g-test-poc-3 g-test-poc-4 g-test-poc-5; do
      gcloud compute instances describe "$name" \
        --project="$PROJECT" --format="value(status)" 2>/dev/null \
        | grep -q RUNNING || { fail=1; break; }
    done
    [ $fail -eq 0 ] && { echo "  IAP ready (instances visible after ${elapsed}s)"; return 0; }
    sleep $sleep_n; elapsed=$((elapsed+sleep_n))
  done
  echo "  IAP not ready after ${max_wait}s; tunnel start anyway"
  return 1
}

start() {
  echo "Starting IAP tunnels..."
  echo "Waiting IAP metadata propagation (max 120s)..."
  _wait_iap_ready
  _start_tunnel g-test-poc-1 12211 asia-east1-a poc1
  _start_tunnel g-test-poc-2 12212 asia-east1-b poc2
  _start_tunnel g-test-poc-3 12213 asia-east1-c poc3
  _start_tunnel g-test-poc-4 12214 asia-east1-a poc4
  _start_tunnel g-test-poc-5 12215 asia-east1-a poc5
  sleep 2
  echo "Tunnels launched (logs: ${LOG_DIR}/iap-tunnel-poc{1..5}.log):"
  echo "  ssh g-test-poc-1  -> localhost:12211  (db node, zone a)"
  echo "  ssh g-test-poc-2  -> localhost:12212  (db node, zone b)"
  echo "  ssh g-test-poc-3  -> localhost:12213  (db node, zone c)"
  echo "  ssh g-test-poc-4  -> localhost:12214  (haproxy,  zone a)"
  echo "  ssh g-test-poc-5  -> localhost:12215  (client,   zone a)"
}

stop() {
  for f in ${LOG_DIR}/iap-tunnel-poc*.pid; do
    [ -f "$f" ] || continue
    pid=$(cat "$f" 2>/dev/null)
    [ -n "$pid" ] && kill "$pid" 2>/dev/null
    rm -f "$f"
  done
  # 兜底：清掉孤兒 gcloud iap tunnel
  pkill -f "start-iap-tunnel g-test-poc-" 2>/dev/null || true
  echo "Tunnels stopped."
}

case "${1:-start}" in
  start) start ;;
  stop)  stop  ;;
  *)     echo "Usage: $0 [start|stop]" ;;
esac
