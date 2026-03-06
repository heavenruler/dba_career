#!/usr/bin/env bash
set -euo pipefail

PODMAN_BIN="${PODMAN_BIN:-podman}"

if ! command -v "$PODMAN_BIN" >/dev/null 2>&1; then
  echo "[ERROR] podman is not installed."
  echo "Install: brew install podman"
  exit 1
fi

if ! "$PODMAN_BIN" machine info >/dev/null 2>&1; then
  echo "[INFO] Podman machine not initialized. Running: podman machine init"
  "$PODMAN_BIN" machine init
fi

if ! "$PODMAN_BIN" info >/dev/null 2>&1; then
  echo "[INFO] Starting podman machine..."
  "$PODMAN_BIN" machine start
fi

echo "[OK] Podman is ready."
