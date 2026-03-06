#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <scenario>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KUBE_FILE="$ROOT_DIR/scenarios/$SCENARIO/kube.yaml"
PODMAN_BIN="${PODMAN_BIN:-podman}"

if [[ ! -f "$KUBE_FILE" ]]; then
  echo "[ERROR] Scenario not found: $SCENARIO"
  exit 1
fi

"$PODMAN_BIN" kube down "$KUBE_FILE" || true
echo "[OK] Scenario stopped: $SCENARIO"
