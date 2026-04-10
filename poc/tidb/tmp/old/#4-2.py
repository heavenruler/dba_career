#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#4-2 TiProxy GCP Off-Peak dataset) - Threads vs Req/sec and Avg Latency.

Template derived from #3-1.py / #4-1.py: DATA constant, ascii table with per-thread efficiency, Δ vs 100-thread baseline,
scaling analysis, observations, dual-axis matplotlib bar/line plot with annotations.

Dataset (multi_thread_multi_conn) provided:
 Threads: 1,100,200,250,500,750,1000
   1    ->  576.95 rps,   1.732 ms, 17.333 s
   100  -> 1696.55 rps,  56.662 ms,  5.894 s (baseline)
   200  -> 1481.10 rps, 126.717 ms,  6.752 s
   250  -> 1624.56 rps, 141.387 ms,  6.156 s
   500  -> 1373.58 rps, 319.890 ms,  7.280 s
   750  -> 1299.53 rps, 471.125 ms,  7.695 s
   1000 -> 1209.03 rps, 646.591 ms,  8.271 s

Output: #4-2.png
"""
from __future__ import annotations

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,     576.95,   1.732, 17.333),
    (100,  1696.55,  56.662,  5.894),
    (200,  1481.10, 126.717,  6.752),
    (250,  1624.56, 141.387,  6.156),
    (500,  1373.58, 319.890,  7.280),
    (750,  1299.53, 471.125,  7.695),
    (1000, 1209.03, 646.591,  8.271),
]

PNG_NAME = "#4-2.png"


def analyze(data):
    peak = max(data, key=lambda r: r[1])
    efficiencies = [(t, rps / t) for t, rps, *_ in data if t > 1]
    best_eff = max(efficiencies, key=lambda x: x[1]) if efficiencies else None
    base100 = next((r for r in data if r[0] == 100), None)
    scaling = []
    if base100:
        base_rps = base100[1]
        for t, rps, *_ in data:
            if t >= 100:
                scaling.append((t, rps / base_rps))
    return {"peak": peak, "best_eff": best_eff, "scaling": scaling}


def ascii_table(data):
    base = next((r[1] for r in data if r[0] == 100), None)
    headers = ["Threads", "Req/sec", "Avg_ms", "Req/sec/Thread", "ΔRPS_vs100%"]
    rows = []
    for t, rps, avg_ms, _ in data:
        eff = rps / t
        delta_pct = (rps - base) / base * 100.0 if base and t != 100 else 0.0
        rows.append((t, rps, avg_ms, eff, delta_pct))
    col_widths = []
    for i, h in enumerate(headers):
        max_content = max(len(f"{row[i]:.2f}" if isinstance(row[i], float) else str(row[i])) for row in rows)
        col_widths.append(max(len(h), max_content))

    def fmt(val, i):
        return (f"{val:.2f}" if isinstance(val, float) else str(val)).rjust(col_widths[i])

    lines = [
        " | ".join(headers[i].ljust(col_widths[i]) for i in range(len(headers))),
        "-+-".join('-'*w for w in col_widths)
    ]
    for row in rows:
        lines.append(" | ".join(fmt(row[i], i) for i in range(len(headers))))
    return "\n".join(lines)


def make_plot(data):
    try:
        import matplotlib.pyplot as plt
    except Exception:  # pragma: no cover
        print("[WARN] matplotlib not available, skipping PNG generation.")
        print("Install with: pip install matplotlib")
        return False

    threads = [r[0] for r in data]
    rps = [r[1] for r in data]
    avg_ms = [r[2] for r in data]

    fig, ax1 = plt.subplots(figsize=(9, 5))
    bars = ax1.bar([str(t) for t in threads], rps, color="#1f77b4", alpha=0.75, label="Req/sec")
    ax1.set_xlabel("Threads")
    ax1.set_ylabel("Requests per second")
    ax1.set_title("#4-2 multi_thread_multi_conn (TiProxy GCP Off-Peak) Scaling")

    ax2 = ax1.twinx()
    ax2.plot([str(t) for t in threads], avg_ms, color="#d62728", marker="o", linewidth=2, label="Avg Resp (ms)")
    ax2.set_ylabel("Average Response (ms)")

    base_rps = next((r[1] for r in data if r[0] == 100), None)
    if base_rps:
        ax1.axhline(base_rps, color='#666', linestyle='--', linewidth=1, label='100-thread baseline')

    for b, (t, val) in zip(bars, [(r[0], r[1]) for r in data]):
        if base_rps and t >= 100:
            delta_pct = (val - base_rps) / base_rps * 100.0
            delta_str = f"{delta_pct:+.1f}%" if t != 100 else "+0.0%"
            color = '#000' if t == 100 else ('#d62728' if delta_pct > 0 else '#2ca02c')
            ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                     f"{val:.0f}\n{delta_str}", ha='center', va='bottom', fontsize=8, color=color, linespacing=0.9)
        else:
            ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                     f"{val:.0f}", ha='center', va='bottom', fontsize=8)

    lines, labels = [], []
    for ax in (ax1, ax2):
        L = ax.get_legend_handles_labels()
        lines.extend(L[0]); labels.extend(L[1])
    ax1.legend(lines, labels, loc='upper right')

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved plot -> {PNG_NAME}")
    return True


def main():
    print("#4-2 multi_thread_multi_conn (TiProxy GCP Off-Peak) dataset:")
    print(ascii_table(DATA))
    results = analyze(DATA)
    peak_threads, peak_rps, peak_avg, _ = results["peak"]
    print(f"\nPeak throughput (overall) at {peak_threads} threads: {peak_rps:.2f} req/sec (avg {peak_avg:.3f} ms)")
    if results["best_eff"]:
        t, eff = results["best_eff"]
        print(f"Best per-thread efficiency (t>1) at {t} threads: {eff:.2f} req/sec/thread")
    if results["scaling"]:
        print("\nScaling vs 100-thread baseline (>=100 threads):")
        for t, ratio in results["scaling"]:
            pct = (ratio - 1) * 100
            sign = "+" if pct >= 0 else ""
            print(f"  {t:>4} threads: {ratio*100:5.1f}% of baseline ({sign}{pct:.2f}%)")

    print("\nObservations:")
    print(" - 100 threads is the peak (1696.55 rps). All higher thread counts fail to surpass baseline, showing early saturation behind TiProxy on this single-node GCP topology")
    print(" - Sharp and monotonic latency inflation: 56.7 ms @100 → 126.7 ms @200 → 319.9 ms @500 → 646.6 ms @1000")
    print(" - Throughput declines moderately (-12.7% @200, -19.0% @500) then heavily (-28.7% @1000) while latency accelerates, indicating queue depth / contention escalation")
    print(" - Per-thread efficiency collapses: 16.97 (100) → 7.41 (200) → 2.75 (500) → 1.21 (1000)")
    print(" - 250 threads gives a partial rebound (-4.2% vs baseline) but higher latency, suggesting transient scheduling variance not structural scaling headroom")
    print(" - Recommendation: Keep concurrency ≤100 for TiProxy in this config; explore TiProxy tuning (connection pool sizing, back-pressure) and network RTT minimization to lift the knee")
    make_plot(DATA)


if __name__ == "__main__":
    main()
