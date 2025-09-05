#!/usr/bin/env python3
"""
Peak vs Off-Peak (上班尖峰 vs 下班離峰) comparison across IDC/GCP and TiDB/TiProxy.

Data sources:
  TiDB  IDC  Peak  : #1-5.py   (multi_thread_multi_conn)
  TiDB  IDC  Off   : #1-13.py
  TiProxy IDC  Peak: #1-6.py
  TiProxy IDC  Off : #1-14.py
  TiDB  GCP  Peak  : #1-7.py
  TiDB  GCP  Off   : #1-15.py
  TiProxy GCP  Peak: #1-8.py
  TiProxy GCP  Off : #1-16.py

Figure (updated): 2 x 1 vertical subplots
    Top : TiDB  (bars: IDC Peak, IDC Off, GCP Peak, GCP Off)
    Bottom: TiProxy (bars: IDC Peak, IDC Off, GCP Peak, GCP Off)
Each thread group has 4 bars. Off-Peak bars may show Δ% vs its region Peak.

Default: show RPS values on top of both bars, Off-Peak includes Δ% vs Peak.
Optional flags:
  --annot-percent    (explicit; identical to default for now, kept for parity with other scripts)
  --no-percent       (suppress Δ% annotations, show only absolute RPS)
  --csv <file>       (export combined summary CSV)

Output PNG (default): #1-5_#1-13_#1-6_#1-14_#1-7_#1-15_#1-8_#1-16_peak_offpeak_compare.png

Color scheme consistent with prior comparison scripts.
"""
from __future__ import annotations

import argparse
import csv
from dataclasses import dataclass
from typing import List, Dict, Tuple

import math

# Thread order baseline
THREADS = [1, 100, 200, 250, 500, 750, 1000]

# Data dictionaries: (threads -> rps)
TIDB_IDC_PEAK = {1: 659.91, 100: 10277.49, 200: 10093.25, 250: 10136.89, 500: 9060.52, 750: 2752.71, 1000: 3132.93}
TIDB_IDC_OFF  = {1: 597.88, 100: 10246.48, 200: 10402.22, 250: 9734.46, 500: 7608.72, 750: 2933.79, 1000: 4762.96}

TIPROXY_IDC_PEAK = {1: 403.05, 100: 7004.83, 200: 7464.26, 250: 7460.40, 500: 6037.01, 750: 5614.70, 1000: 4517.42}
TIPROXY_IDC_OFF  = {1: 382.71, 100: 7258.37, 200: 7261.73, 250: 7590.68, 500: 6317.35, 750: 2530.78, 1000: 4416.35}

TIDB_GCP_PEAK = {1: 600.92, 100: 7499.05, 200: 7592.54, 250: 7460.46, 500: 6274.65, 750: 4695.18, 1000: 3830.52}
TIDB_GCP_OFF  = {1: 873.67, 100: 7366.82, 200: 7173.79, 250: 6669.74, 500: 5680.73, 750: 4717.45, 1000: 3853.71}

TIPROXY_GCP_PEAK = {1: 596.37, 100: 5599.07, 200: 5512.63, 250: 5361.75, 500: 4746.86, 750: 3973.22, 1000: 3490.86}
TIPROXY_GCP_OFF  = {1: 577.14, 100: 5386.95, 200: 5354.77, 250: 5272.05, 500: 4645.23, 750: 4004.45, 1000: 3496.26}


@dataclass
class PairStat:
    threads: int
    peak: float
    off: float
    delta_pct: float  # off vs peak ( (off-peak)/peak * 100 )


def build_pairs(peak: Dict[int, float], off: Dict[int, float]) -> List[PairStat]:
    out: List[PairStat] = []
    for t in THREADS:
        p = peak.get(t)
        o = off.get(t)
        if p is None or o is None:
            continue
        delta = (o - p) / p * 100 if p else 0.0
        out.append(PairStat(t, p, o, delta))
    return out


def pct_fmt(v: float) -> str:
    sign = "+" if v >= 0 else ""
    return f"{sign}{v:.1f}%"


def summary_table(name: str, pairs: List[PairStat]) -> str:
    headers = ["Threads", "Peak_RPS", "Off_RPS", "Off_vs_Peak%", "Off/Peak"]
    rows = []
    for ps in pairs:
        ratio = ps.off / ps.peak if ps.peak else 0.0
        rows.append((ps.threads, ps.peak, ps.off, ps.delta_pct, ratio))
    col_w = []
    for i, h in enumerate(headers):
        w = max(len(h), *(len(f"{r[i]:.2f}" if isinstance(r[i], float) else str(r[i])) for r in rows))
        col_w.append(w)
    def fmt(val, idx):
        return (f"{val:.2f}" if isinstance(val, float) else str(val)).rjust(col_w[idx])
    lines = [f"[{name}] Peak vs Off-Peak", " | ".join(h.ljust(col_w[i]) for i, h in enumerate(headers)), "-+-".join('-'*w for w in col_w)]
    for r in rows:
        lines.append(" | ".join(fmt(r[i], i) for i in range(len(headers))))
    return "\n".join(lines)


def export_csv(path: str, sections: Dict[str, List[PairStat]]):
    with open(path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(["Section", "Threads", "Peak_RPS", "Off_RPS", "Off_vs_Peak_pct", "Off_div_Peak"])
        for name, pairs in sections.items():
            for ps in pairs:
                ratio = ps.off / ps.peak if ps.peak else 0.0
                w.writerow([name, ps.threads, f"{ps.peak:.2f}", f"{ps.off:.2f}", f"{ps.delta_pct:.2f}", f"{ratio:.3f}"])
    print(f"[OK] CSV exported -> {path}")


DEFAULT_PNG = '#1-5_#1-13_#1-6_#1-14_#1-7_#1-15_#1-8_#1-16_peak_offpeak_compare.png'


def make_plot(sections: Dict[str, List[PairStat]], annot_percent: bool, out_png: str):
    """Create 2 vertically stacked subplots (TiDB / TiProxy)."""
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception as e:  # pragma: no cover
        print(f"[WARN] matplotlib not available ({e}), skipping PNG generation.")
        return False

    fig, axes = plt.subplots(2, 1, figsize=(13, 10), sharex=True)

    # Colors per (region, period)
    colors = {
        'IDC_peak': '#1f77b4',
        'IDC_off': '#ff7f0e',
        'GCP_peak': '#2ca02c',
        'GCP_off': '#d62728',
    }

    # Helper to plot one component (TiDB or TiProxy)
    def plot_component(ax, comp: str):
        if comp == 'TiDB':
            idc_pairs = sections['TiDB_IDC']
            gcp_pairs = sections['TiDB_GCP']
        else:
            idc_pairs = sections['TiProxy_IDC']
            gcp_pairs = sections['TiProxy_GCP']

        threads = [ps.threads for ps in idc_pairs]  # assume same thread list
        idx = np.arange(len(threads))
        bar_w = 0.18
        # Offsets: -1.5w, -0.5w, +0.5w, +1.5w
        offsets = [-1.5*bar_w, -0.5*bar_w, 0.5*bar_w, 1.5*bar_w]

        bars = []
        # Build mapping thread->PairStat for convenience
        idc_map = {p.threads: p for p in idc_pairs}
        gcp_map = {p.threads: p for p in gcp_pairs}

        idc_peak_vals = [idc_map[t].peak for t in threads]
        idc_off_vals  = [idc_map[t].off  for t in threads]
        gcp_peak_vals = [gcp_map[t].peak for t in threads]
        gcp_off_vals  = [gcp_map[t].off  for t in threads]

        bars.append(ax.bar(idx + offsets[0], idc_peak_vals, width=bar_w, color=colors['IDC_peak'], label='IDC Peak', alpha=0.85))
        bars.append(ax.bar(idx + offsets[1], idc_off_vals,  width=bar_w, color=colors['IDC_off'],  label='IDC Off', alpha=0.85))
        bars.append(ax.bar(idx + offsets[2], gcp_peak_vals, width=bar_w, color=colors['GCP_peak'], label='GCP Peak', alpha=0.85))
        bars.append(ax.bar(idx + offsets[3], gcp_off_vals,  width=bar_w, color=colors['GCP_off'],  label='GCP Off', alpha=0.85))

        # Axes styling
        ax.set_title(f"{comp} Peak vs Off-Peak (IDC / GCP)")
        ax.set_xticks(idx)
        ax.set_xticklabels([str(t) for t in threads])
        ax.set_ylabel('Req/sec')
        ax.grid(axis='y', linestyle=':', linewidth=0.5, alpha=0.6)

        # Annotations: show value on all bars; for Off bars add Δ% vs corresponding Peak in same region
        for i, t in enumerate(threads):
            # IDC peak / off
            ip = idc_map[t]
            gp = gcp_map[t]
            # IDC Peak
            b = bars[0][i]
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{ip.peak:.0f}", ha='center', va='bottom', fontsize=7)
            # IDC Off
            b = bars[1][i]
            if annot_percent:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{ip.off:.0f}\n{pct_fmt(ip.delta_pct)}", ha='center', va='bottom', fontsize=7, linespacing=0.9)
            else:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{ip.off:.0f}", ha='center', va='bottom', fontsize=7)
            # GCP Peak
            b = bars[2][i]
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{gp.peak:.0f}", ha='center', va='bottom', fontsize=7)
            # GCP Off
            b = bars[3][i]
            if annot_percent:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{gp.off:.0f}\n{pct_fmt(gp.delta_pct)}", ha='center', va='bottom', fontsize=7, linespacing=0.9)
            else:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{gp.off:.0f}", ha='center', va='bottom', fontsize=7)

    plot_component(axes[0], 'TiDB')
    plot_component(axes[1], 'TiProxy')

    axes[1].set_xlabel('Threads')
    axes[0].legend(loc='upper right', ncol=4, fontsize=9, framealpha=0.9)

    fig.suptitle('Peak vs Off-Peak Throughput (multi_thread_multi_conn)\n上班尖峰 vs 下班離峰 (TiDB / TiProxy ; IDC & GCP)', fontsize=14, y=0.985)
    fig.tight_layout(rect=(0,0,1,0.965))
    fig.savefig(out_png, dpi=150)
    print(f"[OK] Saved plot -> {out_png}")
    return True


def analyze_sections(sections: Dict[str, List[PairStat]]):
    print('\n==== Peak vs Off-Peak Summary ====')
    for name, pairs in sections.items():
        # Find max absolute and relative improvements / regressions
        best_improve = max(pairs, key=lambda p: p.delta_pct)
        worst = min(pairs, key=lambda p: p.delta_pct)
        avg_delta = sum(p.delta_pct for p in pairs)/len(pairs)
        print(f"{name}: avg Δ {avg_delta:+.2f}% (best {best_improve.threads}t {best_improve.delta_pct:+.1f}%, worst {worst.threads}t {worst.delta_pct:+.1f}%)")


def main():
    ap = argparse.ArgumentParser(description='Compare Peak vs Off-Peak throughput across IDC/GCP & TiDB/TiProxy.')
    grp = ap.add_mutually_exclusive_group()
    grp.add_argument('--annot-percent', action='store_true', help='Show Δ% annotations (default behavior).')
    grp.add_argument('--no-percent', action='store_true', help='Suppress Δ% annotations, show only RPS values.')
    ap.add_argument('--csv', metavar='FILE', help='Export summary CSV to FILE.')
    ap.add_argument('--out', metavar='PNG', help='Output PNG filename (optional).')
    args = ap.parse_args()

    sections = {
        'TiDB_IDC': build_pairs(TIDB_IDC_PEAK, TIDB_IDC_OFF),
        'TiProxy_IDC': build_pairs(TIPROXY_IDC_PEAK, TIPROXY_IDC_OFF),
        'TiDB_GCP': build_pairs(TIDB_GCP_PEAK, TIDB_GCP_OFF),
        'TiProxy_GCP': build_pairs(TIPROXY_GCP_PEAK, TIPROXY_GCP_OFF),
    }

    # Print ASCII tables
    for key, pairs in sections.items():
        print(summary_table(key, pairs))
        print()

    analyze_sections(sections)

    if args.csv:
        export_csv(args.csv, sections)

    annot = True
    if args.no_percent:
        annot = False
    elif args.annot_percent:
        annot = True
    out_png = args.out or DEFAULT_PNG
    make_plot(sections, annot, out_png)


if __name__ == '__main__':
    main()
