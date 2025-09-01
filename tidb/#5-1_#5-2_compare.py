#!/usr/bin/env python3
"""
Compare multi_thread_multi_conn RPS only for #5-1 (TiDB IDC 3-node) vs #5-2 (TiProxy IDC 3-node) datasets.

Features:
 - Side-by-side bar chart (RPS only) per thread count
 - Annotations: each TiDB bar shows +% over TiProxy; TiProxy bar shows +% only if >= TiDB
 - Text table with deltas & ratios
 - Summary & interpretation of differences (peaks, saturation, efficiency implications)
Output: #5-1_#5-2_compare.png
"""
from __future__ import annotations

TIDB_DATA = [ # (threads, rps)
    (1,    661.34),
    (100, 3788.97),
    (200, 7137.34),
    (250, 3653.09),
    (500, 2428.03),
    (750, 2731.68),
    (1000,2869.28),
]

TIPROXY_DATA = [
    (1,    384.32),
    (100, 5899.92),
    (200, 3839.15),
    (250, 5693.22),
    (500, 3126.86),
    (750, 4265.93),
    (1000,3188.79),
]

PNG_NAME = "#5-1_#5-2_compare.png"


def merge_threads(a, b):
    threads = sorted({t for t, _ in a} | {t for t, _ in b})
    a_map = {t: r for t, r in a}
    b_map = {t: r for t, r in b}
    return [(t, a_map.get(t), b_map.get(t)) for t in threads]


def table(rows):
    headers = ["Threads", "TiDB_RPS", "TiProxy_RPS", "Δ(TiDB-TiProxy)", "TiDB/TiProxy"]
    lines = [" | ".join(headers), "-+-".join('-'*len(h) for h in headers)]
    for t, r1, r2 in rows:
        if r1 is None or r2 is None:
            lines.append(f"{t:>7} | {r1 if r1 is not None else '-':>9} | {r2 if r2 is not None else '-':>11} | {'-':>14} |    -")
            continue
        diff = r1 - r2
        ratio = r1 / r2 if r2 else float('inf')
        lines.append(f"{t:>7} | {r1:9.2f} | {r2:11.2f} | {diff:14.2f} | {ratio:6.2f}x")
    return "\n".join(lines)


def summarize(rows):
    comp = [(t, r1, r2, r1-r2, (r1/r2) if r2 else None) for t, r1, r2 in rows if r1 and r2]
    peak_tidb = max(comp, key=lambda x: x[1])
    peak_proxy = max(comp, key=lambda x: x[2])
    largest_tidb_adv = max(comp, key=lambda x: x[3])
    largest_proxy_adv = min(comp, key=lambda x: x[3])  # may be negative
    ratio_sorted = sorted(comp, key=lambda x: x[4])
    best_ratio = ratio_sorted[0]
    lines = []
    lines.append(f"Peak TiDB: {peak_tidb[1]:.2f} RPS @ {peak_tidb[0]} threads")
    lines.append(f"Peak TiProxy: {peak_proxy[2]:.2f} RPS @ {peak_proxy[0]} threads")
    lines.append(f"Largest TiDB absolute advantage: +{largest_tidb_adv[3]:.2f} RPS at {largest_tidb_adv[0]}T (ratio {largest_tidb_adv[4]:.2f}x)")
    if largest_proxy_adv[3] < 0:
        lines.append(f"Largest TiProxy advantage: {largest_proxy_adv[3]:.2f} RPS at {largest_proxy_adv[0]}T (TiProxy {(largest_proxy_adv[2]/largest_proxy_adv[1]):.2f}x TiDB)")
    else:
        lines.append("TiProxy never exceeds TiDB.")
    lines.append(f"Lowest TiDB/TiProxy ratio: {best_ratio[4]:.2f}x at {best_ratio[0]} threads")
    return "\n".join(lines)


def interpret(rows):
    # Craft narrative differences.
    return "\n".join([
        " - Divergent scaling: TiDB peaks at 200T (7137) while TiProxy peaks at 100T (5899).",
        " - 1T: TiDB +72% (661 vs 384) shows lower single-thread overhead for TiDB path.",
        " - 100T: TiProxy leads (+56%: 5899 vs 3789) indicating proxy aggregation advantage at this knee point.",
        " - 200T: TiDB surges (+86% vs TiProxy 3839) with improved latency (per original dataset) while TiProxy drops from its 100T peak.",
        " - 250T & 750T: TiProxy again outperforms (5693 vs 3653; 4266 vs 2732) showing TiDB regression bands.",
        " - High concurrency 1000T: Throughputs converge (2869 vs 3189, TiProxy +11%) as both degrade from their peaks.",
        " - Pattern: TiDB exhibits pronounced peak then steep falloff; TiProxy shows earlier peak, softer mid-range declines, better stability at some higher thread counts.",
        " - Tuning focus: For TiDB raise post-200T stability (investigate CPU, lock hot spots, network); for TiProxy lift >200T scalability (reduce queuing / context overhead).",
    ])


def plot(rows):
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skipping plot.")
        return False
    threads = [t for t, *_ in rows]
    tidb = [r1 for _, r1, _ in rows]
    proxy = [r2 for _, _, r2 in rows]
    x = np.arange(len(threads))
    w = 0.38
    fig, ax = plt.subplots(figsize=(9,5))
    b1 = ax.bar(x - w/2, tidb, w, label='TiDB (#5-1)', color='#1f77b4')
    b2 = ax.bar(x + w/2, proxy, w, label='TiProxy (#5-2)', color='#ff7f0e')
    ax.set_xlabel('Threads')
    ax.set_ylabel('Requests per second')
    ax.set_title('TiDB vs TiProxy RPS (#5-1 vs #5-2)')
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in threads])
    # Annotate
    for t_idx, (t, r1, r2) in enumerate(rows):
        if r1 and r2:
            ax.text(x[t_idx]-w/2, r1*1.01, f"{r1:.0f}\n{(r1/r2-1)*100:+.0f}%", ha='center', va='bottom', fontsize=8, color='#1f77b4')
            if r2 >= r1:
                ax.text(x[t_idx]+w/2, r2*1.01, f"{r2:.0f}\n{(r2/r1-1)*100:+.0f}%", ha='center', va='bottom', fontsize=8, color='#ff7f0e')
            else:
                ax.text(x[t_idx]+w/2, r2*1.01, f"{r2:.0f}", ha='center', va='bottom', fontsize=8, color='#ff7f0e')
    ax.legend(loc='upper right')
    ax.grid(axis='y', linestyle=':', linewidth=0.6, alpha=0.6)
    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def main():
    rows = merge_threads(TIDB_DATA, TIPROXY_DATA)
    print("RPS Comparison Table (TiDB vs TiProxy):")
    print(table(rows))
    print("\nSummary:")
    print(summarize(rows))
    print("\nInterpretation:")
    print(interpret(rows))
    plot(rows)


if __name__ == "__main__":
    main()
