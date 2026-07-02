#!/usr/bin/env bash
# unfreeze-tidb.sh — restore TiDB PD scheduling limits from pre-freeze dump
# Usage: PD_URL=http://10.x.x.x:2379 DUMP_DIR=/tmp/freeze-state ./unfreeze-tidb.sh
set -euo pipefail

: "${PD_URL:?PD_URL is required}"
: "${DUMP_DIR:?DUMP_DIR is required}"

DUMP_FILE="${DUMP_DIR}/pd-config-before.json"
if [[ ! -f "$DUMP_FILE" ]]; then
  echo "[unfreeze-tidb] ERROR: dump file not found: ${DUMP_FILE}" >&2
  exit 1
fi

LIMITS=(
  leader-schedule-limit
  region-schedule-limit
  replica-schedule-limit
  hot-region-schedule-limit
  merge-schedule-limit
)

# HIGH 1: dump 由 /pd/api/v1/config/schedule 取得，bare key 直接在頂層
# HIGH 3: 找不到 key 即 fail，不可猜值或跳過
for key in "${LIMITS[@]}"; do
  val=$(jq -r ".[\"${key}\"] // empty" "$DUMP_FILE")
  if [[ -z "$val" ]]; then
    echo "[unfreeze-tidb] FAIL: missing key '${key}' in dump ${DUMP_FILE}" >&2
    exit 1
  fi
  echo "[unfreeze-tidb] config set $key = ${val}"
  curl -sf -X POST -H 'Content-Type: application/json' \
    -d "{\"$key\": $val}" "${PD_URL}/pd/api/v1/config" >/dev/null
done

# verify: 還原值實際生效（fail-closed）
for key in "${LIMITS[@]}"; do
  want=$(jq -r ".[\"${key}\"]" "$DUMP_FILE")
  cur=$(curl -sf "${PD_URL}/pd/api/v1/config/schedule" | jq -r ".[\"${key}\"]")
  [[ "$cur" == "$want" ]] || { echo "FAIL: $key = $cur (expected $want)" >&2; exit 1; }
done

echo "[unfreeze-tidb] TiDB unfrozen at $(date)"
