#!/usr/bin/env python3
"""Plot Sysbench results for scenario #1 TiProxy (IDC*3 + GCP*3 isolation) with QPS/TPS bars and 95p latency line.

Source metrics (focus columns):
OLTP Type, 95th percentile latency (ms), Queries per second, Transactions per second.

Rows:
- oltp_read_only        95p=86.00   QPS=1966.71   TPS=122.92
- oltp_read_write       95p=108.68  QPS=1893.37   TPS=94.67
- oltp_write_only       95p=26.68   QPS=2236.19   TPS=372.70
- select_random_points  95p=7.84    QPS=1748.93   TPS=1748.93
- select_random_ranges  95p=7.56    QPS=1725.76   TPS=1725.76

Output: sysbench_results_#1_tiproxy_summary.png
Usage:
  python sysbench_results_#1_tiproxy.py --show [--svg]
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import List

try:
    import matplotlib.pyplot as plt
except Exception as e:  # pragma: no cover
    plt = None
    _mpl_err = e
else:
    _mpl_err = None

@dataclass
class Row:
    name: str
    p95_ms: float
    qps: float
    tps: float

DATA: List[Row] = [
    Row("oltp_read_only", 86.00, 1966.71, 122.92),
    Row("oltp_read_write", 108.68, 1893.37, 94.67),
    Row("oltp_write_only", 26.68, 2236.19, 372.70),
    Row("select_random_points", 7.84, 1748.93, 1748.93),
    Row("select_random_ranges", 7.56, 1725.76, 1725.76),
]

PNG_NAME = "sysbench_results_#1_tiproxy_summary.png"
SVG_NAME = "sysbench_results_#1_tiproxy_summary.svg"

def table() -> str:
    header = ["OLTP Type", "p95(ms)", "QPS", "TPS", "QPS/TPS"]
    rows = []
    for r in DATA:
        ratio = r.qps / r.tps if r.tps else 0
        rows.append([
            r.name,
            f"{r.p95_ms:.2f}",
            f"{r.qps:.2f}",
            f"{r.tps:.2f}",
            f"{ratio:.2f}",
        ])
    widths = [max(len(header[i]), *(len(row[i]) for row in rows)) for i in range(len(header))]
    def fmt(row):
        return " | ".join(row[i].ljust(widths[i]) for i in range(len(row)))
    out = [fmt(header), "-+-".join('-'*w for w in widths)]
    out.extend(fmt(r) for r in rows)
    return "\n".join(out)

def plot():  # pragma: no cover
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False
    names = [r.name for r in DATA]
    p95 = [r.p95_ms for r in DATA]
    qps = [r.qps for r in DATA]
    tps = [r.tps for r in DATA]

    fig, ax_thr = plt.subplots(figsize=(11, 5.4))
    ax_lat = ax_thr.twinx()

    x = list(range(len(names)))
    width = 0.32
    bars_q = ax_thr.bar([i - width/2 for i in x], qps, width=width, color="#1f77b4", alpha=0.85, label="QPS")
    bars_t = ax_thr.bar([i + width/2 for i in x], tps, width=width, color="#2ca02c", alpha=0.80, label="TPS")

    line_lat, = ax_lat.plot(x, p95, color="#d62728", marker='o', linewidth=2, label="95p Latency (ms)")

    ax_thr.set_ylabel("Throughput (ops/sec)", color="#1f77b4")
    ax_lat.set_ylabel("95th percentile latency (ms)", color="#d62728")
    ax_thr.set_xticks(x)
    ax_thr.set_xticklabels([n.replace('_', '\n') for n in names])
    ax_thr.tick_params(axis='y', labelcolor="#1f77b4")
    ax_lat.tick_params(axis='y', labelcolor="#d62728")

    for b in bars_q:
        ax_thr.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}", ha='center', va='bottom', fontsize=8, color="#1f77b4")
    for b in bars_t:
        ax_thr.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}", ha='center', va='bottom', fontsize=8, color="#2ca02c")
    for xi, val in enumerate(p95):
        ax_lat.text(xi, val*1.03, f"{val:.1f}", ha='center', va='bottom', fontsize=8, color="#d62728")

    ax_thr.set_title('Sysbench Scenario #1 (TiProxy) - QPS/TPS Bars + 95p Latency Line')
    ax_thr.grid(axis='y', linestyle='--', alpha=0.35)

    ax_thr.legend([bars_q, bars_t, line_lat], ["QPS", "TPS", "95p Latency (ms)"], loc='upper center', ncol=3, fontsize=9, frameon=False)

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True

def main():
    ap = argparse.ArgumentParser(description='Plot sysbench results (#1 TiProxy isolation).')
    ap.add_argument('--show', action='store_true', help='Print table to stdout')
    ap.add_argument('--svg', action='store_true', help='Also export SVG')
    args = ap.parse_args()
    if args.show:
        print(table())
    if plot() and args.svg and plt is not None:
        import matplotlib.pyplot as plt  # noqa
        plt.gcf().savefig(SVG_NAME)
        print(f"[OK] Saved {SVG_NAME}")

if __name__ == '__main__':
    main()
