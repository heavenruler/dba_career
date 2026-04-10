#!/usr/bin/env python3
"""
Three-way multi_thread_multi_conn RPS comparison (raw values only, no percentages).

Scenarios (TiDB / TiProxy):
 1) IDC * 3               (#5-1 TiDB,  #5-2 TiProxy)
 2) IDC * 1 + GCP * 2     (#7-5 TiDB,  #7-6 TiProxy)  (Simultaneous Exec / Label Isolation)
 3) IDC * 2 + GCP * 3     (#10-5 TiDB, #10-6 TiProxy) (Simultaneous Exec)

Thread set: 1,100,200,250,500,750,1000

Output PNG: #5-1_#7-5_#10-5_#5-2_#7-6_#10-6_scale_compare.png
 - Left subplot: TiDB RPS grouped bars (3 scenarios) per thread count
 - Right subplot: TiProxy RPS grouped bars (3 scenarios) per thread count
 - Bar labels: raw RPS (rounded) only (user preference: no percentage deltas)

Data source: values copied directly from individual dataset scripts to maintain consistency.
"""
from __future__ import annotations

from typing import Dict, List
import argparse

THREADS = [1, 100, 200, 250, 500, 750, 1000]

TIDB_RPS: Dict[str, Dict[int, float]] = {
    "IDC*3": {      # #5-1.py
        1: 661.34, 100: 3788.97, 200: 7137.34, 250: 3653.09, 500: 2428.03, 750: 2731.68, 1000: 2869.28,
    },
    "IDC*1+GCP*2": {  # #7-5.py
        1: 655.42, 100: 3245.01, 200: 4910.52, 250: 3435.43, 500: 4392.55, 750: 2743.21, 1000: 1885.80,
    },
    "IDC*2+GCP*3": {  # #10-5.py
        1: 686.89, 100: 2740.70, 200: 8362.52, 250: 3610.48, 500: 5277.11, 750: 2723.41, 1000: 4278.33,
    },
}

TIPROXY_RPS: Dict[str, Dict[int, float]] = {
    "IDC*3": {      # #5-2.py
        1: 384.32, 100: 5899.92, 200: 3839.15, 250: 5693.22, 500: 3126.86, 750: 4265.93, 1000: 3188.79,
    },
    "IDC*1+GCP*2": {  # #7-6.py
        1: 488.56, 100: 2963.69, 200: 3106.60, 250: 3044.20, 500: 2939.32, 750: 2209.29, 1000: 2726.36,
    },
    "IDC*2+GCP*3": {  # #10-6.py
        1: 427.62, 100: 4446.78, 200: 3960.35, 250: 3664.94, 500: 3507.28, 750: 2149.38, 1000: 2866.68,
    },
}

SCENARIO_ORDER = ["IDC*3", "IDC*1+GCP*2", "IDC*2+GCP*3"]


def _peak(rps_map: Dict[str, Dict[int, float]]):
    info = {}
    for scen, series in rps_map.items():
        thr, rps = max(series.items(), key=lambda kv: kv[1])
        info[scen] = (thr, rps)
    return info


def pct(new: float, base: float) -> float:
    return (new / base - 1.0) * 100.0 if base else 0.0


def print_summary(show_percent: bool):
    print("Three-way RPS comparison (raw values)")
    print("Threads: " + ", ".join(str(t) for t in THREADS))

    def table(rps_map: Dict[str, Dict[int, float]], title: str):
        print(f"\n[{title}] RPS table")
        header = ["Threads"] + SCENARIO_ORDER
        # Corrected: use header[0] instead of undefined 'h'
        col_w = [max(len(header[0]), 7)] + [max(len(s), 7) for s in SCENARIO_ORDER]
        rows: List[List[str]] = []
        for t in THREADS:
            row = [str(t)] + [f"{rps_map[scen][t]:.2f}" for scen in SCENARIO_ORDER]
            rows.append(row)
        # widen columns for data
        for i in range(len(header)):
            col_w[i] = max(col_w[i], *(len(r[i]) for r in rows))
        def fmt_row(r):
            return " | ".join(r[i].rjust(col_w[i]) for i in range(len(r)))
        print(fmt_row(header))
        print("-+-".join('-'*w for w in col_w))
        for r in rows:
            print(fmt_row(r))
    table(TIDB_RPS, "TiDB")
    table(TIPROXY_RPS, "TiProxy")

    tidb_peaks = _peak(TIDB_RPS)
    tiproxy_peaks = _peak(TIPROXY_RPS)
    print("\nPeak RPS (TiDB):")
    for scen in SCENARIO_ORDER:
        thr, rps = tidb_peaks[scen]
        print(f"  {scen:>13}: {rps:.2f} @ {thr} threads")
    print("Peak RPS (TiProxy):")
    for scen in SCENARIO_ORDER:
        thr, rps = tiproxy_peaks[scen]
        print(f"  {scen:>13}: {rps:.2f} @ {thr} threads")

    notable_threads = sorted({tidb_peaks["IDC*3"][0], tidb_peaks["IDC*2+GCP*3"][0], tiproxy_peaks["IDC*3"][0], tiproxy_peaks["IDC*1+GCP*2"][0]})
    print("\nAbsolute RPS differences (selected peak-related thread counts):")
    for t in notable_threads:
        tidb_vals = [TIDB_RPS[s][t] for s in SCENARIO_ORDER]
        tip_vals = [TIPROXY_RPS[s][t] for s in SCENARIO_ORDER]
        print(f"  Threads {t:>4}: TiDB max-min Δ={max(tidb_vals)-min(tidb_vals):.2f}; TiProxy max-min Δ={max(tip_vals)-min(tip_vals):.2f}")

    if show_percent:
        def delta_table(rps_map: Dict[str, Dict[int, float]], title: str):
            base_label = "IDC*3"
            base_series = rps_map[base_label]
            other_labels = [s for s in SCENARIO_ORDER if s != base_label]
            print(f"\n[{title}] Δ% vs {base_label} (per thread)")
            header = ["Threads", f"{base_label} RPS"] + [f"{lbl} Δ%" for lbl in other_labels]
            col_w = [len(h) for h in header]
            rows = []
            for t in THREADS:
                base_v = base_series[t]
                row = [str(t), f"{base_v:.2f}"]
                for lbl in other_labels:
                    dv = pct(rps_map[lbl][t], base_v)
                    row.append(f"{dv:+.1f}%")
                rows.append(row)
                for i, cell in enumerate(row):
                    if len(cell) > col_w[i]:
                        col_w[i] = len(cell)
            def fmt(r):
                return " | ".join(r[i].rjust(col_w[i]) for i in range(len(r)))
            print(fmt(header))
            print("-+-".join('-'*w for w in col_w))
            for r in rows:
                print(fmt(r))
        delta_table(TIDB_RPS, "TiDB")
        delta_table(TIPROXY_RPS, "TiProxy")

    print("\nNotes:")
    print(" - TiDB strong peak at 200T in 'IDC*2+GCP*3' (8362.52) vs 'IDC*3' 200T 7137.34.")
    print(" - TiProxy peak: 'IDC*3' 100T 5899.92; mixed scenarios do not surpass local peak across threads.")
    if show_percent:
        print(" - Δ% tables show per-thread relative gap; positives = higher than baseline, negatives = lower.")
    else:
        print(" - Percent difference tables hidden (enable with --show-percent).")


def make_plot(annot_percent: bool):  # pragma: no cover
    try:
        import matplotlib.pyplot as plt
        import numpy as np
    except Exception:
        print("[WARN] matplotlib/numpy not available; skipping PNG generation.")
        return False

    x = np.arange(len(THREADS))
    width = 0.25
    colors_tidb = ["#1f77b4", "#ff7f0e", "#2ca02c"]
    colors_tip = ["#9467bd", "#8c564b", "#17becf"]
    # Vertical stacking: TiDB (top), TiProxy (bottom)
    fig, axes = plt.subplots(2, 1, figsize=(10, 11), sharex=True)

    # Baselines for percent annotation
    tidb_base = [TIDB_RPS['IDC*3'][t] for t in THREADS]
    tip_base = [TIPROXY_RPS['IDC*3'][t] for t in THREADS]

    # TiDB (top)
    ax = axes[0]
    for i, scen in enumerate(SCENARIO_ORDER):
        series = [TIDB_RPS[scen][t] for t in THREADS]
        pos = x + (i - 1) * width
        bars = ax.bar(pos, series, width, label=scen, color=colors_tidb[i], alpha=0.85)
        for idx, (b, val) in enumerate(zip(bars, series)):
            label = f"{val:.0f}"
            if annot_percent and scen != 'IDC*3':
                base_v = tidb_base[idx]
                delta = (val / base_v - 1.0) * 100 if base_v else 0.0
                label += f"\n{delta:+.0f}%"
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, label, ha='center', va='bottom', fontsize=8, linespacing=0.9)
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in THREADS])
    ax.set_xlabel("Threads")
    ax.set_ylabel("TiDB Req/sec")
    ax.set_title("TiDB Three-Way RPS")
    ax.legend(fontsize=9)
    ax.grid(axis='y', linestyle='--', alpha=0.3)

    # TiProxy (bottom)
    ax = axes[1]
    for i, scen in enumerate(SCENARIO_ORDER):
        series = [TIPROXY_RPS[scen][t] for t in THREADS]
        pos = x + (i - 1) * width
        bars = ax.bar(pos, series, width, label=scen, color=colors_tip[i], alpha=0.85)
        for idx, (b, val) in enumerate(zip(bars, series)):
            label = f"{val:.0f}"
            if annot_percent and scen != 'IDC*3':
                base_v = tip_base[idx]
                delta = (val / base_v - 1.0) * 100 if base_v else 0.0
                label += f"\n{delta:+.0f}%"
            ax.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, label, ha='center', va='bottom', fontsize=8, linespacing=0.9)
    ax.set_xticks(x)
    ax.set_xticklabels([str(t) for t in THREADS])
    ax.set_xlabel("Threads")
    ax.set_ylabel("TiProxy Req/sec")
    ax.set_title("TiProxy Three-Way RPS")
    ax.legend(fontsize=9)
    ax.grid(axis='y', linestyle='--', alpha=0.3)

    fig.suptitle("Three-Way RPS Comparison (Raw Values)\nTiDB (Top) / TiProxy (Bottom)", fontsize=14, y=0.995)
    fig.tight_layout(rect=[0,0,1,0.975])
    out = "#5-1_#7-5_#10-5_#5-2_#7-6_#10-6_scale_compare.png"
    fig.savefig(out, dpi=140)
    print(f"[OK] Saved plot -> {out}")
    return True


def main():
    parser = argparse.ArgumentParser(description="Three-way RPS comparison")
    parser.add_argument("--show-percent", action="store_true", help="Print per-thread percentage deltas vs IDC*3 baseline")
    parser.add_argument("--annot-percent", action="store_true", help="Annotate bars with Δ% vs IDC*3 baseline (second line, non-baseline scenarios)")
    args = parser.parse_args()
    print_summary(show_percent=args.show_percent)
    make_plot(annot_percent=args.annot_percent)


if __name__ == "__main__":
    main()
