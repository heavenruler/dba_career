#!/usr/bin/env python3
"""Plot Sysbench (Label Isolation) results for scenario #1 TiDB (IDC *3 + GCP *3 isolation) as a line chart.

Source table excerpt (focus columns):
OLTP Type, 95th percentile latency (ms), Queries per second, Transactions per second (TPS)

Rows:
- oltp_read_only        95p=82.96   QPS=2087.83   TPS=130.49
- oltp_read_write       95p=106.75  QPS=1950.36   TPS=97.52
- oltp_write_only       95p=25.74   QPS=2324.89   TPS=387.48
- select_random_points  95p=7.56    QPS=1975.64   TPS=1975.64   (point selects: QPS == TPS)
- select_random_ranges  95p=6.91    QPS=1922.42   TPS=1922.42   (range selects: QPS == TPS)

Output: sysbench_results_#1_tidb_summary.png

Usage:
  python sysbench_results_#1_tidb.py            # create PNG
  python sysbench_results_#1_tidb.py --show     # also print table
  python sysbench_results_#1_tidb.py --svg      # additionally emit SVG

If matplotlib is missing, a clear message is printed.
"""
from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from typing import List

try:
    import matplotlib.pyplot as plt
except Exception as e:  # pragma: no cover - optional dependency
    plt = None
    _matplotlib_err = e
else:
    _matplotlib_err = None

@dataclass
class WorkloadRow:
    name: str
    p95_ms: float
    qps: float
    tps: float

DATA: List[WorkloadRow] = [
    WorkloadRow("oltp_read_only", 82.96, 2087.83, 130.49),
    WorkloadRow("oltp_read_write", 106.75, 1950.36, 97.52),
    WorkloadRow("oltp_write_only", 25.74, 2324.89, 387.48),
    WorkloadRow("select_random_points", 7.56, 1975.64, 1975.64),
    WorkloadRow("select_random_ranges", 6.91, 1922.42, 1922.42),
]

PNG_NAME = "sysbench_results_#1_tidb_summary.png"
SVG_NAME = "sysbench_results_#1_tidb_summary.svg"


def as_table() -> str:
    lines = []
    header = ["OLTP Type", "p95(ms)", "QPS", "TPS", "QPS/TPS Ratio"]
    rows = []
    for r in DATA:
        ratio = r.qps / r.tps if r.tps else 0.0
        rows.append([
            r.name,
            f"{r.p95_ms:.2f}",
            f"{r.qps:.2f}",
            f"{r.tps:.2f}",
            f"{ratio:.2f}",
        ])
    widths = [max(len(header[i]), *(len(row[i]) for row in rows)) for i in range(len(header))]
    fmt = lambda row: " | ".join(row[i].ljust(widths[i]) for i in range(len(row)))
    lines.append(fmt(header))
    lines.append("-+-".join('-'*w for w in widths))
    for r in rows:
        lines.append(fmt(r))
    return "\n".join(lines)


def plot():  # pragma: no cover - visual output
    """Render chart with QPS/TPS as grouped bars and 95p latency as overlay line."""
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_matplotlib_err}")
        return False

    names = [r.name for r in DATA]
    p95 = [r.p95_ms for r in DATA]
    qps = [r.qps for r in DATA]
    tps = [r.tps for r in DATA]

    fig, ax_thr = plt.subplots(figsize=(11, 5.4))
    ax_lat = ax_thr.twinx()

    x = list(range(len(names)))
    width = 0.32
    bar_q = ax_thr.bar([i - width/2 for i in x], qps, width=width, color="#1f77b4", label="QPS", alpha=0.85)
    bar_t = ax_thr.bar([i + width/2 for i in x], tps, width=width, color="#2ca02c", label="TPS", alpha=0.80)

    # Latency line (secondary axis)
    ax_lat.plot(x, p95, color="#d62728", marker="o", linewidth=2, label="95p Latency (ms)")

    # Axes labels
    ax_thr.set_ylabel("Throughput (ops/sec)", color="#1f77b4")
    ax_lat.set_ylabel("95th percentile latency (ms)", color="#d62728")
    ax_thr.tick_params(axis='y', labelcolor="#1f77b4")
    ax_lat.tick_params(axis='y', labelcolor="#d62728")
    ax_thr.set_xticks(x)
    ax_thr.set_xticklabels([n.replace('_', '\n') for n in names])

    # Annotate bars (QPS & TPS) and latency points
    for b in bar_q:
        ax_thr.text(b.get_x() + b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}", ha='center', va='bottom', fontsize=8, color="#1f77b4")
    for b in bar_t:
        ax_thr.text(b.get_x() + b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}", ha='center', va='bottom', fontsize=8, color="#2ca02c")
    for xi, val in enumerate(p95):
        ax_lat.text(xi, val * 1.03, f"{val:.1f}", ha='center', va='bottom', fontsize=8, color="#d62728")

    ax_thr.set_title('Sysbench Scenario #1 (TiDB) - QPS/TPS Bars + 95p Latency Line')
    ax_thr.grid(axis='y', linestyle='--', alpha=0.35)

    # Build combined legend manually
    handles = [bar_q, bar_t, ax_lat.lines[0]]
    labels = [h.get_label() for h in handles]
    ax_thr.legend(handles, labels, loc='upper center', ncol=3, fontsize=9, frameon=False)

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot sysbench results (#1 TiDB isolation).')
    ap.add_argument('--show', action='store_true', help='Print table to stdout')
    ap.add_argument('--svg', action='store_true', help='Also export SVG')
    args = ap.parse_args()

    if args.show:
        print(as_table())

    ok = plot()
    if ok and args.svg and plt is not None:
        import matplotlib.pyplot as plt  # ensure available
        plt.gcf().savefig(SVG_NAME)
        print(f"[OK] Saved {SVG_NAME}")

if __name__ == '__main__':
    main()
