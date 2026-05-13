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

# extract p99 latency for a given txn type from a log file
_extract_p99() {
  local file=$1 txn=$2
  grep "^\[Summary\] ${txn}" "${file}" \
    | awk -F'99th\\(ms\\): ' '{print $2}' \
    | awk -F',' '{print $1}' \
    | head -1 \
    || true
}

_extract_tpmc() {
  local file=$1
  grep "^tpmC:" "${file}" \
    | awk '{print $2}' \
    | tr -d ',' \
    | head -1 \
    || true
}

# collect per-concurrency stats
declare -a THREADS_FOUND=()
declare -A TPMC P99_NO P99_PAY CPU_ROWS ERR_COUNT

for log in "${OUTPUT_DIR}"/tpcc-c*.log; do
  [[ -f "${log}" ]] || continue
  c=$(basename "${log}" | sed 's/tpcc-c\([0-9]*\)\.log/\1/')
  THREADS_FOUND+=("${c}")
  TPMC["${c}"]=$(_extract_tpmc "${log}")
  P99_NO["${c}"]=$(_extract_p99 "${log}" "NEW_ORDER")
  P99_PAY["${c}"]=$(_extract_p99 "${log}" "PAYMENT")
  ERR_COUNT["${c}"]=$(grep -Eci 'execute run failed|could not serialize|Restart read required|current transaction is aborted|panic|fatal|bad connection|timeout|Killed|OOM' "${log}" || true)
done

# write summary.md
{
cat <<EOF
# ${TOPO} / ${SCENARIO} / ${VARIANT} / ${TIMESTAMP}

## TPC-C Results

| threads | tpmC | NEW_ORDER p99 (ms) | PAYMENT p99 (ms) |
|---------|------|--------------------|-----------------|
EOF

for c in $(printf '%s\n' "${THREADS_FOUND[@]}" | sort -n); do
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
- control plane overhead: $([[ "${VARIANT}" == vm-* ]] && echo "N/A (VM)" || echo "included (K8s control plane on poc-1)")
EOF

if ((${#THREADS_FOUND[@]})); then
  echo "- log status:"
  for c in $(printf '%s\n' "${THREADS_FOUND[@]}" | sort -n); do
    if [[ -z "${TPMC[${c}]:-}" ]]; then
      echo "  - threads=${c}: incomplete/no tpmC"
    elif [[ "${ERR_COUNT[${c}]:-0}" -gt 0 ]]; then
      echo "  - threads=${c}: completed with ${ERR_COUNT[${c}]} matched error lines"
    else
      echo "  - threads=${c}: completed"
    fi
  done
fi
} > "${SUMMARY}"

echo "==> report written: ${SUMMARY}"
cat "${SUMMARY}"
