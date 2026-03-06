#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCENARIO="${1:-}"
if [[ -z "${SCENARIO}" ]]; then
  echo "Usage: $0 <scenario>"
  exit 1
fi

KUBE_FILE="${ROOT_DIR}/scenarios/${SCENARIO}/kube.yaml"
[[ -f "${KUBE_FILE}" ]] || { echo "[ERROR] 找不到 scenario: ${SCENARIO}"; exit 1; }

podman kube down "${KUBE_FILE}"
echo "[OK] Scenario 已停止並移除: ${SCENARIO}"
