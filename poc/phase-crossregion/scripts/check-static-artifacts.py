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
    gate = glob.glob(os.path.join(d, 'prepare', 'placement-gate-*.json'))
    if not gate:
        fails.append(f'{label}: placement-gate artifact missing (prepare/placement-gate-*.json)')

if checked == 0:
    note = f' (skipped {skipped_dryrun} dry-run-only dir(s))' if skipped_dryrun else ''
    print(f'  WARN: no DB suite dirs found under {base}' + (f' for ts={ts}' if ts else '') + note)
    sys.exit(1)
if fails:
    for f in fails:
        print(f'  FAIL: {f}')
    sys.exit(1)
print(f'  PASS: {checked} DB suite(s) schema-checked' + (f' (ts={ts})' if ts else ''))
