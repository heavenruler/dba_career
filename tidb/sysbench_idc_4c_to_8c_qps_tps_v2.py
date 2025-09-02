#!/usr/bin/env python3
"""Variant: IDC *3 4vCPU -> 8vCPU raw QPS/TPS with smarter delta label placement.

Original script kept at sysbench_idc_4c_to_8c_qps_tps.py (unchanged).
This version avoids label overlap when the target (8c) bar is shorter (negative delta)
by placing both raw value & delta above the taller of the two bars.

Label rules:
  - Baseline (4c) bars: raw value centered above its own bar.
  - Target (8c) bars: two-line annotation (raw, delta%).
    * If 8c >= 4c: place just above 8c bar (raw then delta above it).
    * If 8c < 4c: place above baseline bar (raw then delta) so text does not sit inside tall baseline bar.
  - Delta color: red for positive, green for negative.

Outputs:
  sysbench_idc_4c_to_8c_qps_tps_v2.png
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

PNG_NAME = "sysbench_idc_4c_to_8c_qps_tps_v2.png"


def pct(base: float, new: float) -> float:
    if base == 0:
        return 0.0
    return (new / base - 1.0) * 100.0


def table() -> str:
    header = [
        "Workload",
        "TiDB4c QPS", "TiDB8c QPS", "TiDB QPS %",
        "TiProxy4c QPS", "TiProxy8c QPS", "TiProxy QPS %",
        "TiDB4c TPS", "TiDB8c TPS", "TiDB TPS %",
        "TiProxy4c TPS", "TiProxy8c TPS", "TiProxy TPS %",
    ]
    body: List[List[str]] = []
    for w in WORKLOADS:
        tqb = TIDB_4C[w].qps; tqt = TIDB_8C[w].qps
        tpb = TIPROXY_4C[w].qps; tpt = TIPROXY_8C[w].qps
        ttb = TIDB_4C[w].tps; ttt = TIDB_8C[w].tps
        tpb2 = TIPROXY_4C[w].tps; tpt2 = TIPROXY_8C[w].tps
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


def _annotate_pair(ax, base_bar, target_bar, delta_pct: float, color_raw: str, color_delta: str):
    h_base = base_bar.get_height()
    h_tar = target_bar.get_height()
    # Decide anchor height: above taller to avoid overlap when decrease
    anchor = (h_tar if h_tar >= h_base else h_base) * 1.01
    # If positive and target taller, keep two-line just above target; else above base.
    if h_tar >= h_base:
        raw_y = h_tar * 1.005
        delta_y = h_tar * 1.03
    else:
        raw_y = anchor
        delta_y = anchor * 1.02
    x_center = target_bar.get_x() + target_bar.get_width()/2
    ax.text(x_center, raw_y, f"{h_tar:.0f}", ha='center', va='bottom', fontsize=7, color=color_raw)
    ax.text(x_center, delta_y, f"{delta_pct:+.1f}%", ha='center', va='bottom', fontsize=7,
            color=('#d62728' if delta_pct > 0 else '#2ca02c'))


def plot():  # pragma: no cover
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False
    x = list(range(len(WORKLOADS)))
    width = 0.18
    fig, (ax_qps, ax_tps) = plt.subplots(2, 1, figsize=(14, 8), sharex=True)

    c_tidb4 = "#1f77b4"; c_tidb8 = "#6baed6"
    c_tpx4 = "#ff7f0e"; c_tpx8 = "#ffbb78"

    def bars(ax, metric: str):
        def get(d, w):
            return getattr(d[w], metric)
        b1 = ax.bar([i - 1.5*width for i in x], [get(TIDB_4C, w) for w in WORKLOADS], width, color=c_tidb4, label='TiDB 4c')
        b2 = ax.bar([i - 0.5*width for i in x], [get(TIDB_8C, w) for w in WORKLOADS], width, color=c_tidb8, label='TiDB 8c')
        b3 = ax.bar([i + 0.5*width for i in x], [get(TIPROXY_4C, w) for w in WORKLOADS], width, color=c_tpx4, label='TiProxy 4c')
        b4 = ax.bar([i + 1.5*width for i in x], [get(TIPROXY_8C, w) for w in WORKLOADS], width, color=c_tpx8, label='TiProxy 8c')
        # baseline single-line annotations
        for bars_ in (b1, b3):
            for bar in bars_:
                h = bar.get_height()
                ax.text(bar.get_x()+bar.get_width()/2, h*1.01, f"{h:.0f}", ha='center', va='bottom', fontsize=7)
        # target two-line annotations with smart placement
        for idx, w in enumerate(WORKLOADS):
            # TiDB
            delta_tidb = pct(b1[idx].get_height(), b2[idx].get_height())
            _annotate_pair(ax, b1[idx], b2[idx], delta_tidb, color_raw=c_tidb8, color_delta=c_tidb8)
            # TiProxy
            delta_tpx = pct(b3[idx].get_height(), b4[idx].get_height())
            _annotate_pair(ax, b3[idx], b4[idx], delta_tpx, color_raw=c_tpx8, color_delta=c_tpx8)
        ax.set_ylabel(metric.upper())
        ax.grid(axis='y', linestyle='--', alpha=0.3)
        return b1, b2, b3, b4

    bq1, bq2, bq3, bq4 = bars(ax_qps, 'qps')
    bt1, bt2, bt3, bt4 = bars(ax_tps, 'tps')
    ax_tps.set_xticks(x)
    ax_tps.set_xticklabels([w.replace('_', '\n') for w in WORKLOADS])

    fig.suptitle('IDC *3 Scale-Up Raw Throughput (4c -> 8c) - Annotated v2', y=0.97, fontsize=14)
    fig.legend([bq1, bq2, bq3, bq4], ['TiDB 4c', 'TiDB 8c', 'TiProxy 4c', 'TiProxy 8c'],
               loc='upper center', bbox_to_anchor=(0.5, 0.9), ncol=4, fontsize=10, frameon=False)
    fig.tight_layout(rect=(0, 0, 1, 0.86))
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot raw QPS/TPS 4c vs 8c (smart labels).')
    ap.add_argument('--show', action='store_true', help='Print raw + delta table')
    args = ap.parse_args()
    if args.show:
        print(table())
    plot()


if __name__ == '__main__':  # pragma: no cover
    main()
