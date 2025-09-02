#!/usr/bin/env python3
"""Compare IDC*3 vs IDC*3+GCP*3 (Scenario #2 -> #1) raw QPS/TPS with percent deltas.

Baseline: Scenario #2 (IDC*3) datasets
Target:   Scenario #1 (IDC*3+GCP*3 simultaneous) datasets

Bars per workload (4): TiDB IDC, TiDB IDC+GCP, TiProxy IDC, TiProxy IDC+GCP
Annotations:
  Baseline bars show raw value only
  Target bars show raw value (first line) + delta vs baseline (second line, red + / green -)

Outputs:
  sysbench_idc_vs_idc_gcp_qps_tps.png
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


# Baseline IDC*3 (Scenario #2)
TIDB_IDC: Dict[str, M] = {
    "oltp_read_only": M(8584.75, 536.55),
    "oltp_read_write": M(6693.06, 334.65),
    "oltp_write_only": M(5848.28, 974.71),
    "select_random_points": M(3467.61, 3467.61),
    "select_random_ranges": M(4091.08, 4091.08),
}
TIPROXY_IDC: Dict[str, M] = {
    "oltp_read_only": M(8903.67, 556.48),
    "oltp_read_write": M(7019.79, 350.99),
    "oltp_write_only": M(5770.23, 961.70),
    "select_random_points": M(3509.69, 3509.69),
    "select_random_ranges": M(4143.52, 4143.52),
}

# Target IDC*3 + GCP*3 (Scenario #1) datasets
TIDB_IDC_GCP: Dict[str, M] = {
    "oltp_read_only": M(2087.83, 130.49),
    "oltp_read_write": M(1950.36, 97.52),
    "oltp_write_only": M(2324.89, 387.48),
    "select_random_points": M(1975.64, 1975.64),
    "select_random_ranges": M(1922.42, 1922.42),
}
TIPROXY_IDC_GCP: Dict[str, M] = {
    "oltp_read_only": M(1966.71, 122.92),
    "oltp_read_write": M(1893.37, 94.67),
    "oltp_write_only": M(2236.19, 372.70),
    "select_random_points": M(1748.93, 1748.93),
    "select_random_ranges": M(1725.76, 1725.76),
}

PNG_NAME = "sysbench_idc_vs_idc_gcp_qps_tps.png"


def pct(base: float, new: float) -> float:
    if base == 0:
        return 0.0
    return (new / base - 1.0) * 100.0


def table() -> str:
    header = [
        "Workload",
        "TiDB_IDC QPS", "TiDB_IDC+GCP QPS", "TiDB QPS %",
        "TiProxy_IDC QPS", "TiProxy_IDC+GCP QPS", "TiProxy QPS %",
        "TiDB_IDC TPS", "TiDB_IDC+GCP TPS", "TiDB TPS %",
        "TiProxy_IDC TPS", "TiProxy_IDC+GCP TPS", "TiProxy TPS %",
    ]
    body: List[List[str]] = []
    for w in WORKLOADS:
        tqb = TIDB_IDC[w].qps; tqt = TIDB_IDC_GCP[w].qps
        tpb = TIPROXY_IDC[w].qps; tpt = TIPROXY_IDC_GCP[w].qps
        ttb = TIDB_IDC[w].tps; ttt = TIDB_IDC_GCP[w].tps
        tpb2 = TIPROXY_IDC[w].tps; tpt2 = TIPROXY_IDC_GCP[w].tps
        body.append([
            w,
            f"{tqb:.2f}", f"{tqt:.2f}", f"{pct(tqb,tqt):+.1f}",
            f"{tpb:.2f}", f"{tpt:.2f}", f"{pct(tpb,tpt):+.1f}",
            f"{ttb:.2f}", f"{ttt:.2f}", f"{pct(ttb,ttt):+.1f}",
            f"{tpb2:.2f}", f"{tpt2:.2f}", f"{pct(tpb2,tpt2):+.1f}",
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

    c_tidb_base = "#1f77b4"; c_tidb_target = "#6baed6"
    c_tpx_base = "#ff7f0e"; c_tpx_target = "#ffbb78"

    def bars(ax, metric: str):
        def get(d, w):
            return getattr(d[w], metric)
        b1 = ax.bar([i - 1.5*width for i in x], [get(TIDB_IDC, w) for w in WORKLOADS], width, color=c_tidb_base, label='TiDB IDC')
        b2 = ax.bar([i - 0.5*width for i in x], [get(TIDB_IDC_GCP, w) for w in WORKLOADS], width, color=c_tidb_target, label='TiDB IDC+GCP')
        b3 = ax.bar([i + 0.5*width for i in x], [get(TIPROXY_IDC, w) for w in WORKLOADS], width, color=c_tpx_base, label='TiProxy IDC')
        b4 = ax.bar([i + 1.5*width for i in x], [get(TIPROXY_IDC_GCP, w) for w in WORKLOADS], width, color=c_tpx_target, label='TiProxy IDC+GCP')
        # baseline annotation
        for bars_ in (b1, b3):
            for bar in bars_:
                h = bar.get_height()
                ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{h:.0f}", ha='center', va='bottom', fontsize=7)
        # target annotation with delta color-coded
        for idx in range(len(WORKLOADS)):
            # TiDB
            h_base = b1[idx].get_height(); h_tar = b2[idx].get_height()
            p = pct(h_base, h_tar)
            color = '#d62728' if p > 0 else '#2ca02c'
            ax.text(b2[idx].get_x()+b2[idx].get_width()/2, h_tar*1.005, f"{h_tar:.0f}", ha='center', va='bottom', fontsize=7)
            ax.text(b2[idx].get_x()+b2[idx].get_width()/2, h_tar*1.03, f"{p:+.1f}%", ha='center', va='bottom', fontsize=7, color=color)
            # TiProxy
            h_base_p = b3[idx].get_height(); h_tar_p = b4[idx].get_height()
            pp = pct(h_base_p, h_tar_p)
            colorp = '#d62728' if pp > 0 else '#2ca02c'
            ax.text(b4[idx].get_x()+b4[idx].get_width()/2, h_tar_p*1.005, f"{h_tar_p:.0f}", ha='center', va='bottom', fontsize=7)
            ax.text(b4[idx].get_x()+b4[idx].get_width()/2, h_tar_p*1.03, f"{pp:+.1f}%", ha='center', va='bottom', fontsize=7, color=colorp)
        ax.set_ylabel(metric.upper())
        ax.grid(axis='y', linestyle='--', alpha=0.3)
        return b1, b2, b3, b4

    bq1, bq2, bq3, bq4 = bars(ax_qps, 'qps')
    bt1, bt2, bt3, bt4 = bars(ax_tps, 'tps')
    ax_tps.set_xticks(x)
    ax_tps.set_xticklabels([w.replace('_', '\n') for w in WORKLOADS])

    fig.suptitle('IDC*3 -> IDC*3+GCP*3 Raw Throughput Impact (Scenario #2 vs #1)', y=0.97, fontsize=14)
    fig.legend([bq1, bq2, bq3, bq4], ['TiDB IDC', 'TiDB IDC+GCP', 'TiProxy IDC', 'TiProxy IDC+GCP'],
               loc='upper center', bbox_to_anchor=(0.5, 0.9), ncol=4, fontsize=10, frameon=False)
    fig.tight_layout(rect=(0, 0, 1, 0.86))
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot IDC vs IDC+GCP raw throughput with deltas.')
    ap.add_argument('--show', action='store_true', help='Print table to stdout')
    ap.add_argument('--svg', action='store_true', help='Also export SVG (same base name)')
    args = ap.parse_args()
    if args.show:
        print(table())
    if plot() and args.svg and plt is not None:
        import matplotlib.pyplot as plt  # noqa
        plt.gcf().savefig(PNG_NAME.replace('.png', '.svg'))
        print(f"[OK] Saved {PNG_NAME.replace('.png', '.svg')}")


if __name__ == '__main__':  # pragma: no cover
    main()
