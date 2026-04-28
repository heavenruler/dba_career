#!/usr/bin/env bash
# yuga-tpcc.sh — BenchmarkSQL TPC-C wrapper for YugabyteDB (YSQL)
# Usage: YUGA_HOST=x YUGA_PORT=x VARIANT=yuga-vm bash yuga-tpcc.sh <prepare|run|cleanup>
#
# Required env:
#   YUGA_HOST       DB host (HAProxy or K8s NodePort)
#   YUGA_PORT       YSQL port (15433 for VM HAProxy, 30005 for K8s NodePort)
#
# Optional env (defaults shown):
#   YUGA_USER       yugabyte
#   YUGA_PASS       (empty)
#   WAREHOUSES      10
#   DURATION        10m
#   THREADS_LIST    "16 32 64"
#   WARMUP          5m
#   VARIANT         yuga-vm     # yuga-vm | yuga-k8s
#   TOPO            yuga-tc1
#   SCENARIO        S-BASE
#   RESULT_BASE     results
#   REMOTE_HOST     (empty)     # if set: run on remote via SSH, rsync results back
#
# Note on isolation level: BenchmarkSQL runs under READ COMMITTED by default.
# YugabyteDB default is also READ COMMITTED (as of v2.18+). tpmC is comparable
# within YugabyteDB (VM vs K8s) but cross-DB comparison with TiDB go-tpc is
# informational only due to tool/driver differences.
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
VARIANT=${VARIANT:-yuga-vm}
TOPO=${TOPO:-yuga-tc1}
SCENARIO=${SCENARIO:-S-BASE}
RESULT_BASE=${RESULT_BASE:-results}
DB_NAME=${DB_NAME:-benchmarksql}
REMOTE_HOST=${REMOTE_HOST:-}

## BenchmarkSQL install dir on remote/local
BSL_DIR=${BSL_DIR:-/opt/benchmarksql}
BSL_VERSION=${BSL_VERSION:-5.0}
BSL_URL="https://sourceforge.net/projects/benchmarksql/files/benchmarksql-${BSL_VERSION}.zip"

TIMESTAMP=$(date +%Y%m%d-%H%M)
OUTPUT_DIR="${RESULT_BASE}/${TOPO}/${SCENARIO}/${VARIANT}/${TIMESTAMP}"

_elapsed() {
  local start=$1 end=$2
  local s=$(( end - start ))
  printf "%dm%02ds" $(( s / 60 )) $(( s % 60 ))
}

# duration string (e.g. "10m") → seconds
_duration_to_sec() {
  local d=$1
  if [[ "${d}" =~ ^([0-9]+)m$ ]]; then echo $(( ${BASH_REMATCH[1]} * 60 ))
  elif [[ "${d}" =~ ^([0-9]+)s$ ]]; then echo "${BASH_REMATCH[1]}"
  elif [[ "${d}" =~ ^([0-9]+)h$ ]]; then echo $(( ${BASH_REMATCH[1]} * 3600 ))
  else echo 600; fi
}

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
    export BSL_DIR='${BSL_DIR}'
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

# --- BenchmarkSQL setup (idempotent) ---
_ensure_bsl() {
  if [[ -f "${BSL_DIR}/run/runBenchmark.sh" ]]; then return 0; fi
  echo "==> [yuga-tpcc] installing BenchmarkSQL ${BSL_VERSION} → ${BSL_DIR}"
  command -v java >/dev/null || { echo "ERROR: java not found"; exit 1; }
  command -v unzip >/dev/null || apt-get install -y unzip 2>/dev/null || dnf install -y unzip

  command -v ant >/dev/null || dnf install -y ant 2>/dev/null || apt-get install -y ant

  local tmp=$(mktemp -d)
  curl -fsSL -o "${tmp}/bsl.zip" "${BSL_URL}"
  unzip -q "${tmp}/bsl.zip" -d "${tmp}"
  mkdir -p "$(dirname "${BSL_DIR}")"
  mv "${tmp}/benchmarksql-${BSL_VERSION}" "${BSL_DIR}"
  rm -rf "${tmp}"
  ant -q -f "${BSL_DIR}/build.xml"
  echo "==> [yuga-tpcc] BenchmarkSQL installed"
}

# write props file for current run
_write_props() {
  local threads=$1 duration_sec=$2 props_file=$3
  local pass_line="password=${YUGA_PASS}"

  cat > "${props_file}" <<EOF
db=postgres
driver=org.postgresql.Driver
conn=jdbc:postgresql://${YUGA_HOST}:${YUGA_PORT}/${DB_NAME}
user=${YUGA_USER}
${pass_line}

warehouses=${WAREHOUSES}
loadWorkers=16
terminals=${threads}
runTxnsPerTerminal=0
runMins=$(( duration_sec / 60 ))
limitTxnsPerMin=0
terminalWarehouseFixed=true

newOrderWeight=45
paymentWeight=43
orderStatusWeight=4
deliveryWeight=4
stockLevelWeight=4

resultDirectory=%tpc-c_result%
osCollectorScript=./misc/os_collector_linux.py
osCollectorInterval=1
EOF
}

# parse BenchmarkSQL terminal output → go-tpc compatible lines
# output: "tpmC: <value>" and "[Summary] NEW_ORDER ... 99th(ms): <value>, ..."
_parse_bsl_output() {
  local log=$1 out=$2
  local tpmc p99_no p99_pay

  tpmc=$(grep -i "Measured tpmC" "${log}" | awk '{print $NF}' | tr -d ',' | head -1)
  # BenchmarkSQL 5.x writes latency percentiles in result CSV
  # Fall back to 0 if not present
  local result_dir
  result_dir=$(grep -o 'tpc-c_result[^ ]*' "${log}" 2>/dev/null | head -1 || true)
  if [[ -d "${result_dir}" ]]; then
    p99_no=$(awk -F',' '/NEW_ORDER/ && /99/{print $NF; exit}' "${result_dir}"/*.csv 2>/dev/null || echo "n/a")
    p99_pay=$(awk -F',' '/PAYMENT/ && /99/{print $NF; exit}' "${result_dir}"/*.csv 2>/dev/null || echo "n/a")
  else
    p99_no="n/a"; p99_pay="n/a"
  fi

  {
    echo "tpmC: ${tpmc:-0}"
    echo "[Summary] NEW_ORDER ... 99th(ms): ${p99_no}, ..."
    echo "[Summary] PAYMENT ... 99th(ms): ${p99_pay}, ..."
  } >> "${out}"
}

cmd_prepare() {
  _ensure_bsl
  local t0=$SECONDS
  echo "==> [yuga-tpcc] prepare: ${YUGA_HOST}:${YUGA_PORT} db=${DB_NAME} warehouses=${WAREHOUSES}"

  # create DB if not exists (ignore "already exists" error)
  local _ysql="PGPASSWORD=${YUGA_PASS} psql -h ${YUGA_HOST} -p ${YUGA_PORT} -U ${YUGA_USER}"
  eval "$_ysql -c 'CREATE DATABASE ${DB_NAME}'" 2>&1 | grep -v "already exists" || true

  # enable bulk-load optimisation (skip Raft path for INSERT during load)
  eval "$_ysql -d ${DB_NAME} -c 'ALTER DATABASE ${DB_NAME} SET yb_disable_transactional_writes = true;'" 2>&1
  echo "==> [yuga-tpcc] yb_disable_transactional_writes=true (bulk load mode)"

  local props=$(mktemp /tmp/bsl-prepare.XXXXXX.props)
  _write_props 16 600 "${props}"

  cd "${BSL_DIR}/run"
  ./runDatabaseBuild.sh "${props}"
  rm -f "${props}"

  # restore transactional writes for normal operation
  eval "$_ysql -d ${DB_NAME} -c 'ALTER DATABASE ${DB_NAME} RESET yb_disable_transactional_writes;'" 2>&1
  echo "==> [yuga-tpcc] yb_disable_transactional_writes restored"
  echo "==> [yuga-tpcc] prepare done ($(_elapsed $t0 $SECONDS))"
}

cmd_run() {
  _ensure_bsl
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

  # warmup
  local warmup_sec; warmup_sec=$(_duration_to_sec "${WARMUP}")
  local t0=$SECONDS
  echo "==> [yuga-tpcc] warmup ${WARMUP} threads=16"
  local props_w; props_w=$(mktemp /tmp/bsl-warmup.XXXXXX.props)
  _write_props 16 "${warmup_sec}" "${props_w}"
  cd "${BSL_DIR}/run" && ./runBenchmark.sh "${props_w}" > /dev/null 2>&1 || true
  rm -f "${props_w}"
  echo "==> [yuga-tpcc] warmup done ($(_elapsed $t0 $SECONDS))"

  local duration_sec; duration_sec=$(_duration_to_sec "${DURATION}")

  for THREADS in ${THREADS_LIST}; do
    t0=$SECONDS
    echo "==> [yuga-tpcc] run threads=${THREADS} duration=${DURATION}"
    local props; props=$(mktemp /tmp/bsl-run.XXXXXX.props)
    _write_props "${THREADS}" "${duration_sec}" "${props}"

    local raw_log="${OUTPUT_DIR}/tpcc-c${THREADS}.raw"
    cd "${BSL_DIR}/run" && ./runBenchmark.sh "${props}" 2>&1 | tee "${raw_log}"
    rm -f "${props}"

    # convert to go-tpc compatible format for report.sh
    _parse_bsl_output "${raw_log}" "${OUTPUT_DIR}/tpcc-c${THREADS}.log"
    echo "==> [yuga-tpcc] threads=${THREADS} done ($(_elapsed $t0 $SECONDS))"
  done

  echo "==> [yuga-tpcc] all runs complete: ${OUTPUT_DIR} (total $(_elapsed $t_total $SECONDS))"
}

cmd_cleanup() {
  local t0=$SECONDS
  echo "==> [yuga-tpcc] cleanup db=${DB_NAME}"
  PGPASSWORD="${YUGA_PASS}" psql \
    -h "${YUGA_HOST}" -p "${YUGA_PORT}" -U "${YUGA_USER}" \
    -c "DROP DATABASE IF EXISTS ${DB_NAME}"
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
