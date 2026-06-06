#!/usr/bin/env bash
# verify-readme-gates.sh — comprehensive README/results integrity gates
#
# Runs 6 sub-phase verifications:
#   P4a: markdown link + anchor verify (delegates to verify-readme-links.py)
#   P4b: canonical TS dry-run — 18 cells × 3 DB, picker should yield expected TS
#   P4c: deprecated archive reference check — cockroach-tc1 / yuga-tc1-old
#        should only appear with explicit deprecated / archive marker nearby
#   P4d: TOC smoke — required main headings exist in README.md
#   P4e: terminology — `CRDB` / `YBDB` should not appear in narrative
#        (path codes like `crdb-tc1` are exempt — lowercase only)
#   P4f: phase scope contamination — T-THRD / X-CROSS paths禁入 README main tables
#        (baseline_eligible=false scopes must not feed main-table source list)
#
# Exit: 0 = all gates pass; >0 = number of gates that failed.

set -uo pipefail
ROOT=$(cd "$(dirname "$0")" && pwd)
README="$ROOT/README.md"

ERR=0
section() { echo; echo "=== $1 ==="; }
pass() { echo "  PASS — $1"; }
fail() { echo "  FAIL — $1"; ERR=$((ERR+1)); }

# ----------------------------------------------------------------------------
section "P4a: markdown link + anchor verify"
# ----------------------------------------------------------------------------
if python3 "$ROOT/verify-readme-links.py" > /tmp/readme-links.out 2>&1; then
  pass "verify-readme-links.py exit 0"
  grep -E '^Total|^  (OK|EXT_WARN|FILE_MISS|ANCHOR_MISS|XFILE_MISS|XANCHOR_MISS)' /tmp/readme-links.out
else
  fail "verify-readme-links.py exit non-zero"
  cat /tmp/readme-links.out
fi

# ----------------------------------------------------------------------------
section "P4b: canonical TS dry-run (18 cells × 3 DB)"
# ----------------------------------------------------------------------------
# Algorithm (relaxed): pick highest TS dir under cell that has .suite.done
# + ≥20 go-tpc-stdout.txt > 1k.  For vm-3node, also require .gate-isolation.done.

canonical_ts() {
  local cell_dir="$1"
  for d in $(ls -1d "$cell_dir"/*-rc-* 2>/dev/null | sort -r); do
    [ -f "$d/.suite.done" ] || continue
    [ "$(find "$d/runs" -name 'go-tpc-stdout.txt' -type f -size +1k 2>/dev/null | wc -l)" -ge 20 ] || continue
    if [[ "$d" != *vm-1node* ]]; then
      [ -f "$d/.gate-isolation.done" ] || continue
    fi
    echo "$d"
    return 0
  done
  return 1
}

declare -A EXPECTED=(
  ["tidb-tc1/S-BASE/vm-1node-rc"]="tidb-vm-1node-rc-20260518T202009+0800"
  ["tidb-tc1/S-BASE/vm-3node-1s1r-rc"]="tidb-vm-3node-1s1r-rc-20260529T132940+0800"
  ["tidb-tc1/S-BASE/vm-3node-1s3r-rc-pd-sched-l4r4"]="tidb-vm-3node-1s3r-rc-20260530T162428+0800"
  ["tidb-tc1/S-BASE/vm-3node-3s1r-rc"]="tidb-vm-3node-3s1r-rc-20260530T023238+0800"
  ["tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l4r4"]="tidb-vm-3node-3s3r-rc-20260531T085812+0800"
  ["tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4"]="tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800"
  ["crdb-tc1/S-BASE/vm-1node-rc"]="crdb-vm-1node-rc-20260519T085346+0800"
  ["crdb-tc1/S-BASE/vm-3node-1s1r-rc"]="crdb-vm-3node-1s1r-rc-20260601T105859+0800"
  ["crdb-tc1/S-BASE/vm-3node-1s3r-rc"]="crdb-vm-3node-1s3r-rc-20260601T142702+0800"
  ["crdb-tc1/S-BASE/vm-3node-3s1r-rc"]="crdb-vm-3node-3s1r-rc-20260601T221341+0800"
  ["crdb-tc1/S-BASE/vm-3node-3s3r-rc"]="crdb-vm-3node-3s3r-rc-20260602T014253+0800"
  ["crdb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc"]="crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800"
  ["yuga-tc1/S-BASE/vm-1node-rc"]="ybdb-vm-1node-rc-20260520T134929+0800"
  ["yuga-tc1/S-BASE/vm-3node-1s1r-rc"]="ybdb-vm-3node-1s1r-rc-20260524T032814+0800"
  ["yuga-tc1/S-BASE/vm-3node-1s3r-rc"]="ybdb-vm-3node-1s3r-rc-20260524T074754+0800"
  ["yuga-tc1/S-BASE/vm-3node-3s1r-rc"]="ybdb-vm-3node-3s1r-rc-20260524T202219+0800"
  ["yuga-tc1/S-BASE/vm-3node-3s3r-rc"]="ybdb-vm-3node-3s3r-rc-20260525T031918+0800"
  ["yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc"]="ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800"
)

p4b_fail=0
for key in $(printf "%s\n" "${!EXPECTED[@]}" | sort); do
  cdir="$ROOT/$key"
  picked=$(canonical_ts "$cdir")
  expected="${EXPECTED[$key]}"
  if [ "$(basename "$picked")" = "$expected" ]; then
    : # silent on pass
  else
    fail "$key — expected=$expected got=$(basename "$picked")"
    p4b_fail=$((p4b_fail+1))
  fi
done
[ "$p4b_fail" -eq 0 ] && pass "all 18 cells canonical TS resolved correctly"

# ----------------------------------------------------------------------------
section "P4c: deprecated archive reference check"
# ----------------------------------------------------------------------------
# Each occurrence of cockroach-tc1 or yuga-tc1-old in README must have one of
# {deprecated, archive, 封存, 已 deprecated, 已封存, deprecated /} within ±2 lines.

check_deprecated() {
  local pattern="$1"
  local marker_re="deprecated|archive|封存|migrated"
  local out=""
  while IFS=: read -r line content; do
    # context: ±2 lines around the hit
    ctx=$(sed -n "$((line-2)),$((line+2))p" "$README" 2>/dev/null)
    if ! echo "$ctx" | grep -qiE "$marker_re"; then
      out+="line $line: $content\n"
    fi
  done < <(grep -nE "$pattern" "$README" 2>/dev/null | grep -v "^[0-9]*:[[:space:]]*#" || true)
  if [ -n "$out" ]; then
    fail "$pattern occurrences without deprecated/archive marker nearby:"
    printf "%b" "$out"
    return 1
  fi
  pass "$pattern — all occurrences have deprecated/archive marker"
}

check_deprecated 'cockroach-tc1' || true
check_deprecated 'yuga-tc1-old' || true

# ----------------------------------------------------------------------------
section "P4d: TOC smoke (required main headings)"
# ----------------------------------------------------------------------------
REQUIRED_HEADINGS=(
  "^## 如何閱讀$"
  "^## 目前總覽$"
  "^## 已驗證結果$"
  "^## 執行矩陣$"
  "^## 資料庫說明$"
  "^## 修正歷程 \(Fixes Catalog\)$"
  "^## 候選配置與彙整分析 \(Pending N=3 Validation\)$"
  "^## 專案進度$"
  "^## 操作指南$"
  "^## 表格註解（標準四項）$"
  "^## 數據品質註解（補充）$"
  "^## 參考 / 文件索引$"
)
toc_fail=0
for h in "${REQUIRED_HEADINGS[@]}"; do
  if grep -qE "$h" "$README"; then
    :
  else
    fail "missing heading: $h"
    toc_fail=$((toc_fail+1))
  fi
done
[ "$toc_fail" -eq 0 ] && pass "all ${#REQUIRED_HEADINGS[@]} required headings present"

# ----------------------------------------------------------------------------
section "P4e: terminology (uppercase CRDB / YBDB in narrative)"
# ----------------------------------------------------------------------------
# Whitelist: anywhere CRDB or YBDB appears INSIDE a path (lowercase neighbors
# like crdb-tc1, crdb-vm-3node-...). But uppercase CRDB / YBDB as standalone
# words in narrative is the violation.
#
# Allowed contexts:
#   - explicit warning/discussion lines (e.g., "不使用 `CRDB` / `YBDB`")
#   - dispatch-records line text that uses CRDB / YBDB historically
#
# This script only checks README.md.

violations=$(grep -nE '\bCRDB\b|\bYBDB\b' "$README" | grep -v "不使用" || true)
if [ -z "$violations" ]; then
  pass "no narrative use of CRDB / YBDB in README.md"
else
  fail "narrative use of CRDB / YBDB found:"
  echo "$violations"
fi

# ----------------------------------------------------------------------------
section "P4f: phase scope contamination (T-THRD / X-CROSS in README main tables)"
# ----------------------------------------------------------------------------
# baseline_eligible=false scopes (T-THRD, X-CROSS) must not appear as data
# source in README.md main tables. Allowed contexts:
#   - phase registry references (e.g., 連結 results/PHASES.md / phase-*/README.md)
#   - explicit forbidden / caveat / 禁讀 discussion
# Implementation: any line in README.md containing `T-THRD/` or `X-CROSS/` MUST
# co-occur with one of: `PHASES.md`, `phase-`, `forbidden`, `禁讀`, `caveat`.

phase_violations=""
while IFS= read -r line; do
  case "$line" in
    *PHASES.md*|*phase-*|*forbidden*|*禁讀*|*caveat*) ;;
    *) phase_violations+="$line"$'\n' ;;
  esac
done < <(grep -nE 'T-THRD/|X-CROSS/' "$README" || true)

if [ -z "$phase_violations" ]; then
  pass "no main-table contamination from T-THRD / X-CROSS in README.md"
else
  fail "T-THRD / X-CROSS references in README.md missing phase-registry context:"
  echo "$phase_violations"
fi

# ----------------------------------------------------------------------------
echo
echo "=== SUMMARY ==="
if [ "$ERR" -eq 0 ]; then
  echo "  All 6 sub-phase gates PASS."
  exit 0
else
  echo "  $ERR gate(s) FAILED — see above."
  exit "$ERR"
fi
