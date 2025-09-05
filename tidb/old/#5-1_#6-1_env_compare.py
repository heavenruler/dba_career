#!/usr/bin/env python3
"""
TiDB IDC(3-node) vs GCP(3-node) multi_thread_multi_conn RPS comparison.
Plot labels English only; console SUMMARY Traditional Chinese.
Sources: #5-1.py (IDC TiDB), #6-1.py (GCP TiDB)
"""
from __future__ import annotations
import matplotlib.pyplot as plt
import numpy as np

THREADS = [1,100,200,250,500,750,1000]
IDC_TIDB = {1:661.34,100:3788.97,200:7137.34,250:3653.09,500:2428.03,750:2731.68,1000:2869.28}
GCP_TIDB = {1:875.95,100:2995.93,200:7151.47,250:2715.47,500:5408.90,750:1979.18,1000:3254.47}
PNG_NAME = "#5-1_#6-1_env_compare.png"

def pct(new: float, old: float) -> float:
    if old == 0: return 0.0
    return (new/old - 1.0)*100.0

def make_plot():
    x = np.arange(len(THREADS))
    width = 0.4
    idc_vals = [IDC_TIDB[t] for t in THREADS]
    gcp_vals = [GCP_TIDB[t] for t in THREADS]
    fig, ax = plt.subplots(figsize=(10,4.5))
    b1 = ax.bar(x - width/2, idc_vals, width, label='IDC', color='#4f81bd')
    b2 = ax.bar(x + width/2, gcp_vals, width, label='GCP', color='#c0504d')
    ax.set_xticks(x, THREADS)
    ax.set_xlabel('Threads')
    ax.set_ylabel('RPS')
    ax.set_title('TiDB RPS: IDC vs GCP (multi_thread_multi_conn)')
    ax.legend()
    for r_idc, r_gcp, vi, vg, t in zip(b1, b2, idc_vals, gcp_vals, THREADS):
        delta = pct(vg, vi)
        ax.text(r_idc.get_x()+r_idc.get_width()/2, vi, f"{vi:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        ax.text(r_gcp.get_x()+r_gcp.get_width()/2, vg, f"{vg:,.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')
    # annotate max gain & worst drop
    diffs = [pct(GCP_TIDB[t], IDC_TIDB[t]) for t in THREADS]
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
    lines.append("GCP 在 500 threads 顯示明顯優勢 (網路/資源分配較佳)；250 / 750 threads 可能受限排程或熱點。")
    lines.append("建議: 深入檢視 GCP 低/中併發退化點 (250, 750) 的 TiKV 與 PD 指標，確認是否資源搶奪或 region balance 影響。")
    summary = '\n'.join(lines)
    print('\n[SUMMARY]\n'+summary)
    return summary


def main():
    make_plot()
    summarize()

if __name__ == '__main__':
    main()
