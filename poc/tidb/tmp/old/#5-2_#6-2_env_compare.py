#!/usr/bin/env python3
"""
TiProxy IDC(3-node) vs GCP(3-node) multi_thread_multi_conn RPS comparison.
Plot labels English only; console SUMMARY Traditional Chinese.
Sources: #5-2.py (IDC TiProxy), #6-2.py (GCP TiProxy)
"""
from __future__ import annotations
import matplotlib.pyplot as plt
import numpy as np

THREADS = [1,100,200,250,500,750,1000]
IDC_TIPX = {1:384.32,100:5899.92,200:3839.15,250:5693.22,500:3126.86,750:4265.93,1000:3188.79}
GCP_TIPX = {1:583.51,100:2758.88,200:5099.57,250:2539.88,500:4137.94,750:1893.95,1000:3017.88}
PNG_NAME = "#5-2_#6-2_env_compare.png"

def pct(new: float, old: float) -> float:
    if old == 0: return 0.0
    return (new/old - 1.0)*100.0

def make_plot():
    x = np.arange(len(THREADS))
    width = 0.4
    idc_vals = [IDC_TIPX[t] for t in THREADS]
    gcp_vals = [GCP_TIPX[t] for t in THREADS]
    fig, ax = plt.subplots(figsize=(10,4.5))
    b1 = ax.bar(x - width/2, idc_vals, width, label='IDC', color='#4f81bd')
    b2 = ax.bar(x + width/2, gcp_vals, width, label='GCP', color='#c0504d')
    ax.set_xticks(x, THREADS)
    ax.set_xlabel('Threads')
    ax.set_ylabel('RPS')
    ax.set_title('TiProxy RPS: IDC vs GCP (multi_thread_multi_conn)')
    ax.legend()
    for r_idc, r_gcp, vi, vg in zip(b1, b2, idc_vals, gcp_vals):
        delta = pct(vg, vi)
        ax.text(r_idc.get_x()+r_idc.get_width()/2, vi, f"{vi:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        ax.text(r_gcp.get_x()+r_gcp.get_width()/2, vg, f"{vg:,.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')
    diffs = [pct(GCP_TIPX[t], IDC_TIPX[t]) for t in THREADS]
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
    lines.append(f"GCP 對 IDC 最大正向差異在 {max_t} threads: {diffs[max_t]:+.1f}%")
    lines.append(f"最大負向差異在 {min_t} threads: {diffs[min_t]:+.1f}%")
    lines.append("GCP 高併發 (500) 仍劣於 IDC, 但單執行緒 / 200 threads 有局部增益，可能與網路 RTT 與連線池熱化差異相關。")
    lines.append("IDC TiProxy 在多個中高併發點 (100 / 250 / 750) 維持領先，顯示本地網路拓撲更適合作為代理層。")
    lines.append("建議: GCP 需檢視 TiProxy 後端連線多工與路由策略；調整連線池大小與健康探測間隔，降低中併發抖動。")
    summary = '\n'.join(lines)
    print('\n[SUMMARY]\n'+summary)
    return summary


def main():
    make_plot()
    summarize()

if __name__ == '__main__':
    main()
