#!/usr/bin/env bash
# probe-iso-latency.sh — sample SELECT 1 + UPDATE latency from controller host
#
# Purpose: verify closest-replicas / lease-preference 是否真生效 — 從 IDC
# 與 GCP 兩端各跑同樣 SQL，比 p50/p95/p99 latency。
# 預期（per decisions Q13 + 0630.md §5.3）：
#   - IDC SELECT 1 應 ~1-5ms（local read）
#   - GCP SELECT 1 應 ~1-5ms（若 closest-replicas 生效；走 GCP follower）
#   - GCP SELECT 1 ~ 50ms = follower read 沒生效 / fell back to IDC leader
#   - UPDATE latency 雙端均 ~30-60ms（cross-region commit；無法降低）
#
# Usage:
#   probe-iso-latency.sh --db {tidb|crdb|ybdb} \
#                        --db-host <ip> --port <int> --user <user> --dbname <db> \
#                        --duration-sec <N> --out-dir <path> \
#                        [--label <idc|gcp>]
#
# Output:
#   <out-dir>/probe-iso-latency-<label>.csv   ← raw per-iteration rows
#   <out-dir>/probe-iso-latency-<label>.json  ← p50 / p95 / p99 per query type
#
# Caveat (per Q13 同源 caveat):
#   - CRDB SELECT 1 不走 follower read（需 AS OF SYSTEM TIME 才走）
#     → CRDB probe 結果僅作 latency baseline，不是 closest-replicas 驗證
#   - YBDB SELECT 1 由 yb_read_from_followers 控制；ALTER DATABASE 已 SET，
#     但本 script 啟新連線即生效
#   - probe 啟動的連線數量 1；不模擬 connection-pool 競爭

set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
[[ -f "$SELF/lib/common.sh" ]] && source "$SELF/lib/common.sh" || true

DB="" DB_HOST="" PORT="" USER="" DBNAME="" DURATION=60 OUT_DIR="" LABEL="probe"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --db-host) DB_HOST=$2; shift 2 ;;
    --port) PORT=$2; shift 2 ;;
    --user) USER=$2; shift 2 ;;
    --dbname) DBNAME=$2; shift 2 ;;
    --duration-sec) DURATION=$2; shift 2 ;;
    --out-dir) OUT_DIR=$2; shift 2 ;;
    --label) LABEL=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done

[[ -n "$DB" && -n "$DB_HOST" && -n "$PORT" && -n "$OUT_DIR" ]] || {
  echo "missing required arg(s)" >&2
  exit 2
}

mkdir -p "$OUT_DIR"
CSV="$OUT_DIR/probe-iso-latency-${LABEL}.csv"
JSON="$OUT_DIR/probe-iso-latency-${LABEL}.json"

# CSV header
echo "ts_ns,query_type,latency_ms" > "$CSV"

# DB-specific one-shot query runner; echo latency in ms (3 decimals).
run_query() {
  local kind=$1   # select | update
  local start_ns end_ns dt_ms

  start_ns=$(date +%s%N)
  case "$DB" in
    tidb)
      if [[ "$kind" == "select" ]]; then
        mysql -h "$DB_HOST" -P "$PORT" -u "${USER:-root}" "$DBNAME" -e "SELECT 1;" >/dev/null 2>&1
      else
        mysql -h "$DB_HOST" -P "$PORT" -u "${USER:-root}" "$DBNAME" -e \
          "UPDATE warehouse SET w_ytd = w_ytd WHERE w_id = 1;" >/dev/null 2>&1
      fi
      ;;
    crdb)
      if [[ "$kind" == "select" ]]; then
        cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e "SELECT 1 AS OF SYSTEM TIME follower_read_timestamp();" >/dev/null 2>&1
      else
        cockroach sql --insecure --host="$DB_HOST:$PORT" -d "$DBNAME" -e \
          "UPDATE warehouse SET w_ytd = w_ytd WHERE w_id = 1;" >/dev/null 2>&1
      fi
      ;;
    ybdb)
      if [[ "$kind" == "select" ]]; then
        psql "postgres://${USER:-yugabyte}@${DB_HOST}:${PORT}/${DBNAME}" -v ON_ERROR_STOP=1 \
          -c "SELECT 1;" >/dev/null 2>&1
      else
        psql "postgres://${USER:-yugabyte}@${DB_HOST}:${PORT}/${DBNAME}" -v ON_ERROR_STOP=1 \
          -c "UPDATE warehouse SET w_ytd = w_ytd WHERE w_id = 1;" >/dev/null 2>&1
      fi
      ;;
  esac
  end_ns=$(date +%s%N)
  # ms with 3 decimals
  echo "scale=3; ($end_ns - $start_ns) / 1000000" | bc
}

DEADLINE=$(( $(date +%s) + DURATION ))
SELECT_COUNT=0
UPDATE_COUNT=0
SELECT_FAIL=0
UPDATE_FAIL=0

while [[ $(date +%s) -lt $DEADLINE ]]; do
  ts_ns=$(date +%s%N)
  if lat=$(run_query select 2>/dev/null); then
    echo "$ts_ns,select,$lat" >> "$CSV"
    SELECT_COUNT=$((SELECT_COUNT + 1))
  else
    SELECT_FAIL=$((SELECT_FAIL + 1))
  fi

  ts_ns=$(date +%s%N)
  if lat=$(run_query update 2>/dev/null); then
    echo "$ts_ns,update,$lat" >> "$CSV"
    UPDATE_COUNT=$((UPDATE_COUNT + 1))
  else
    UPDATE_FAIL=$((UPDATE_FAIL + 1))
  fi

  # Pace ~ 5 ops/sec (200ms gap) to avoid saturating during main workload.
  sleep 0.1
done

# Aggregate p50/p95/p99 per query_type.
agg() {
  local qtype=$1
  awk -F, -v q="$qtype" '
    $2 == q { lats[NR] = $3; n++ }
    END {
      if (n == 0) { print "null null null null"; exit }
      asort(lats)
      p50 = lats[int(n * 0.5) + 1]
      p95 = lats[int(n * 0.95) + 1]
      p99 = lats[int(n * 0.99) + 1]
      printf "%s %s %s %s\n", p50, p95, p99, n
    }
  ' "$CSV"
}

read -r s_p50 s_p95 s_p99 s_n < <(agg select)
read -r u_p50 u_p95 u_p99 u_n < <(agg update)

cat > "$JSON" <<EOF
{
  "label": "$LABEL",
  "db": "$DB",
  "db_host": "$DB_HOST",
  "duration_sec": $DURATION,
  "controller_host": "$(hostname -f 2>/dev/null || hostname)",
  "select_1": {
    "p50_ms": $s_p50, "p95_ms": $s_p95, "p99_ms": $s_p99,
    "samples": $s_n, "fail_count": $SELECT_FAIL
  },
  "update_1": {
    "p50_ms": $u_p50, "p95_ms": $u_p95, "p99_ms": $u_p99,
    "samples": $u_n, "fail_count": $UPDATE_FAIL
  },
  "interpretation_hint": "若 SELECT_1 p99 跨 IDC vs GCP 兩端皆 < 10ms = closest-replicas 生效；GCP 端 ~50ms = follower read 沒生效或 fall back to leader",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

echo "[probe-iso-latency] $LABEL DB=$DB duration=${DURATION}s select_p99=${s_p99}ms update_p99=${u_p99}ms — $JSON"
