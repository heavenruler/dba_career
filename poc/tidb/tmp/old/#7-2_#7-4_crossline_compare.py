#!/usr/bin/env python3
"""
Cross-line scenario performance difference: TiProxy IDC vs GCP (Label Isolation Set) multi_thread_multi_conn RPS
Sources: #7-2.py (IDC TiProxy), #7-4.py (GCP TiProxy)
PNG labels English only; console SUMMARY Traditional Chinese.
"""
from __future__ import annotations
import matplotlib.pyplot as plt
import numpy as np

IDC_TIPX = {1:498.98,100:2816.72,200:3179.19,250:2865.28,500:2953.45,750:2297.84,1000:2561.23}
GCP_TIPX = {1:581.31,100:2520.97,200:3682.57,250:2351.49,500:3185.46,750:1781.75,1000:2557.00}
THREADS = [1,100,200,250,500,750,1000]
PNG_NAME = "#7-2_#7-4_crossline_compare.png"

def pct(new: float, old: float) -> float:
    if old == 0: return 0.0
    return (new/old - 1.0)*100.0

def make_plot():
    x = np.arange(len(THREADS))
    width = 0.4
    idc_vals = [IDC_TIPX[t] for t in THREADS]
    gcp_vals = [GCP_TIPX[t] for t in THREADS]
    fig, ax = plt.subplots(figsize=(10,4.8))
    b1 = ax.bar(x - width/2, idc_vals, width, label='IDC', color='#4f81bd')
    b2 = ax.bar(x + width/2, gcp_vals, width, label='GCP', color='#c0504d')
    ax.set_title('TiProxy RPS: IDC vs GCP (#7 cross-line)')
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
    diffs = {t: pct(GCP_TIPX[t], IDC_TIPX[t]) for t in THREADS}
    max_t = max(diffs, key=lambda k: diffs[k])
    min_t = min(diffs, key=lambda k: diffs[k])
    lines = []
    lines.append(f"最大正向差異 (GCP 相對 IDC) 出現在 {max_t} threads: {diffs[max_t]:+.1f}%")
    lines.append(f"最大負向差異 出現在 {min_t} threads: {diffs[min_t]:+.1f}%")
    lines.append(f"GCP TiProxy 在 1 / 200 / 500 threads 有增益 (1 {diffs[1]:+.1f}%, 200 {diffs[200]:+.1f}%, 500 {diffs[500]:+.1f}%).")
    lines.append(f"GCP 顯著退化在 100 / 250 / 750 threads (100 {diffs[100]:+.1f}%, 250 {diffs[250]:+.1f}%, 750 {diffs[750]:+.1f}%).")
    lines.append("推測: 高延遲跨線路下連線池熱化與路由決策對中併發敏感，造成波動；低 / 部分高併發點 (1 / 200 / 500) 仍能受益。")
    lines.append("建議: 針對 100~250 / 750 threads 收集 proxy scheduler、backend latency、connection reuse metrics，調整路由與 batch 策略。")
    summary = '\n'.join(lines)
    print('\n[SUMMARY]\n' + summary)
    return summary


def main():
    make_plot()
    summarize()

if __name__ == '__main__':
    main()
