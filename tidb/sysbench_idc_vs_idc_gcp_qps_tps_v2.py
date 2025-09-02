#!/usr/bin/env python3
"""Variant v2: IDC*3 (Scenario #2) -> IDC*3+GCP*3 (Scenario #1) raw QPS/TPS with smart labels.

Original kept as sysbench_idc_vs_idc_gcp_qps_tps.py (unchanged).

Problem addressed: When target (IDC+GCP) throughput is LOWER than baseline, the two-line
annotation (raw + delta%) drawn relative to the shorter bar overlaps visually with the taller
baseline bar area or sits too low. This variant repositions those labels above the taller of
the two bars (baseline vs target) to avoid overlap for negative deltas.

Rules:
  - Baseline bars (IDC) always: single raw value above its own bar.
  - Target bars (IDC+GCP): two lines (raw, delta%).
      * If target >= baseline: place just above target (like original).
      * If target < baseline: place above BASELINE bar instead (so visible and not crowded).
  - Delta color: red (+) for increase, green (-) for decrease.
  - Optional fine‑tuning thresholds (--min-gap) to control vertical gap multiplier.

Output: sysbench_idc_vs_idc_gcp_qps_tps_v2.png (and optional SVG).
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

# Target IDC*3 + GCP*3 (Scenario #1)
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

PNG_NAME = "sysbench_idc_vs_idc_gcp_qps_tps_v2.png"


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


def _annotate(ax, base_bar, target_bar, show_raw_target: bool, gap: float):
    """Stack raw + delta in two lines using constant point offsets to avoid overlap.

    We anchor at the taller of base/target so negative deltas don't bury labels inside the taller bar.
    Raw value appears first line; delta second line (color-coded).
    """
    h_base = base_bar.get_height()
    h_tar = target_bar.get_height()
    p = pct(h_base, h_tar)
    delta_color = '#d62728' if p > 0 else '#2ca02c'
    anchor_height = max(h_base, h_tar)
    x_center = target_bar.get_x() + target_bar.get_width()/2
    # Use a tiny additive offset so even very small bars still show labels above the bar top.
    y_anchor = anchor_height * (1 + gap)
    if show_raw_target:
        ax.annotate(f"{h_tar:.0f}", xy=(x_center, y_anchor), xytext=(0, 0), textcoords='offset points',
                    ha='center', va='bottom', fontsize=7)
        ax.annotate(f"{p:+.1f}%", xy=(x_center, y_anchor), xytext=(0, 10), textcoords='offset points',
                    ha='center', va='bottom', fontsize=7, color=delta_color)
    else:  # fallback just percent (not used presently)
        ax.annotate(f"{p:+.1f}%", xy=(x_center, y_anchor), xytext=(0, 0), textcoords='offset points',
                    ha='center', va='bottom', fontsize=7, color=delta_color)


def plot(min_gap: float):  # pragma: no cover
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
        # Baseline raw labels
        for bars_ in (b1, b3):
            for bar in bars_:
                h = bar.get_height()
                ax.text(bar.get_x()+bar.get_width()/2, h * (1 + min_gap), f"{h:.0f}", ha='center', va='bottom', fontsize=7)
        # Target labels with smart placement
        for i in range(len(WORKLOADS)):
            _annotate(ax, b1[i], b2[i], show_raw_target=True, gap=min_gap)
            _annotate(ax, b3[i], b4[i], show_raw_target=True, gap=min_gap)
        ax.set_ylabel(metric.upper())
        ax.grid(axis='y', linestyle='--', alpha=0.3)
        return b1, b2, b3, b4

    bq1, bq2, bq3, bq4 = bars(ax_qps, 'qps')
    bt1, bt2, bt3, bt4 = bars(ax_tps, 'tps')
    ax_tps.set_xticks(x)
    ax_tps.set_xticklabels([w.replace('_', '\n') for w in WORKLOADS])

    fig.suptitle('IDC*3 -> IDC*3+GCP*3 Raw Throughput Impact (Smart Labels v2)', y=0.97, fontsize=14)
    fig.legend([bq1, bq2, bq3, bq4], ['TiDB IDC', 'TiDB IDC+GCP', 'TiProxy IDC', 'TiProxy IDC+GCP'],
               loc='upper center', bbox_to_anchor=(0.5, 0.9), ncol=4, fontsize=10, frameon=False)
    fig.tight_layout(rect=(0, 0, 1, 0.86))
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():  # pragma: no cover
    ap = argparse.ArgumentParser(description='Plot IDC vs IDC+GCP raw throughput with smart delta labels.')
    ap.add_argument('--show', action='store_true', help='Print data table')
    ap.add_argument('--svg', action='store_true', help='Also export SVG')
    ap.add_argument('--min-gap', type=float, default=0.01, help='Relative vertical gap factor for labels (default 0.01)')
    args = ap.parse_args()
    if args.show:
        print(table())
    if plot(args.min_gap) and args.svg and plt is not None:
        import matplotlib.pyplot as _plt  # noqa
        _plt.gcf().savefig(PNG_NAME.replace('.png', '.svg'))
        print(f"[OK] Saved {PNG_NAME.replace('.png', '.svg')}")


if __name__ == '__main__':  # pragma: no cover
    main()
