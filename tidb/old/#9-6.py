#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#9-6 TiProxy IDC Simultaneous Execution Off-Peak dataset) - Threads vs Req/sec and Avg Latency.

Template preserved:
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline (deltas & dashed line)
 - Dual-axis matplotlib (bars=RPS, line=latency) with per-bar annotation (RPS + Δ%)
 - Scaling & observations section

Output: #9-6.png
"""

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,    394.48,   2.534, 25.350),
    (100, 2693.88,  15.416,  3.712),
    (200, 2626.27,  41.133,  3.808),
    (250, 5156.92,  33.316,  1.939),
    (500, 3387.40,  94.211,  2.952),
    (750, 4017.87,  95.852,  2.489),
    (1000,3126.35,  32.013,  3.199),
]

PNG_NAME = "#9-6.png"


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
    ax1.set_title("#9-6 multi_thread_multi_conn Scaling")

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
    print("#9-6 multi_thread_multi_conn dataset:")
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
    print(" - Peak throughput at 250 threads: 5156.92 req/sec (+91.5% vs 100T 2693.88) with 33.316 ms latency (+116% vs 15.416 ms)")
    print(" - 200 threads regresses: 2626.27 req/sec (-2.5%) while latency inflates to 41.133 ms (+167%) — early contention / queue growth")
    print(" - Secondary highs: 4017.87 @750T (+49.1%) and 3387.40 @500T (+25.8%) but both with severe latency 95.852 / 94.211 ms (~6.1–6.2x baseline)")
    print(" - 1000T retains +16.0% throughput (3126.35) while latency drops back to 32.013 ms (2.1x baseline) — partial recovery after oversubscription")
    print(" - Per-thread efficiency: 26.94 (100T) → 13.13 (200T) → 20.63 (250T) → 6.77 (500T) → 5.36 (750T) → 3.13 (1000T); efficiency peak at baseline 100T (ignoring 1T single-thread)")
    print(" - Non-monotonic latency: sharp spike at 200T, lower at 250T than 200T, huge inflation 500–750T, recovery at 1000T — suggests bursty queuing + scheduler / pool thresholds")
    print(" - Single-thread to 100T scaling: +583% throughput (394.48 → 2693.88) at cost of ~5.1x latency (2.534 → 15.416 ms)")
    print(" - Recommendation: operate 100–250 threads; choose 250 only if higher throughput offsets 2.1x latency. Avoid 500–750 due to extreme latency; investigate contention (locks, I/O mux saturation, CPU run-queue, proxy connection pooling). 1000T offers modest throughput gain with acceptable latency relative to 500–750T but lower efficiency.")
    make_plot(DATA)


if __name__ == "__main__":
    main()
