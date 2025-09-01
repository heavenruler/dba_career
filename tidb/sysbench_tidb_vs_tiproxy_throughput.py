#!/usr/bin/env python3
"""Sysbench Throughput (QPS & TPS) comparison: TiDB vs TiProxy (Scenario #1 Isolation)

Features:
  - Bars only (no latency).
  - Select baseline system (default: tidb) via --baseline {tidb,tiproxy}.
  - Two subplots: left QPS, right TPS (workloads on X, two bars per workload).
  - Baseline bar annotated with raw value; counterpart annotated with raw value + delta percent.
  - Delta = (other / baseline - 1)*100 kept with sign; bar heights always raw throughput ("正向數據表示").

Usage:
  python sysbench_tidb_vs_tiproxy_throughput.py
  python sysbench_tidb_vs_tiproxy_throughput.py --baseline tiproxy
  python sysbench_tidb_vs_tiproxy_throughput.py --show        # print table of values & deltas
  python sysbench_tidb_vs_tiproxy_throughput.py --svg         # also export SVG
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


# Source numbers (Scenario #1 isolation already in markdown):
DATA: List[Row] = [
    Row("oltp_read_only",       2087.83, 1966.71, 130.49, 122.92),
    Row("oltp_read_write",      1950.36, 1893.37,  97.52,  94.67),
    Row("oltp_write_only",      2324.89, 2236.19, 387.48, 372.70),
    Row("select_random_points", 1975.64, 1748.93,1975.64,1748.93),
    Row("select_random_ranges", 1922.42, 1725.76,1922.42,1725.76),
]

PNG_NAME = "sysbench_tidb_vs_tiproxy_throughput.png"
SVG_NAME = "sysbench_tidb_vs_tiproxy_throughput.svg"


def _delta(a: float, b: float) -> float:
    if a == 0:
        return 0.0
    return (b / a - 1.0) * 100.0


def build_table(baseline: Literal['tidb','tiproxy']) -> str:
    header = ["Workload", "Baseline", "Baseline QPS", "Other QPS", "QPS Δ%", "Baseline TPS", "Other TPS", "TPS Δ%"]
    rows = []
    for r in DATA:
        if baseline == 'tidb':
            bq, oq = r.tidb_qps, r.tiproxy_qps
            bt, ot = r.tidb_tps, r.tiproxy_tps
            bname = 'tidb'
        else:
            bq, oq = r.tiproxy_qps, r.tidb_qps
            bt, ot = r.tiproxy_tps, r.tidb_tps
            bname = 'tiproxy'
        rows.append([
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


def plot(baseline: Literal['tidb','tiproxy']):  # pragma: no cover
    if plt is None:
        print(f"[ERROR] matplotlib not available: {_mpl_err}")
        return False

    workloads = [r.name for r in DATA]
    x = list(range(len(workloads)))
    width = 0.35

    fig, (ax_qps, ax_tps) = plt.subplots(1, 2, figsize=(13, 5.0), sharex=True)

    tidb_qps = [r.tidb_qps for r in DATA]
    tiproxy_qps = [r.tiproxy_qps for r in DATA]
    tidb_tps = [r.tidb_tps for r in DATA]
    tiproxy_tps = [r.tiproxy_tps for r in DATA]

    # Choose colors (baseline darker)
    if baseline == 'tidb':
        c_base, c_other = "#1f77b4", "#ff7f0e"
    else:
        c_base, c_other = "#ff7f0e", "#1f77b4"

    # QPS subplot
    if baseline == 'tidb':
        bvals, ovals = tidb_qps, tiproxy_qps
    else:
        bvals, ovals = tiproxy_qps, tidb_qps
    b1 = ax_qps.bar([i - width/2 for i in x], bvals, width=width, color=c_base, alpha=0.90, label=f"{baseline} QPS")
    b2 = ax_qps.bar([i + width/2 for i in x], ovals, width=width, color=c_other, alpha=0.80, label=f"other QPS")
    ax_qps.set_ylabel("QPS")
    ax_qps.set_title("QPS Comparison")
    ax_qps.grid(axis='y', linestyle='--', alpha=0.35)

    # Annotate
    for i, (bb, ob) in enumerate(zip(b1, b2)):
        ax_qps.text(bb.get_x()+bb.get_width()/2, bb.get_height()*1.01, f"{bb.get_height():.0f}", ha='center', va='bottom', fontsize=8, color=c_base)
        delta = _delta(bvals[i], ovals[i])
        ax_qps.text(ob.get_x()+ob.get_width()/2, ob.get_height()*1.01, f"{ob.get_height():.0f}\n({delta:+.1f}%)", ha='center', va='bottom', fontsize=8, color=c_other)

    ax_qps.legend(frameon=False, fontsize=8, loc='upper center', ncol=2)

    # TPS subplot
    if baseline == 'tidb':
        bvals_t, ovals_t = tidb_tps, tiproxy_tps
    else:
        bvals_t, ovals_t = tiproxy_tps, tidb_tps
    t1 = ax_tps.bar([i - width/2 for i in x], bvals_t, width=width, color=c_base, alpha=0.90, label=f"{baseline} TPS")
    t2 = ax_tps.bar([i + width/2 for i in x], ovals_t, width=width, color=c_other, alpha=0.80, label=f"other TPS")
    ax_tps.set_ylabel("TPS")
    ax_tps.set_title("TPS Comparison")
    ax_tps.grid(axis='y', linestyle='--', alpha=0.35)
    for i, (bb, ob) in enumerate(zip(t1, t2)):
        ax_tps.text(bb.get_x()+bb.get_width()/2, bb.get_height()*1.01, f"{bb.get_height():.0f}", ha='center', va='bottom', fontsize=8, color=c_base)
        delta = _delta(bvals_t[i], ovals_t[i])
        ax_tps.text(ob.get_x()+ob.get_width()/2, ob.get_height()*1.01, f"{ob.get_height():.0f}\n({delta:+.1f}%)", ha='center', va='bottom', fontsize=8, color=c_other)
    ax_tps.legend(frameon=False, fontsize=8, loc='upper center', ncol=2)

    # Shared X labels
    labels = [w.replace('_', '\n') for w in workloads]
    for ax in (ax_qps, ax_tps):
        ax.set_xticks(x)
        ax.set_xticklabels(labels)

    fig.suptitle(f"Sysbench Scenario #1 - Throughput (Baseline = {baseline})", fontsize=13)
    fig.tight_layout(rect=(0,0,1,0.94))
    fig.savefig(PNG_NAME, dpi=140)
    print(f"[OK] Saved {PNG_NAME}")
    return True


def main():
    ap = argparse.ArgumentParser(description="Plot TiDB vs TiProxy throughput (QPS/TPS) with selectable baseline.")
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
