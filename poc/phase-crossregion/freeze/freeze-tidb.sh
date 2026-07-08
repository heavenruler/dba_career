#!/usr/bin/env bash
# freeze-tidb.sh — freeze TiDB PD scheduling before timed rounds
# Usage: PD_URL=http://10.x.x.x:2379 DUMP_DIR=/tmp/freeze-state ./freeze-tidb.sh
set -euo pipefail

: "${PD_URL:?PD_URL is required (e.g. http://10.x.x.x:2379)}"
: "${DUMP_DIR:?DUMP_DIR is required}"

SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib-pd-drain.sh"

mkdir -p "$DUMP_DIR"

DUMP_FILE="${DUMP_DIR}/pd-config-before.json"

# HIGH 5: 若 dump 已存在，rename 為 .bak 避免覆寫（unfreeze 需要 freeze 前的原始值）
if [[ -f "$DUMP_FILE" ]]; then
  bak="${DUMP_FILE}.bak-$(date +%s)"
  echo "[freeze-tidb] WARN: dump already exists, renaming to $(basename "$bak")"
  mv "$DUMP_FILE" "$bak"
fi

# HIGH 4: rollback trap — 記錄已改的 key，失敗時 best-effort 還原
CHANGED_KEYS=()
rollback() {
  local rc=$?
  echo "[freeze-tidb] ROLLBACK: restoring ${#CHANGED_KEYS[@]} key(s) (exit code $rc)" >&2
  for k in "${CHANGED_KEYS[@]}"; do
    orig=$(jq -r ".[\"${k}\"] // empty" "$DUMP_FILE" 2>/dev/null || true)
    if [[ -n "$orig" ]]; then
      echo "[freeze-tidb] rollback: config set $k $orig" >&2
      curl -sf -X POST -H "Content-Type: application/json" -d "{\"$k\": $orig}" "${PD_URL}/pd/api/v1/config" >/dev/null || true
    fi
  done
}
trap rollback ERR INT TERM

# dump — 用 curl 直接取 JSON（HIGH 1: 以 bare key 為準，dump 需可解析 bare key）
echo "[freeze-tidb] dumping PD config to ${DUMP_FILE}"
curl -sf "${PD_URL}/pd/api/v1/config/schedule" > "$DUMP_FILE"
[[ -s "$DUMP_FILE" ]] || { echo "FAIL: dump empty or unreachable"; exit 1; }

LIMITS=(
  leader-schedule-limit
  region-schedule-limit
  replica-schedule-limit
  hot-region-schedule-limit
  merge-schedule-limit
)

# HIGH 1: 使用無前綴 bare key；PD HTTP API 直設（.31 無 tiup，curl 即可）
for key in "${LIMITS[@]}"; do
  echo "[freeze-tidb] config set $key = 0"
  curl -sf -X POST -H 'Content-Type: application/json' \
    -d "{\"$key\": 0}" "${PD_URL}/pd/api/v1/config" >/dev/null
  CHANGED_KEYS+=("$key")
done

# verify: 全部 limit 實際歸零（POST 成功 ≠ 生效，fail-closed 驗一次）
for key in "${LIMITS[@]}"; do
  cur=$(curl -sf "${PD_URL}/pd/api/v1/config/schedule" | jq -r ".[\"${key}\"]")
  [[ "$cur" == "0" ]] || { echo "FAIL: $key = $cur (expected 0)" >&2; exit 1; }
done

# HIGH 2: polling fail-closed — 等待 in-flight operators 清空，超時即 fail
# 排水上限可用 FREEZE_DRAIN_MAX_SEC 覆寫（default 150s，語意不動；共用 lib-pd-drain.sh）
DRAIN_MAX_SEC="${FREEZE_DRAIN_MAX_SEC:-150}"
pd_drain_wait "$PD_URL" "$DRAIN_MAX_SEC" "freeze-tidb" || {
  echo "FAIL: operators still pending after ${DRAIN_MAX_SEC}s" >&2
  exit 1
}

trap - ERR INT TERM  # 成功，解除 rollback trap
echo "[freeze-tidb] TiDB frozen at $(date)"
