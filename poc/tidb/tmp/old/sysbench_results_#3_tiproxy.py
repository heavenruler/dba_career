#!/usr/bin/env python3
"""Plot Sysbench Scenario #3 (TiProxy) results.

Style requirement: QPS/TPS grouped bars; 95p latency line on twin axis.

Scenario #3 numbers (IDC *3 同時執行 TiProxy perspective):
Workload               p95(ms)   QPS       TPS
oltp_read_only         87.56     1959.76   122.49
oltp_read_write        110.66    1866.93   93.35
oltp_write_only        27.17     2190.04   365.01
select_random_points   8.13      1690.04   1690.04
select_random_ranges   7.30      1800.92   1800.92

Usage:
    python sysbench_results_#3_tiproxy.py            # generate PNG
    python sysbench_results_#3_tiproxy.py --show     # print table then generate
    python sysbench_results_#3_tiproxy.py --svg      # also export SVG
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
    Row("oltp_read_only", 87.56, 1959.76, 122.49),
    Row("oltp_read_write", 110.66, 1866.93, 93.35),
    Row("oltp_write_only", 27.17, 2190.04, 365.01),
    Row("select_random_points", 8.13, 1690.04, 1690.04),
    Row("select_random_ranges", 7.30, 1800.92, 1800.92),
]

PNG_NAME = "sysbench_results_#3_tiproxy_summary.png"
SVG_NAME = "sysbench_results_#3_tiproxy_summary.svg"


def table() -> str:
    header = ["Workload", "p95(ms)", "QPS", "TPS", "QPS/TPS"]
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
    """Create grouped bar chart for QPS/TPS with latency line."""
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False
    names = [r.name for r in DATA]
    p95 = [r.p95_ms for r in DATA]
    qps = [r.qps for r in DATA]
    tps = [r.tps for r in DATA]
    x = list(range(len(names)))
    width = 0.36

    fig, ax_thr = plt.subplots(figsize=(11.2, 5.2))
    ax_lat = ax_thr.twinx()

    bars_qps = ax_thr.bar([xi - width/2 for xi in x], qps, width, label="QPS", color="#1f77b4", alpha=0.85)
    bars_tps = ax_thr.bar([xi + width/2 for xi in x], tps, width, label="TPS", color="#2ca02c", alpha=0.85)
    line_p95, = ax_lat.plot(x, p95, marker='D', linewidth=2, color="#d62728", label="95p Latency (ms)")

    ax_thr.set_xticks(x)
    ax_thr.set_xticklabels([n.replace('_', '\n') for n in names])
    ax_thr.set_ylabel("Throughput (ops/sec)")
    ax_lat.set_ylabel("95th percentile latency (ms)", color="#d62728")
    ax_lat.tick_params(axis='y', labelcolor="#d62728")
    ax_thr.grid(axis='y', linestyle='--', alpha=0.35, linewidth=0.7)
    ax_thr.set_axisbelow(True)
    ax_thr.set_title('Sysbench Scenario #3 (TiProxy) - QPS/TPS Bars & 95p Latency Line')

    def annotate(bars, color):
        for b in bars:
            h = b.get_height()
            ax_thr.text(b.get_x() + b.get_width()/2, h*1.01, f"{h:.0f}", ha='center', va='bottom', fontsize=8, color=color)
    annotate(bars_qps, "#1f77b4")
    annotate(bars_tps, "#2ca02c")
    for xi, val in enumerate(p95):
        ax_lat.text(xi, val*1.05, f"{val:.1f}", ha='center', va='bottom', fontsize=8, color="#d62728")

    handles = [bars_qps, bars_tps, line_p95]
    labels = [h.get_label() for h in handles]
    ax_thr.legend(handles, labels, loc='upper center', ncol=3, fontsize=9, frameon=False)

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot sysbench scenario #3 (TiProxy) QPS/TPS bars + latency line.')
    ap.add_argument('--show', action='store_true', help='Print table to stdout')
    ap.add_argument('--svg', action='store_true', help='Also export SVG')
    args = ap.parse_args()
    if args.show:
        print(table())
    if plot() and args.svg and plt is not None:
        import matplotlib.pyplot as plt  # noqa
        plt.gcf().savefig(SVG_NAME)
        print(f"[OK] Saved {SVG_NAME}")


if __name__ == '__main__':  # pragma: no cover
    main()
