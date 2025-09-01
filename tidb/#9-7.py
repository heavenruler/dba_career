#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#9-7 TiDB GCP Simultaneous Execution Off-Peak dataset) - Threads vs Req/sec and Avg Latency.

Template preserved:
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline (deltas & dashed line)
 - Dual-axis matplotlib (bars=RPS, line=latency) with per-bar annotation (RPS + Δ%)
 - Scaling & observations section

Output: #9-7.png
"""

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,    938.11,   1.065, 10.660),
    (100, 2907.39,  31.817,  3.440),
    (200, 5703.00,  27.169,  1.753),
    (250, 2650.38,  78.617,  3.773),
    (500, 4337.12,  66.139,  2.306),
    (750, 1980.50,  25.645,  5.049),
    (1000,3224.52,  12.123,  3.101),
]

PNG_NAME = "#9-7.png"


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
    ax1.set_title("#9-7 multi_thread_multi_conn Scaling")

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
    print("#9-7 multi_thread_multi_conn dataset:")
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
    print(" - Peak throughput at 200 threads: 5703.00 req/sec (+96.1% vs 100T 2907.39) with lower latency 27.169 ms (-14.6% vs 31.817 ms)")
    print(" - 250T regression: 2650.38 req/sec (-8.8%) while latency spikes to 78.617 ms (+147%); onset of queue contention")
    print(" - Secondary high: 4337.12 @500T (+49.2%) but latency 66.139 ms (+108%) — diminished efficiency")
    print(" - 1000T yields modest +10.9% throughput (3224.52) yet best multiplexed latency 12.123 ms (-61.9%) — likely more parallel in-flight hiding latency, but per-thread efficiency low")
    print(" - 750T collapse: 1980.50 req/sec (-31.8%) latency improves to 25.645 ms (-19.4%) suggesting resource throttling / saturation reducing concurrency actually completing")
    print(" - Per-thread efficiency: 29.07 (100T) → 28.52 (200T) → 10.60 (250T) → 8.67 (500T) → 2.64 (750T) → 3.22 (1000T); efficiency plateau around 100–200 then collapses")
    print(" - Latency behavior: baseline high (31.817) drops at 200T, surges 250–500T, drops sharply at 1000T — non-linear effects (scheduler, batching, queue drain)")
    print(" - Single-thread to 100T scaling: +210% throughput (938.11 → 2907.39) at cost of ~29.9x latency (1.065 → 31.817 ms)")
    print(" - Recommendation: operate near 100–200 threads for balanced throughput & latency. Avoid 250–500 when latency sensitive; 1000T acceptable for latency but offers limited throughput gain and lower efficiency. Investigate 250T latency spike (lock contention, network I/O backlog, GC, CPU steal).")
    make_plot(DATA)


if __name__ == "__main__":
    main()
