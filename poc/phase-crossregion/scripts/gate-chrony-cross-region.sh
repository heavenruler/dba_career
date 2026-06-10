#!/usr/bin/env bash
# phase-crossregion/scripts/gate-chrony-cross-region.sh
#
# Cross-region chrony drift gate (per phase-crossregion/decisions-2026-06-08.md Q10):
#   - 比對 IDC client (.31) 與 GCP client (g-test-poc-5 via :12215 IAP tunnel) chrony tracking
#   - drift > 100ms → fail-closed (cell 不進 sweep)
#   - drift < 100ms → pass
#
# 採 chronyc tracking 'Last offset' 欄位（單位秒；正/負皆視 abs 值）。
# 兩端各自相對其上游 stratum source 校準 → 用兩端 offset 相加近似為 cross-region drift。
#
# 用法:
#   bash gate-chrony-cross-region.sh --ts <ts> --root-suffix <dir-name> --result-scope X-CROSS
#
# 輸出:
#   $TPCC_ARTIFACTS/$RESULT_SCOPE/<root-suffix>/gate/chrony-cross-region.txt
#   含: idc tracking / gcp tracking / drift_ms / verdict (PASS|FAIL)
#
# Exit:
#   0 = pass (drift < threshold)
#   1 = fail (drift >= threshold, or chronyc 無法執行)
#
# Threshold: 100ms (overridable via CHRONY_DRIFT_MS_MAX env)

set -euo pipefail

TS=""
ROOT_SUFFIX=""
RESULT_SCOPE=""
while [[ $# -gt 0 ]]; do
  case $1 in
    --ts) TS=$2; shift 2 ;;
    --root-suffix) ROOT_SUFFIX=$2; shift 2 ;;
    --result-scope) RESULT_SCOPE=$2; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

: "${TS:?--ts required}"
: "${ROOT_SUFFIX:?--root-suffix required}"
: "${RESULT_SCOPE:=X-CROSS}"
: "${CHRONY_DRIFT_MS_MAX:=100}"

# IDC + GCP endpoints
: "${IDC_CLIENT:=root@172.24.40.31}"
: "${GCP_CLIENT_PORT:=12215}"
: "${GCP_CLIENT_SSH:=root@localhost}"

: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts/$RESULT_SCOPE}"
ROOT="$TPCC_ARTIFACTS/$ROOT_SUFFIX"
GATE_DIR="$ROOT/gate"
mkdir -p "$GATE_DIR"
OUT="$GATE_DIR/chrony-cross-region.txt"

remote_chronyc() {
  local label="$1"; shift
  echo "=== $label chronyc tracking ==="
  "$@" 'chronyc tracking 2>/dev/null | head -20' || echo "(chronyc failed on $label)"
  echo
}

# Capture both sides
{
  echo "=== gate-chrony-cross-region.sh  ts=$TS  threshold_ms=$CHRONY_DRIFT_MS_MAX ==="
  echo
  remote_chronyc "IDC client (.31)" ssh "$IDC_CLIENT"
  remote_chronyc "GCP client (g-test-poc-5 via :$GCP_CLIENT_PORT)" ssh -p "$GCP_CLIENT_PORT" "$GCP_CLIENT_SSH"
} > "$OUT" 2>&1

# Parse 'Last offset' (sec) — chronyc 輸出格式: "Last offset     : +0.000123456 seconds"
parse_offset() {
  awk '/Last offset/ { gsub(/[+s,]/, "", $4); print $4; exit }' "$1"
}

# 取 IDC + GCP 各自的 Last offset 區段
awk '/IDC client/, /GCP client/' "$OUT" > "$GATE_DIR/.idc.tmp"
awk '/GCP client/, /^$/'         "$OUT" > "$GATE_DIR/.gcp.tmp"

idc_off=$(parse_offset "$GATE_DIR/.idc.tmp" 2>/dev/null || echo "")
gcp_off=$(parse_offset "$GATE_DIR/.gcp.tmp" 2>/dev/null || echo "")
rm -f "$GATE_DIR/.idc.tmp" "$GATE_DIR/.gcp.tmp"

if [[ -z "$idc_off" || -z "$gcp_off" ]]; then
  echo "FAIL: cannot parse Last offset (idc='$idc_off' gcp='$gcp_off')" | tee -a "$OUT" >&2
  echo "verdict=FAIL" >> "$OUT"
  exit 1
fi

# drift ms = |idc_off| + |gcp_off| approximation (worst-case cross-region drift)
# 用 awk 處理浮點，避免 bash 依賴 bc
drift_ms=$(awk -v a="$idc_off" -v b="$gcp_off" 'BEGIN {
  if (a<0) a=-a;
  if (b<0) b=-b;
  printf "%.3f", (a+b)*1000.0;
}')

{
  echo "----- parsed -----"
  echo "idc_last_offset_sec=$idc_off"
  echo "gcp_last_offset_sec=$gcp_off"
  echo "cross_region_drift_ms=$drift_ms"
  echo "threshold_ms=$CHRONY_DRIFT_MS_MAX"
} >> "$OUT"

# verdict
verdict_pass=$(awk -v d="$drift_ms" -v t="$CHRONY_DRIFT_MS_MAX" 'BEGIN { print (d+0 < t+0) ? "PASS" : "FAIL" }')
echo "verdict=$verdict_pass" >> "$OUT"

if [[ "$verdict_pass" != "PASS" ]]; then
  echo "[gate-chrony-cross-region] FAIL: drift=${drift_ms}ms >= ${CHRONY_DRIFT_MS_MAX}ms" >&2
  exit 1
fi

echo "[gate-chrony-cross-region] PASS: drift=${drift_ms}ms < ${CHRONY_DRIFT_MS_MAX}ms"
