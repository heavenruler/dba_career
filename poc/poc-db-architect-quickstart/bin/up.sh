#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <scenario>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCENARIO_DIR="$ROOT_DIR/scenarios/$SCENARIO"
KUBE_FILE="$SCENARIO_DIR/kube.yaml"
PODMAN_BIN="${PODMAN_BIN:-podman}"

if [[ ! -f "$KUBE_FILE" ]]; then
  echo "[ERROR] Scenario not found: $SCENARIO"
  exit 1
fi

mkdir -p "$ROOT_DIR/volumes/$SCENARIO"

"$PODMAN_BIN" kube play --replace "$KUBE_FILE"

echo "[OK] Scenario started: $SCENARIO"

if [[ "$SCENARIO" == "redis-cluster" ]]; then
  echo "[INFO] Initializing redis cluster topology..."
  sleep 4
  "$PODMAN_BIN" exec redis-cluster-node-1 redis-cli --cluster create \
    127.0.0.1:7001 127.0.0.1:7002 127.0.0.1:7003 \
    127.0.0.1:7004 127.0.0.1:7005 127.0.0.1:7006 \
    --cluster-replicas 1 --cluster-yes || true
fi
