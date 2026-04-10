#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#2-12 TiProxy GCP Peak dataset) - Threads vs Req/sec and Avg Latency.

Dataset provided (multi_thread_multi_conn rows extracted):
 Threads |   RPS    |  Avg_ms | Total_Time_s (as given) 
      1  |    29.19 |  34.252 | 342.529
    100  |  2843.08 |  33.849 |   3.517   *anomaly (avg_ms * N ~= 338s expected)
    200  |  4615.91 |  34.944 |   2.166   *anomaly
    250  |  4977.37 |  37.116 |   2.009   *anomaly
    500  |  4391.55 |  45.609 |   2.277   *anomaly
    750  |  3779.19 |  45.643 |   2.646   *anomaly
   1000  |  3163.10 |  43.773 |   3.161   *anomaly

Notes:
 - Total_Time_s values (>=100 threads) are inconsistent with Avg_ms; treat as anomalies (likely units mismatch or truncated output segment).
 - We still display the raw numbers but flag anomaly heuristically.

Template features (mirrors #2-11 style):
 - DATA constant: (threads, req_per_sec, avg_resp_ms, total_time_s)
 - ascii_table(): Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100% | anomaly
 - analyze(): peak throughput, best per-thread efficiency (>1 thread), scaling ratios vs 100-thread baseline
 - matplotlib dual-axis chart (bars=RPS, line=latency) with baseline and delta annotations
 - Observations + Chinese summary

Output: #2-12.png
"""
from __future__ import annotations

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,     29.19,   34.252, 342.529),
    (100, 2843.08,   33.849,   3.517),
    (200, 4615.91,   34.944,   2.166),
    (250, 4977.37,   37.116,   2.009),
    (500, 4391.55,   45.609,   2.277),
    (750, 3779.19,   45.643,   2.646),
    (1000, 3163.10,  43.773,   3.161),
]

PNG_NAME = "#2-12.png"


def _expected_total_time(avg_ms: float, total_tests: int = 10000) -> float:
    return (avg_ms / 1000.0) * total_tests


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
    # anomaly detection (compare given total_time vs expected from avg_ms)
    anomalies = {}
    for t, rps, avg_ms, real_t in data:
        expected = _expected_total_time(avg_ms)
        if real_t:  # avoid div by zero
            diff_ratio = abs(expected - real_t) / expected
            anomalies[t] = diff_ratio > 0.5 and t >= 100  # mark only for >=100 to avoid 1-thread huge baseline skew
        else:
            anomalies[t] = True
    return {"peak": peak, "best_eff": best_eff, "scaling": scaling, "anomalies": anomalies}


def ascii_table(data):
    base = next((r[1] for r in data if r[0] == 100), None)
    headers = ["Threads", "Req/sec", "Avg_ms", "Req/sec/Thread", "ΔRPS_vs100%", "Anom"]
    rows = []
    for t, rps, avg_ms, total_time in data:
        eff = rps / t
        delta_pct = (rps - base) / base * 100.0 if base and t != 100 else 0.0
        expected = _expected_total_time(avg_ms)
        anomaly = abs(expected - total_time) / expected > 0.5 and t >= 100
        rows.append((t, rps, avg_ms, eff, delta_pct, "Y" if anomaly else ""))

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
        print("[WARN] matplotlib not available, skipping PNG generation. Install with: pip install matplotlib")
        return False

    threads = [r[0] for r in data]
    rps = [r[1] for r in data]
    avg_ms = [r[2] for r in data]

    fig, ax1 = plt.subplots(figsize=(9, 5))
    bars = ax1.bar([str(t) for t in threads], rps, color="#1f77b4", alpha=0.75, label="Req/sec")
    ax1.set_xlabel("Threads")
    ax1.set_ylabel("Requests per second")
    ax1.set_title("#2-12 multi_thread_multi_conn Scaling (TiProxy GCP Peak)")

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
    print("#2-12 multi_thread_multi_conn dataset (TiProxy GCP Peak):")
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
    r = {t: rps for t, rps, *_ in DATA}
    def d(t):
        return (r[t] - base_rps)/base_rps*100 if base_rps and t != 100 else 0.0

    # Observations
    print("\nObservations:")
    print(" - Peak throughput at {} threads ({:.2f} req/sec) = +{:.1f}% over 100-thread baseline ({:.2f}).".format(
        peak_threads, peak_rps, (peak_rps/base_rps -1)*100 if base_rps else 0, base_rps))
    print(" - Throughput climbs from 2843 (100T) -> 4616 (200T) -> 4977 (250T) with modest latency rise (33.8 -> 37.1 ms).")
    print(" - After peak, RPS declines: 4392 (500T), 3779 (750T), 3163 (1000T); latency worsens to ~45 ms region.")
    print(" - Per-thread efficiency erodes continuously (28.43 @100T -> 19.91 @250T -> 8.78 @500T -> 3.16 @1000T).")
    print(" - Anomalous total_time_s values (>=100T) suggest measurement artifact (possibly reporting only active phase).")
    print(" - Recommend capping at ~250T for max throughput or ~200T for slightly lower latency with ~93% of peak RPS.")

    print("\n摘要 (繁體中文):")
    print(" - 峰值於 250T (~4977 RPS, 較 100T +{:.1f}%)，延遲僅略升".format(d(250)))
    print(" - 200T 仍保有 {:.1f}% 增益且延遲較 250T 更低，適合作為穩定高效併發點".format(d(200)))
    print(" - 500T 以上吞吐遞減且效率快速衰退，建議避免超過 250T 持續運行")
    print(" - total_time_s 顯示異常，需重新驗證壓測工具統計方式")

    make_plot(DATA)


if __name__ == "__main__":
    main()
