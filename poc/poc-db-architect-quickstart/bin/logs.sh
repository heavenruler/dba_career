#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-}"
PODMAN_BIN="${PODMAN_BIN:-podman}"

if [[ -z "$SCENARIO" ]]; then
  "$PODMAN_BIN" pod ps
  exit 0
fi

"$PODMAN_BIN" pod logs "$SCENARIO"
