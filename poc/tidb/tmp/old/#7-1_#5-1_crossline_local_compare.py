#!/usr/bin/env python3
"""
Compare multi_thread_multi_conn throughput: Cross-Line (Label Isolation IDC node in mixed IDC+GCP) vs Local IDC 3-node TiDB cluster.

Datasets:
 - #7-1 (Cross-Line / Label Isolation TiDB IDC node)   -> CROSS_LINE
 - #5-1 (Local IDC 3-node TiDB cluster)                -> LOCAL

Metric: Requests per second (multi_thread_multi_conn) across thread counts.

Plot: Grouped bar chart (English labels) with per-bar RPS values. For each thread group
      we annotate the Cross-Line bar with Δ% vs Local (baseline). Positive delta = Cross-Line faster.

Console Summary (Traditional Chinese):
 - 最大正向差異 (Cross-Line 相對 Local)
 - 最大負向差異
 - 各關鍵 thread (200, 250, 500, 750, 1000) 的差異概述
 - 建議 (tuning / investigation)

Output: #7-1_#5-1_crossline_local_compare.png
"""
from __future__ import annotations

CROSS_LINE = [
    # (threads, req_per_sec)
    (1,     649.56),
    (100,  3331.77),
    (200,  4624.85),
    (250,  3044.57),
    (500,  3282.37),
    (750,  2473.37),
    (1000, 1805.21),
]

LOCAL = [
    (1,     661.34),
    (100,  3788.97),
    (200,  7137.34),
    (250,  3653.09),
    (500,  2428.03),
    (750,  2731.68),
    (1000, 2869.28),
]

PNG_NAME = "#7-1_#5-1_crossline_local_compare.png"


def align(cross_line, local):
    m = {}
    for t, r in local:
        m.setdefault(t, {})['local'] = r
    for t, r in cross_line:
        m.setdefault(t, {})['cross'] = r
    rows = []
    for t in sorted(m):
        if 'local' in m[t] and 'cross' in m[t]:
            rows.append((t, m[t]['cross'], m[t]['local']))
    return rows


def pct(a, b):
    if b == 0:
        return 0.0
    return (a - b) / b * 100.0


def make_plot(pairs):
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skip plot. Install: pip install matplotlib numpy")
        return False

    threads = [t for t, *_ in pairs]
    cross = [c for _, c, _ in pairs]
    local = [l for _, _, l in pairs]

    x = np.arange(len(threads))
    width = 0.38

    fig, ax = plt.subplots(figsize=(10, 5.2))
    b1 = ax.bar(x - width/2, local, width, label='Local IDC (3-node)', color='#1f77b4', alpha=0.80)
    b2 = ax.bar(x + width/2, cross, width, label='Cross-Line (Label Isolation)', color='#ff7f0e', alpha=0.80)

    ax.set_xlabel('Threads')
    ax.set_ylabel('Requests per second')
    ax.set_title('TiDB Cross-Line vs Local Throughput')
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in threads])
    ax.legend(loc='upper right')

    # Annotate bars with RPS
    for bars in (b1, b2):
        for b in bars:
            ax.text(b.get_x() + b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}",
                    ha='center', va='bottom', fontsize=8)

    # Delta annotations above Cross-Line bars
    for (t, c, l), b in zip(pairs, b2):
        d = pct(c, l)
        color = '#d62728' if d >= 0 else '#2ca02c'  # red = higher (better), green = lower
        ax.text(b.get_x() + b.get_width()/2, b.get_height()*1.15, f"{d:+.1f}%", ha='center', va='bottom',
                fontsize=8, color=color)

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def summarize(pairs):
    deltas = [(t, pct(c, l)) for t, c, l in pairs]
    max_pos = max(deltas, key=lambda x: x[1])
    max_neg = min(deltas, key=lambda x: x[1])

    lines = []
    lines.append("=== SUMMARY (繁體中文) ===")
    lines.append(f"最大正向差異 (Cross-Line 相對 Local) 出現在 {max_pos[0]} threads: {max_pos[1]:+.1f}%")
    lines.append(f"最大負向差異 出現在 {max_neg[0]} threads: {max_neg[1]:+.1f}%")

    focus_threads = [200, 250, 500, 750, 1000]
    lines.append("重點 thread 差異:")
    for ft in focus_threads:
        for t, c, l in pairs:
            if t == ft:
                lines.append(f"  {t:>4} : {pct(c,l):+6.1f}% (Cross {c:.0f} vs Local {l:.0f})")
                break

    # Observations
    # Identify where Cross-Line outperforms / underperforms notably
    pos_notes = [f"{t}({d:+.1f}%)" for t, d in deltas if d >= 15]
    neg_notes = [f"{t}({d:+.1f}%)" for t, d in deltas if d <= -15]
    lines.append("觀察:")
    if pos_notes:
        lines.append(" - Cross-Line 優勢 thread: " + ", ".join(pos_notes))
    if neg_notes:
        lines.append(" - Cross-Line 顯著劣勢 thread: " + ", ".join(neg_notes))
    lines.append(" - 200 thread 下 Local 峰值大幅領先 (7137 vs 4625), Cross-Line 早期飽和")
    lines.append(" - Cross-Line 在 500 threads 相對 Local 反而較佳 (資源分佈與延遲型態不同)")
    lines.append(" - 高併發 (750, 1000) Cross-Line 下降幅度更深, 可能受跨站網路/排程延遲與熱點拖累")
    lines.append("建議:")
    lines.append(" - 針對 Cross-Line: 聚焦 200 以前的效能提升 (PD/TiKV 熱點, SQL plan, network RTT)")
    lines.append(" - 驗證 500 threads 優勢來源 (緩存 / 分佈較均衡) 是否可前移到 200~250 區間")
    lines.append(" - 高併發優先減少跨區熱點與 lock 等待 (調整 region 分佈與 auto-analyze 時機)")
    return "\n".join(lines)


def main():
    pairs = align(CROSS_LINE, LOCAL)
    print("Threads | Cross-Line | Local | Δ% (Cross-Line vs Local)")
    print("--------+------------+-------+-------------------------")
    for t, c, l in pairs:
        print(f"{t:7d} | {c:10.2f} | {l:5.2f} | {pct(c,l):+9.2f}%")
    print()
    print(summarize(pairs))
    make_plot(pairs)


if __name__ == "__main__":
    main()
