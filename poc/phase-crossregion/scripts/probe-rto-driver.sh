#!/usr/bin/env bash
# phase-crossregion/scripts/probe-rto-driver.sh
#
# Independent RTO probe loop (per RTO-RPO-methodology.md §3.2).
# Runs alongside go-tpc; sends per-DB INSERT probe every 100ms,
# logs (ts_ms, ok|err, err_kind) to probe.txt for RTO calculation.
#
# Usage:
#   bash probe-rto-driver.sh --db tidb|crdb|ybdb --artifact-dir <dir> [--host <h>] [--port <p>]
#
# Outputs:
#   <artifact-dir>/probe.txt   — one line per probe: "<ts_ms> ok|err <err_kind>"
#
# DB defaults (haproxy endpoint; do NOT point directly at TiKV/CRDB-node):
#   tidb  host=172.24.47.20  port=4000   (MySQL protocol)
#   crdb  host=172.24.47.20  port=26257  (PostgreSQL protocol)
#   ybdb  host=172.24.47.20  port=5433   (YSQL/PostgreSQL protocol)
#
# Env:
#   PROBE_INTERVAL_MS   (default 100)   probe cadence in milliseconds
#   PROBE_TABLE         (default probe_rto)
#   PROBE_USER          (default root)
#   PROBE_PASS          (default "")
#   STOP_FILE           (default $artifact-dir/.probe.stop) — touch to stop loop
#
# Exit: 0 (stopped via STOP_FILE or SIGTERM), 1 (setup failure)

set -euo pipefail

DB=""
ARTIFACT_DIR=""
HOST_OVERRIDE=""
PORT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case $1 in
    --db)           DB=$2;           shift 2 ;;
    --artifact-dir) ARTIFACT_DIR=$2; shift 2 ;;
    --host)         HOST_OVERRIDE=$2; shift 2 ;;
    --port)         PORT_OVERRIDE=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${DB:?--db required (tidb|crdb|ybdb)}"
: "${ARTIFACT_DIR:?--artifact-dir required}"
[[ "$DB" =~ ^(tidb|crdb|ybdb)$ ]] || { echo "DB must be tidb|crdb|ybdb" >&2; exit 1; }

: "${PROBE_INTERVAL_MS:=100}"
: "${PROBE_TABLE:=probe_rto}"
: "${PROBE_USER:=root}"
: "${PROBE_PASS:=}"
STOP_FILE="${STOP_FILE:-$ARTIFACT_DIR/.probe.stop}"
PROBE_OUT="$ARTIFACT_DIR/probe.txt"

mkdir -p "$ARTIFACT_DIR"
rm -f "$STOP_FILE"

# --- per-DB defaults ---
case "$DB" in
  tidb) DEFAULT_HOST=172.24.47.20; DEFAULT_PORT=4000 ;;
  crdb) DEFAULT_HOST=172.24.47.20; DEFAULT_PORT=26257 ;;
  ybdb) DEFAULT_HOST=172.24.47.20; DEFAULT_PORT=5433 ;;
esac
DB_HOST="${HOST_OVERRIDE:-$DEFAULT_HOST}"
DB_PORT="${PORT_OVERRIDE:-$DEFAULT_PORT}"

ts_ms() { date '+%s%3N'; }

# --- setup probe table ---
setup_probe_table() {
  case "$DB" in
    tidb)
      mysql -h "$DB_HOST" -P "$DB_PORT" -u "$PROBE_USER" \
        ${PROBE_PASS:+-p"$PROBE_PASS"} --connect-timeout=5 -e \
        "CREATE DATABASE IF NOT EXISTS probe_db;
         CREATE TABLE IF NOT EXISTS probe_db.${PROBE_TABLE} (
           id BIGINT AUTO_INCREMENT PRIMARY KEY,
           ts BIGINT NOT NULL,
           seq INT NOT NULL
         );" 2>&1
      ;;
    crdb|ybdb)
      psql "host=$DB_HOST port=$DB_PORT user=$PROBE_USER dbname=defaultdb connect_timeout=5" \
        -c "CREATE DATABASE IF NOT EXISTS probe_db;" 2>/dev/null || true
      psql "host=$DB_HOST port=$DB_PORT user=$PROBE_USER dbname=probe_db connect_timeout=5" \
        -c "CREATE TABLE IF NOT EXISTS ${PROBE_TABLE} (
              id SERIAL PRIMARY KEY,
              ts BIGINT NOT NULL,
              seq INT NOT NULL
            );" 2>&1
      ;;
  esac
}

# --- single probe ---
do_probe() {
  local seq=$1
  local t; t=$(ts_ms)
  local err_out
  case "$DB" in
    tidb)
      if err_out=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$PROBE_USER" \
          ${PROBE_PASS:+-p"$PROBE_PASS"} --connect-timeout=3 \
          -e "INSERT INTO probe_db.${PROBE_TABLE}(ts,seq) VALUES($t,$seq);" 2>&1); then
        printf '%s ok -\n' "$t" >> "$PROBE_OUT"
      else
        local kind; kind=$(printf '%s' "$err_out" | grep -oP '(?<=ERROR )\d+|connection refused|lost connection|timeout' | head -1 || echo "unknown")
        printf '%s err %s\n' "$t" "${kind:-unknown}" >> "$PROBE_OUT"
      fi
      ;;
    crdb|ybdb)
      if err_out=$(psql "host=$DB_HOST port=$DB_PORT user=$PROBE_USER dbname=probe_db connect_timeout=3" \
          -c "INSERT INTO ${PROBE_TABLE}(ts,seq) VALUES($t,$seq);" 2>&1); then
        printf '%s ok -\n' "$t" >> "$PROBE_OUT"
      else
        local kind; kind=$(printf '%s' "$err_out" | grep -oP 'connection refused|SSL|timeout|no route|EOF' | head -1 || echo "unknown")
        printf '%s err %s\n' "$t" "${kind:-unknown}" >> "$PROBE_OUT"
      fi
      ;;
  esac
}

echo "[probe-rto] db=$DB host=$DB_HOST:$DB_PORT interval=${PROBE_INTERVAL_MS}ms out=$PROBE_OUT"

if ! setup_probe_table 2>/dev/null; then
  echo "[probe-rto] WARN: probe table setup failed — continuing (table may already exist)" >&2
fi

: > "$PROBE_OUT"
seq=0
SLEEP_S=$(awk "BEGIN{printf \"%.3f\", $PROBE_INTERVAL_MS/1000}")

_stop() { echo "[probe-rto] stopped (signal)"; exit 0; }
trap '_stop' SIGTERM SIGINT

while [[ ! -f "$STOP_FILE" ]]; do
  do_probe "$seq"
  seq=$((seq + 1))
  sleep "$SLEEP_S"
done

echo "[probe-rto] STOP_FILE detected — exiting (seq=$seq written=$PROBE_OUT)"
