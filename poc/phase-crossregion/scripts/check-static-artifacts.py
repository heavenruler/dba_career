#!/usr/bin/env python3
# phase-crossregion/scripts/check-static-artifacts.py
# Artifact schema check on .31 before fetch (phase8.5-static-check).
# Usage: python3 check-static-artifacts.py <artifact_base_dir> [--ts <TPCC_TS>]
#   --ts: 只檢查目錄名含該 TS 的 suite（避免字典序 sorted()[-1] 挑到
#         歷史 run（如 *-run1-20260622*）而非本輪；per-cell gate 必帶）。
# Dry-run-only 目錄（有 .dry-run.done、無 runs/）不是 suite，跳過不檢。
import os, glob, sys

args = list(sys.argv[1:])
ts = None
if '--ts' in args:
    i = args.index('--ts')
    ts = args[i + 1]
    del args[i:i + 2]
base = args[0]

fails = []
dbs = ['tidb', 'crdb', 'ybdb']
checked = 0
skipped_dryrun = 0
for db in dbs:
    dirs = glob.glob(os.path.join(base, f'{db}-vm-6node-*'))
    if ts:
        dirs = [d for d in dirs if ts in os.path.basename(d)]
    real = []
    for d in dirs:
        if os.path.exists(os.path.join(d, '.dry-run.done')) and \
           not os.path.isdir(os.path.join(d, 'runs')):
            skipped_dryrun += 1
            continue
        real.append(d)
    if not real:
        continue  # not yet run; per-cell gate skips absent cells
    checked += 1
    # 無 --ts 時取 mtime 最新（不可用字典序：'run1-2026...' 會排在 '2026...' 後）
    d = max(real, key=os.path.getmtime)
    label = os.path.basename(d)
    if not os.path.exists(os.path.join(d, '.suite.done')):
        fails.append(f'{label}: .suite.done missing')
    sj = os.path.join(d, 'summary.json')
    if not os.path.exists(sj):
        fails.append(f'{label}: summary.json missing')
    else:
        txt = open(sj).read()
        for kw in ('fake', 'speculative'):
            if kw in txt.lower():
                fails.append(f'{label}: summary.json contains forbidden keyword "{kw}"')
    # TiDB 的 prepare.sh 寫 .json（結構化 verdict）+ .txt；CRDB 只寫 .txt（原始
    # SHOW RANGES 輸出，無結構化 verdict）— DB 分支本身的既有實作差異（prepare.sh
    # 屬 tests/common/ 不可改），故兩種副檔名皆接受，只驗證「gate 真的留了證據」。
    gate = glob.glob(os.path.join(d, 'prepare', 'placement-gate-*.json')) or \
           glob.glob(os.path.join(d, 'prepare', 'placement-gate-*.txt'))
    if not gate:
        fails.append(f'{label}: placement-gate artifact missing (prepare/placement-gate-*.{{json,txt}})')
    # GCP 副本存在 gate 證據（2026-07-13 起 run-vm6-suite.sh 必產；缺=gate 沒跑=fail-closed）
    if not glob.glob(os.path.join(d, 'gate', 'gcp-replica-gate-*.txt')):
        fails.append(f'{label}: gcp-replica-gate evidence missing (gate/gcp-replica-gate-*.txt)')
    # GCP 端 near-read probe：w128 首輪四 suite 全 fail_count>0 卻靜默通過 → 斷言 fail-closed。
    # 每 suite 至少要有 1 份 gcp probe json，且全部 select_1.fail_count == 0。
    import json as _json
    probes = glob.glob(os.path.join(d, 'runs', 'threads-*', 'round-*', 'probe-iso-latency-gcp-*.json'))
    if not probes:
        fails.append(f'{label}: no probe-iso-latency-gcp-*.json (GCP-side probe never ran)')
    for p in probes:
        try:
            pd = _json.load(open(p))
            fc = (pd.get('select_1') or {}).get('fail_count')
            if fc is None or fc > 0:
                fails.append(f'{label}: GCP probe fail_count={fc} in {os.path.relpath(p, d)}')
        except Exception as e:
            fails.append(f'{label}: unreadable probe json {os.path.relpath(p, d)} ({e})')

if checked == 0:
    note = f' (skipped {skipped_dryrun} dry-run-only dir(s))' if skipped_dryrun else ''
    print(f'  WARN: no DB suite dirs found under {base}' + (f' for ts={ts}' if ts else '') + note)
    sys.exit(1)
if fails:
    for f in fails:
        print(f'  FAIL: {f}')
    sys.exit(1)
print(f'  PASS: {checked} DB suite(s) schema-checked' + (f' (ts={ts})' if ts else ''))
