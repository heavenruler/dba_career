#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (TiProxy GCP Peak) - Threads vs Req/sec and Avg Latency.

Data source: Extracted from TiProxy with GCP # 尖峰 benchmark snippet.

Generates: tiproxy_gcp_peak_mt_multi_conn.png

If matplotlib is not installed, the script will attempt a lightweight ASCII fallback and hint to install.
"""
from __future__ import annotations
import math
import statistics as stats

DATA = [
    # (threads, req_per_sec, avg_resp_ms, total_time_s)
    (1,    613.84,  1.628, 16.291),
    (100,  5821.99, 15.625, 1.718),
    (200,  5655.58, 29.160, 1.768),
    (250,  5489.46, 35.037, 1.822),
    (500,  4656.07, 63.569, 2.148),
    (750,  4011.99, 83.732, 2.493),
    (1000, 3540.01, 21.078, 2.825),  # 注意：相較 750 threads avg latency 降低，可能測試條件變動或抖動
]

PNG_NAME = "#0.png"  # Output filename requested

def analyze(data):
    peak = max(data, key=lambda r: r[1])
    # Throughput efficiency = req/sec per thread (excluding single-thread baseline which is conceptually different)
    efficiencies = [(t, rps / t) for t, rps, *_ in data if t > 1]
    best_eff = max(efficiencies, key=lambda x: x[1]) if efficiencies else None
    # Simple scaling ratios relative to 100-thread point
    base100 = next((r for r in data if r[0] == 100), None)
    scaling = []
    if base100:
        base_rps = base100[1]
        for t, rps, *_ in data:
            if t >= 100:
                scaling.append((t, rps / base_rps))
    return {
        "peak": peak,
        "best_eff": best_eff,
        "scaling": scaling,
    }

def ascii_table(data):
    # Determine baseline (100 threads)
    base = next((r[1] for r in data if r[0] == 100), None)
    headers = ["Threads", "Req/sec", "Avg_ms", "Req/sec/Thread", "ΔRPS_vs100%"]
    rows = []
    for t, rps, avg_ms, _ in data:
        eff = rps / t
        if base and base > 0:
            delta_pct = (rps - base) / base * 100.0
        else:
            delta_pct = 0.0
        rows.append((t, rps, avg_ms, eff, delta_pct))
    # compute column widths
    col_widths = []
    for i, h in enumerate(headers):
        max_content = max(len(f"{row[i]:.2f}" if isinstance(row[i], float) else str(row[i])) for row in rows)
        col_widths.append(max(len(h), max_content))
    def fmt(val, i):
        if isinstance(val, float):
            return f"{val:.2f}".rjust(col_widths[i])
        return str(val).rjust(col_widths[i])
    lines = [" | ".join(headers[i].ljust(col_widths[i]) for i in range(len(headers))),
             "-+-".join('-'*w for w in col_widths)]
    for row in rows:
        lines.append(" | ".join(fmt(row[i], i) for i in range(len(headers))))
    return "\n".join(lines)

def make_plot(data):
    try:
        import matplotlib.pyplot as plt
    except Exception as e:  # pragma: no cover
        print("[WARN] matplotlib not available, skipping PNG generation.")
        print("Install with: pip install matplotlib")
        return False
    threads = [r[0] for r in data]
    rps = [r[1] for r in data]
    avg_ms = [r[2] for r in data]
    fig, ax1 = plt.subplots(figsize=(9,5))
    bars = ax1.bar([str(t) for t in threads], rps, color="#1f77b4", alpha=0.75, label="Req/sec")
    ax1.set_xlabel("Threads")
    ax1.set_ylabel("Requests per second")
    ax1.set_title("TiProxy GCP Peak - multi_thread_multi_conn Scaling")
    # Secondary axis for latency
    ax2 = ax1.twinx()
    ax2.plot([str(t) for t in threads], avg_ms, color="#d62728", marker="o", linewidth=2, label="Avg Resp (ms)")
    ax2.set_ylabel("Average Response (ms)")
    # Baseline (100-thread) reference
    base_rps = next((r[1] for r in data if r[0] == 100), None)
    if base_rps:
        ax1.axhline(base_rps, color='#666', linestyle='--', linewidth=1, label='100-thread baseline')

    # Annotate bars with RPS and delta vs baseline
    for b, (t, val) in zip(bars, [(r[0], r[1]) for r in data]):
        if base_rps and base_rps > 0:
            delta_pct = (val - base_rps) / base_rps * 100.0
            delta_str = f"{delta_pct:+.1f}%" if t != 100 else "+0.0%"
            if t == 100:
                color = '#000000'  # baseline black
            else:
                # 正向(>0) 用紅色, 負向(<0) 用綠色
                color = '#d62728' if delta_pct > 0 else '#2ca02c'
            ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{val:.0f}\n{delta_str}",
                     ha='center', va='bottom', fontsize=8, color=color, linespacing=0.9)
        else:
            ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{val:.0f}", ha='center', va='bottom', fontsize=8)
    # Legend
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
    print("Multi-thread multi-conn data (TiProxy GCP Peak):")
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
            sign = "+" if ratio >= 1 else ""
            pct = (ratio - 1) * 100
            print(f"  {t:>4} threads: {ratio*100:5.1f}% of baseline ({sign}{pct:.2f}%)")
    # Observations
    obs = []
    obs.append("Throughput jumps sharply between 1 and 100 threads ( ~9.5x ) while avg latency rises ~9.6x (1.63->15.6 ms ).")
    obs.append("After 100 threads, absolute throughput declines gradually (~5-6% drop by 250, ~31% drop by 750).")
    obs.append("Latency generally increases with threads until 750 (83.7 ms), but 1000-thread run shows lower avg latency (21.1 ms) suggesting a test artifact or changed workload duration.")
    obs.append("Efficiency (req/sec/thread) is highest at 100 threads; diminishing returns beyond due to contention / coordination overhead.")
    print("\nObservations:")
    for o in obs:
        print(" - " + o)
    make_plot(DATA)

if __name__ == "__main__":
    main()
