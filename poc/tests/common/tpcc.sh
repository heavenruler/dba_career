#!/usr/bin/env bash
# tpcc.sh — go-tpc TPC-C wrapper
# Usage: TIDB_HOST=x TIDB_PORT=x VARIANT=vm bash tpcc.sh <prepare|run|cleanup>
#
# Required env:
#   TIDB_HOST       DB host (HAProxy or K8s NodePort)
#   TIDB_PORT       DB port
#
# Optional env (defaults shown):
#   TIDB_USER       root
#   TIDB_PASS       (empty)
#   WAREHOUSES      10
#   DURATION        10m
#   THREADS_LIST    "16 32 64"
#   WARMUP          5m
#   VARIANT         vm          # vm | k8s-unlimit | k8s-limit
#   TOPO            tidb-tc1
#   SCENARIO        S-BASE
#   RESULT_BASE     results
set -euo pipefail

CMD=${1:-run}

TIDB_HOST=${TIDB_HOST:?TIDB_HOST is required}
TIDB_PORT=${TIDB_PORT:?TIDB_PORT is required}
TIDB_USER=${TIDB_USER:-root}
TIDB_PASS=${TIDB_PASS:-}
WAREHOUSES=${WAREHOUSES:-10}
DURATION=${DURATION:-10m}
THREADS_LIST=${THREADS_LIST:-"16 32 64"}
WARMUP=${WARMUP:-5m}
VARIANT=${VARIANT:-vm}
TOPO=${TOPO:-tidb-tc1}
SCENARIO=${SCENARIO:-S-BASE}
RESULT_BASE=${RESULT_BASE:-results}
DB_NAME=${DB_NAME:-tpcc}

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_DIR="${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/${TIMESTAMP}"

_go_tpc() {
  local pass_flag=""
  [[ -n "${TIDB_PASS}" ]] && pass_flag="-p ${TIDB_PASS}"
  go-tpc tpcc \
    -H "${TIDB_HOST}" \
    -P "${TIDB_PORT}" \
    -U "${TIDB_USER}" \
    ${pass_flag} \
    --db "${DB_NAME}" \
    --warehouses "${WAREHOUSES}" \
    "$@"
}

cmd_prepare() {
  echo "==> [tpcc] prepare: ${TIDB_HOST}:${TIDB_PORT} warehouses=${WAREHOUSES}"
  _go_tpc prepare --threads 8
  echo "==> [tpcc] prepare done"
}

cmd_run() {
  mkdir -p "${OUTPUT_DIR}"
  echo "==> [tpcc] output dir: ${OUTPUT_DIR}"

  # record connection info
  cat > "${OUTPUT_DIR}/env.txt" <<EOF
TIDB_HOST=${TIDB_HOST}
TIDB_PORT=${TIDB_PORT}
TIDB_USER=${TIDB_USER}
WAREHOUSES=${WAREHOUSES}
DURATION=${DURATION}
THREADS_LIST=${THREADS_LIST}
WARMUP=${WARMUP}
VARIANT=${VARIANT}
TOPO=${TOPO}
SCENARIO=${SCENARIO}
TIMESTAMP=${TIMESTAMP}
EOF

  # warmup (results discarded)
  echo "==> [tpcc] warmup ${WARMUP} threads=16"
  _go_tpc run --threads 16 --time "${WARMUP}" > /dev/null 2>&1 || true

  # run per concurrency level
  for THREADS in ${THREADS_LIST}; do
    echo "==> [tpcc] run threads=${THREADS} duration=${DURATION}"
    _go_tpc run \
      --threads "${THREADS}" \
      --time "${DURATION}" \
      2>&1 | tee "${OUTPUT_DIR}/tpcc-c${THREADS}.log"
    echo "==> [tpcc] threads=${THREADS} done"
  done

  echo "==> [tpcc] all runs complete: ${OUTPUT_DIR}"
}

cmd_cleanup() {
  echo "==> [tpcc] cleanup db=${DB_NAME}"
  _go_tpc cleanup
  echo "==> [tpcc] cleanup done"
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
