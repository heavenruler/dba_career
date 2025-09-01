#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#8-7 TiDB GCP Simultaneous Execution Off-Peak dataset) - Threads vs Req/sec and Avg Latency.

Template preserved:
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline (deltas & dashed line)
 - Dual-axis matplotlib (bars=RPS, line=latency) with per-bar annotation (RPS + Δ%)
 - Scaling & observations section

Output: #8-7.png
"""

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,    950.96,   1.051, 10.516),
    (100, 2405.80,  38.711,  4.157),
    (200, 3047.46,  58.696,  3.281),
    (250, 2266.70,  97.222,  4.412),
    (500, 2663.84, 142.255,  3.754),
    (750, 1732.99, 311.517,  5.770),
    (1000,2211.28, 268.076,  4.522),
]

PNG_NAME = "#8-7.png"


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
    ax1.set_title("#8-7 multi_thread_multi_conn Scaling")

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
    print("#8-7 multi_thread_multi_conn dataset:")
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
    print(" - Peak throughput at 200 threads: 3047.46 req/sec (+26.7% vs 100T baseline 2405.80) with latency 58.696 ms (+51.5% vs 38.711 ms)")
    print(" - Secondary high at 500T: 2663.84 req/sec (+10.7%) but latency 142.255 ms (3.67x 100T) -> poor efficiency trade-off")
    print(" - Regression points: 250T 2266.70 (-5.8%), 750T 1732.99 (-28.0%, severe, 311.517 ms 8.0x), 1000T 2211.28 (-8.1% with still elevated latency 268.076 ms 6.9x)")
    print(" - Per-thread efficiency collapse: 24.06 (100) → 15.24 (200) → 9.07 (250) → 5.33 (500) → 2.31 (750) → 2.21 (1000); single-thread shows 950.96 req/sec solo capacity")
    print(" - Latency trajectory: 38.711 ms (100) → 58.696 (200, +51%) → 97.222 (250) → 142.255 (500) → 311.517 (750) then partial improvement 268.076 (1000) still 6.9x baseline")
    print(" - Single-thread to 100T scaling: +153% throughput (950.96 → 2405.80) at cost of ~36.8x latency, indicating early contention surfaces at low concurrency")
    print(" - 200T gain (+26.7%) comes with +51% latency; beyond 200T added threads give negative or modest returns with steep latency penalties")
    print(" - Recommendation: operate near 200T for peak throughput if latency tolerable; use 100T for lower latency steady state; avoid ≥500T unless throughput boost justifies 3.6x+ latency; 750T+ strongly discouraged")
    make_plot(DATA)


if __name__ == "__main__":
    main()
