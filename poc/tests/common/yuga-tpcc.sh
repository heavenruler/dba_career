#!/usr/bin/env bash
# yuga-tpcc.sh — go-tpc TPC-C wrapper for YugabyteDB (YSQL / PostgreSQL wire)
# Usage: YUGA_HOST=x YUGA_PORT=x VARIANT=vm-1node bash yuga-tpcc.sh <prepare|run|cleanup>
#
# Required env:
#   YUGA_HOST       DB host (direct or HAProxy)
#   YUGA_PORT       YSQL port (5433 direct, 15433 HAProxy)
#
# Optional env (defaults shown):
#   YUGA_USER       yugabyte
#   YUGA_PASS       (empty)
#   WAREHOUSES      128
#   DURATION        10m
#   THREADS_LIST    "16 32 64 128"
#   WARMUP          5m
#   VARIANT         vm-1node
#   TOPO            yuga-tc1
#   SCENARIO        S-BASE
#   RESULT_BASE     results
#   DB_NAME         tpcc
#   REMOTE_HOST     (empty)     # if set: run go-tpc on remote via SSH, rsync results back
set -euo pipefail

CMD=${1:-run}

YUGA_HOST=${YUGA_HOST:?YUGA_HOST is required}
YUGA_PORT=${YUGA_PORT:?YUGA_PORT is required}
YUGA_USER=${YUGA_USER:-yugabyte}
YUGA_PASS=${YUGA_PASS:-}
WAREHOUSES=${WAREHOUSES:-128}
DURATION=${DURATION:-10m}
THREADS_LIST=${THREADS_LIST:-"16 32 64 128"}
WARMUP=${WARMUP:-5m}
VARIANT=${VARIANT:-vm-1node}
TOPO=${TOPO:-yuga-tc1}
SCENARIO=${SCENARIO:-S-BASE}
RESULT_BASE=${RESULT_BASE:-results}
DB_NAME=${DB_NAME:-tpcc}
REMOTE_HOST=${REMOTE_HOST:-}

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_DIR="${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/${TIMESTAMP}"

# --- remote execution ---
if [[ -n "${REMOTE_HOST}" ]]; then
  REMOTE_DIR="/tmp/yuga-tpcc-runner"
  SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
  SCP="scp -o StrictHostKeyChecking=accept-new"

  echo "==> [yuga-tpcc] remote mode: ${REMOTE_HOST} (${REMOTE_DIR})"
  $SSH "${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
  $SCP -q "$0" "${REMOTE_HOST}:${REMOTE_DIR}/yuga-tpcc.sh"

  $SSH "${REMOTE_HOST}" "
    export YUGA_HOST='${YUGA_HOST}'
    export YUGA_PORT='${YUGA_PORT}'
    export YUGA_USER='${YUGA_USER}'
    export YUGA_PASS='${YUGA_PASS}'
    export WAREHOUSES='${WAREHOUSES}'
    export DURATION='${DURATION}'
    export THREADS_LIST='${THREADS_LIST}'
    export WARMUP='${WARMUP}'
    export VARIANT='${VARIANT}'
    export TOPO='${TOPO}'
    export SCENARIO='${SCENARIO}'
    export RESULT_BASE='${REMOTE_DIR}/results'
    export DB_NAME='${DB_NAME}'
    bash ${REMOTE_DIR}/yuga-tpcc.sh ${CMD}
  "

  if [[ "${CMD}" == "run" ]]; then
    echo "==> [yuga-tpcc] rsync results back"
    mkdir -p "${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}"
    rsync -a -e "$SSH" \
      "${REMOTE_HOST}:${REMOTE_DIR}/results/${TOPO}/${SCENARIO}/${VARIANT}/" \
      "${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/"
    echo "==> [yuga-tpcc] results synced: ${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/"
  fi
  exit 0
fi

# go-tpc with PostgreSQL driver (-d postgres) for YBDB YSQL
_go_tpc_base() {
  local threads=$1 extra_global=$2; shift 2
  local pass_flag=""
  [[ -n "${YUGA_PASS}" ]] && pass_flag="-p ${YUGA_PASS}"
  go-tpc \
    -d postgres \
    -H "${YUGA_HOST}" \
    -P "${YUGA_PORT}" \
    -U "${YUGA_USER}" \
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
  echo "==> [yuga-tpcc] prepare: ${YUGA_HOST}:${YUGA_PORT} warehouses=${WAREHOUSES}"
  _go_tpc_base 8 "" prepare --no-check
  echo "==> [yuga-tpcc] prepare done ($(_elapsed $t0 $SECONDS))"
}

cmd_run() {
  local t_total=$SECONDS
  mkdir -p "${OUTPUT_DIR}"
  echo "==> [yuga-tpcc] output dir: ${OUTPUT_DIR}"

  cat > "${OUTPUT_DIR}/env.txt" <<EOF
YUGA_HOST=${YUGA_HOST}
YUGA_PORT=${YUGA_PORT}
YUGA_USER=${YUGA_USER}
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
  echo "==> [yuga-tpcc] warmup ${WARMUP} threads=16"
  _go_tpc_base 16 "--time ${WARMUP}" run > /dev/null 2>&1 || true
  echo "==> [yuga-tpcc] warmup done ($(_elapsed $t0 $SECONDS))"

  # run per concurrency level
  for THREADS in ${THREADS_LIST}; do
    t0=$SECONDS
    echo "==> [yuga-tpcc] run threads=${THREADS} duration=${DURATION}"
    _go_tpc_base "${THREADS}" "--time ${DURATION}" run \
      2>&1 | tee "${OUTPUT_DIR}/tpcc-c${THREADS}.log"
    echo "==> [yuga-tpcc] threads=${THREADS} done ($(_elapsed $t0 $SECONDS))"
  done

  echo "==> [yuga-tpcc] all runs complete: ${OUTPUT_DIR} (total $(_elapsed $t_total $SECONDS))"
}

cmd_cleanup() {
  local t0=$SECONDS
  echo "==> [yuga-tpcc] cleanup db=${DB_NAME}"
  _go_tpc_base 1 "" cleanup
  echo "==> [yuga-tpcc] cleanup done ($(_elapsed $t0 $SECONDS))"
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
