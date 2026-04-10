#!/usr/bin/env python3
"""Plot Sysbench Scenario #19 (TiProxy) results as bar (QPS/TPS) + line (p95) chart.

Environment: IDC * 3 (8vCPU 16GB RAM) TiProxy 連線

Dataset:
Workload               p95(ms)   QPS       TPS
oltp_read_only         19.65     8449.29   528.08
oltp_read_write        27.66     7387.28   369.36
oltp_write_only        8.90      6945.77   1157.63
select_random_points   3.07      4113.32   4113.32
select_random_ranges   2.52      4495.30   4495.30

Chart:
  - Grouped bars: QPS & TPS (left Y axis)
  - Line: p95 latency (right Y axis)
  - Value annotations on each bar + latency point

Outputs:
  sysbench_results_#19_tiproxy_summary.png
  (optional) sysbench_results_#19_tiproxy_summary.svg

Usage:
  python sysbench_results_#19_tiproxy.py            # generate PNG
  python sysbench_results_#19_tiproxy.py --show     # print table then generate
  python sysbench_results_#19_tiproxy.py --svg      # also export SVG
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
    Row("oltp_read_only", 19.65, 8449.29, 528.08),
    Row("oltp_read_write", 27.66, 7387.28, 369.36),
    Row("oltp_write_only", 8.90, 6945.77, 1157.63),
    Row("select_random_points", 3.07, 4113.32, 4113.32),
    Row("select_random_ranges", 2.52, 4495.30, 4495.30),
]

PNG_NAME = "sysbench_results_#19_tiproxy_summary.png"
SVG_NAME = "sysbench_results_#19_tiproxy_summary.svg"


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
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False
    names = [r.name for r in DATA]
    p95 = [r.p95_ms for r in DATA]
    qps = [r.qps for r in DATA]
    tps = [r.tps for r in DATA]

    x = list(range(len(names)))
    fig, ax_thr = plt.subplots(figsize=(11, 5.2))
    ax_lat = ax_thr.twinx()

    width = 0.32
    b_q = ax_thr.bar([i - width/2 for i in x], qps, width=width, color="#1f77b4", alpha=0.85, label="QPS")
    b_t = ax_thr.bar([i + width/2 for i in x], tps, width=width, color="#2ca02c", alpha=0.80, label="TPS")
    l_p, = ax_lat.plot(x, p95, color="#d62728", marker='o', linewidth=2, label="95p Latency (ms)")

    ax_thr.set_xticks(x)
    ax_thr.set_xticklabels([n.replace('_', '\n') for n in names])
    ax_thr.set_ylabel("Throughput (ops/sec)", color="#1f77b4")
    ax_lat.set_ylabel("95th percentile latency (ms)", color="#d62728")
    ax_thr.tick_params(axis='y', labelcolor="#1f77b4")
    ax_lat.tick_params(axis='y', labelcolor="#d62728")
    ax_thr.grid(axis='y', linestyle='--', alpha=0.35)
    ax_thr.set_title('Sysbench Scenario #19 (TiProxy IDC*3 8vCPU/16GB) - QPS/TPS Bars + 95p Latency Line')

    # Annotate bars
    for b in b_q:
        ax_thr.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}", ha='center', va='bottom', fontsize=8, color="#1f77b4")
    for b in b_t:
        ax_thr.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{b.get_height():.0f}", ha='center', va='bottom', fontsize=8, color="#2ca02c")
    for xi, val in enumerate(p95):
        ax_lat.text(xi, val*1.03, f"{val:.1f}", ha='center', va='bottom', fontsize=8, color="#d62728")

    ax_thr.legend([b_q, b_t, l_p], ["QPS", "TPS", "95p Latency (ms)"], loc='upper center', ncol=3, fontsize=9, frameon=False)

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot sysbench scenario #19 (TiProxy) bar+line chart.')
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
