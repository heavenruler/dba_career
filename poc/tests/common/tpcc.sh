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
#   REMOTE_HOST     (empty)     # if set: run go-tpc on remote via SSH, rsync results back
set -euo pipefail

CMD=${1:-run}

TIDB_HOST=${TIDB_HOST:?TIDB_HOST is required}
TIDB_PORT=${TIDB_PORT:?TIDB_PORT is required}
TIDB_USER=${TIDB_USER:-root}
TIDB_PASS=${TIDB_PASS:-}
WAREHOUSES=${WAREHOUSES:-128}
DURATION=${DURATION:-10m}
THREADS_LIST=${THREADS_LIST:-"16 32 64 128"}
WARMUP=${WARMUP:-5m}
VARIANT=${VARIANT:-vm}
TOPO=${TOPO:-tidb-tc1}
SCENARIO=${SCENARIO:-S-BASE}
RESULT_BASE=${RESULT_BASE:-results}
DB_NAME=${DB_NAME:-tpcc}
REMOTE_HOST=${REMOTE_HOST:-}

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_DIR="${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/${TIMESTAMP}"

# --- remote execution ---
# If REMOTE_HOST is set: ship this script + env to remote, run there, rsync results back
if [[ -n "${REMOTE_HOST}" ]]; then
  REMOTE_DIR="/tmp/tpcc-runner"
  SSH="ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10"
  SCP="scp -o StrictHostKeyChecking=accept-new"

  echo "==> [tpcc] remote mode: ${REMOTE_HOST} (${REMOTE_DIR})"
  $SSH "${REMOTE_HOST}" "mkdir -p ${REMOTE_DIR}"
  $SCP -q "$0" "${REMOTE_HOST}:${REMOTE_DIR}/tpcc.sh"

  $SSH "${REMOTE_HOST}" "
    export TIDB_HOST='${TIDB_HOST}'
    export TIDB_PORT='${TIDB_PORT}'
    export TIDB_USER='${TIDB_USER}'
    export TIDB_PASS='${TIDB_PASS}'
    export WAREHOUSES='${WAREHOUSES}'
    export DURATION='${DURATION}'
    export THREADS_LIST='${THREADS_LIST}'
    export WARMUP='${WARMUP}'
    export VARIANT='${VARIANT}'
    export TOPO='${TOPO}'
    export SCENARIO='${SCENARIO}'
    export RESULT_BASE='${REMOTE_DIR}/results'
    export DB_NAME='${DB_NAME}'
    bash ${REMOTE_DIR}/tpcc.sh ${CMD}
  "

  if [[ "${CMD}" == "run" ]]; then
    echo "==> [tpcc] rsync results back"
    mkdir -p "${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}"
    rsync -a -e "$SSH" \
      "${REMOTE_HOST}:${REMOTE_DIR}/results/${TOPO}/${SCENARIO}/${VARIANT}/" \
      "${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/"
    echo "==> [tpcc] results synced: ${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/"
  fi
  exit 0
fi

# go-tpc global flags go BEFORE subcommand: go-tpc [global] tpcc [tpcc-flags] prepare|run
_go_tpc_base() {
  local threads=$1 extra_global=$2; shift 2
  local pass_flag=""
  [[ -n "${TIDB_PASS}" ]] && pass_flag="-p ${TIDB_PASS}"
  go-tpc \
    -H "${TIDB_HOST}" \
    -P "${TIDB_PORT}" \
    -U "${TIDB_USER}" \
    -T "${threads}" \
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
  echo "==> [tpcc] prepare: ${TIDB_HOST}:${TIDB_PORT} warehouses=${WAREHOUSES}"
  _go_tpc_base 8 "" prepare
  echo "==> [tpcc] prepare done ($(_elapsed $t0 $SECONDS))"
}

cmd_run() {
  local t_total=$SECONDS
  mkdir -p "${OUTPUT_DIR}"
  echo "==> [tpcc] output dir: ${OUTPUT_DIR}"

  cat > "${OUTPUT_DIR}/env.txt" <<EOF
TIDB_HOST=${TIDB_HOST}
TIDB_PORT=${TIDB_PORT}
TIDB_USER=${TIDB_USER}
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
  echo "==> [tpcc] warmup ${WARMUP} threads=16"
  _go_tpc_base 16 "--time ${WARMUP}" run > /dev/null 2>&1 || true
  echo "==> [tpcc] warmup done ($(_elapsed $t0 $SECONDS))"

  # run per concurrency level
  for THREADS in ${THREADS_LIST}; do
    t0=$SECONDS
    echo "==> [tpcc] run threads=${THREADS} duration=${DURATION}"
    _go_tpc_base "${THREADS}" "--time ${DURATION}" run \
      2>&1 | tee "${OUTPUT_DIR}/tpcc-c${THREADS}.log"
    echo "==> [tpcc] threads=${THREADS} done ($(_elapsed $t0 $SECONDS))"
  done

  echo "==> [tpcc] all runs complete: ${OUTPUT_DIR} (total $(_elapsed $t_total $SECONDS))"
}

cmd_cleanup() {
  local t0=$SECONDS
  echo "==> [tpcc] cleanup db=${DB_NAME}"
  _go_tpc_base 1 "" cleanup
  echo "==> [tpcc] cleanup done ($(_elapsed $t0 $SECONDS))"
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
