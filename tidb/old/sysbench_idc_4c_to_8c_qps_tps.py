#!/usr/bin/env python3
"""IDC *3 4vCPU -> 8vCPU scale-up raw QPS/TPS comparison (no latency, no % deltas).

For each workload we show 4 bars:
  TiDB 4c, TiDB 8c, TiProxy 4c, TiProxy 8c

Two stacked subplots:
  Top: QPS
  Bottom: TPS

Outputs:
  sysbench_idc_4c_to_8c_qps_tps.png
  (optional) sysbench_idc_4c_to_8c_qps_tps.svg

Usage:
  python sysbench_idc_4c_to_8c_qps_tps.py            # generate PNG
  python sysbench_idc_4c_to_8c_qps_tps.py --show     # print raw table
  python sysbench_idc_4c_to_8c_qps_tps.py --svg      # also export SVG
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import Dict, List

try:
    import matplotlib.pyplot as plt
except Exception as e:  # pragma: no cover
    plt = None
    _mpl_err = e
else:
    _mpl_err = None


WORKLOADS = [
    "oltp_read_only",
    "oltp_read_write",
    "oltp_write_only",
    "select_random_points",
    "select_random_ranges",
]


@dataclass
class M:
    qps: float
    tps: float


# 4c (Scenario #2) datasets
TIDB_4C: Dict[str, M] = {
    "oltp_read_only": M(8584.75, 536.55),
    "oltp_read_write": M(6693.06, 334.65),
    "oltp_write_only": M(5848.28, 974.71),
    "select_random_points": M(3467.61, 3467.61),
    "select_random_ranges": M(4091.08, 4091.08),
}

TIPROXY_4C: Dict[str, M] = {
    "oltp_read_only": M(8903.67, 556.48),
    "oltp_read_write": M(7019.79, 350.99),
    "oltp_write_only": M(5770.23, 961.70),
    "select_random_points": M(3509.69, 3509.69),
    "select_random_ranges": M(4143.52, 4143.52),
}

# 8c (Scenario #19) datasets
TIDB_8C: Dict[str, M] = {
    "oltp_read_only": M(10349.42, 646.84),
    "oltp_read_write": M(8579.39, 428.97),
    "oltp_write_only": M(7846.96, 1307.83),
    "select_random_points": M(4441.26, 4441.26),
    "select_random_ranges": M(4843.63, 4843.63),
}

TIPROXY_8C: Dict[str, M] = {
    "oltp_read_only": M(8449.29, 528.08),
    "oltp_read_write": M(7387.28, 369.36),
    "oltp_write_only": M(6945.77, 1157.63),
    "select_random_points": M(4113.32, 4113.32),
    "select_random_ranges": M(4495.30, 4495.30),
}

PNG_NAME = "sysbench_idc_4c_to_8c_qps_tps.png"
SVG_NAME = "sysbench_idc_4c_to_8c_qps_tps.svg"


def table() -> str:
    header = [
        "Workload",
        "TiDB4c QPS", "TiDB8c QPS", "TiProxy4c QPS", "TiProxy8c QPS",
        "TiDB4c TPS", "TiDB8c TPS", "TiProxy4c TPS", "TiProxy8c TPS",
    ]
    body: List[List[str]] = []
    for w in WORKLOADS:
        body.append([
            w,
            f"{TIDB_4C[w].qps:.2f}", f"{TIDB_8C[w].qps:.2f}", f"{TIPROXY_4C[w].qps:.2f}", f"{TIPROXY_8C[w].qps:.2f}",
            f"{TIDB_4C[w].tps:.2f}", f"{TIDB_8C[w].tps:.2f}", f"{TIPROXY_4C[w].tps:.2f}", f"{TIPROXY_8C[w].tps:.2f}",
        ])
    widths = [max(len(header[i]), *(len(r[i]) for r in body)) for i in range(len(header))]

    def fmt(row):
        return " | ".join(row[i].ljust(widths[i]) for i in range(len(row)))

    out = [fmt(header), "-+-".join('-'*w for w in widths)]
    out.extend(fmt(r) for r in body)
    return "\n".join(out)


def plot():  # pragma: no cover
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False
    x = list(range(len(WORKLOADS)))
    width = 0.18

    fig, (ax_qps, ax_tps) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)

    # Colors
    c_tidb4 = "#1f77b4"
    c_tidb8 = "#6baed6"
    c_tpx4 = "#ff7f0e"
    c_tpx8 = "#ffbb78"

    def bars(ax, metric: str):
        def get(d, w):
            return getattr(d[w], metric)
        b1 = ax.bar([i - 1.5*width for i in x], [get(TIDB_4C, w) for w in WORKLOADS], width, label='TiDB 4c', color=c_tidb4)
        b2 = ax.bar([i - 0.5*width for i in x], [get(TIDB_8C, w) for w in WORKLOADS], width, label='TiDB 8c', color=c_tidb8)
        b3 = ax.bar([i + 0.5*width for i in x], [get(TIPROXY_4C, w) for w in WORKLOADS], width, label='TiProxy 4c', color=c_tpx4)
        b4 = ax.bar([i + 1.5*width for i in x], [get(TIPROXY_8C, w) for w in WORKLOADS], width, label='TiProxy 8c', color=c_tpx8)

        # Annotate baseline (4c) with single-line raw value
        for bars in (b1, b3):
            for bar in bars:
                h = bar.get_height()
                ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{h:.0f}", ha='center', va='bottom', fontsize=7)

        # Annotate 8c with raw value + second line percent delta vs respective 4c
    for idx in range(len(WORKLOADS)):
        # TiDB delta
        h4 = b1[idx].get_height(); h8 = b2[idx].get_height()
        pct = (h8 / h4 - 1.0) * 100 if h4 else 0.0
        x_center = b2[idx].get_x()+b2[idx].get_width()/2
        ax.text(x_center, h8*1.005, f"{h8:.0f}", ha='center', va='bottom', fontsize=7)
        ax.text(x_center, h8*1.005 + (ax.get_ylim()[1]-ax.get_ylim()[0])*0.01, f"{pct:+.1f}%",
            ha='center', va='bottom', fontsize=7, color=('#d62728' if pct >= 0 else '#2ca02c'))
        # TiProxy delta
        h4p = b3[idx].get_height(); h8p = b4[idx].get_height()
        pctp = (h8p / h4p - 1.0) * 100 if h4p else 0.0
        x_center_p = b4[idx].get_x()+b4[idx].get_width()/2
        ax.text(x_center_p, h8p*1.005, f"{h8p:.0f}", ha='center', va='bottom', fontsize=7)
        ax.text(x_center_p, h8p*1.005 + (ax.get_ylim()[1]-ax.get_ylim()[0])*0.01, f"{pctp:+.1f}%",
            ha='center', va='bottom', fontsize=7, color=('#d62728' if pctp >= 0 else '#2ca02c'))

        ax.set_ylabel(metric.upper())
        ax.grid(axis='y', linestyle='--', alpha=0.3)
        return b1, b2, b3, b4

    bq1, bq2, bq3, bq4 = bars(ax_qps, 'qps')
    bt1, bt2, bt3, bt4 = bars(ax_tps, 'tps')

    ax_tps.set_xticks(x)
    ax_tps.set_xticklabels([w.replace('_', '\n') for w in WORKLOADS])

    # Title + legend spacing: place legend below title (no overlap)
    fig.suptitle('IDC *3 Scale-Up Raw Throughput (4vCPU vs 8vCPU)', y=0.97, fontsize=14)
    fig.legend([bq1, bq2, bq3, bq4], ["TiDB 4c", "TiDB 8c", "TiProxy 4c", "TiProxy 8c"],
               loc='upper center', bbox_to_anchor=(0.5, 0.905), ncol=4, fontsize=10, frameon=False)
    # Leave space at top for title + legend
    fig.tight_layout(rect=(0, 0, 1, 0.87))
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot raw QPS/TPS for 4c vs 8c (TiDB & TiProxy).')
    ap.add_argument('--show', action='store_true', help='Print raw table to stdout')
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
