#!/usr/bin/env python3
"""
RPS scale comparison with optional Δ% vs baseline (IDC*3).

Datasets (multi_thread_multi_conn):
  TiDB   : #5-1 (IDC*3 baseline), #9-5 (IDC simultaneous), #9-7 (GCP simultaneous)
  TiProxy: #5-2 (IDC*3 baseline), #9-6 (IDC simultaneous), #9-8 (GCP simultaneous)

Features:
  - Raw RPS grouped bars (TiDB top / TiProxy bottom)
  - Optional per-thread Δ% vs baseline (IDC*3) printed (--show-percent)
  - Optional bar second-line annotation of Δ% for non-baseline scenarios (--annot-percent)

Output PNG: #5-1_#9-5_#9-7_#5-2_#9-6_#9-8_scale_compare.png
"""
from __future__ import annotations

import argparse
from typing import List, Tuple

try:
    import matplotlib.pyplot as plt  # type: ignore
except Exception:  # pragma: no cover
    plt = None

THREADS = [1, 100, 200, 250, 500, 750, 1000]

# TiDB datasets
TIDB_IDC3 =    {1: 661.34, 100: 3788.97, 200: 7137.34, 250: 3653.09, 500: 2428.03, 750: 2731.68, 1000: 2869.28}
TIDB_IDC_SIM = {1: 591.14, 100: 3938.95, 200: 9545.70, 250: 4028.54, 500: 2719.85, 750: 2809.31, 1000: 2229.57}
TIDB_GCP_SIM = {1: 938.11, 100: 2907.39, 200: 5703.00, 250: 2650.38, 500: 4337.12, 750: 1980.50, 1000: 3224.52}

# TiProxy datasets
TIPROXY_IDC3 =    {1: 384.32, 100: 5899.92, 200: 3839.15, 250: 5693.22, 500: 3126.86, 750: 4265.93, 1000: 3188.79}
TIPROXY_IDC_SIM = {1: 394.48, 100: 2693.88, 200: 2626.27, 250: 5156.92, 500: 3387.40, 750: 4017.87, 1000: 3126.35}
TIPROXY_GCP_SIM = {1: 610.76, 100: 2581.78, 200: 3853.03, 250: 2365.68, 500: 3233.98, 750: 1807.05, 1000: 2577.48}

# Scenario ordering (baseline first)
TIDB_SCENARIOS: List[Tuple[str, dict, str]] = [
    ("TiDB IDC*3", TIDB_IDC3, '#1f77b4'),
    ("TiDB IDC Req", TIDB_IDC_SIM, '#ff7f0e'),
    ("TiDB GCP Req", TIDB_GCP_SIM, '#2ca02c'),
]
TIPROXY_SCENARIOS: List[Tuple[str, dict, str]] = [
    ("TiProxy IDC*3", TIPROXY_IDC3, '#1f77b4'),
    ("TiProxy IDC Req", TIPROXY_IDC_SIM, '#ff7f0e'),
    ("TiProxy GCP Req", TIPROXY_GCP_SIM, '#2ca02c'),
]

OUTPUT_PNG = '#5-1_#9-5_#9-7_#5-2_#9-6_#9-8_scale_compare.png'


def pct(new: float, base: float) -> float:
    return (new / base - 1.0) * 100.0 if base else 0.0


def print_percent_tables():
    def table(title: str, scenarios: List[Tuple[str, dict, str]]):
        baseline_label, baseline_map, _ = scenarios[0]
        others = scenarios[1:]
        headers = ["Threads", f"{baseline_label} RPS"] + [f"{lbl} Δ%" for lbl, *_ in others]
        rows = []
        col_w = [len(h) for h in headers]
        for t in THREADS:
            base_v = baseline_map[t]
            row = [str(t), f"{base_v:.2f}"]
            for lbl, mapping, _ in others:
                dv = pct(mapping[t], base_v)
                row.append(f"{dv:+.1f}%")
            rows.append(row)
            for i, cell in enumerate(row):
                if len(cell) > col_w[i]:
                    col_w[i] = len(cell)
        def fmt(r):
            return " | ".join(r[i].rjust(col_w[i]) for i in range(len(r)))
        print(f"\n[{title}] Δ% vs {baseline_label}")
        print(fmt(headers))
        print("-+-".join('-'*w for w in col_w))
        for r in rows:
            print(fmt(r))
    table('TiDB', TIDB_SCENARIOS)
    table('TiProxy', TIPROXY_SCENARIOS)


def plot(annot_percent: bool):  # pragma: no cover
    if not plt:
        print('[WARN] matplotlib not available; cannot create plot.')
        return False
    fig, axes = plt.subplots(2, 1, figsize=(11, 10), sharex=True)

    def grouped(ax, scenarios: List[Tuple[str, dict, str]], title: str):
        bar_w = 0.25
        x_idx = list(range(len(THREADS)))
        baseline_map = scenarios[0][1]
        for i, (label, data, color) in enumerate(scenarios):
            offs = [x + (i-1)*bar_w for x in x_idx]
            vals = [data[t] for t in THREADS]
            bars = ax.bar(offs, vals, width=bar_w, label=label, color=color, alpha=0.85)
            for idx, (b, v) in enumerate(zip(bars, vals)):
                txt = f"{int(round(v))}"
                if annot_percent and i > 0:  # annotate only non-baseline
                    dv = pct(v, baseline_map[THREADS[idx]])
                    txt += f"\n{dv:+.0f}%"
                ax.text(b.get_x()+b.get_width()/2, v*1.01, txt, ha='center', va='bottom', fontsize=7, linespacing=0.9)
        ax.set_xticks(x_idx, THREADS)
        ax.set_ylabel('RPS')
        ax.set_title(title)
        ax.grid(axis='y', alpha=0.3)
        ax.legend(fontsize=8)

    grouped(axes[0], TIDB_SCENARIOS, 'TiDB RPS (Raw)')
    grouped(axes[1], TIPROXY_SCENARIOS, 'TiProxy RPS (Raw)')

    axes[1].set_xlabel('Threads')
    fig.suptitle('TiDB & TiProxy multi_thread_multi_conn RPS (Raw Values)')
    fig.tight_layout(rect=[0,0,1,0.94])
    fig.savefig(OUTPUT_PNG, dpi=160)
    print(f'[OK] Saved {OUTPUT_PNG}')
    return True


def main():
    parser = argparse.ArgumentParser(description='RPS scale comparison with optional Δ% vs IDC*3 baseline')
    parser.add_argument('--show-percent', action='store_true', help='Print Δ% tables vs IDC*3 baseline')
    parser.add_argument('--annot-percent', action='store_true', help='Annotate non-baseline bars with Δ% second line')
    args = parser.parse_args()

    if args.show_percent:
        print_percent_tables()
    plot(annot_percent=args.annot_percent)


if __name__ == '__main__':
    main()

# NOTE: Removed duplicated corrupted second script section that caused IndentationError.
