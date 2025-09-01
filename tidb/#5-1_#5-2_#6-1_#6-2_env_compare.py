#!/usr/bin/env python3
"""
IDC *3 vs GCP *3  (TiDB Direct vs TiProxy)  multi_thread_multi_conn RPS
Sources: #5-1.py #5-2.py (IDC 3-node) ; #6-1.py #6-2.py (GCP 3-node)
Plot labels in English only. Console SUMMARY in Traditional Chinese.
"""
from __future__ import annotations
import matplotlib.pyplot as plt
import numpy as np

# RPS data (multi_thread_multi_conn) per threads
THREADS = [1,100,200,250,500,750,1000]
IDC_TIDB = {1:661.34,100:3788.97,200:7137.34,250:3653.09,500:2428.03,750:2731.68,1000:2869.28}
IDC_TIPX = {1:384.32,100:5899.92,200:3839.15,250:5693.22,500:3126.86,750:4265.93,1000:3188.79}
GCP_TIDB = {1:875.95,100:2995.93,200:7151.47,250:2715.47,500:5408.90,750:1979.18,1000:3254.47}
GCP_TIPX = {1:583.51,100:2758.88,200:5099.57,250:2539.88,500:4137.94,750:1893.95,1000:3017.88}

PNG_NAME = "#5-1_#5-2_#6-1_#6-2_env_compare.png"

def pct(new: float, base: float) -> float:
    if base == 0: return 0.0
    return (new/base - 1.0)*100.0

def make_plot():
    fig, axes = plt.subplots(1,2, figsize=(14,5), sharey=True)
    width = 0.35
    x = np.arange(len(THREADS))

    # ------ IDC (3-node) ------
    ax = axes[0]
    v_tidb = [IDC_TIDB[t] for t in THREADS]
    v_tipx = [IDC_TIPX[t] for t in THREADS]
    b1 = ax.bar(x - width/2, v_tidb, width, label='TiDB', color='#4f81bd')
    b2 = ax.bar(x + width/2, v_tipx, width, label='TiProxy', color='#c0504d')
    ax.set_title('IDC (3-node) RPS')
    ax.set_xlabel('Threads')
    ax.set_ylabel('RPS')
    ax.set_xticks(x, THREADS)
    ax.legend()
    for r_tidb, r_tipx, vt, vp in zip(b1, b2, v_tidb, v_tipx):
        diff = pct(vp, vt)
        ax.text(r_tidb.get_x()+r_tidb.get_width()/2, vt, f"{vt:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        ax.text(r_tipx.get_x()+r_tipx.get_width()/2, vp, f"{vp:,.0f}\n{diff:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')

    # highlight max positive TiProxy gain
    gains_idc = [pct(IDC_TIPX[t], IDC_TIDB[t]) for t in THREADS]
    best_i = int(np.argmax(gains_idc))
    ax.annotate('Top Gain', xy=(x[best_i]+width/2, v_tipx[best_i]), xytext=(0,30),
                textcoords='offset points', ha='center', arrowprops=dict(arrowstyle='->'))

    # ------ GCP (3-node) ------
    ax2 = axes[1]
    v_tidb2 = [GCP_TIDB[t] for t in THREADS]
    v_tipx2 = [GCP_TIPX[t] for t in THREADS]
    b1g = ax2.bar(x - width/2, v_tidb2, width, label='TiDB', color='#4f81bd')
    b2g = ax2.bar(x + width/2, v_tipx2, width, label='TiProxy', color='#c0504d')
    ax2.set_title('GCP (3-node) RPS')
    ax2.set_xlabel('Threads')
    ax2.set_xticks(x, THREADS)
    ax2.legend()
    for r_tidb, r_tipx, vt, vp in zip(b1g, b2g, v_tidb2, v_tipx2):
        diff = pct(vp, vt)
        ax2.text(r_tidb.get_x()+r_tidb.get_width()/2, vt, f"{vt:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        ax2.text(r_tipx.get_x()+r_tipx.get_width()/2, vp, f"{vp:,.0f}\n{diff:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')

    # In GCP TiProxy never beats TiDB (all negative); annotate worst drop
    drops_gcp = [pct(GCP_TIPX[t], GCP_TIDB[t]) for t in THREADS]
    worst_i = int(np.argmin(drops_gcp))
    ax2.annotate('Largest Drop', xy=(x[worst_i]+width/2, v_tipx2[worst_i]), xytext=(0,30),
                 textcoords='offset points', ha='center', arrowprops=dict(arrowstyle='->'))

    fig.suptitle('IDC vs GCP: TiDB vs TiProxy RPS (multi_thread_multi_conn)')
    fig.tight_layout(rect=[0,0,1,0.95])
    plt.savefig(PNG_NAME, dpi=150)
    print(f"Saved {PNG_NAME}")


def summarize():
    lines = []
    # TiProxy vs TiDB percent diff per env
    idc_diff = {t: pct(IDC_TIPX[t], IDC_TIDB[t]) for t in THREADS}
    gcp_diff = {t: pct(GCP_TIPX[t], GCP_TIDB[t]) for t in THREADS}
    best_gain_t = max(idc_diff, key=lambda k: idc_diff[k])
    worst_drop_t = min(gcp_diff, key=lambda k: gcp_diff[k])
    # GCP vs IDC TiDB
    env_tidb = {t: pct(GCP_TIDB[t], IDC_TIDB[t]) for t in THREADS}
    env_tipx = {t: pct(GCP_TIPX[t], IDC_TIPX[t]) for t in THREADS}

    lines.append(f"IDC: TiProxy 對 TiDB 最大增益出現在 {best_gain_t} threads ({idc_diff[best_gain_t]:+.1f}%).")
    neg_idc = [t for t,v in idc_diff.items() if v < 0]
    if neg_idc:
        lines.append(f"IDC: 退化點 threads = {neg_idc} (低併發或特定峰值下 TiProxy 不利)。")
    lines.append(f"GCP: TiProxy 全部 threads 均低於 TiDB，最大跌幅在 {worst_drop_t} threads ({gcp_diff[worst_drop_t]:+.1f}%).")
    lines.append(f"跨環境 TiDB GCP 相對 IDC：主要提升在 500 threads ({env_tidb[500]:+.1f}%)，部分 threads 反而下降 (250 {env_tidb[250]:+.1f}%).")
    lines.append(f"跨環境 TiProxy GCP 相對 IDC：高增益在 1 thread ({env_tipx[1]:+.1f}%)，但 100/250/750 顯著下滑 (100 {env_tipx[100]:+.1f}%, 250 {env_tipx[250]:+.1f}%, 750 {env_tipx[750]:+.1f}%).")
    lines.append("結論: IDC 環境 TiProxy 可在多個中高併發點提供 >+50% 吞吐; GCP 中 TiProxy 尚未展現優勢，偏向優化代理層連線/路由或觀察網路延遲因素。")
    summary = '\n'.join(lines)
    print('\n[SUMMARY]\n' + summary)
    return summary


def main():
    make_plot()
    summarize()

if __name__ == '__main__':
    main()
