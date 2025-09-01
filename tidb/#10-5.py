#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#10-5 TiDB? / TiProxy? GCP Simultaneous Execution Off-Peak dataset) - Threads vs Req/sec and Avg Latency.
(Adjust descriptor if needed.)

Template preserved:
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline (deltas & dashed line)
 - Dual-axis matplotlib (bars=RPS, line=latency) with per-bar annotation (RPS + Δ%)
 - Scaling & observations section

Output: #10-5.png
"""

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,    686.89,   1.455, 14.558),
    (100, 2740.70,  23.076,  3.649),
    (200, 8362.52,  17.541,  1.196),
    (250, 3610.48,  55.607,  2.770),
    (500, 5277.11,  23.457,  1.895),
    (750, 2723.41,  32.893,  3.672),
    (1000,4278.33,  18.982,  2.337),
]

PNG_NAME = "#10-5.png"


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
    ax1.set_title("#10-5 multi_thread_multi_conn Scaling")

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
    print("#10-5 multi_thread_multi_conn dataset:")
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
    base_latency = next((r[2] for r in DATA if r[0] == 100), None)
    print("\nObservations:")
    print(" - Peak throughput at 200 threads: 8362.52 req/sec (+205.0% vs 100T 2740.70) with lower latency 17.541 ms (-23.9% vs 23.076 ms baseline)")
    print(" - Secondary highs: 5277.11 @500T (+92.6%, latency 23.457 ~+1.7%); 4278.33 @1000T (+56.1%, latency 18.982 -17.7%)")
    print(" - 250T anomaly: 3610.48 (+31.7%) but latency spike 55.607 ms (2.41x baseline); 750T near baseline throughput (-0.6%) with elevated latency 32.893 ms (+42.6%)")
    print(" - Per-thread efficiency: 27.41 (100T) → 41.81 (200T peak) → 14.44 (250T) → 10.55 (500T) → 3.63 (750T) → 4.28 (1000T)")
    print(" - Latency pattern: improves at 200T, degrades sharply 250T, moderates 500T, worsens 750T, improves again 1000T (non-monotonic contention / scheduler effects)")
    print(" - Single-thread to 100T scaling: +299% throughput (686.89 → 2740.70) with ~15.9x latency increase (1.455 → 23.076 ms)")
    print(" - 200T delivers both highest throughput and lower latency (rare favorable zone). 500T trades some throughput drop (-36.9% from peak) for near-baseline latency. 1000T offers mid performance with improved latency vs baseline.")
    print(" - Recommendation: target 200T for max efficiency & throughput; consider 500T if needing >5K RPS with acceptable latency; validate 1000T stability before use; avoid 250T & 750T due to instability and latency spikes.")
    make_plot(DATA)


if __name__ == "__main__":
    main()
