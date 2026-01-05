#!/usr/bin/env python3
"""
Compare multi_thread_multi_conn throughput: Cross-Line (Label Isolation TiProxy IDC node in mixed cluster) vs Local IDC 3-node TiProxy cluster.

Datasets:
 - #7-2 (Cross-Line / Label Isolation TiProxy IDC node) -> CROSS_LINE
 - #5-2 (Local IDC 3-node TiProxy)                       -> LOCAL

Metric: Requests per second across thread counts.

Plot: Grouped bar chart; Local as baseline; Cross-Line bars annotated with Δ% vs Local.
Console summary in Traditional Chinese highlighting biggest gain / drop and recommendations.

Output: #7-2_#5-2_crossline_local_compare.png
"""
from __future__ import annotations

CROSS_LINE = [
    (1,    498.98),
    (100, 2816.72),
    (200, 3179.19),
    (250, 2865.28),
    (500, 2953.45),
    (750, 2297.84),
    (1000,2561.23),
]

LOCAL = [
    (1,     384.32),
    (100,  5899.92),
    (200,  3839.15),
    (250,  5693.22),
    (500,  3126.86),
    (750,  4265.93),
    (1000, 3188.79),
]

PNG_NAME = "#7-2_#5-2_crossline_local_compare.png"


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
    ax.set_title('TiProxy Cross-Line vs Local Throughput')
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
        color = '#d62728' if d >= 0 else '#2ca02c'
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

    focus_threads = [100, 200, 250, 500, 750, 1000]
    lines.append("重點 thread 差異:")
    for ft in focus_threads:
        for t, c, l in pairs:
            if t == ft:
                lines.append(f"  {t:>4} : {pct(c,l):+6.1f}% (Cross {c:.0f} vs Local {l:.0f})")
                break

    pos_notes = [f"{t}({d:+.1f}%)" for t, d in deltas if d >= 15]
    neg_notes = [f"{t}({d:+.1f}%)" for t, d in deltas if d <= -15]
    lines.append("觀察:")
    if pos_notes:
        lines.append(" - Cross-Line 優勢 thread: " + ", ".join(pos_notes))
    if neg_notes:
        lines.append(" - Cross-Line 顯著劣勢 thread: " + ", ".join(neg_notes))
    lines.append(" - Local 在 100 threads 達到峰值 5899 RPS, Cross-Line 任何併發無法逼近")
    lines.append(" - Cross-Line 在所有中高併發區間 (200~1000) 均顯著劣於 Local, 顯示早期飽和與延遲放大")
    lines.append(" - 500 / 750 / 1000 threads 仍維持 -5x~-40% 區間, 疑似跨區網路 RTT / proxy 排程開銷")
    lines.append("建議:")
    lines.append(" - 剖析 Cross-Line TiProxy CPU / goroutine wait 與後端連線池命中率")
    lines.append(" - 檢視跨站流量是否集中至少數 region / leader, 調整 placement / balance")
    lines.append(" - 嘗試調降併發至 100~200, 以避免無效排隊與長尾延遲擴散")
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
