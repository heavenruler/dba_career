#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <scenario>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERIFY_SCRIPT="$ROOT_DIR/scenarios/$SCENARIO/verify.sh"

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "[ERROR] verify.sh is missing or not executable for scenario: $SCENARIO"
  exit 1
fi

"$VERIFY_SCRIPT"
