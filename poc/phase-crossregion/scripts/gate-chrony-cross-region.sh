#!/usr/bin/env bash
# phase-crossregion/scripts/gate-chrony-cross-region.sh
#
# Cross-region chrony drift gate (per phase-crossregion/decisions-2026-06-08.md Q10).
#
# 取樣：10 hosts —— IDC 5 (driver/db×3/haproxy) + GCP 5 (db×3/haproxy/client via .31 ProxyJump)
# 每台抓 chronyc tracking 的 Stratum / Last offset / Leap status / Reference ID。
# Verdict 三條件 (all 必須成立才 PASS)：
#   1. all 10 Leap == Normal                          (no false-PASS on unsynced host)
#   2. drift_median_ms < CHRONY_DRIFT_MS_MAX           (default 100; 主指標, median-of-abs-offsets sum)
#   3. drift_worst_ms  < CHRONY_DRIFT_MS_WORST_MAX     (default 250; 尾端 hard limit, max+max)
#
# 用法:
#   bash gate-chrony-cross-region.sh --ts <ts> --root-suffix <dir-name> --result-scope X-CROSS
#
# 輸出 (artifact root = $TPCC_ARTIFACTS/$ROOT_SUFFIX/gate/):
#   chrony-cross-region.txt        # 主檔 (與舊版相容: verdict=PASS|FAIL)
#   chrony-cross-region-all10.md   # markdown 表格 + 統計
#   raw/<label>.txt × 10           # 每台原始 chronyc tracking
#   ../.gate-chrony.done           # JSON (verdict + 三 drift + leap_anomalies)
#
# Exit:
#   0 = PASS
#   1 = FAIL (verdict false / 任何 Leap 非 Normal / chronyc 取樣失敗)
#
# Env overrides:
#   CHRONY_DRIFT_MS_MAX        (default 100;  median drift hard ceiling)
#   CHRONY_DRIFT_MS_WORST_MAX  (default 250;  worst-case drift hard ceiling)
#   IDC_HOSTS_SPEC             "label=user@host[,...]"  (override 預設 5 IDC hosts)
#   GCP_HOSTS_SPEC             "label=port[,...]"        (override 預設 5 GCP tunnel ports)
#   GCP_SSH_USER               (default root)
#   GCP_SSH_KEY                (default $HOME/.ssh/id_rsa)
#   GCP_VIA_31                 (default 1): use ProxyJump via 172.24.40.31; set 0 for IAP legacy

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
: "${CHRONY_DRIFT_MS_WORST_MAX:=250}"
: "${GCP_SSH_USER:=root}"
: "${GCP_SSH_KEY:=$HOME/.ssh/id_rsa}"
: "${GCP_VIA_31:=1}"

: "${IDC_HOSTS_SPEC:=idc-driver=root@172.24.40.31,idc-dbhost-1=root@172.24.40.32,idc-dbhost-2=root@172.24.40.33,idc-dbhost-3=root@172.24.40.34,idc-haproxy=root@172.24.47.20}"
# GCP_VIA_31=1 (default): probe via ProxyJump through .31; no IAP tunnel required
# GCP_VIA_31=0 (legacy):   probe via localhost:PORT (IAP tunnel)
if [[ "${GCP_VIA_31}" == "1" ]]; then
  : "${GCP_HOSTS_SPEC:=gcp-poc-1=10.160.152.11,gcp-poc-2=10.160.152.12,gcp-poc-3=10.160.152.13,gcp-poc-4=10.160.152.14,gcp-poc-5=10.160.152.15}"
else
  : "${GCP_HOSTS_SPEC:=gcp-poc-1=12211,gcp-poc-2=12212,gcp-poc-3=12213,gcp-poc-4=12214,gcp-poc-5=12215}"
fi

: "${TPCC_ARTIFACTS:=/tmp/poc-tpcc/artifacts/$RESULT_SCOPE}"
ROOT="$TPCC_ARTIFACTS/$ROOT_SUFFIX"
GATE_DIR="$ROOT/gate"
RAW_DIR="$GATE_DIR/raw"
mkdir -p "$RAW_DIR"

OUT_TXT="$GATE_DIR/chrony-cross-region.txt"
OUT_MD="$GATE_DIR/chrony-cross-region-all10.md"
DONE_JSON="$ROOT/.gate-chrony.done"
TSV="$GATE_DIR/.records.tsv"
: > "$TSV"

probe() {
  local region=$1 label=$2; shift 2
  local out="$RAW_DIR/${label}.txt"
  "$@" "chronyc tracking" > "$out" 2>/dev/null || true
  local STR OFF LEAP REFID
  STR=$(awk '/^Stratum/ {print $3; exit}' "$out")
  OFF=$(awk '/^Last offset/ {gsub(/[+s,]/,"",$4); print $4; exit}' "$out")
  LEAP=$(awk -F': +' '/^Leap status/ {print $2; exit}' "$out")
  REFID=$(awk -F': +' '/^Reference ID/ {print $2; exit}' "$out")
  printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$region" "$label" "${STR:-}" "${OFF:-}" "${LEAP:-}" "${REFID:-}" >> "$TSV"
}

IFS=',' read -ra IDC_ENTRIES <<< "$IDC_HOSTS_SPEC"
for entry in "${IDC_ENTRIES[@]}"; do
  label="${entry%%=*}"; addr="${entry#*=}"
  probe IDC "$label" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "$addr"
done

IFS=',' read -ra GCP_ENTRIES <<< "$GCP_HOSTS_SPEC"
for entry in "${GCP_ENTRIES[@]}"; do
  label="${entry%%=*}"; target="${entry#*=}"
  if [[ "${GCP_VIA_31}" == "1" ]]; then
    # ProxyJump via .31 → GCP direct IP (no IAP tunnel needed)
    probe GCP "$label" ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
      -o ProxyJump="root@172.24.40.31" "${GCP_SSH_USER}@${target}"
  else
    # Legacy IAP: target = port number, connect to localhost
    probe GCP "$label" ssh -i "$GCP_SSH_KEY" -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new \
      -p "$target" "${GCP_SSH_USER}@localhost"
  fi
done

python3 - "$TSV" "$OUT_TXT" "$OUT_MD" "$DONE_JSON" "$TS" "$CHRONY_DRIFT_MS_MAX" "$CHRONY_DRIFT_MS_WORST_MAX" <<'PY' || exit 1
import sys, json, statistics
tsv, out_txt, out_md, done_json, ts, mx, wmx = sys.argv[1:]
mx=float(mx); wmx=float(wmx)
recs={'IDC':[], 'GCP':[]}
anomalies=[]  # label,reason
with open(tsv) as f:
    for line in f:
        p=line.rstrip('\n').split('\t')
        if len(p) < 6:
            continue
        region,label,stratum,off,leap,refid=p
        if not off:
            anomalies.append((label, 'chronyc unreadable / Last offset missing'))
            recs[region].append((label, None, leap, stratum, refid))
            continue
        if leap != 'Normal':
            anomalies.append((label, f'Leap status = {leap or "(empty)"}'))
        try:
            off_ms = float(off)*1000.0
        except ValueError:
            anomalies.append((label, f'cannot parse offset: {off}'))
            off_ms = None
        recs[region].append((label, off_ms, leap, stratum, refid))

def region_stats(rows):
    abs_off=[abs(o) for _,o,_,_,_ in rows if o is not None]
    if not abs_off: return None
    return {
        'n': len(abs_off),
        'mean': statistics.mean(abs_off),
        'median': statistics.median(abs_off),
        'max': max(abs_off),
        'min': min(abs_off),
        'stdev': statistics.pstdev(abs_off) if len(abs_off)>1 else 0.0,
    }

idc_stat = region_stats(recs['IDC'])
gcp_stat = region_stats(recs['GCP'])

drift = {}
if idc_stat and gcp_stat:
    drift['median'] = idc_stat['median'] + gcp_stat['median']
    drift['mean']   = idc_stat['mean']   + gcp_stat['mean']
    drift['worst']  = idc_stat['max']    + gcp_stat['max']
    drift['best']   = idc_stat['min']    + gcp_stat['min']

verdict='PASS'
fail_reasons=[]
if not (idc_stat and gcp_stat):
    verdict='FAIL'; fail_reasons.append('insufficient samples (region missing all chronyc data)')
if anomalies:
    verdict='FAIL'
    for label,reason in anomalies:
        fail_reasons.append(f'host {label}: {reason}')
if drift:
    if drift['median'] >= mx:
        verdict='FAIL'; fail_reasons.append(f'drift_median {drift["median"]:.3f}ms >= {mx}ms')
    if drift['worst'] >= wmx:
        verdict='FAIL'; fail_reasons.append(f'drift_worst {drift["worst"]:.3f}ms >= {wmx}ms')

# --- Write OUT_TXT (legacy-compatible) ---
with open(out_txt,'w') as f:
    f.write(f"=== gate-chrony-cross-region.sh  ts={ts}  threshold_median_ms={mx}  threshold_worst_ms={wmx} ===\n\n")
    for region in ('IDC','GCP'):
        f.write(f"--- {region} hosts ---\n")
        for label,off,leap,stratum,refid in recs[region]:
            off_s = f"{off:+.6f} ms" if off is not None else "(no data)"
            f.write(f"  {label:<14} stratum={stratum or '?':<3} leap={leap or '?':<18} last_offset={off_s:<18} refid={refid or '?'}\n")
        f.write('\n')
    f.write("----- parsed -----\n")
    if idc_stat:
        f.write(f"idc_n={idc_stat['n']} idc_median_ms={idc_stat['median']:.6f} idc_mean_ms={idc_stat['mean']:.6f} idc_max_ms={idc_stat['max']:.6f} idc_min_ms={idc_stat['min']:.6f}\n")
    if gcp_stat:
        f.write(f"gcp_n={gcp_stat['n']} gcp_median_ms={gcp_stat['median']:.6f} gcp_mean_ms={gcp_stat['mean']:.6f} gcp_max_ms={gcp_stat['max']:.6f} gcp_min_ms={gcp_stat['min']:.6f}\n")
    if drift:
        f.write(f"cross_region_drift_median_ms={drift['median']:.6f}\n")
        f.write(f"cross_region_drift_mean_ms={drift['mean']:.6f}\n")
        f.write(f"cross_region_drift_worst_ms={drift['worst']:.6f}\n")
    f.write(f"threshold_ms={mx}\n")
    f.write(f"threshold_worst_ms={wmx}\n")
    if fail_reasons:
        f.write("fail_reasons:\n")
        for r in fail_reasons: f.write(f"  - {r}\n")
    f.write(f"verdict={verdict}\n")

# --- Write OUT_MD ---
with open(out_md,'w') as f:
    f.write(f"# chrony cross-region drift gate — 10 hosts\nTS: {ts}  median_threshold: {mx} ms  worst_threshold: {wmx} ms\n\n")
    f.write("## Per-host\n| Region | Label | Stratum | Last offset (ms) | Leap | Reference ID |\n|---|---|---|---|---|---|\n")
    for region in ('IDC','GCP'):
        for label,off,leap,stratum,refid in recs[region]:
            off_s = f"{off:+.6f}" if off is not None else "—"
            f.write(f"| {region} | {label} | {stratum or '?'} | {off_s} | {leap or '?'} | {refid or '?'} |\n")
    f.write("\n## Per-region |Last offset| (ms) stats\n```\n")
    for region,stat in (('IDC',idc_stat),('GCP',gcp_stat)):
        if stat:
            f.write(f"{region}  n={stat['n']}  mean={stat['mean']:.6f}  median={stat['median']:.6f}  max={stat['max']:.6f}  min={stat['min']:.6f}  stdev={stat['stdev']:.6f}\n")
    if drift:
        f.write(f"\ndrift_median_ms = {drift['median']:.6f}\ndrift_mean_ms   = {drift['mean']:.6f}\ndrift_worst_ms  = {drift['worst']:.6f}\ndrift_best_ms   = {drift['best']:.6f}\n")
    f.write("```\n\n")
    if fail_reasons:
        f.write("## Fail reasons\n")
        for r in fail_reasons: f.write(f"- {r}\n")
        f.write("\n")
    f.write(f"verdict={verdict}\n")

# --- Write DONE_JSON ---
done = {
    'phase': 'gate-chrony',
    'ts': ts,
    'verdict': verdict,
    'thresholds': {'median_ms': mx, 'worst_ms': wmx},
    'drift': drift,
    'idc': idc_stat,
    'gcp': gcp_stat,
    'leap_anomalies': [{'label':l, 'reason':r} for l,r in anomalies],
    'fail_reasons': fail_reasons,
}
with open(done_json,'w') as f:
    json.dump(done, f, indent=2, sort_keys=True)

print(f"verdict={verdict}", file=sys.stderr)
sys.exit(0 if verdict=='PASS' else 1)
PY
RC=$?

rm -f "$TSV"

if [[ $RC -eq 0 ]]; then
  echo "[gate-chrony-cross-region] PASS"
  exit 0
else
  echo "[gate-chrony-cross-region] FAIL — see $OUT_TXT" >&2
  exit 1
fi
