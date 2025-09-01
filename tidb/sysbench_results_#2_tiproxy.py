#!/usr/bin/env python3
"""Plot Sysbench Scenario #2 (TiProxy) results as line charts.

Scenario #2 numbers (IDC *3 baseline, TiProxy) - from markdown table:
Workload               p95(ms)   QPS       TPS
oltp_read_only         81.48     3254.39   203.40
oltp_read_write        110.66    2550.61   127.53
oltp_write_only        43.39     1576.06   262.68
select_random_points   18.61     594.02    594.02
select_random_ranges   16.12     676.82    676.82

Chart:
  - Three lines: QPS, TPS (left Y); p95 latency (right Y).
  - Markers + value annotations.

Outputs:
  sysbench_results_#2_tiproxy_summary.png
  (optional) sysbench_results_#2_tiproxy_summary.svg

Usage:
  python sysbench_results_#2_tiproxy.py            # generate PNG
  python sysbench_results_#2_tiproxy.py --show     # print table then generate
  python sysbench_results_#2_tiproxy.py --svg      # also export SVG
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
    Row("oltp_read_only", 81.48, 3254.39, 203.40),
    Row("oltp_read_write", 110.66, 2550.61, 127.53),
    Row("oltp_write_only", 43.39, 1576.06, 262.68),
    Row("select_random_points", 18.61, 594.02, 594.02),
    Row("select_random_ranges", 16.12, 676.82, 676.82),
]

PNG_NAME = "sysbench_results_#2_tiproxy_summary.png"
SVG_NAME = "sysbench_results_#2_tiproxy_summary.svg"


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
    fig, ax_thr = plt.subplots(figsize=(10.8, 5.0))
    ax_lat = ax_thr.twinx()

    l_qps = ax_thr.plot(x, qps, marker='o', linewidth=2, color="#1f77b4", label="QPS")
    l_tps = ax_thr.plot(x, tps, marker='s', linewidth=2, color="#2ca02c", label="TPS")
    l_p95 = ax_lat.plot(x, p95, marker='D', linewidth=2, color="#d62728", label="95p Latency (ms)")

    ax_thr.set_xticks(x)
    ax_thr.set_xticklabels([n.replace('_', '\n') for n in names])
    ax_thr.set_ylabel("Throughput (ops/sec)", color="#1f77b4")
    ax_lat.set_ylabel("95th percentile latency (ms)", color="#d62728")
    ax_thr.tick_params(axis='y', labelcolor="#1f77b4")
    ax_lat.tick_params(axis='y', labelcolor="#d62728")
    ax_thr.grid(axis='y', linestyle='--', alpha=0.35)
    ax_thr.set_title('Sysbench Scenario #2 (TiProxy) - QPS/TPS & 95p Latency Lines')

    # Annotations
    for xi, val in enumerate(qps):
        ax_thr.text(xi, val*1.015, f"{val:.0f}", ha='center', va='bottom', fontsize=8, color="#1f77b4")
    for xi, val in enumerate(tps):
        ax_thr.text(xi, val*1.015, f"{val:.0f}", ha='center', va='bottom', fontsize=8, color="#2ca02c")
    for xi, val in enumerate(p95):
        ax_lat.text(xi, val*1.03, f"{val:.1f}", ha='center', va='bottom', fontsize=8, color="#d62728")

    handles = l_qps + l_tps + l_p95
    labels = [h.get_label() for h in handles]
    ax_thr.legend(handles, labels, loc='upper center', ncol=3, fontsize=9, frameon=False)

    fig.tight_layout()
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot sysbench scenario #2 (TiProxy) line charts.')
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
