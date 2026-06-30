#!/usr/bin/env bash
# promotion-gate.sh — Promotion checklist #9 final gate (per decisions Q12)
#
# Verifies on .31:
#   #1  W=128 × P-A × 3-DB cells (summary.json warehouses=128 + .suite.done)
#   #2  P-B × 3-DB cells (.suite.done present)
#   #7  probe driver artifact (probe-stats.json in any cell)
#   #8  no cell has incomplete_reason in .suite.done
#
# All PASS → prints #9 flip command; any FAIL → exit 1 (blocks flip).
#
# Usage (from Mac/controller):
#   bash phase-crossregion/scripts/promotion-gate.sh \
#     --artifact-dir /tmp/poc-tpcc/artifacts/X-CROSS --ts <TPCC_TS>

set -euo pipefail

IDC_ADMIN=172.24.40.31
ARTIFACT_DIR="" TS=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --artifact-dir) ARTIFACT_DIR=$2; shift 2 ;;
    --ts) TS=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[[ -n "$ARTIFACT_DIR" && -n "$TS" ]] || { echo "usage: $0 --artifact-dir <path> --ts <ts>" >&2; exit 2; }

PASS=0; FAIL=0
pass() { echo "  [PASS] $1"; PASS=$((PASS+1)); }
fail() { echo "  [FAIL] $1 — $2"; FAIL=$((FAIL+1)); }

remote() {
  ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
      root@"$IDC_ADMIN" "$1" 2>/dev/null
}

echo "==> Promotion checklist gate  TS=$TS"
echo "    artifact_dir=$ARTIFACT_DIR"
echo ""

# ── #1: W=128 × P-A × 3-DB ────────────────────────────────────────────────
echo "--- #1 W=128 × P-A × 3-DB ---"
for db in tidb crdb ybdb; do
  suite=$(remote "ls -d $ARTIFACT_DIR/${db}-vm-6node-P-A-rc-* 2>/dev/null | tail -1" || true)
  if [[ -z "$suite" ]]; then
    fail "#1 $db P-A suite" "no suite dir found in $ARTIFACT_DIR"
    continue
  fi
  if ! remote "test -f $suite/.suite.done"; then
    fail "#1 $db P-A .suite.done" "missing"
    continue
  fi
  w=$(remote "python3 -c \"import json; print(json.load(open('$suite/summary.json')).get('warehouses','?'))\"" || echo "?")
  if [[ "$w" == "128" ]]; then
    pass "#1 $db P-A W=128"
  else
    fail "#1 $db P-A W=128" "summary.json warehouses=$w (expected 128)"
  fi
done

# ── #2: P-B × 3-DB ────────────────────────────────────────────────────────
echo ""
echo "--- #2 P-B × 3-DB ---"
for db in tidb crdb ybdb; do
  suite=$(remote "ls -d $ARTIFACT_DIR/${db}-vm-6node-P-B-rc-* 2>/dev/null | tail -1" || true)
  if [[ -z "$suite" ]]; then
    fail "#2 $db P-B suite" "no P-B suite dir found"
    continue
  fi
  if remote "test -f $suite/.suite.done"; then
    pass "#2 $db P-B .suite.done"
  else
    fail "#2 $db P-B .suite.done" "missing"
  fi
done

# ── #7: probe driver artifact ─────────────────────────────────────────────
echo ""
echo "--- #7 probe driver ---"
probe=$(remote "ls $ARTIFACT_DIR/*/probe-stats.json 2>/dev/null | head -1" || true)
if [[ -n "$probe" ]]; then
  pass "#7 probe-stats.json ($probe)"
else
  fail "#7 probe-stats.json" "not found in any cell — run probe-rto-driver before promotion"
fi

# ── #8: no incomplete cells ───────────────────────────────────────────────
echo ""
echo "--- #8 no incomplete cells ---"
incomplete=$(remote "grep -rl 'incomplete_reason' $ARTIFACT_DIR/*/.suite.done 2>/dev/null || true" || true)
if [[ -z "$incomplete" ]]; then
  pass "#8 no cells with incomplete_reason"
else
  fail "#8 incomplete cells found" "$incomplete"
fi

# ── Summary ───────────────────────────────────────────────────────────────
echo ""
echo "==> Results: ${PASS} PASS, ${FAIL} FAIL"

if [[ $FAIL -eq 0 ]]; then
  echo ""
  echo "==> ALL PASS — ready for #9 promotion flip"
  echo ""
  echo "    Run this single commit to flip:"
  echo "    sed -i '' 's/OFFICIAL EXPLORATORY/OFFICIAL (MEASURED)/g' \\"
  echo "      results/x-cross/demo/x-cross-report-demo.md"
  echo "    git add results/x-cross/demo/x-cross-report-demo.md"
  echo "    git commit -m 'docs(x-cross): #9 — promote to OFFICIAL (MEASURED)  ts=$(TS)'"
  exit 0
else
  echo ""
  echo "==> PROMOTION GATE FAIL — resolve above before #9 flip"
  exit 1
fi
