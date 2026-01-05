#!/usr/bin/env python3
"""
IDC *1 vs IDC *3 scaling difference (RPS / multi_thread_multi_conn)
Sources: #3-1.py, #5-1.py (Direct TiDB); #3-2.py, #5-2.py (TiProxy)
Focus only on multi_thread_multi_conn RPS vs threads to see scale-up & degradation points.
"""
from __future__ import annotations
import matplotlib.pyplot as plt
import numpy as np

# Data dictionaries keyed by threads -> RPS
TIDB_IDC1 = {   1: 703.02, 100: 5178.16, 200: 5346.08, 250: 5107.33, 500: 4499.16, 750: 4255.60, 1000: 3190.80 }
TIDB_IDC3 = {   1: 661.34, 100: 3788.97, 200: 7137.34, 250: 3653.09, 500: 2428.03, 750: 2731.68, 1000: 2869.28 }
TIPROXY_IDC1 = {1: 502.62, 100: 3220.79, 200: 3465.21, 250: 3428.05, 500: 3337.43, 750: 3054.79, 1000: 2968.66 }
TIPROXY_IDC3 = {1: 384.32, 100: 5899.92, 200: 3839.15, 250: 5693.22, 500: 3126.86, 750: 4265.93, 1000: 3188.79 }

THREADS = [1,100,200,250,500,750,1000]
PNG_NAME = "#3-1_#5-1_#3-2_#5-2_scale_compare.png"


def pct(new: float, old: float) -> float:
    if old == 0:
        return 0.0
    return (new / old - 1.0) * 100.0


def make_plot():
    fig, axes = plt.subplots(1, 2, figsize=(14, 5), sharey=True)
    width = 0.35
    x = np.arange(len(THREADS))

    # --- TiDB Direct ---
    ax = axes[0]
    rps1 = [TIDB_IDC1[t] for t in THREADS]
    rps3 = [TIDB_IDC3[t] for t in THREADS]
    b1 = ax.bar(x - width/2, rps1, width, label='IDC*1', color='#4f81bd')
    b2 = ax.bar(x + width/2, rps3, width, label='IDC*3', color='#c0504d')
    ax.set_xticks(x, THREADS)
    ax.set_xlabel('Threads')
    ax.set_ylabel('RPS')
    ax.set_title('TiDB Direct RPS Scale-Up (multi_thread_multi_conn)')
    ax.legend()
    # annotate percentage change on top of IDC*3 bars
    for i, (rect1, rect2, v1, v3) in enumerate(zip(b1, b2, rps1, rps3)):
        delta = pct(v3, v1)
        # value labels
        ax.text(rect1.get_x() + rect1.get_width()/2, v1, f"{v1:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        ax.text(rect2.get_x() + rect2.get_width()/2, v3, f"{v3:,.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')

    # highlight best improvement
    improvements = [pct(v3, v1) for v1, v3 in zip(rps1, rps3)]
    best_idx = int(np.argmax(improvements))
    ax.annotate('Best Gain', xy=(x[best_idx]+width/2, rps3[best_idx]), xytext=(0, 30),
                textcoords='offset points', ha='center', arrowprops=dict(arrowstyle='->', color='black'))

    # --- TiProxy Path ---
    axp = axes[1]
    rps1p = [TIPROXY_IDC1[t] for t in THREADS]
    rps3p = [TIPROXY_IDC3[t] for t in THREADS]
    b1p = axp.bar(x - width/2, rps1p, width, label='IDC*1', color='#4f81bd')
    b2p = axp.bar(x + width/2, rps3p, width, label='IDC*3', color='#c0504d')
    axp.set_xticks(x, THREADS)
    axp.set_xlabel('Threads')
    axp.set_title('TiProxy RPS Scale-Up (multi_thread_multi_conn)')
    axp.legend()
    for rect1, rect2, v1, v3 in zip(b1p, b2p, rps1p, rps3p):
        delta = pct(v3, v1)
        axp.text(rect1.get_x() + rect1.get_width()/2, v1, f"{v1:,.0f}", ha='center', va='bottom', fontsize=7, color='#17365d')
        axp.text(rect2.get_x() + rect2.get_width()/2, v3, f"{v3:,.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7, color='#7f1d1d')

    improvements_p = [pct(v3, v1) for v1, v3 in zip(rps1p, rps3p)]
    best_idx_p = int(np.argmax(improvements_p))
    axp.annotate('Best Gain', xy=(x[best_idx_p]+width/2, rps3p[best_idx_p]), xytext=(0, 30),
                 textcoords='offset points', ha='center', arrowprops=dict(arrowstyle='->', color='black'))

    fig.suptitle('IDC *1 → IDC *3 RPS Scale Comparison')
    fig.tight_layout(rect=[0,0,1,0.95])
    plt.savefig(PNG_NAME, dpi=150)
    print(f"Saved {PNG_NAME}")


def summarize():
    # concise textual summary
    lines = []
    # TiDB best improvement
    tidb_impr = {t: pct(TIDB_IDC3[t], TIDB_IDC1[t]) for t in THREADS}
    best_t_tidb = max(tidb_impr, key=lambda k: tidb_impr[k])
    # TiProxy best improvement
    tipx_impr = {t: pct(TIPROXY_IDC3[t], TIPROXY_IDC1[t]) for t in THREADS}
    best_t_tipx = max(tipx_impr, key=lambda k: tipx_impr[k])

    lines.append(f"TiDB: 最佳提升出現在 {best_t_tidb} threads (+{tidb_impr[best_t_tidb]:.1f}%), 其後吞吐快速衰退。")
    lines.append(f"TiProxy: 顯著提升出現在 {best_t_tipx} threads (+{tipx_impr[best_t_tipx]:.1f}%), 其他中高併發大多仍為正向增益。")
    # Note on low thread degradation
    low_deg_tidb = pct(TIDB_IDC3[1], TIDB_IDC1[1])
    low_deg_tipx = pct(TIPROXY_IDC3[1], TIPROXY_IDC1[1])
    lines.append(f"低併發 (1 thread): 直連 {low_deg_tidb:+.1f}%, TiProxy {low_deg_tipx:+.1f}% → 多節點與代理在極低負載存在固定開銷。")
    lines.append("建議: 直連 TiDB 聚焦 ~200 threads 熱點 / 調度調優；TiProxy 維持多節點以支撐 100~250 與 250~750 兩個效益區間。")
    summary = '\n'.join(lines)
    print('\n[SUMMARY]\n' + summary)
    return summary


def main():
    make_plot()
    summarize()

if __name__ == '__main__':
    main()
