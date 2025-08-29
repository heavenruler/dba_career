#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (TiProxy GCP Off-Peak Simultaneous) - Threads vs Req/sec and Avg Latency.

Style preserved from #1-16.py / #2 series: DATA constant, ASCII table with per-thread efficiency & Δ vs 100-thread baseline,
dual-axis matplotlib plot (throughput bars + latency line) plus textual observations. No stylistic deviations.

Source: "RPS From TiProxy with GCP # 離峰 # 同時執行 #2-8.py" multi_thread_multi_conn rows only.

Output: #2-8.png
"""
from __future__ import annotations

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,     31.15, 32.104, 321.050),
    (100, 2974.73, 32.119,   3.362),
    (200, 4783.69, 33.683,   2.090),
    (250, 5143.19, 35.783,   1.944),
    (500, 4570.40, 43.914,   2.188),
    (750, 3772.58, 45.274,   2.651),
    (1000,3221.94, 42.207,   3.104),
]

PNG_NAME = "#2-8.png"


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
    ax1.set_title("TiProxy GCP Off-Peak Simultaneous - multi_thread_multi_conn Scaling")

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
    print("TiProxy GCP Off-Peak Simultaneous multi_thread_multi_conn dataset:")
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

    print("\nObservations:")
    print(" - Peak at 250 threads (5143.19 req/sec) = +72.9% over 100-thread baseline; modest incremental gain 200->250 (+7.5%) after strong 100->200 step (+60.8%)")
    print(" - Throughput declines after peak: +53.6% at 500, +26.8% at 750, +8.3% at 1000 vs baseline indicating early saturation & regression")
    print(" - Best multi-thread efficiency appears at 100 threads (29.75 req/sec/thread) while single-thread shows 31.15 (low coordination overhead at very low concurrency)")
    print(" - Efficiency erosion: 29.75 -> 23.92 (200) -> 20.57 (250) -> 9.14 (500) -> 5.03 (750) -> 3.22 (1000)")
    print(" - Latency inflates steadily with load (32.12 ms @100 -> 35.78 ms @250 -> 45.27 ms @750) then eases slightly at 1000 (42.21 ms) as throughput falls")
    print(" - Sub-linear scaling & early knee suggest bottlenecks (proxy CPU scheduling, backend connection saturation, or network RTT accumulation) under simultaneous workload on GCP")
    print(" - Diminishing returns beyond 200 threads: consider capping concurrency or scaling out backend capacity before increasing thread count further")
    make_plot(DATA)


if __name__ == "__main__":
    main()
