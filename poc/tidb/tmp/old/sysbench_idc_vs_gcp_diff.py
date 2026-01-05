#!/usr/bin/env python3
"""IDC vs GCP Throughput comparison (TiDB vs TiProxy) styled like baseline script.

Four subplots (2 x 2 grid):
  Row 1 (IDC):   QPS (TiDB vs TiProxy) , TPS (TiDB vs TiProxy)
  Row 2 (GCP):   QPS (TiDB vs TiProxy) , TPS (TiDB vs TiProxy)

Baseline selectable (default: tidb). For each workload & subplot:
  - Baseline bar annotated with raw value.
  - Other bar annotated with raw value + delta percent (other vs baseline).

Data sources:
  IDC  = Scenario #1 isolation tables.
  GCP  = Scenario #2 tables.

Usage:
  python sysbench_idc_vs_gcp_diff.py [--baseline tidb|tiproxy] [--show] [--svg]
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass
from typing import List, Literal

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
    tidb_qps: float
    tiproxy_qps: float
    tidb_tps: float
    tiproxy_tps: float

# IDC (Scenario #1)
IDC_DATA: List[Row] = [
    Row("oltp_read_only",       2087.83, 1966.71, 130.49, 122.92),
    Row("oltp_read_write",      1950.36, 1893.37,  97.52,  94.67),
    Row("oltp_write_only",      2324.89, 2236.19, 387.48, 372.70),
    Row("select_random_points", 1975.64, 1748.93,1975.64,1748.93),
    Row("select_random_ranges", 1922.42, 1725.76,1922.42,1725.76),
]

# GCP (Scenario #2)
GCP_DATA: List[Row] = [
    Row("oltp_read_only",       3455.60, 3254.39, 215.97, 203.40),
    Row("oltp_read_write",      2685.90, 2550.61, 134.29, 127.53),
    Row("oltp_write_only",      1533.41, 1576.06, 255.57, 262.68),
    Row("select_random_points",  573.45,  594.02, 573.45, 594.02),
    Row("select_random_ranges",  708.15,  676.82, 708.15, 676.82),
]

PNG_NAME = "sysbench_idc_vs_gcp_diff.png"
SVG_NAME = "sysbench_idc_vs_gcp_diff.svg"


def _delta(a: float, b: float) -> float:
    if a == 0:
        return 0.0
    return (b / a - 1.0) * 100.0


def build_table(baseline: Literal['tidb','tiproxy']) -> str:
    header = ["Env", "Workload", "Baseline", "Base QPS", "Other QPS", "QPS Δ%", "Base TPS", "Other TPS", "TPS Δ%"]
    rows: List[List[str]] = []
    for env, dataset in (("IDC", IDC_DATA), ("GCP", GCP_DATA)):
        for r in dataset:
            if baseline == 'tidb':
                bq, oq = r.tidb_qps, r.tiproxy_qps
                bt, ot = r.tidb_tps, r.tiproxy_tps
                bname = 'tidb'
            else:
                bq, oq = r.tiproxy_qps, r.tidb_qps
                bt, ot = r.tiproxy_tps, r.tidb_tps
                bname = 'tiproxy'
            rows.append([
                env,
                r.name,
                bname,
                f"{bq:.2f}",
                f"{oq:.2f}",
                f"{_delta(bq, oq):+.2f}%",
                f"{bt:.2f}",
                f"{ot:.2f}",
                f"{_delta(bt, ot):+.2f}%",
            ])
    widths = [max(len(header[i]), *(len(row[i]) for row in rows)) for i in range(len(header))]
    def fmt(row):
        return " | ".join(row[i].ljust(widths[i]) for i in range(len(row)))
    out = [fmt(header), "-+-".join('-'*w for w in widths)]
    out.extend(fmt(r) for r in rows)
    return "\n".join(out)


def _subplot(ax, dataset: List[Row], metric: str, baseline: Literal['tidb','tiproxy'], env_label: str):
    workloads = [r.name for r in dataset]
    x = list(range(len(workloads)))
    width = 0.35
    tidb_vals = [getattr(r, f"tidb_{metric}") for r in dataset]
    tiproxy_vals = [getattr(r, f"tiproxy_{metric}") for r in dataset]

    if baseline == 'tidb':
        bvals, ovals = tidb_vals, tiproxy_vals
        c_base, c_other = "#1f77b4", "#ff7f0e"
        base_label = "tidb"
    else:
        bvals, ovals = tiproxy_vals, tidb_vals
        c_base, c_other = "#ff7f0e", "#1f77b4"
        base_label = "tiproxy"

    b_bars = ax.bar([i - width/2 for i in x], bvals, width=width, color=c_base, alpha=0.90, label=f"{base_label} {metric.upper()}")
    o_bars = ax.bar([i + width/2 for i in x], ovals, width=width, color=c_other, alpha=0.80, label=f"other {metric.upper()}")
    ax.grid(axis='y', linestyle='--', alpha=0.35)
    ax.set_ylabel(metric.upper())
    ax.set_title(f"{env_label} {metric.upper()}")
    # Annotations
    for i, (bb, ob) in enumerate(zip(b_bars, o_bars)):
        ax.text(bb.get_x()+bb.get_width()/2, bb.get_height()*1.01, f"{bb.get_height():.0f}", ha='center', va='bottom', fontsize=7, color=c_base)
        d = _delta(bvals[i], ovals[i])
        ax.text(ob.get_x()+ob.get_width()/2, ob.get_height()*1.01, f"{ob.get_height():.0f}\n({d:+.1f}%)", ha='center', va='bottom', fontsize=7, color=c_other)
    labels = [w.replace('_', '\n') for w in workloads]
    ax.set_xticks(x)
    ax.set_xticklabels(labels)


def plot(baseline: Literal['tidb','tiproxy']):  # pragma: no cover
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False
    fig, axes = plt.subplots(2, 2, figsize=(13, 9), sharex='col')
    _subplot(axes[0][0], IDC_DATA, 'qps', baseline, 'IDC')
    _subplot(axes[0][1], IDC_DATA, 'tps', baseline, 'IDC')
    _subplot(axes[1][0], GCP_DATA, 'qps', baseline, 'GCP')
    _subplot(axes[1][1], GCP_DATA, 'tps', baseline, 'GCP')

    # Legends (single consolidated) - take first axes handles
    handles, labels = axes[0][0].get_legend_handles_labels()
    fig.legend(handles, labels, loc='upper center', ncol=2, frameon=False, fontsize=9)
    fig.suptitle(f"IDC vs GCP Throughput (Baseline = {baseline})", fontsize=14)
    fig.tight_layout(rect=(0,0,1,0.94))
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description='Plot IDC vs GCP (TiDB vs TiProxy) throughput comparison.')
    ap.add_argument('--baseline', choices=['tidb','tiproxy'], default='tidb', help='Baseline system for delta calculation')
    ap.add_argument('--show', action='store_true', help='Print table of values & deltas')
    ap.add_argument('--svg', action='store_true', help='Also export SVG')
    args = ap.parse_args()
    if args.show:
        print(build_table(args.baseline))
    if plot(args.baseline) and args.svg and plt is not None:
        import matplotlib.pyplot as plt  # noqa: F401
        plt.gcf().savefig(SVG_NAME)
        print(f"[OK] Saved {SVG_NAME}")

if __name__ == '__main__':  # pragma: no cover
    main()
