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
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_matplotlib_err}")
        return False

    names = [r.name for r in DATA]
    p95 = [r.p95_ms for r in DATA]
    qps = [r.qps for r in DATA]
    tps = [r.tps for r in DATA]

    # Because QPS/TPS numeric ranges differ strongly from latency, use two y-axes.
    fig, ax_left = plt.subplots(figsize=(10.5, 5.2))
    ax_right = ax_left.twinx()

    x = range(len(names))

    # Left axis: latency
    ax_left.plot(x, p95, marker='o', color='#d62728', label='95th Latency (ms)')
    ax_left.set_ylabel('95th percentile latency (ms)', color='#d62728')
    ax_left.tick_params(axis='y', labelcolor='#d62728')
    ax_left.set_xticks(list(x))
    ax_left.set_xticklabels([n.replace('_', '\n') for n in names], rotation=0)

    # Right axis: throughput
    ax_right.plot(x, qps, marker='s', color='#1f77b4', label='QPS')
    ax_right.plot(x, tps, marker='^', color='#2ca02c', label='TPS')
    ax_right.set_ylabel('Throughput (ops/sec)', color='#1f77b4')
    ax_right.tick_params(axis='y', labelcolor='#1f77b4')

    # Annotate points (optional concise labels)
    for xi, (p, q, t) in enumerate(zip(p95, qps, tps)):
        ax_left.text(xi, p * 1.02, f"{p:.1f}", ha='center', va='bottom', fontsize=8, color='#d62728')
        ax_right.text(xi, q * 1.01, f"Q{q:.0f}", ha='center', va='bottom', fontsize=7, color='#1f77b4')
        if abs(q - t) > 1:  # show TPS only if meaningfully different
            ax_right.text(xi, t * 0.99, f"T{t:.0f}", ha='center', va='top', fontsize=7, color='#2ca02c')

    ax_left.set_title('Sysbench Scenario #1 (TiDB) - Latency & Throughput (Label Isolation)')
    ax_left.grid(axis='y', linestyle='--', alpha=0.35)

    # Combined legend
    lines_left, labels_left = ax_left.get_legend_handles_labels()
    lines_right, labels_right = ax_right.get_legend_handles_labels()
    ax_left.legend(lines_left + lines_right, labels_left + labels_right, loc='upper center', ncol=3, fontsize=9, frameon=False)

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
