#!/usr/bin/env python3
# phase-crossregion/scripts/check-static-artifacts.py
# Artifact schema check on .31 before fetch (phase8.5-static-check).
# Usage: python3 check-static-artifacts.py <artifact_base_dir>
import os, glob, sys

base = sys.argv[1]
fails = []
dbs = ['tidb', 'crdb', 'ybdb']
for db in dbs:
    dirs = glob.glob(os.path.join(base, f'{db}-vm-6node-*'))
    if not dirs:
        fails.append(f'{db}: no artifact dir found')
        continue
    d = sorted(dirs)[-1]
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

if fails:
    for f in fails:
        print(f'  FAIL: {f}')
    sys.exit(1)
print(f'  PASS: {len(dbs)} DB suites schema-checked')
