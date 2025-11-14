#!/usr/bin/env python3
"""
Four-way multi_thread_multi_conn RPS comparison (raw + optional Δ% vs baseline).

Scenarios (TiDB / TiProxy):
 1) IDC * 3                 (#5-1 TiDB,  #5-2 TiProxy)          [Baseline]
 2) IDC * 1 + GCP * 2       (#7-5 TiDB,  #7-6 TiProxy)          (Off-Peak Simultaneous / Label Isolation)
 3) IDC * 2 + GCP * 3       (#10-5 TiDB, #10-6 TiProxy)         (Off-Peak Simultaneous)
 4) IDC * 3 + GCP * 3       (#1-5 TiDB,  #1-6 TiProxy)          (Peak Simultaneous)

Threads: 1,100,200,250,500,750,1000

CLI options:
  --show-percent    Print per-thread Δ% tables vs baseline (IDC*3)
  --annot-percent   Add Δ% (vs baseline) as second-line annotations on non-baseline bars

Output PNG: #5-1_#7-5_#10-5_#1-5_#5-2_#7-6_#10-6_#1-6_scale_compare.png
"""
from __future__ import annotations

from typing import Dict, List
import argparse

THREADS = [1, 100, 200, 250, 500, 750, 1000]

# ---------------- TiDB RPS datasets ----------------
TIDB_RPS: Dict[str, Dict[int, float]] = {
    "IDC*3": {        # #5-1.py Off-Peak
        1: 661.34, 100: 3788.97, 200: 7137.34, 250: 3653.09, 500: 2428.03, 750: 2731.68, 1000: 2869.28,
    },
    "IDC*1+GCP*2": {  # #7-5.py Off-Peak Simultaneous Isolation
        1: 655.42, 100: 3245.01, 200: 4910.52, 250: 3435.43, 500: 4392.55, 750: 2743.21, 1000: 1885.80,
    },
    "IDC*2+GCP*3": {  # #10-5.py Off-Peak Simultaneous
        1: 686.89, 100: 2740.70, 200: 8362.52, 250: 3610.48, 500: 5277.11, 750: 2723.41, 1000: 4278.33,
    },
    "IDC*3+GCP*3": {  # #1-5.py Peak Simultaneous
        1: 659.91, 100: 10277.49, 200: 10093.25, 250: 10136.89, 500: 9060.52, 750: 2752.71, 1000: 3132.93,
    },
}

# --------------- TiProxy RPS datasets ---------------
TIPROXY_RPS: Dict[str, Dict[int, float]] = {
    "IDC*3": {        # #5-2.py Off-Peak
        1: 384.32, 100: 5899.92, 200: 3839.15, 250: 5693.22, 500: 3126.86, 750: 4265.93, 1000: 3188.79,
    },
    "IDC*1+GCP*2": {  # #7-6.py Off-Peak
        1: 488.56, 100: 2963.69, 200: 3106.60, 250: 3044.20, 500: 2939.32, 750: 2209.29, 1000: 2726.36,
    },
    "IDC*2+GCP*3": {  # #10-6.py Off-Peak
        1: 427.62, 100: 4446.78, 200: 3960.35, 250: 3664.94, 500: 3507.28, 750: 2149.38, 1000: 2866.68,
    },
    "IDC*3+GCP*3": {  # #1-6.py Peak
        1: 403.05, 100: 7004.83, 200: 7464.26, 250: 7460.40, 500: 6037.01, 750: 5614.70, 1000: 4517.42,
    },
}

SCENARIO_ORDER = ["IDC*3", "IDC*1+GCP*2", "IDC*2+GCP*3", "IDC*3+GCP*3"]


def pct(new: float, base: float) -> float:
    return (new / base - 1.0) * 100.0 if base else 0.0


def _peak(rps_map: Dict[str, Dict[int, float]]):
    out = {}
    for scen, series in rps_map.items():
        thr, rps = max(series.items(), key=lambda kv: kv[1])
        out[scen] = (thr, rps)
    return out


def print_summary(show_percent: bool):
    print("Four-way RPS comparison (raw values)")
    print("Threads: " + ", ".join(str(t) for t in THREADS))

    def table(rps_map: Dict[str, Dict[int, float]], title: str):
        print(f"\n[{title}] RPS table")
        header = ["Threads"] + SCENARIO_ORDER
        col_w = [max(len(header[0]), 7)] + [max(len(s), 9) for s in SCENARIO_ORDER]
        rows: List[List[str]] = []
        for t in THREADS:
            row = [str(t)] + [f"{rps_map[scen][t]:.2f}" for scen in SCENARIO_ORDER]
            rows.append(row)
        for i in range(len(header)):
            col_w[i] = max(col_w[i], *(len(r[i]) for r in rows))
        def fmt(r):
            return " | ".join(r[i].rjust(col_w[i]) for i in range(len(r)))
        print(fmt(header))
        print("-+-".join('-'*w for w in col_w))
        for r in rows:
            print(fmt(r))
    table(TIDB_RPS, "TiDB")
    table(TIPROXY_RPS, "TiProxy")

    tidb_peaks = _peak(TIDB_RPS)
    tip_peaks = _peak(TIPROXY_RPS)
    print("\nPeak RPS (TiDB):")
    for scen in SCENARIO_ORDER:
        thr, rps = tidb_peaks[scen]
        print(f"  {scen:>14}: {rps:.2f} @ {thr}T")
    print("Peak RPS (TiProxy):")
    for scen in SCENARIO_ORDER:
        thr, rps = tip_peaks[scen]
        print(f"  {scen:>14}: {rps:.2f} @ {thr}T")

    if show_percent:
        def delta_table(rps_map: Dict[str, Dict[int, float]], title: str):
            base_label = SCENARIO_ORDER[0]
            base_series = rps_map[base_label]
            others = [s for s in SCENARIO_ORDER if s != base_label]
            print(f"\n[{title}] Δ% vs {base_label}")
            header = ["Threads", f"{base_label} RPS"] + [f"{s} Δ%" for s in others]
            widths = [len(h) for h in header]
            rows = []
            for t in THREADS:
                b = base_series[t]
                row = [str(t), f"{b:.2f}"]
                for s in others:
                    row.append(f"{pct(rps_map[s][t], b):+.1f}%")
                rows.append(row)
                for i, cell in enumerate(row):
                    if len(cell) > widths[i]:
                        widths[i] = len(cell)
            def fmt(r):
                return " | ".join(r[i].rjust(widths[i]) for i in range(len(r)))
            print(fmt(header))
            print("-+-".join('-'*w for w in widths))
            for r in rows:
                print(fmt(r))
        delta_table(TIDB_RPS, "TiDB")
        delta_table(TIPROXY_RPS, "TiProxy")

    print("\nNotes:")
    print(" - Baseline(IDC*3) vs mixed/expanded: identify cost of cross-region and benefit of added nodes.")
    print(" - TiDB peak shifts dramatically upward in peak mixed (IDC*3+GCP*3) scenario (10K RPS range).")
    print(" - Off-peak mixed (IDC*2+GCP*3) achieves higher 200T RPS than baseline but below peak mixed expansion.")
    print(" - TiProxy peak improves in mixed peak scenario but baseline local (100T) remains efficiency reference.")
    if show_percent:
        print(" - Δ% tables: positives = higher than baseline per thread; large negatives show cross-region penalty.")
    else:
        print(" - (Use --show-percent for per-thread Δ% tables.)")


def make_plot(annot_percent: bool):  # pragma: no cover
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skipping PNG generation.")
        return False

    x = np.arange(len(THREADS))
    width = 0.18
    colors_tidb = ["#1f77b4", "#ff7f0e", "#2ca02c", "#9467bd"]
    colors_tip = ["#8c564b", "#17becf", "#e377c2", "#7f7f7f"]
    # Stack TiDB (top) and TiProxy (bottom) vertically
    fig, axes = plt.subplots(2, 1, figsize=(10, 11))

    tidb_base = [TIDB_RPS['IDC*3'][t] for t in THREADS]
    tip_base = [TIPROXY_RPS['IDC*3'][t] for t in THREADS]

    # TiDB subplot (top)
    ax = axes[0]
    for i, scen in enumerate(SCENARIO_ORDER):
        series = [TIDB_RPS[scen][t] for t in THREADS]
        pos = x + (i - (len(SCENARIO_ORDER)-1)/2) * width
        bars = ax.bar(pos, series, width, label=scen, color=colors_tidb[i], alpha=0.85)
        for idx, (b, val) in enumerate(zip(bars, series)):
            label = f"{val:.0f}"
            if annot_percent and scen != 'IDC*3':
                base_v = tidb_base[idx]
                d = (val / base_v - 1.0) * 100 if base_v else 0.0
                label += f"\n{d:+.0f}%"
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, label, ha='center', va='bottom', fontsize=7, linespacing=0.9)
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in THREADS])
    ax.set_xlabel("Threads")
    ax.set_ylabel("TiDB Req/sec")
    ax.set_title("TiDB Four-Way RPS")
    ax.legend(fontsize=8, ncol=2)
    ax.grid(axis='y', linestyle='--', alpha=0.3)

    # TiProxy subplot (bottom)
    ax = axes[1]
    for i, scen in enumerate(SCENARIO_ORDER):
        series = [TIPROXY_RPS[scen][t] for t in THREADS]
        pos = x + (i - (len(SCENARIO_ORDER)-1)/2) * width
        bars = ax.bar(pos, series, width, label=scen, color=colors_tip[i], alpha=0.85)
        for idx, (b, val) in enumerate(zip(bars, series)):
            label = f"{val:.0f}"
            if annot_percent and scen != 'IDC*3':
                base_v = tip_base[idx]
                d = (val / base_v - 1.0) * 100 if base_v else 0.0
                label += f"\n{d:+.0f}%"
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, label, ha='center', va='bottom', fontsize=7, linespacing=0.9)
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in THREADS])
    ax.set_xlabel("Threads")
    ax.set_ylabel("TiProxy Req/sec")
    ax.set_title("TiProxy Four-Way RPS")
    ax.legend(fontsize=8, ncol=2)
    ax.grid(axis='y', linestyle='--', alpha=0.3)

    fig.suptitle("Four-Way RPS Comparison (Raw Values)", fontsize=15, y=0.995)
    fig.tight_layout(rect=[0,0,1,0.985])
    out = "#5-1_#7-5_#10-5_#1-5_#5-2_#7-6_#10-6_#1-6_scale_compare.png"
    fig.savefig(out, dpi=140)
    print(f"[OK] Saved plot -> {out}")
    return True


def main():
    p = argparse.ArgumentParser(description="Four-way RPS comparison")
    p.add_argument("--show-percent", action="store_true", help="Print per-thread percentage deltas vs IDC*3 baseline")
    p.add_argument("--annot-percent", action="store_true", help="Annotate bars with Δ% vs baseline (non-baseline scenarios)")
    args = p.parse_args()
    print_summary(show_percent=args.show_percent)
    make_plot(annot_percent=args.annot_percent)


if __name__ == "__main__":
    main()
