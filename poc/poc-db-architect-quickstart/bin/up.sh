#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  echo "Usage: $0 [--logs] <scenario>"
}

if [[ "${1:-}" == "--logs" ]]; then
  SCENARIO="${2:-}"
  [[ -n "${SCENARIO}" ]] || { usage; exit 1; }
  CONTAINERS="$(podman ps --format '{{.Names}}' | grep "^${SCENARIO}-" || true)"
  if [[ -z "${CONTAINERS}" ]]; then
    echo "[WARN] 找不到執行中的容器: ${SCENARIO}-*"
    exit 0
  fi
  while read -r c; do
    echo "===== $c ====="
    podman logs --tail 80 "$c"
  done <<<"${CONTAINERS}"
  exit 0
fi

SCENARIO="${1:-}"
[[ -n "${SCENARIO}" ]] || { usage; exit 1; }

KUBE_FILE="${ROOT_DIR}/scenarios/${SCENARIO}/kube.yaml"
[[ -f "${KUBE_FILE}" ]] || { echo "[ERROR] 找不到 scenario: ${SCENARIO}"; exit 1; }

podman kube play --replace "${KUBE_FILE}"
echo "[OK] Scenario 已啟動: ${SCENARIO}"
