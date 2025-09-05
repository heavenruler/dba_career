#!/usr/bin/env python3
"""
IDC*3 + GCP*3 topology: With vs Without Traffic Isolation (Label / 分流隔離) performance comparison.

Sources (multi_thread_multi_conn only):
  From IDC Clients:
    - TiDB   With Isolation: #1-5.py   Without: #2-13.py
    - TiProxy With Isolation: #1-6.py   Without: #2-14.py
  From GCP Clients:
    - TiDB   With Isolation: #1-7.py   Without: #2-15.py
    - TiProxy With Isolation: #1-8.py   Without: #2-16.py

Goal: Quantify impact of isolation on throughput (RPS) across thread counts, both origins and both components, after scale-out (IDC*3 + GCP*3).

Output: Single composite PNG with 2x2 subplots (rows = Origin {IDC,GCP}, cols = Component {TiDB,TiProxy}).
  File: #1-5_#2-13_#1-6_#2-14_#1-7_#2-15_#1-8_#2-16_isolation_compare.png

Features:
  - Grouped bars: two bars per thread (With Isolation, Without Isolation)
  - Optional Δ% annotation for "With" bar vs corresponding "Without" baseline (>=100 threads by default)
  - Textual summary tables (RPS + Δ%) per panel & peak comparison
  - CSV export (optional) for reporting

CLI Flags:
  --annot-percent   annotate bars with Δ% (With vs Without); default off
  --show-percent    include Δ% columns in printed tables
  --all-threads     include thread=1 in percent annotations (otherwise skip thread=1 deltas)
  --csv FILE        export tidy data to CSV

Assumptions:
  - Thread set is consistent across all datasets (1,100,200,250,500,750,1000)
  - "Without" isolation acts as baseline for percentage deltas
"""
from __future__ import annotations

import argparse
import csv
from typing import Dict, List, Tuple

import matplotlib.pyplot as plt
import numpy as np

THREADS = [1, 100, 200, 250, 500, 750, 1000]

# Data dictionaries: origin -> component -> mode -> thread->rps
# mode keys: 'with', 'without'
DATA: Dict[str, Dict[str, Dict[str, Dict[int, float]]]] = {
    "IDC": {
        "TiDB": {
            "with":    {1: 659.91, 100: 10277.49, 200: 10093.25, 250: 10136.89, 500: 9060.52, 750: 2752.71, 1000: 3132.93},  # #1-5
            "without": {1: 678.20, 100: 10683.84, 200: 10505.96, 250:  9581.09, 500: 8348.60, 750: 5620.90, 1000: 2998.63},  # #2-13
        },
        "TiProxy": {
            "with":    {1: 403.05, 100: 7004.83, 200: 7464.26, 250: 7460.40, 500: 6037.01, 750: 5614.70, 1000: 4517.42},  # #1-6
            "without": {1: 400.76, 100: 6893.57, 200: 6359.17, 250: 7230.17, 500: 6576.74, 750: 5113.17, 1000: 4428.23},  # #2-14
        },
    },
    "GCP": {
        "TiDB": {
            "with":    {1: 600.92, 100: 7499.05, 200: 7592.54, 250: 7460.46, 500: 6274.65, 750: 4695.18, 1000: 3830.52},  # #1-7
            "without": {1: 917.72, 100: 8771.13, 200: 8202.95, 250: 8081.34, 500: 6435.23, 750: 4775.13, 1000: 3836.46},  # #2-15
        },
        "TiProxy": {
            "with":    {1: 596.37, 100: 5599.07, 200: 5512.63, 250: 5361.75, 500: 4746.86, 750: 3973.22, 1000: 3490.86},  # #1-8
            "without": {1:  28.77, 100: 3023.19, 200: 4649.79, 250: 5162.68, 500: 4511.78, 750: 3761.68, 1000: 3159.47},  # #2-16
        },
    },
}

OUTPUT_PNG = "#1-5_#2-13_#1-6_#2-14_#1-7_#2-15_#1-8_#2-16_isolation_compare.png"
BAR_COLORS = {"with": "#1f77b4", "without": "#ff7f0e"}


def pct(curr: float, base: float) -> float:
    return (curr - base) / base * 100.0 if base else 0.0


def summary_table(origin: str, component: str, show_percent: bool) -> str:
    d_with = DATA[origin][component]["with"]
    d_without = DATA[origin][component]["without"]
    headers = ["Threads", "With_RPS", "Without_RPS"]
    if show_percent:
        headers.append("Δ%(With-Without)")
    rows: List[List[str]] = []
    for t in THREADS:
        w = d_with[t]
        wo = d_without[t]
        row = [str(t), f"{w:.2f}", f"{wo:.2f}"]
        if show_percent:
            row.append(f"{pct(w, wo):+6.1f}%")
        rows.append(row)
    widths = [max(len(h), max(len(r[i]) for r in rows)) for i, h in enumerate(headers)]
    def fmt(r):
        return " | ".join(r[i].rjust(widths[i]) for i in range(len(r)))
    lines = [fmt(headers), "-+-".join('-'*w for w in widths)] + [fmt(r) for r in rows]
    # Peaks
    peak_t_with = max(d_with, key=lambda k: d_with[k])
    peak_t_without = max(d_without, key=lambda k: d_without[k])
    peak_with = d_with[peak_t_with]
    peak_without = d_without[peak_t_without]
    cross_delta_same_t = pct(d_with.get(peak_t_without, peak_with), peak_without)
    lines.append("")
    lines.append(f"Peak With: {peak_with:.2f} @ {peak_t_with}T | Peak Without: {peak_without:.2f} @ {peak_t_without}T")
    lines.append(f"Δ at Without-peak thread ({peak_t_without}T): {cross_delta_same_t:+.1f}%")
    return "\n".join(lines)


def export_csv(path: str):
    cols = ["origin", "component", "threads", "mode", "rps", "baseline_without_rps", "delta_pct_vs_without"]
    with open(path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(cols)
        for origin, comps in DATA.items():
            for comp, modes in comps.items():
                without = modes["without"]
                for mode, series in modes.items():
                    for t, rps_v in series.items():
                        base = without[t]
                        w.writerow([origin, comp, t, mode, f"{rps_v:.2f}", f"{base:.2f}", f"{pct(rps_v, base):.2f}"])
    print(f"[OK] CSV exported -> {path}")


def make_plot(annot_percent: bool, include_thread1: bool):
    """Render plot with both 'With' and 'Without' as grouped bars (user requested all bar chart)."""
    fig, axes = plt.subplots(2, 2, figsize=(13, 9), sharex=True)
    panel_order: List[Tuple[str, str, plt.Axes]] = [
        ("IDC", "TiDB", axes[0][0]),
        ("IDC", "TiProxy", axes[0][1]),
        ("GCP", "TiDB", axes[1][0]),
        ("GCP", "TiProxy", axes[1][1]),
    ]
    x = np.arange(len(THREADS))
    width = 0.38  # two bars per group
    for origin, comp, ax in panel_order:
        series_without = [DATA[origin][comp]["without"][t] for t in THREADS]
        series_with = [DATA[origin][comp]["with"][t] for t in THREADS]
        bars_without = ax.bar(x - width/2, series_without, width=width, label="Without Isolation", color=BAR_COLORS["without"], alpha=0.80)
        bars_with = ax.bar(x + width/2, series_with, width=width, label="With Isolation", color=BAR_COLORS["with"], alpha=0.85)
        # Annotate bars
        for bw, val in zip(bars_without, series_without):
            ax.text(bw.get_x()+bw.get_width()/2, val*1.01, f"{val:.0f}", ha='center', va='bottom', fontsize=7)
        for bw, ww, t in zip(bars_with, series_with, THREADS):
            base = DATA[origin][comp]["without"][t]
            if annot_percent and (include_thread1 or t != 1):
                delta = pct(ww, base)
                ax.text(bw.get_x()+bw.get_width()/2, bw.get_height()*1.01,
                        f"{ww:.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7)
            else:
                ax.text(bw.get_x()+bw.get_width()/2, bw.get_height()*1.01, f"{ww:.0f}", ha='center', va='bottom', fontsize=7)
        ax.set_title(f"{origin} – {comp}")
        ax.grid(axis='y', linestyle='--', alpha=0.25)
        ax.set_ylabel("RPS")
    # X axis ticks / labels
    axes[1][0].set_xticks(x)
    axes[1][0].set_xticklabels([str(t) for t in THREADS])
    axes[1][1].set_xticks(x)
    axes[1][1].set_xticklabels([str(t) for t in THREADS])
    axes[1][0].set_xlabel("Threads")
    axes[1][1].set_xlabel("Threads")
    handles, labels = axes[0][0].get_legend_handles_labels()
    axes[0][1].legend(handles, labels, fontsize=9, loc='upper right')
    fig.suptitle("IDC*3 + GCP*3 Isolation Impact (Grouped Bars)", fontsize=14)
    fig.tight_layout(rect=[0, 0, 1, 0.96])
    fig.savefig(OUTPUT_PNG, dpi=150)
    print(f"[OK] Saved combined plot -> {OUTPUT_PNG}")


def main():
    ap = argparse.ArgumentParser(description="Isolation vs Non-Isolation performance comparison (IDC*3 + GCP*3)")
    ap.add_argument("--annot-percent", action="store_true", help="Annotate 'With' bars with Δ% vs 'Without'")
    ap.add_argument("--show-percent", action="store_true", help="Include Δ% columns in tables")
    ap.add_argument("--all-threads", action="store_true", help="Include thread=1 in percentage annotations")
    ap.add_argument("--csv", metavar="FILE", help="Export tidy CSV of results")
    args = ap.parse_args()

    for origin in ("IDC", "GCP"):
        for comp in ("TiDB", "TiProxy"):
            print(f"\n=== {origin} {comp} With vs Without Isolation ===")
            print(summary_table(origin, comp, args.show_percent))

    make_plot(args.annot_percent, args.all_threads)

    if args.csv:
        export_csv(args.csv)

    print("\nNotes:")
    print(" - Δ% = (With - Without) / Without * 100 per thread.")
    print(" - Thread=1 often dominated by connection warm-up; focus on >=100 for capacity impact.")
    print(" - Compare peak shifts: isolation may alter optimal thread count or flatten plateau.")
    print(" - Use CSV for deeper latency overlay if you extend this script.")


if __name__ == "__main__":
    main()
