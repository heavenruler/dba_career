#!/usr/bin/env bash
# report.sh — parse go-tpc output → summary.md
# Usage: bash report.sh <output_dir>
#
# Reads:  <output_dir>/tpcc-c*.log, <output_dir>/env.txt
# Writes: <output_dir>/summary.md
set -euo pipefail

OUTPUT_DIR=${1:?Usage: $0 <output_dir>}
SUMMARY="${OUTPUT_DIR}/summary.md"

[[ -f "${OUTPUT_DIR}/env.txt" ]] && source "${OUTPUT_DIR}/env.txt"

VARIANT=${VARIANT:-unknown}
TOPO=${TOPO:-unknown}
SCENARIO=${SCENARIO:-unknown}
TIMESTAMP=${TIMESTAMP:-$(basename "${OUTPUT_DIR}")}

# extract a single Summary field from a log file
# usage: _extract_field <file> <txn_type> <field>
# field: TPM | Avg | 95th | 99th | Max
_extract_field() {
  local file=$1 txn=$2 field=$3
  grep "^\[Summary\] ${txn}" "${file}" \
    | grep -oP "${field}\(ms\): \K[0-9.]+" \
    | head -1
}

_extract_tpmc() {
  local file=$1
  grep "^\[Summary\] tpmC" "${file}" \
    | grep -oP "tpmC: \K[0-9.]+" \
    | head -1
}

# collect per-concurrency stats
declare -a THREADS_FOUND=()
declare -A TPMC P99_NO P99_PAY CPU_ROWS

for log in "${OUTPUT_DIR}"/tpcc-c*.log; do
  [[ -f "${log}" ]] || continue
  c=$(basename "${log}" | grep -oP 'c\K[0-9]+')
  THREADS_FOUND+=("${c}")
  TPMC["${c}"]=$(_extract_tpmc "${log}")
  P99_NO["${c}"]=$(_extract_field "${log}" "NEW_ORDER" "99th")
  P99_PAY["${c}"]=$(_extract_field "${log}" "PAYMENT" "99th")
done

# write summary.md
{
cat <<EOF
# ${TOPO} / ${SCENARIO} / ${VARIANT} / ${TIMESTAMP}

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
EOF

for c in "${THREADS_FOUND[@]}"; do
  printf "| %-7s | %-4s | %-18s | %-15s |\n" \
    "${c}" \
    "${TPMC[${c}]:-n/a}" \
    "${P99_NO[${c}]:-n/a}" \
    "${P99_PAY[${c}]:-n/a}"
done

cat <<EOF

## Environment

\`\`\`
$(cat "${OUTPUT_DIR}/env.txt" 2>/dev/null || echo "env.txt not found")
\`\`\`

## Notes

- variant: ${VARIANT}
- control plane overhead: $([ "${VARIANT}" = "vm" ] && echo "N/A (VM)" || echo "included (K8s control plane on poc-1)")
EOF
} > "${SUMMARY}"

echo "==> report written: ${SUMMARY}"
cat "${SUMMARY}"
