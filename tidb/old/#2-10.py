#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#2-10 TiProxy IDC Peak dataset) - Threads vs Req/sec and Avg Latency.

Dataset (multi_thread_multi_conn rows):
 Threads |   RPS    | Avg_ms
      1  |   387.88 |  2.577
    100  |  5138.88 | 17.144
    200  |  4358.89 | 38.158
    250  |  5446.26 | 35.572
    500  |  3845.41 | 85.351
    750  |  2944.66 | 36.464
   1000  |  3476.31 | 31.195

Features:
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s placeholder=0.0)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline dashed line + per-bar delta annotations (>=100)
 - Dual-axis matplotlib (bars=RPS, line=latency)
 - Observations (English) + Chinese summary lines; plot text English only.

Output: #2-10.png
"""
from __future__ import annotations

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,     387.88,  2.577, 0.0),
    (100,  5138.88, 17.144, 0.0),
    (200,  4358.89, 38.158, 0.0),
    (250,  5446.26, 35.572, 0.0),
    (500,  3845.41, 85.351, 0.0),
    (750,  2944.66, 36.464, 0.0),
    (1000, 3476.31, 31.195, 0.0),
]

PNG_NAME = "#2-10.png"


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
    ax1.set_title("#2-10 TiProxy multi_thread_multi_conn Scaling (Peak)")

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
    print("#2-10 multi_thread_multi_conn dataset (TiProxy IDC Peak):")
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
    rmap = {t: rps for t, rps, *_ in DATA}
    def d(t):
        return (rmap[t]-base_rps)/base_rps*100 if base_rps and t!=100 else 0.0

    print("\nObservations:")
    print(" - Baseline 100T = {:.2f} req/sec @17.14 ms; 250T peak {:.2f} (+{:.1f}%) despite higher latency 35.57 ms".format(base_rps, rmap[250], d(250)))
    print(" - 200T regression: {:.2f} (-{:.1f}% vs baseline) with latency jump 38.16 ms indicates early contention".format(rmap[200], -d(200)))
    print(" - Latency spike at 500T (85.35 ms) while throughput drops -25.2%; subsequent latency improves (36.46 ms @750, 31.20 ms @1000) but RPS remains below baseline")
    print(" - Non-monotonic pattern suggests scheduling / queueing burst then backpressure reducing effective concurrency after 500T")
    print(" - Efficiency erosion: 51.39 (100T) -> 21.79 (250T peak) -> 7.69 (500T) -> 3.48 (1000T)")
    print(" - Recommendation: operate near 100T for efficiency or 250T for max throughput if doubled latency acceptable; avoid ≥500T until latency root cause (lock, network, Proxy scheduling) addressed")
    print("\n摘要 (繁體中文):")
    print(" - 250T 峰值 +{:.1f}% vs 100T, 延遲翻倍 -> 視 SLA 決定是否採用".format(d(250)))
    print(" - 200T 退化顯示過早資源競爭, 500T 大幅延遲激增需排查")
    print(" - 建議聚焦 100T (效率) 與 250T (峰值), 避免 500T 以上負載")

    make_plot(DATA)


if __name__ == "__main__":
    main()
