#!/bin/bash
# 啟動 GCP IAP SSH tunnels for dev env
# Usage: ./tunnel.sh [start|stop]

PROJECT="lab-service-project-dba"

start() {
  echo "Starting IAP tunnels..."
  gcloud compute start-iap-tunnel g-test-poc-1 22 \
    --local-host-port=localhost:12211 \
    --project=$PROJECT \
    --zone=asia-east1-a &
  echo $! > /tmp/iap-tunnel-poc1.pid

  gcloud compute start-iap-tunnel g-test-poc-2 22 \
    --local-host-port=localhost:12212 \
    --project=$PROJECT \
    --zone=asia-east1-b &
  echo $! > /tmp/iap-tunnel-poc2.pid

  gcloud compute start-iap-tunnel g-test-poc-3 22 \
    --local-host-port=localhost:12213 \
    --project=$PROJECT \
    --zone=asia-east1-c &
  echo $! > /tmp/iap-tunnel-poc3.pid

  gcloud compute start-iap-tunnel g-test-poc-4 22 \
    --local-host-port=localhost:12214 \
    --project=$PROJECT \
    --zone=asia-east1-a &
  echo $! > /tmp/iap-tunnel-poc4.pid

  sleep 2
  echo "Tunnels ready:"
  echo "  ssh g-test-poc-1  -> localhost:12211"
  echo "  ssh g-test-poc-2  -> localhost:12212"
  echo "  ssh g-test-poc-3  -> localhost:12213"
  echo "  ssh g-test-poc-4  -> localhost:12214"
}

stop() {
  for f in /tmp/iap-tunnel-poc*.pid; do
    kill $(cat $f) 2>/dev/null && rm $f
  done
  echo "Tunnels stopped."
}

case "${1:-start}" in
  start) start ;;
  stop)  stop  ;;
  *)     echo "Usage: $0 [start|stop]" ;;
esac
