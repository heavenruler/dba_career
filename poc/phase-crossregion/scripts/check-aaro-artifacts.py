#!/usr/bin/env python3
# phase-crossregion/scripts/check-aaro-artifacts.py
# Artifact schema check for A-A-RO/A-A suites on .31 (fail-closed).
#
# 與 check-static-artifacts.py 分開的原因：aaro/aa suite 用 ANCHOR_ONLY 產生
# 的 anchor 目錄本身「沒有」runs/ 或 probe json（設計如此，見 win-aaro-w128.sh
# 的 ANCHOR_ONLY 說明），check-static-artifacts.py 的 4 檔位斷言會誤判 anchor
# 目錄失敗；且 aaro suite 的 GCP 側是直呼 go-tpc（go-tpc-stdout-gcp.txt），
# 沒有 near-read probe json（read-only workload 本身就是真流量，非探測）。
#
# Usage: python3 check-aaro-artifacts.py <aaro_suite_dir>
import json, os, sys, glob, re

d = sys.argv[1]
fails = []

sj = os.path.join(d, 'summary.json')
if not os.path.exists(sj):
    print(f'  FAIL: summary.json missing at {d}')
    sys.exit(1)

j = json.load(open(sj))
gcp = j.get('gcp_side')
if not gcp:
    fails.append('summary.json 缺 gcp_side 頂層區塊（G2 未注入）')
else:
    if gcp.get('profile') not in ('A-A-RO', 'A-A'):
        fails.append(f'gcp_side.profile 非預期值：{gcp.get("profile")}')
    tr = gcp.get('thread_results', {})
    if not tr:
        fails.append('gcp_side.thread_results 為空')
    for t, r in tr.items():
        if gcp.get('profile') == 'A-A-RO' and r.get('tpmC_mean') is not None:
            fails.append(f'threads={t}: A-A-RO 的 gcp_side tpmC_mean 應為 null（G2），實際={r.get("tpmC_mean")}')
        if r.get('read_tpmTotal_mean') is None:
            fails.append(f'threads={t}: gcp_side.read_tpmTotal_mean 缺值')

idc_tr = j.get('thread_results', {})
if not idc_tr:
    fails.append('IDC 側 thread_results 為空')

for t in idc_tr:
    for side, pat in (('idc', 'go-tpc-stdout.txt'), ('gcp', 'go-tpc-stdout-gcp.txt')):
        rounds = glob.glob(os.path.join(d, 'runs', f'threads-{t}', 'round-*', pat))
        if not rounds:
            fails.append(f'threads={t} side={side}: 無 {pat}（runs/threads-{t}/round-*/）')
            continue
        for f in rounds:
            txt = open(f, errors='replace').read()
            if not re.search(r'\[Summary\]|tpmC:', txt):
                fails.append(f'{os.path.relpath(f, d)}: 無 [Summary]/tpmC 行（工具本身失效，非量到零）')

if fails:
    for f in fails:
        print(f'  FAIL: {f}')
    sys.exit(1)
print(f'  PASS: aaro/aa suite schema-checked ({d})')
