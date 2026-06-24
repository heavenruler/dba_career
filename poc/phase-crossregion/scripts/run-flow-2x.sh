#!/usr/bin/env bash
# run-flow-2x.sh — Path C Step 1 stability harness (Agent-a4)
# Usage: run-flow-2x.sh [--dry-run] [--skip-destroy] [--once]
set -euo pipefail

# ─── constants ────────────────────────────────────────────────────────────────
WAREHOUSES=4
RUN_SEC=300
WARMUP_SEC=300
ROUNDS=5
THREADS_LIST=16
RESULT_BASE="results/x-cross/run-flow-2x"
MAKEFILE_DIR="$(cd "$(dirname "$0")/../../" && pwd)"  # poc/

# ─── flags ────────────────────────────────────────────────────────────────────
DRY_RUN=0
SKIP_DESTROY=0
ONCE=0

for arg in "$@"; do
  case $arg in
    --dry-run)      DRY_RUN=1 ;;
    --skip-destroy) SKIP_DESTROY=1 ;;
    --once)         ONCE=1 ;;
    *) echo "[WARN] unknown arg: $arg" ;;
  esac
done

# timestamps generated once (separate to guarantee different values)
TS_RUN1="run1-$(date +%Y%m%dT%H%M%S%z)"
sleep 1
TS_RUN2="run2-$(date +%Y%m%dT%H%M%S%z)"

# ─── helpers ──────────────────────────────────────────────────────────────────
log() { echo "[$(date +%H:%M:%S)] $*"; }

run() {
  local label="$1"; shift
  local logfile="$1"; shift
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] make $* (log → $logfile)"
    return 0
  fi
  mkdir -p "$(dirname "$logfile")"
  log ">>> $label"
  if ! make -C "$MAKEFILE_DIR" "$@" 2>&1 | tee "$logfile"; then
    log "!!! FAILED: $label"
    log "--- last 50 lines of $logfile ---"
    tail -50 "$logfile" || true
    cleanup_residue
    exit 1
  fi
  log "<<< OK: $label"
}

# check if a make target exists; return 0 if yes
target_exists() {
  make -C "$MAKEFILE_DIR" -n "$1" &>/dev/null
}

# resolve target: prefer -safe variant, fall back to original
safe_target() {
  local base="$1"
  local safe="${base}-safe"
  if target_exists "$safe"; then
    echo "$safe"
  else
    echo "[WARN] target $safe not found; falling back to $base" >&2
    echo "$base"
  fi
}

cleanup_residue() {
  if [[ "${KEEP_ON_FAIL:-0}" = "1" ]]; then
    log "==> KEEP_ON_FAIL=1 → skip phase9-destroy (cluster kept for debugging)"
    return 0
  fi
  log "==> cleanup: attempting phase9-destroy (set KEEP_ON_FAIL=1 to skip)"
  make -C "$MAKEFILE_DIR" phase9-destroy 2>/dev/null || true
}

# ─── CV calculator (inline python3) ───────────────────────────────────────────
calc_cv() {
  local log_dir="$1"   # run-N-<ts>/ dir on local results
  local out_json="$2"  # destination json
  python3 - "$log_dir" "$out_json" <<'PYEOF'
import json, statistics, sys, re, glob, os

log_dir = sys.argv[1]
out_json = sys.argv[2]

def parse_tpmc(path):
    """Extract tpmC value from go-tpc stdout log."""
    tpmc_list = []
    if not os.path.exists(path):
        return tpmc_list
    with open(path) as f:
        for line in f:
            # match: "tpmC: 1234.56" or "[Summary] ... tpmC = 1234.56"
            m = re.search(r'tpmC[\s=:]+([0-9]+(?:\.[0-9]+)?)', line, re.IGNORECASE)
            if m:
                tpmc_list.append(float(m.group(1)))
    return tpmc_list

results = {}
for db in ('tidb', 'ybdb', 'crdb'):
    # locate round logs: threads-16/round-*/go-tpc-stdout.txt
    pattern = os.path.join(log_dir, '**', f'*{db}*', 'threads-16', 'round-*', 'go-tpc-stdout.txt')
    alt_pattern = os.path.join(log_dir, '**', f'threads-16', 'round-*', 'go-tpc-stdout.txt')
    files = sorted(glob.glob(pattern, recursive=True)) or sorted(glob.glob(alt_pattern, recursive=True))

    # also try smoke log captured by this script
    smoke_log = os.path.join(log_dir, f'phase-{db}-smoke.log')
    if not files and os.path.exists(smoke_log):
        files = [smoke_log]

    rounds_tpmc = {}
    for f in files:
        m = re.search(r'round-(\d+)', f)
        rnd = int(m.group(1)) if m else 0
        vals = parse_tpmc(f)
        if vals:
            rounds_tpmc[rnd] = vals[-1]  # last tpmC line per round

    # discard R1 (warmup round), use R2-R5
    keep = [v for k, v in sorted(rounds_tpmc.items()) if k >= 2]
    if len(keep) < 2:
        results[db] = {'error': 'insufficient rounds', 'rounds': rounds_tpmc}
        continue
    mean  = statistics.mean(keep)
    stdev = statistics.pstdev(keep)
    cv    = stdev / mean if mean else 0
    median = statistics.median(keep)
    results[db] = {
        'rounds_tpmc': rounds_tpmc,
        'mean': round(mean, 2),
        'stdev': round(stdev, 2),
        'cv': round(cv, 4),
        'median': round(median, 2),
        'pass_cv': cv < 0.10,
    }
    print(f"  {db:6s}  mean={mean:8.1f}  stdev={stdev:7.1f}  CV={cv:.2%}  median={median:.1f}  {'PASS' if cv<0.10 else 'FAIL-CV'}")

os.makedirs(os.path.dirname(out_json) or '.', exist_ok=True)
with open(out_json, 'w') as f:
    json.dump(results, f, indent=2)
print(f"  => {out_json}")
PYEOF
}

# ─── comparison report ────────────────────────────────────────────────────────
compare_runs() {
  local json1="$1"
  local json2="$2"
  local out_md="$3"
  python3 - "$json1" "$json2" "$out_md" <<'PYEOF'
import json, sys, os

j1 = json.load(open(sys.argv[1]))
j2 = json.load(open(sys.argv[2]))
out = sys.argv[3]

lines = ["# run-flow-2x comparison", ""]
lines.append("| DB | run1 mean | run1 CV | run2 mean | run2 CV | cross-run delta | verdict |")
lines.append("|---|---|---|---|---|---|---|")

all_pass = True
for db in ('tidb', 'ybdb', 'crdb'):
    r1 = j1.get(db, {})
    r2 = j2.get(db, {})
    if 'error' in r1 or 'error' in r2:
        lines.append(f"| {db} | ERR | ERR | ERR | ERR | ERR | FAIL |")
        all_pass = False
        continue
    m1, m2 = r1['mean'], r2['mean']
    cv1, cv2 = r1['cv'], r2['cv']
    delta = abs(m1 - m2) / max(m1, m2) if max(m1, m2) else 1
    pass_cv   = cv1 < 0.10 and cv2 < 0.10
    pass_delta = delta < 0.10
    verdict = "PASS" if (pass_cv and pass_delta) else "FAIL"
    if verdict == "FAIL":
        all_pass = False
    lines.append(f"| {db} | {m1:.1f} | {cv1:.2%} | {m2:.1f} | {cv2:.2%} | {delta:.2%} | {verdict} |")

lines.append("")
lines.append(f"**Overall: {'DETERMINISTIC (PASS)' if all_pass else 'NON-DETERMINISTIC (FAIL)'}**")
lines.append("")
lines.append("Thresholds: within-run CV < 10%, cross-run delta < 10%")

text = "\n".join(lines)
print(text)
os.makedirs(os.path.dirname(out) or '.', exist_ok=True)
with open(out, 'w') as f:
    f.write(text + "\n")
print(f"\n=> {out}")
PYEOF
}

# ─── target resolution ────────────────────────────────────────────────────────
T_PREFLIGHT="$(safe_target phase0-preflight 2>/dev/null || echo phase0-preflight)"
T_PREFLIGHT_FIX="$(safe_target phase0-preflight-fix 2>/dev/null || echo phase0-preflight-fix)"
T_DESTROY="phase9-destroy"
T_P1_APPLY="$(safe_target phase1-apply)"
T_P1_WAIT="$(safe_target phase1-wait)"
T_P2_DNS="$(safe_target phase2-dns-fix)"
T_P2_SSH="$(safe_target phase2-ssh-prime)"
T_P2="$(safe_target phase2-bootstrap)"
T_P1_WAIT_VIA31="$(safe_target phase1-wait-via-31)"
T_P3="$(safe_target phase3-tidb-deploy)"
T_P4="$(safe_target phase4-ybdb-deploy)"
T_P4F="$(safe_target phase4-ybdb-fix6n)"
T_P5="$(safe_target phase5-crdb-deploy)"
T_P6="$(safe_target phase6-tidb-smoke)"
T_P7="$(safe_target phase7-ybdb-smoke)"
T_P8="$(safe_target phase8-crdb-smoke)"
T_P85="$(safe_target phase8.5-fetch)"

# ─── smoke runner ─────────────────────────────────────────────────────────────
# Sets global LAST_CV_JSON after each call (avoids subshell stdout pollution)
LAST_CV_JSON=""

run_smoke_and_cv() {
  local run_label="$1"   # run1 or run2
  local ts="$2"
  local rundir="${RESULT_BASE}/${ts}"

  # Serial chain per user spec: deploy → smoke → cleanup (Makefile prereq) → next DB
  # Reasoning: TiDB tiup deploys node_exporter:9100 → blocks YBDB tserver RPC.
  #            YBDB resources may conflict with CRDB scheduling.
  #            => Each DB gets exclusive cluster, smoke immediately, then cleanup
  #            before the next DB's deploy phase pulls the cleanup as a prereq.

  log "=== $run_label: TiDB deploy → smoke ==="
  run "$run_label phase3-tidb-deploy" "$rundir/phase3-tidb-deploy.log" "$T_P3" TPCC_TS="$ts"
  run "$run_label phase6-tidb-smoke"  "$rundir/phase6-tidb-smoke.log" \
    "$T_P6" TPCC_TS="$ts" WAREHOUSES=$WAREHOUSES RUN_SEC=$RUN_SEC \
    WARMUP_SEC=$WARMUP_SEC ROUNDS=$ROUNDS THREADS_LIST=$THREADS_LIST

  log "=== $run_label: YBDB deploy (auto cleanup-tidb prereq) → fix6n → smoke ==="
  run "$run_label phase4-ybdb-deploy" "$rundir/phase4-ybdb-deploy.log" "$T_P4" TPCC_TS="$ts"
  run "$run_label phase4-ybdb-fix6n"  "$rundir/phase4-ybdb-fix6n.log"  "$T_P4F" TPCC_TS="$ts"
  run "$run_label phase7-ybdb-smoke"  "$rundir/phase7-ybdb-smoke.log" \
    "$T_P7" TPCC_TS="$ts" WAREHOUSES=$WAREHOUSES RUN_SEC=$RUN_SEC \
    WARMUP_SEC=$WARMUP_SEC ROUNDS=$ROUNDS THREADS_LIST=$THREADS_LIST

  log "=== $run_label: CRDB deploy (auto cleanup-ybdb prereq) → smoke ==="
  run "$run_label phase5-crdb-deploy" "$rundir/phase5-crdb-deploy.log" "$T_P5" TPCC_TS="$ts"
  run "$run_label phase8-crdb-smoke"  "$rundir/phase8-crdb-smoke.log" \
    "$T_P8" TPCC_TS="$ts" WAREHOUSES=$WAREHOUSES RUN_SEC=$RUN_SEC \
    WARMUP_SEC=$WARMUP_SEC ROUNDS=$ROUNDS THREADS_LIST=$THREADS_LIST

  log "=== $run_label: fetch artifacts ==="
  run "$run_label fetch artifacts" "$rundir/phase8.5-fetch.log" \
    "$T_P85" TPCC_TS="$ts"

  log "=== $run_label: calculating CV ==="
  local fetched_dir="${MAKEFILE_DIR}/results/x-cross/${ts}"
  local cv_json="${rundir}/cv-report.json"
  if [[ $DRY_RUN -eq 1 ]]; then
    log "[DRY-RUN] calc_cv $fetched_dir -> $cv_json"
  else
    calc_cv "$fetched_dir" "$cv_json"
  fi
  LAST_CV_JSON="$cv_json"
}

# ─── main ─────────────────────────────────────────────────────────────────────
log "=== run-flow-2x.sh start | DRY_RUN=$DRY_RUN SKIP_DESTROY=$SKIP_DESTROY ONCE=$ONCE ==="
[[ $DRY_RUN -eq 1 ]] && log "[DRY-RUN mode — no make commands executed]"

# Step 0: preflight
log "--- Step 0: preflight ---"
if ! make -C "$MAKEFILE_DIR" -n "$T_PREFLIGHT" &>/dev/null; then
  log "[WARN] target $T_PREFLIGHT not found; skipping preflight"
elif [[ $DRY_RUN -eq 0 ]]; then
  if ! make -C "$MAKEFILE_DIR" "$T_PREFLIGHT" 2>&1; then
    log "preflight failed; attempting $T_PREFLIGHT_FIX"
    make -C "$MAKEFILE_DIR" "$T_PREFLIGHT_FIX" 2>&1 || true
    make -C "$MAKEFILE_DIR" "$T_PREFLIGHT" 2>&1 || { log "preflight still failing; abort"; exit 1; }
  fi
fi

# Step 1: optional destroy existing cluster
if [[ $SKIP_DESTROY -eq 0 ]]; then
  log "--- Step 1: destroy existing cluster (if any) ---"
  if [[ $DRY_RUN -eq 1 ]]; then
    echo "[DRY-RUN] make $T_DESTROY"
  else
    make -C "$MAKEFILE_DIR" "$T_DESTROY" 2>/dev/null || log "[INFO] destroy exited non-zero (cluster may not exist); continuing"
  fi
fi

# Step 2: provision cluster
log "--- Step 2: provision cluster ---"
run "phase1-apply"      "${RESULT_BASE}/${TS_RUN1}/phase1-apply.log"     "$T_P1_APPLY"     TPCC_TS="$TS_RUN1"
run "phase1-wait"       "${RESULT_BASE}/${TS_RUN1}/phase1-wait.log"      "$T_P1_WAIT"      TPCC_TS="$TS_RUN1"
run "phase2-dns-fix"    "${RESULT_BASE}/${TS_RUN1}/phase2-dns-fix.log"   "$T_P2_DNS"       TPCC_TS="$TS_RUN1"
run "phase2-ssh-prime"  "${RESULT_BASE}/${TS_RUN1}/phase2-ssh-prime.log" "$T_P2_SSH"       TPCC_TS="$TS_RUN1"
run "phase1-wait-via-31" "${RESULT_BASE}/${TS_RUN1}/phase1-wait-via-31.log" "$T_P1_WAIT_VIA31" TPCC_TS="$TS_RUN1"
run "phase2-bootstrap"  "${RESULT_BASE}/${TS_RUN1}/phase2-bootstrap.log" "$T_P2"           TPCC_TS="$TS_RUN1"

# Step 3: run-1
log "--- Step 3: run-1 ---"
run_smoke_and_cv run1 "$TS_RUN1"
CV1_JSON="$LAST_CV_JSON"

if [[ $ONCE -eq 1 ]]; then
  log "=== --once: skipping run-2 ==="
  log "run-flow-2x.sh done (single run). CV report: $CV1_JSON"
  exit 0
fi

# Step 4: run-2 (same cluster, redeploy)
log "--- Step 4: run-2 (same cluster, redeploy) ---"
run_smoke_and_cv run2 "$TS_RUN2"
CV2_JSON="$LAST_CV_JSON"

# Step 5: compare
log "--- Step 5: cross-run comparison ---"
COMPARE_MD="${RESULT_BASE}/comparison.md"
if [[ $DRY_RUN -eq 1 ]]; then
  log "[DRY-RUN] compare $CV1_JSON vs $CV2_JSON -> $COMPARE_MD"
else
  compare_runs "$CV1_JSON" "$CV2_JSON" "$COMPARE_MD"
fi

log "=== run-flow-2x.sh COMPLETE ==="
log "  run1 cv:    $CV1_JSON"
log "  run2 cv:    $CV2_JSON"
log "  comparison: $COMPARE_MD"
