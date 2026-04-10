#!/usr/bin/env python3
"""
Cross-line scenario performance difference: TiDB IDC vs GCP (Label Isolation Set) multi_thread_multi_conn RPS
Sources: #7-1.py (IDC TiDB), #7-3.py (GCP TiDB)
PNG labels English only; console SUMMARY Traditional Chinese.
"""
from __future__ import annotations
import matplotlib.pyplot as plt
import numpy as np

# Extracted RPS data (threads -> RPS) from #7-1.py and #7-3.py
IDC_TIDB = {1:649.56,100:3331.77,200:4624.85,250:3044.57,500:3282.37,750:2473.37,1000:1805.21}
GCP_TIDB = {1:868.92,100:2823.05,200:5325.85,250:2616.31,500:4291.31,750:1954.34,1000:3163.21}
THREADS = [1,100,200,250,500,750,1000]
PNG_NAME = "#7-1_#7-3_crossline_compare.png"

def pct(new: float, old: float) -> float:
    if old == 0: return 0.0
    return (new/old - 1.0)*100.0

def make_plot():
    x = np.arange(len(THREADS))
    width = 0.4
    idc_vals = [IDC_TIDB[t] for t in THREADS]
    gcp_vals = [GCP_TIDB[t] for t in THREADS]
    fig, ax = plt.subplots(figsize=(10,4.8))
    b1 = ax.bar(x - width/2, idc_vals, width, label='IDC', color='#4f81bd')
    b2 = ax.bar(x + width/2, gcp_vals, width, label='GCP', color='#c0504d')
    ax.set_title('TiDB RPS: IDC vs GCP (#7 cross-line)')
    ax.set_xlabel('Threads')
    ax.set_ylabel('RPS')
    ax.set_xticks(x, THREADS)
    ax.legend()
    diffs = []
    for r_idc, r_gcp, vi, vg in zip(b1, b2, idc_vals, gcp_vals):
        d = pct(vg, vi)
        diffs.append(d)
        ax.text(r_idc.get_x()+r_idc.get_width()/2, vi, f"{vi:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        ax.text(r_gcp.get_x()+r_gcp.get_width()/2, vg, f"{vg:,.0f}\n{d:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')
    max_i = int(np.argmax(diffs))
    min_i = int(np.argmin(diffs))
    ax.annotate('Max Gain', xy=(x[max_i]+width/2, gcp_vals[max_i]), xytext=(0,30), textcoords='offset points', ha='center', arrowprops=dict(arrowstyle='->'))
    ax.annotate('Worst Drop', xy=(x[min_i]+width/2, gcp_vals[min_i]), xytext=(0,30), textcoords='offset points', ha='center', arrowprops=dict(arrowstyle='->'))
    fig.tight_layout()
    plt.savefig(PNG_NAME, dpi=150)
    print(f"Saved {PNG_NAME}")


def summarize():
    diffs = {t: pct(GCP_TIDB[t], IDC_TIDB[t]) for t in THREADS}
    max_t = max(diffs, key=lambda k: diffs[k])
    min_t = min(diffs, key=lambda k: diffs[k])
    lines = []
    lines.append(f"最大正向差異 (GCP 相對 IDC) 出現在 {max_t} threads: {diffs[max_t]:+.1f}%")
    lines.append(f"最大負向差異 出現在 {min_t} threads: {diffs[min_t]:+.1f}%")
    # Characterize patterns
    lines.append(f"GCP 對 IDC 顯著增益的區段：200 (+{diffs[200]:.1f}%), 500 (+{diffs[500]:.1f}%), 1000 (+{diffs[1000]:.1f}%).")
    lines.append(f"GCP 退化 / 表現不佳區段：250 ({diffs[250]:+.1f}%), 750 ({diffs[750]:+.1f}%).")
    lines.append("研判: 200 / 500 threads 於 GCP 可更有效利用資源 (CPU / I/O pipeline)，750 threads 產生負壓可能源自排程或 hotspot。")
    lines.append("建議: GCP 負載壓測以 200 / 500 作主要 sweet spots；調查 750 thread 降幅 (region balance、transaction lock、網路 jitter)。")
    summary = '\n'.join(lines)
    print('\n[SUMMARY]\n' + summary)
    return summary


def main():
    make_plot()
    summarize()

if __name__ == '__main__':
    main()
