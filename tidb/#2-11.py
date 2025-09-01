#!/usr/bin/env python3
"""
Plot multi_thread_multi_conn performance (#2-11 TiDB GCP Peak dataset) - Threads vs Req/sec and Avg Latency.

Dataset provided (multi_thread_multi_conn rows extracted):
 Threads | RPS      | Avg_ms
      1  |    883.76 |   1.131
    100  |   2937.60 |  30.208
    200  |   7074.92 |  20.115
    250  |   2741.13 |  71.075
    500  |   5445.14 |  24.492
    750  |   1990.58 |  20.781
   1000  |   3300.35 |   6.979

Template features (same style as #2-9):
 - DATA constant (threads, req_per_sec, avg_resp_ms, total_time_s placeholder=0 for unknown exact)
 - ASCII table: Threads | Req/sec | Avg_ms | Req/sec/Thread | ΔRPS_vs100%
 - 100-thread baseline (dashed line + per-bar delta annotations for >=100 threads)
 - Dual-axis matplotlib (bars=RPS, line=latency)
 - Observations / recommendations (English) + concise analysis notes (Chinese) – English only in plot text.

Output: #2-11.png
"""
from __future__ import annotations

# (threads, req_per_sec, avg_resp_ms, total_time_s)
DATA = [
    (1,     883.76,  1.131, 0.0),
    (100,  2937.60, 30.208, 0.0),
    (200,  7074.92, 20.115, 0.0),
    (250,  2741.13, 71.075, 0.0),
    (500,  5445.14, 24.492, 0.0),
    (750,  1990.58, 20.781, 0.0),
    (1000, 3300.35,  6.979, 0.0),
]

PNG_NAME = "#2-11.png"


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
        " | " .join(headers[i].ljust(col_widths[i]) for i in range(len(headers))),
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
    ax1.set_title("#2-11 multi_thread_multi_conn Scaling (GCP Peak)")

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
    print("#2-11 multi_thread_multi_conn dataset (GCP Peak):")
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

    print("\nObservations:")
    print(" - Peak at {} threads ({:.2f} req/sec) = +{:.1f}% over 100-thread baseline ({:.2f})".format(peak_threads, peak_rps, (peak_rps/base_rps -1)*100 if base_rps else 0, base_rps))
    print(" - Latency improves from 30.21 ms @100T to 20.12 ms @200T while RPS +{:.1f}% -> strong scaling under peak.".format((r[200]/base_rps -1)*100))
    print(" - 250T regression: 2741.13 ({:+.1f}% vs baseline, -{:.1f}% vs peak) latency spike 71.08 ms suggests contention / queue saturation.".format(d(250), (peak_rps-2741.13)/peak_rps*100))
    print(" - 500T recovers: 5445.14 ({:+.1f}%) still -{:.1f}% vs peak; latency moderate 24.49 ms.".format(d(500), (peak_rps-5445.14)/peak_rps*100))
    print(" - 750T / 1000T inconsistent: 1990.58 ({:+.1f}%) then rebound 3300.35 ({:+.1f}%). Investigate scheduler / GC / network variance.".format(d(750), d(1000)))
    print(" - Efficiency erosion: 29.38 (100T) -> 35.37 (200T peak eff) -> ~10.9 (250-500T) -> 2.65 (750T) -> 3.30 (1000T).")
    print(" - Recommendation: cap concurrency near 200T for peak, monitor at 500T; treat 250T spike as anomaly; analyze metrics (lock wait, region hotspot, GC) during 250T run.")
    print("\n摘要 (繁體中文):")
    print(" - 峰值 200T RPS +{:.1f}% 且延遲下降 (30ms -> 20ms) 表現最佳".format((r[200]/base_rps -1)*100))
    print(" - 250T 出現延遲暴衝 71ms 並跌回 baseline 附近, 需檢視鎖 / 排程 / 熱點")
    print(" - 500T RPS 仍高 (+{:.1f}%) 可作為次佳併發, 但效率已明顯下降".format(d(500)))
    print(" - 750T~1000T 波動加大 顯示系統瓶頸 / 資源調度不穩, 建議營運落在 200T 或 500T 以下")

    make_plot(DATA)


if __name__ == "__main__":
    main()
