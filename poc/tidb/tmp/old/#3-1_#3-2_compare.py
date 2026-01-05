#!/usr/bin/env python3
"""
Compare multi_thread_multi_conn RPS only for #3-1 (TiDB IDC) vs #3-2 (TiProxy IDC) datasets.

Requirements:
 - Merge #3-1.py and #3-2.py datasets
 - Bar chart ONLY Requests/sec (no latency axis)
 - Side-by-side bars per thread count
 - Annotate each bar with RPS value and (optional) delta vs the *other* system at that thread
 - Provide textual diff summary (peaks, relative gaps, efficiency notes)
 - Output PNG: #3-1_#3-2_compare.png

Data sources:
 #3-1 TiDB IDC    : [(threads, rps), ...]
 #3-2 TiProxy IDC : [(threads, rps), ...]
"""
from __future__ import annotations

# Extracted from #3-1.py and #3-2.py
TIDB_DATA = [
    (1,    703.02),
    (100, 5178.16),
    (200, 5346.08),
    (250, 5107.33),
    (500, 4499.16),
    (750, 4255.60),
    (1000,3190.80),
]

TIPROXY_DATA = [
    (1,    502.62),
    (100, 3220.79),
    (200, 3465.21),
    (250, 3428.05),
    (500, 3337.43),
    (750, 3054.79),
    (1000,2968.66),
]

PNG_NAME = "#3-1_#3-2_compare.png"


def merge_threads(a, b):
    threads = sorted({t for t, _ in a} | {t for t, _ in b})
    a_map = {t: rps for t, rps in a}
    b_map = {t: rps for t, rps in b}
    rows = []
    for t in threads:
        rows.append((t, a_map.get(t), b_map.get(t)))
    return rows


def print_table(rows):
    headers = ["Threads", "TiDB_RPS", "TiProxy_RPS", "Delta(TiDB-TiProxy)", "TiDB/TiProxy"]
    lines = [" | ".join(headers), "-+-".join('-'*len(h) for h in headers)]
    for t, r1, r2 in rows:
        if r1 is None or r2 is None:
            lines.append(f"{t:>7} | {r1 if r1 is not None else '-':>9} | {r2 if r2 is not None else '-':>11} |    -         |    -")
            continue
        diff = r1 - r2
        ratio = (r1 / r2) if r2 else float('inf')
        lines.append(f"{t:>7} | {r1:9.2f} | {r2:11.2f} | {diff:14.2f} | {ratio:6.2f}x")
    return "\n".join(lines)


def summarize(rows):
    # Compute overall stats
    deltas = [(t, (r1 - r2), (r1 / r2) if r2 else None) for t, r1, r2 in rows if r1 and r2]
    largest_abs_gain = max(deltas, key=lambda x: x[1])
    smallest_gap = min(deltas, key=lambda x: abs(x[1]))
    peak_tidb = max(rows, key=lambda x: x[1] or 0)
    peak_tiproxy = max(rows, key=lambda x: x[2] or 0)
    lines = []
    lines.append(f"Peak TiDB RPS: {peak_tidb[1]:.2f} @ {peak_tidb[0]} threads")
    lines.append(f"Peak TiProxy RPS: {peak_tiproxy[2]:.2f} @ {peak_tiproxy[0]} threads")
    lines.append(f"Largest TiDB advantage: +{largest_abs_gain[1]:.2f} RPS at {largest_abs_gain[0]} threads ({largest_abs_gain[2]:.2f}x)")
    lines.append(f"Closest performance: {smallest_gap[0]} threads (Δ {smallest_gap[1]:.2f} RPS, ratio {smallest_gap[2]:.2f}x)")
    # Identify where TiProxy narrows the gap (ratio minimal >1) or if never surpasses.
    ratio_sorted = sorted(deltas, key=lambda x: x[2])
    best_ratio = ratio_sorted[0]
    lines.append(f"Best (lowest) TiDB/TiProxy ratio: {best_ratio[2]:.2f}x at {best_ratio[0]} threads")
    if all(d[1] > 0 for d in deltas):
        lines.append("TiProxy never exceeds TiDB at any tested concurrency.")
    return "\n".join(lines)


def make_bar_plot(rows):
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available, skipping PNG generation. Install with: pip install matplotlib numpy")
        return False

    threads = [t for t, *_ in rows]
    tidb_rps = [r1 for _, r1, _ in rows]
    tiproxy_rps = [r2 for _, _, r2 in rows]

    x = np.arange(len(threads))
    w = 0.38

    fig, ax = plt.subplots(figsize=(9,5))
    bars1 = ax.bar(x - w/2, tidb_rps, width=w, label='TiDB (#3-1)', color='#1f77b4')
    bars2 = ax.bar(x + w/2, tiproxy_rps, width=w, label='TiProxy (#3-2)', color='#ff7f0e')

    ax.set_xlabel('Threads')
    ax.set_ylabel('Requests per second')
    ax.set_title('TiDB vs TiProxy RPS (multi_thread_multi_conn) #3-1 vs #3-2')
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in threads])

    # Annotate bars with RPS and delta vs other at that thread
    for bx, r1, r2, b in zip(x, tidb_rps, tiproxy_rps, bars1):
        if r1 is not None and r2 is not None:
            diff = r1 - r2
            pct = diff / r2 * 100 if r2 else 0
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                    f"{r1:.0f}\n+{pct:.0f}%", ha='center', va='bottom', fontsize=8, color='#1f77b4')
    for bx, r1, r2, b in zip(x, tidb_rps, tiproxy_rps, bars2):
        if r1 is not None and r2 is not None:
            diff = r2 - r1
            pct = diff / r1 * 100 if r1 else 0
            # Only show if TiProxy >= TiDB (else redundancy)
            if diff >= 0:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                        f"{r2:.0f}\n+{pct:.0f}%", ha='center', va='bottom', fontsize=8, color='#ff7f0e')
            else:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                        f"{r2:.0f}", ha='center', va='bottom', fontsize=8, color='#ff7f0e')

    # Draw simple lines connecting pair differences (optional) - skip for clarity
    ax.legend(loc='upper right')
    ax.grid(axis='y', linestyle=':', linewidth=0.6, alpha=0.6)
    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def main():
    rows = merge_threads(TIDB_DATA, TIPROXY_DATA)
    print("Merged RPS Comparison (TiDB vs TiProxy):")
    print(print_table(rows))
    print("\nSummary:")
    print(summarize(rows))
    print("\nInterpretation:")
    print(" - TiDB outperforms TiProxy at every tested concurrency level in this sample.")
    print(" - TiDB peak: 5346.08 RPS @200T vs TiProxy peak: 3465.21 RPS @200T (TiDB +54.3% higher at peak thread count).")
    print(" - Relative advantage is largest at low concurrency (1T: +39.9%) and remains substantial (100T: +60.8%, 500T: +34.8%).")
    print(" - TiProxy degradation becomes more pronounced beyond 500 threads; gap narrows slightly at 1000T (TiDB +7.5%) as TiDB also declines more sharply.")
    print(" - Action: Investigate TiProxy overhead (connection multiplexing, scheduling, backpressure) to close the mid/high concurrency gap, and TiDB saturation causes after 200T.")
    make_bar_plot(rows)


if __name__ == "__main__":
    main()
