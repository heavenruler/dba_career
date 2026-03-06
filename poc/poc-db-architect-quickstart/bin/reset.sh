#!/usr/bin/env bash
set -euo pipefail

SCENARIO="${1:-}"
if [[ -z "$SCENARIO" ]]; then
  echo "Usage: $0 <scenario>"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
"$ROOT_DIR/bin/down.sh" "$SCENARIO"

rm -rf "$ROOT_DIR/volumes/$SCENARIO"
mkdir -p "$ROOT_DIR/volumes/$SCENARIO"

"$ROOT_DIR/bin/up.sh" "$SCENARIO"
echo "[OK] Scenario reset: $SCENARIO"
