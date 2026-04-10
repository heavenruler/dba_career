#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#9-1 TiDB IDC Simultaneous Execution Off-Peak dataset) - Threads vs Req/sec and Avg Latency.

Template preserved:
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline (deltas & dashed line)
 - Dual-axis matplotlib (bars=RPS, line=latency) with per-bar annotation (RPS + Δ%)
 - Scaling & observations section

Output: #9-1.png
"""

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,    677.35,   1.475, 14.763),
    (100, 3958.24,  22.339,  2.526),
    (200,10410.03,  12.917,  0.961),
    (250, 3691.15,  44.376,  2.709),
    (500, 7080.02,  12.804,  1.412),
    (750, 2946.77,  26.944,  3.394),
    (1000,2510.54,  15.000,  3.983),
]

PNG_NAME = "#9-1.png"


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
    ax1.set_title("#9-1 multi_thread_multi_conn Scaling")

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
    print("#9-1 multi_thread_multi_conn dataset:")
    print(ascii_table(DATA))
    results = analyze(DATA)
    peak_threads, peak_rps, peak_avg, _ = results["peak"]
    print(f"\nPeak throughput at {peak_threads} threads: {peak_rps:.2f} req/sec (avg {peak_avg:.3f} ms)")
    if results["best_eff"]:
        t, eff = results["best_eff"]
        print(f"Best per-thread efficiency (t>1) at {t} threads: {eff:.2f} req/sec/thread")
    if results["scaling"]:
        print("\nScaling vs 100-thread baseline (>=100 threads):")
        for t, ratio in results["scaling"]:
            pct = (ratio - 1) * 100
            sign = "+" if pct >= 0 else ""
            print(f"  {t:>4} threads: {ratio*100:5.1f}% of baseline ({sign}{pct:.2f}%)")

    base_rps = next((r[1] for r in DATA if r[0] == 100), None)
    print("\nObservations:")
    # Derived deltas vs 100-thread baseline
    print(" - Peak at 200 threads (10410.03 req/sec) = +{:.1f}% over 100-thread baseline ({:.2f})".format((10410.03/base_rps - 1)*100, base_rps))
    print(" - Secondary plateau: 500 threads 7080.02 req/sec = +{:.1f}% vs baseline but -32.0% vs peak".format((7080.02/base_rps - 1)*100))
    print(" - Sharp regressions after peak: 250T -6.8%, 750T -25.5%, 1000T -36.6% vs baseline")
    print(" - Per-thread efficiency: 39.58 (100) → 52.05 (200 peak) → 14.16 (500) → 2.51 (1000) showing severe diminishing returns beyond 200T")
    print(" - Latency improves at peak (22.34 → 12.92 ms), then spikes (44.38 ms @250), normalizes (12.80 ms @500), rises again (26.94 ms @750, 15.00 ms @1000) while throughput drops")
    print(" - Peak efficiency & throughput coincide at 200T (rare alignment); higher concurrency wastes capacity")
    print(" - Recommendation: operate near 200T for both throughput & efficiency; optionally 100T for lower latency consistency; avoid sustaining >250T unless transient; monitor 250T latency spike root cause")
    make_plot(DATA)


if __name__ == "__main__":
    main()
