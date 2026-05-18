#!/usr/bin/env bash
set -euo pipefail
SELF=$(cd "$(dirname "$0")" && pwd)
source "$SELF/lib/common.sh"

DB="" ISO="" TS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db) DB=$2; shift 2 ;;
    --iso) ISO=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    *) die "unknown arg: $1" ;;
  esac
done
[[ -n "$DB" && -n "$ISO" && -n "$TS" ]] || die "missing required args"

RESULT_ROOT="results/${DB}-tc1/S-BASE/vm-1node-${ISO}"
SUMMARY="${RESULT_ROOT}/${TS}/summary.json"
REPORT="${RESULT_ROOT}/pipeline-log.md"
[[ -f "$SUMMARY" ]] || die "summary.json not found: $SUMMARY"

require_cmd jq
mkdir -p "$RESULT_ROOT"

jqv() {
  local expr=$1
  jq -r "$expr // \"N/A\"" "$SUMMARY"
}

fmt() {
  local value=$1
  if [[ "$value" == "null" || -z "$value" ]]; then
    printf 'N/A'
  else
    printf '%s' "$value"
  fi
}

round_cell() {
  local threads=$1 round=$2 expr=$3
  local out
  out=$(jq -r --argjson threads "$threads" --argjson round "$round" \
    '.runs[]? | select(.threads == $threads) | .rounds[]? | select(.round == $round) | '"$expr"' // "N/A"' "$SUMMARY" | head -1)
  [[ -n "$out" ]] && printf '%s\n' "$out" || printf 'N/A\n'
}

median_cell() {
  local threads=$1 expr=$2
  local out
  out=$(jq -r --argjson threads "$threads" \
    '.runs[]? | select(.threads == $threads) | .median_round_2_5.'"$expr"' // "N/A"' "$SUMMARY" | head -1)
  [[ -n "$out" ]] && printf '%s\n' "$out" || printf 'N/A\n'
}

mix_cell() {
  local threads=$1 round=$2
  local out
  out=$(jq -r --argjson threads "$threads" --argjson round "$round" '
    .runs[]? | select(.threads == $threads) | .rounds[]? | select(.round == $round) |
    if .mix == null then "N/A"
    else "\(.mix.NewOrder // "N/A")/\(.mix.Payment // "N/A")/\(.mix.OrderStatus // "N/A")/\(.mix.Delivery // "N/A")/\(.mix.StockLevel // "N/A")"
    end' "$SUMMARY" | head -1)
  [[ -n "$out" ]] && printf '%s\n' "$out" || printf 'N/A\n'
}

sqlstate_cell() {
  local threads=$1 round=$2
  local out
  out=$(jq -r --argjson threads "$threads" --argjson round "$round" '
    .runs[]? | select(.threads == $threads) | .rounds[]? | select(.round == $round) |
    if (.sqlstate_top // []) | length == 0 then "N/A"
    else (.sqlstate_top | map("\(.code):\(.count)") | join(", "))
    end' "$SUMMARY" | head -1)
  [[ -n "$out" ]] && printf '%s\n' "$out" || printf 'N/A\n'
}

threads_list=$(jq -r '.runs[]?.threads' "$SUMMARY" | sort -n | tr '\n' ' ')
[[ -n "${threads_list// }" ]] || threads_list="16 32 64 128"

artifact_root="${TPCC_ARTIFACTS:-/tmp/poc-tpcc/artifacts}/${DB}-vm-1node-${ISO}-${TS}"

resource_summary=$(
  {
    echo "- Artifact root: ${artifact_root}"
    if [[ -d "$artifact_root/runs" ]]; then
      vmstat_peak=$(awk 'NR>2 && $13 ~ /^[0-9.]+$/ {v=100-$15; if (v>max) max=v} END {if (max=="") print "N/A"; else printf "%.2f", max}' "$artifact_root"/runs/threads-*/round-*/vmstat-1s.txt 2>/dev/null || true)
      iowait_peak=$(awk 'NR>2 && $16 ~ /^[0-9.]+$/ {if ($16>max) max=$16} END {if (max=="") print "N/A"; else printf "%.2f", max}' "$artifact_root"/runs/threads-*/round-*/iostat-1s.txt 2>/dev/null || true)
      pid_cpu_peak=$(awk 'NR>2 && $0 !~ /UID/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9.]+$/) last=$i; if (last>max) max=last} END {if (max=="") print "N/A"; else printf "%.2f", max}' "$artifact_root"/runs/threads-*/round-*/pidstat-1s.txt 2>/dev/null || true)
      rss_peak=$(awk 'NR>2 && $0 !~ /UID/ {for (i=1;i<=NF;i++) if ($i ~ /^[0-9]+$/) last=$i; if (last>max) max=last} END {if (max=="") print "N/A"; else print max}' "$artifact_root"/runs/threads-*/round-*/pidstat-1s.txt 2>/dev/null || true)
      client_cpu_peak=$(jq -r '[.runs[]?.rounds[]?.client_cpu_p95 | select(. != null)] | if length == 0 then "N/A" else max end' "$SUMMARY")
      client_idle_p95_min=$(jq -r '[.runs[]?.rounds[]?.client_idle_p95 | select(. != null)] | if length == 0 then "N/A" else min end' "$SUMMARY")
      echo "- DB process peak CPU%: $(fmt "${pid_cpu_peak:-N/A}")"
      echo "- DB process peak RSS: $(fmt "${rss_peak:-N/A}")"
      echo "- I/O wait peak %: $(fmt "${iowait_peak:-N/A}")"
      echo "- Host CPU peak % from vmstat: $(fmt "${vmstat_peak:-N/A}")"
      echo "- Client process CPU p95 max: $(fmt "$client_cpu_peak")"
      echo "- Client host idle p95 min: $(fmt "$client_idle_p95_min")"
    else
      echo "- Resource artifacts not found locally; OS/DB peak fields are N/A."
    fi
  }
)

{
  echo "## 0. Benchmark boundary 聲明"
  echo
  echo "> 本測試為 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C。"
  if [[ "$DB" == "crdb" ]]; then
    echo "> CockroachDB start-single-node 不適合 perf testing；本拓撲僅作 single-node baseline 對比。"
  fi
  echo
  echo "## 1. 版本資訊"
  echo "- DB: $DB"
  echo "- DB version: $(jqv '.meta.db_version')"
  echo "- go-tpc version: $(jqv '.meta.gotpc_version')"
  echo "- go-tpc sha256: $(jqv '.meta.gotpc_sha256')"
  echo "- OS / kernel: $(jqv '.meta.kernel')"
  echo "- Test timestamp: $(jqv '.meta.timestamp')"
  echo "- Warehouses: $(jqv '.meta.warehouses')"
  echo
  echo "## 2. 對齊設定快照"
  echo "- Topology: $(jqv '.meta.topology')"
  echo "- Isolation: $ISO"
  echo "- Isolation expected: $(jqv '.gates.isolation_expected')"
  echo "- Isolation actual: $(jqv '.gates.isolation_actual')"
  echo "- Memory budget: 11GB DB-process envelope"
  echo "- WAL durable: enabled by SSOT for all DBs"
  echo "- Auto-statistics: disabled"
  if [[ "$DB" == "tidb" ]]; then
    echo "- TiDB pessimistic mode: enabled"
  fi
  echo
  echo "## 3. Gate 結果"
  echo "- OS gate: $(jqv '.gates.os')"
  echo "- Chrony offset ms: $(jqv '.gates.chrony_offset_ms')"
  echo "- Isolation pass: $(jqv '.gates.isolation_pass')"
  echo "- Cluster health: $(jqv '.gates.cluster_health')"
  echo "- Disk free GB: $(jqv '.gates.disk_free_gb')"
  echo "- Client saturation: see per-round client_idle_p95/client_cpu_p95"
  echo
  echo "## 4. Prepare 階段"
  echo "- Duration sec: $(jqv '.prepare.duration_sec')"
  echo "- check-all pass: $(jqv '.prepare.check_all_pass')"
  echo "- ANALYZE pass: $(jqv '.prepare.analyze_pass')"
  echo "- Hotspot snapshot: $(jqv '.prepare.hotspot_snapshot')"
  echo "- EXPLAIN dumps: artifacts/prepare/explain-*.txt"
  echo "- Stats snapshot: artifacts/prepare/stats-snapshot.txt"
  echo
  echo "## 5. Run 結果"
  for threads in $threads_list; do
    echo
    echo "### threads = $threads"
    echo
    echo "| Round | tpmC raw | tpmC ex-abort | Mix NewOrder/Pay/OS/Del/SL % | P50 | P95 | P99 | retry | abort | SQLSTATE top | 備註 |"
    echo "|---|---:|---:|---|---:|---:|---:|---:|---:|---|---|"
    for round in 1 2 3 4 5; do
      label="$round"
      [[ "$round" == "1" ]] && label="1 (丟)"
      note=$(round_cell "$threads" "$round" '.invalid_reason')
      [[ "$note" == "N/A" && "$round" == "1" ]] && note="warmup recovery"
      echo "| $label | $(round_cell "$threads" "$round" '.tpmC_raw') | $(round_cell "$threads" "$round" '.tpmC_ex_abort') | $(mix_cell "$threads" "$round") | $(round_cell "$threads" "$round" '.latency_ms.p50') | $(round_cell "$threads" "$round" '.latency_ms.p95') | $(round_cell "$threads" "$round" '.latency_ms.p99') | $(round_cell "$threads" "$round" '.retry') | $(round_cell "$threads" "$round" '.abort') | $(sqlstate_cell "$threads" "$round") | $note |"
    done
    echo "| **Median (2-5)** | $(median_cell "$threads" 'tpmC_raw') | $(median_cell "$threads" 'tpmC_ex_abort') | $(jq -r --argjson threads "$threads" '.runs[]? | select(.threads == $threads) | ([.rounds[]? | select(.round >= 2 and .round <= 5) | .mix_pass] | if length == 0 then "N/A" elif all then "pass" else "fail" end)' "$SUMMARY" | head -1) | N/A | N/A | $(median_cell "$threads" 'p99_ms') | N/A | N/A | N/A | retry_rate=$(median_cell "$threads" 'retry_rate') |"
  done
  echo
  echo "## 6. OS / DB 資源觀察"
  echo "$resource_summary"
  echo
  echo "## 7. Artifact 索引"
  echo "- summary.json: ${SUMMARY}"
  echo "- db-config: ${artifact_root}/db-config/"
  echo "- gate: ${artifact_root}/gate/"
  echo "- prepare: ${artifact_root}/prepare/"
  echo "- runs: ${artifact_root}/runs/"
  echo
  echo "## 8. 結論與限制"
  echo "- Round 1 依 SSOT 作為 cold-reset 後恢復觀察，不納入代表 median。"
  echo "- 欄位為 N/A 表示 summary.json 或 artifacts 未提供，禁止據此推論為 0。"
  if [[ "$DB" == "crdb" && "$ISO" == "rr" ]]; then
    echo "- CockroachDB repeatable read tier 為 preview opt-in，報告解讀需標註。"
  fi
} > "$REPORT"

info "pipeline log rendered: $REPORT"
