#!/usr/bin/env bash
# cockroach-tpcc.sh — go-tpc TPC-C wrapper for CockroachDB (PostgreSQL wire)
# Usage: CRDB_HOST=x CRDB_PORT=x VARIANT=vm-1node bash cockroach-tpcc.sh <prepare|run|cleanup>
set -euo pipefail

CMD=${1:-run}

CRDB_HOST=${CRDB_HOST:?CRDB_HOST is required}
CRDB_PORT=${CRDB_PORT:?CRDB_PORT is required}
CRDB_USER=${CRDB_USER:-root}
CRDB_PASS=${CRDB_PASS:-}
WAREHOUSES=${WAREHOUSES:-128}
DURATION=${DURATION:-10m}
THREADS_LIST=${THREADS_LIST:-"16 32 64 128"}
WARMUP=${WARMUP:-5m}
VARIANT=${VARIANT:-vm-1node}
TOPO=${TOPO:-cockroach-tc1}
SCENARIO=${SCENARIO:-S-BASE}
RESULT_BASE=${RESULT_BASE:-results}
DB_NAME=${DB_NAME:-tpcc}

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_DIR="${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/${TIMESTAMP}"

# go-tpc with PostgreSQL driver (-d postgres) for CockroachDB
_go_tpc_base() {
  local threads=$1 extra_global=$2; shift 2
  local pass_flag=""
  [[ -n "${CRDB_PASS}" ]] && pass_flag="-p ${CRDB_PASS}"
  go-tpc \
    -d postgres \
    -H "${CRDB_HOST}" \
    -P "${CRDB_PORT}" \
    -U "${CRDB_USER}" \
    -T "${threads}" \
    --conn-params sslmode=disable \
    --isolation 2 \
    ${pass_flag} \
    ${extra_global} \
    tpcc \
    --warehouses "${WAREHOUSES}" \
    --db "${DB_NAME}" \
    "$@"
}

_elapsed() {
  local start=$1 end=$2
  local s=$(( end - start ))
  printf "%dm%02ds" $(( s / 60 )) $(( s % 60 ))
}

cmd_prepare() {
  local t0=$SECONDS
  echo "==> [cockroach-tpcc] prepare: ${CRDB_HOST}:${CRDB_PORT} warehouses=${WAREHOUSES}"
  _go_tpc_base 8 "" prepare
  echo "==> [cockroach-tpcc] prepare done ($(_elapsed $t0 $SECONDS))"
}

cmd_run() {
  local t_total=$SECONDS
  mkdir -p "${OUTPUT_DIR}"
  echo "==> [cockroach-tpcc] output dir: ${OUTPUT_DIR}"

  cat > "${OUTPUT_DIR}/env.txt" <<EOF
CRDB_HOST=${CRDB_HOST}
CRDB_PORT=${CRDB_PORT}
CRDB_USER=${CRDB_USER}
WAREHOUSES=${WAREHOUSES}
DURATION=${DURATION}
THREADS_LIST="${THREADS_LIST}"
WARMUP=${WARMUP}
VARIANT=${VARIANT}
TOPO=${TOPO}
SCENARIO=${SCENARIO}
TIMESTAMP=${TIMESTAMP}
EOF

  # warmup (results discarded)
  local t0=$SECONDS
  echo "==> [cockroach-tpcc] warmup ${WARMUP} threads=16"
  _go_tpc_base 16 "--time ${WARMUP}" run > /dev/null 2>&1 || true
  echo "==> [cockroach-tpcc] warmup done ($(_elapsed $t0 $SECONDS))"

  # run per concurrency level
  for THREADS in ${THREADS_LIST}; do
    t0=$SECONDS
    echo "==> [cockroach-tpcc] run threads=${THREADS} duration=${DURATION}"
    _go_tpc_base "${THREADS}" "--time ${DURATION}" run \
      2>&1 | tee "${OUTPUT_DIR}/tpcc-c${THREADS}.log"
    echo "==> [cockroach-tpcc] threads=${THREADS} done ($(_elapsed $t0 $SECONDS))"
  done

  echo "==> [cockroach-tpcc] all runs complete: ${OUTPUT_DIR} (total $(_elapsed $t_total $SECONDS))"
}

cmd_cleanup() {
  local t0=$SECONDS
  echo "==> [cockroach-tpcc] cleanup db=${DB_NAME}"
  _go_tpc_base 1 "" cleanup
  echo "==> [cockroach-tpcc] cleanup done ($(_elapsed $t0 $SECONDS))"
}

case "${CMD}" in
  prepare) cmd_prepare ;;
  run)     cmd_run ;;
  cleanup) cmd_cleanup ;;
  *)
    echo "Usage: $0 <prepare|run|cleanup>" >&2
    exit 1
    ;;
esac
