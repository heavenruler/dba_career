#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

SCENARIO="${1:-}"
if [[ -z "${SCENARIO}" ]]; then
  echo "Usage: $0 <scenario>"
  exit 1
fi

"${ROOT_DIR}/bin/down.sh" "${SCENARIO}" || true

SCENARIO_VOL_DIR="${ROOT_DIR}/volumes/${SCENARIO}"
if [[ "${SCENARIO_VOL_DIR}" == "${ROOT_DIR}/volumes/${SCENARIO}" && -d "${ROOT_DIR}/volumes" ]]; then
  rm -rf "${SCENARIO_VOL_DIR}"
  mkdir -p "${SCENARIO_VOL_DIR}"
fi

"${ROOT_DIR}/bin/up.sh" "${SCENARIO}"

echo "[OK] Scenario 已重置: ${SCENARIO}"
