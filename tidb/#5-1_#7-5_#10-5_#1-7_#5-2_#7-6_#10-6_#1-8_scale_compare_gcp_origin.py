#!/usr/bin/env python3
"""
Four-scenario multi_thread_multi_conn comparison (GCP origin) for TiDB & TiProxy.

Scenarios (order fixed, baseline = first):
    1) IDC*3                 (#5-1 / #5-2)
    2) IDC*1 + GCP*2         (#7-5 / #7-6)
    3) IDC*2 + GCP*3         (#10-5 / #10-6)
    4) IDC*3 + GCP*3 (Peak)  (#1-7 / #1-8)  -- GCP Peak Simultaneous datasets

Purpose: Confirm post scale-out throughput deltas (RPS) from GCP client perspective.

Update: Unified into a single composite PNG (two subplots: top=TiDB, bottom=TiProxy)
    Output: #5-1_#7-5_#10-5_#1-7_#5-2_#7-6_#10-6_#1-8_scale_compare_gcp_origin.png

Optional CLI flags:
    --show-percent  : include Δ% vs baseline tables in text output
    --annot-percent : add Δ% vs baseline as a second line under each non-baseline bar (plot)
    --csv <file>    : export combined per-thread RPS (& Δ%) to CSV for reporting

Notes:
 - Threads set identical across all component datasets (1,100,200,250,500,750,1000)
 - Baseline chosen as IDC*3 scenario for continuity with earlier analyses
 - Data sources: values copied verbatim from the referenced individual scripts
"""
from __future__ import annotations

import argparse
import csv
from typing import Dict, List

import matplotlib.pyplot as plt
import numpy as np

SCENARIO_ORDER = [
    "IDC*3",
    "IDC*1+GCP*2",
    "IDC*2+GCP*3",
    "IDC*3+GCP*3",
]
BASELINE = SCENARIO_ORDER[0]
OUTPUT_PNG = "#5-1_#7-5_#10-5_#1-7_#5-2_#7-6_#10-6_#1-8_scale_compare_gcp_origin.png"

# TiDB RPS (thread -> RPS)
TIDB_RPS: Dict[str, Dict[int, float]] = {
    "IDC*3": {1: 661.34, 100: 3788.97, 200: 7137.34, 250: 3653.09, 500: 2428.03, 750: 2731.68, 1000: 2869.28},  # #5-1
    "IDC*1+GCP*2": {1: 655.42, 100: 3245.01, 200: 4910.52, 250: 3435.43, 500: 4392.55, 750: 2743.21, 1000: 1885.80},  # #7-5
    "IDC*2+GCP*3": {1: 686.89, 100: 2740.70, 200: 8362.52, 250: 3610.48, 500: 5277.11, 750: 2723.41, 1000: 4278.33},  # #10-5
    "IDC*3+GCP*3": {1: 600.92, 100: 7499.05, 200: 7592.54, 250: 7460.46, 500: 6274.65, 750: 4695.18, 1000: 3830.52},  # #1-7
}

# TiProxy RPS (thread -> RPS)
TIPROXY_RPS: Dict[str, Dict[int, float]] = {
    "IDC*3": {1: 384.32, 100: 5899.92, 200: 3839.15, 250: 5693.22, 500: 3126.86, 750: 4265.93, 1000: 3188.79},  # #5-2
    "IDC*1+GCP*2": {1: 488.56, 100: 2963.69, 200: 3106.60, 250: 3044.20, 500: 2939.32, 750: 2209.29, 1000: 2726.36},  # #7-6
    "IDC*2+GCP*3": {1: 427.62, 100: 4446.78, 200: 3960.35, 250: 3664.94, 500: 3507.28, 750: 2149.38, 1000: 2866.68},  # #10-6
    "IDC*3+GCP*3": {1: 596.37, 100: 5599.07, 200: 5512.63, 250: 5361.75, 500: 4746.86, 750: 3973.22, 1000: 3490.86},  # #1-8
}

THREADS = [1, 100, 200, 250, 500, 750, 1000]

COLORS = [
    "#1f77b4",  # baseline
    "#ff7f0e",
    "#2ca02c",
    "#d62728",
]


def pct(curr: float, base: float) -> float:
    return (curr - base) / base * 100.0 if base else 0.0


def print_summary(title: str, data: Dict[str, Dict[int, float]], show_percent: bool):
    print(f"\n=== {title} (RPS) ===")
    # Header
    header_cols = ["Threads"] + SCENARIO_ORDER
    if show_percent:
        # add perc columns except baseline
        header_cols += [f"Δ% vs {BASELINE} ({s})" for s in SCENARIO_ORDER if s != BASELINE]
    # Build rows
    rows: List[List[str]] = []
    for t in THREADS:
        row = [str(t)]
        base_val = data[BASELINE][t]
        for scen in SCENARIO_ORDER:
            row.append(f"{data[scen][t]:.2f}")
        if show_percent:
            for scen in SCENARIO_ORDER:
                if scen == BASELINE:
                    continue
                row.append(f"{pct(data[scen][t], base_val):+6.1f}%")
        rows.append(row)

    # Column widths
    widths = [max(len(r[i]) for r in ([header_cols] + rows)) for i in range(len(header_cols))]
    fmt_row = lambda r: " | ".join(r[i].rjust(widths[i]) for i in range(len(r)))
    print(fmt_row(header_cols))
    print("-+-".join('-'*w for w in widths))
    for r in rows:
        print(fmt_row(r))

    # Peak per scenario
    print("\nPeaks (max RPS across threads):")
    for scen in SCENARIO_ORDER:
        series = data[scen]
        peak_thread = max(series, key=lambda k: series[k])
        peak_val = series[peak_thread]
        base_peak_series = data[BASELINE]
        base_at_thread = base_peak_series[peak_thread]
        delta_same_thread = pct(peak_val, base_at_thread)
        peak_vs_base_peak = pct(peak_val, max(base_peak_series.values()))
        note = "" if scen == BASELINE else f" | Δ vs {BASELINE} same thread: {delta_same_thread:+.1f}% | vs {BASELINE} peak: {peak_vs_base_peak:+.1f}%"
        print(f"  {scen:<15} peak {peak_val:8.2f} @ {peak_thread:4}T{note}")


def make_plot(title: str, data: Dict[str, Dict[int, float]], annot_percent: bool, png_name: str):
    fig, ax = plt.subplots(figsize=(11, 5.3))
    x = np.arange(len(THREADS))
    n = len(SCENARIO_ORDER)
    width = 0.14 if n == 4 else 0.18
    for i, scen in enumerate(SCENARIO_ORDER):
        vals = [data[scen][t] for t in THREADS]
        offset = (i - (n-1)/2) * width
        bars = ax.bar(x + offset, vals, width=width, label=scen, color=COLORS[i % len(COLORS)], alpha=0.85 if scen == BASELINE else 0.78)
        base_vals = [data[BASELINE][t] for t in THREADS]
        for b, v, base_v, t in zip(bars, vals, base_vals, THREADS):
            if annot_percent and scen != BASELINE and t != 1:  # omit thread=1 percent (baseline semantics at load >=100)
                delta = pct(v, base_v)
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                        f"{v:.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7.5)
            else:
                ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                        f"{v:.0f}", ha='center', va='bottom', fontsize=7.5)

    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in THREADS])
    ax.set_xlabel("Threads")
    ax.set_ylabel("Requests per second")
    ax.set_title(title)
    ax.grid(axis='y', linestyle='--', alpha=0.25)
    ax.legend(ncol=2, fontsize=9)
    fig.tight_layout()
    fig.savefig(png_name, dpi=140)
    print(f"[OK] Saved plot -> {png_name}")


def make_combined_plot(tidb: Dict[str, Dict[int, float]], tiproxy: Dict[str, Dict[int, float]], annot_percent: bool, png_name: str):
    """Single figure with two stacked subplots (TiDB on top, TiProxy below)."""
    fig, axes = plt.subplots(2, 1, figsize=(11.5, 10.5), sharex=True)
    for ax, (title, dataset) in zip(axes, [("TiDB", tidb), ("TiProxy", tiproxy)]):
        x = np.arange(len(THREADS))
        n = len(SCENARIO_ORDER)
        width = 0.14 if n == 4 else 0.18
        for i, scen in enumerate(SCENARIO_ORDER):
            vals = [dataset[scen][t] for t in THREADS]
            offset = (i - (n-1)/2) * width
            bars = ax.bar(x + offset, vals, width=width, label=scen, color=COLORS[i % len(COLORS)], alpha=0.85 if scen == BASELINE else 0.78)
            base_vals = [dataset[BASELINE][t] for t in THREADS]
            for b, v, base_v, t in zip(bars, vals, base_vals, THREADS):
                if annot_percent and scen != BASELINE and t != 1:
                    delta = pct(v, base_v)
                    ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                            f"{v:.0f}\n{delta:+.1f}%", ha='center', va='bottom', fontsize=7)
                else:
                    ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01,
                            f"{v:.0f}", ha='center', va='bottom', fontsize=7)
        ax.set_ylabel("RPS")
        ax.set_title(f"{title} multi_thread_multi_conn RPS (GCP origin)")
        ax.grid(axis='y', linestyle='--', alpha=0.25)
    axes[-1].set_xticks(np.arange(len(THREADS)))
    axes[-1].set_xticklabels([str(t) for t in THREADS])
    axes[-1].set_xlabel("Threads")
    # Single legend combined (upper subplot)
    handles, labels = axes[0].get_legend_handles_labels()
    axes[0].legend(handles, labels, ncol=2, fontsize=9, loc='upper right')
    fig.tight_layout()
    fig.savefig(png_name, dpi=150)
    print(f"[OK] Saved combined plot -> {png_name}")


def export_csv(path: str, tidb: Dict[str, Dict[int, float]], tiproxy: Dict[str, Dict[int, float]]):
    cols = ["component", "threads", "scenario", "rps", "baseline_rps", "delta_pct_vs_baseline"]
    with open(path, 'w', newline='') as f:
        w = csv.writer(f)
        w.writerow(cols)
        for comp, dataset in [("TiDB", tidb), ("TiProxy", tiproxy)]:
            for scen in SCENARIO_ORDER:
                for t in THREADS:
                    base_v = dataset[BASELINE][t]
                    rps_v = dataset[scen][t]
                    w.writerow([comp, t, scen, f"{rps_v:.2f}", f"{base_v:.2f}", f"{pct(rps_v, base_v):.2f}"])
    print(f"[OK] CSV exported -> {path}")


def main():
    ap = argparse.ArgumentParser(description="Four-scenario TiDB & TiProxy RPS comparison (GCP origin)")
    ap.add_argument("--show-percent", action="store_true", help="Display Δ% vs baseline columns in textual tables")
    ap.add_argument("--annot-percent", action="store_true", help="Annotate bars with Δ% vs baseline (omit baseline & thread=1)")
    ap.add_argument("--csv", metavar="FILE", help="Export combined per-thread data to CSV")
    args = ap.parse_args()

    print_summary("TiDB", TIDB_RPS, args.show_percent)
    print_summary("TiProxy", TIPROXY_RPS, args.show_percent)

    # Unified combined plot
    make_combined_plot(TIDB_RPS, TIPROXY_RPS, args.annot_percent, OUTPUT_PNG)

    if args.csv:
        export_csv(args.csv, TIDB_RPS, TIPROXY_RPS)

    print("\nNotes:")
    print(f" - Baseline: {BASELINE}. Δ% computed per thread vs baseline's RPS at same thread count.")
    print(" - Thread=1 differences often dominated by connection / warm-up effects; focus on >=100 threads for capacity.")
    print(" - Use --show-percent for detailed tables; keep default raw view for uncluttered trend reading.")
    print(" - Peak shifts: observe how GCP-origin load responds to added GCP nodes (latency path not shown here). Unified plot for TiDB & TiProxy saved.")


if __name__ == "__main__":
    main()
