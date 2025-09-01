#!/usr/bin/env python3
"""
RPS scale comparison (raw values only, no percentage annotations)

Datasets (multi_thread_multi_conn):
  TiDB   : #3-1 (IDC*1 baseline), #9-5 (IDC simultaneous), #9-7 (GCP simultaneous)
  TiProxy: #3-2 (IDC*1 baseline), #9-6 (IDC simultaneous), #9-8 (GCP simultaneous)

Output: #3-1_#9-5_#9-7_#3-2_#9-6_#9-8_scale_compare.png
"""
from __future__ import annotations

import math  # kept in case of later extensions

try:
    import matplotlib.pyplot as plt
except Exception:  # pragma: no cover
    plt = None

# (threads, rps)
THREADS = [1, 100, 200, 250, 500, 750, 1000]

TIDB_IDC1 = {   1: 703.02, 100: 5178.16, 200: 5346.08, 250: 5107.33, 500: 4499.16, 750: 4255.60, 1000: 3190.80 }
TIDB_IDC_SIM = {1: 591.14, 100: 3938.95, 200: 9545.70, 250: 4028.54, 500: 2719.85, 750: 2809.31, 1000: 2229.57 }
TIDB_GCP_SIM = {1: 938.11, 100: 2907.39, 200: 5703.00, 250: 2650.38, 500: 4337.12, 750: 1980.50, 1000: 3224.52 }

TIPROXY_IDC1 = {1: 502.62, 100: 3220.79, 200: 3465.21, 250: 3428.05, 500: 3337.43, 750: 3054.79, 1000: 2968.66 }
TIPROXY_IDC_SIM = {1: 394.48, 100: 2693.88, 200: 2626.27, 250: 5156.92, 500: 3387.40, 750: 4017.87, 1000: 3126.35 }
TIPROXY_GCP_SIM = {1: 610.76, 100: 2581.78, 200: 3853.03, 250: 2365.68, 500: 3233.98, 750: 1807.05, 1000: 2577.48 }

OUTPUT_PNG = '#3-1_#9-5_#9-7_#3-2_#9-6_#9-8_scale_compare.png'


def plot():
    if not plt:  # pragma: no cover
        print('[WARN] matplotlib not available; cannot create plot.')
        return False
    fig, axes = plt.subplots(1, 2, figsize=(15, 5), sharey=False)

    def grouped(ax, datasets, title):
        bar_w = 0.25
        x_idx = list(range(len(THREADS)))
        colors = ['#1f77b4', '#ff7f0e', '#2ca02c']
        for i, (label, data, color) in enumerate(datasets):
            offs = [x + (i-1)*bar_w for x in x_idx]
            vals = [data[t] for t in THREADS]
            bars = ax.bar(offs, vals, width=bar_w, label=label, color=color, alpha=0.85)
            for b, v in zip(bars, vals):
                ax.text(b.get_x()+b.get_width()/2, v*1.01, f'{int(round(v))}', ha='center', va='bottom', fontsize=7)
        ax.set_xticks(x_idx, THREADS)
        ax.set_xlabel('Threads')
        ax.set_ylabel('RPS')
        ax.set_title(title)
        ax.grid(axis='y', alpha=0.3)
        ax.legend(fontsize=8)

    grouped(axes[0], [
        ('TiDB IDC*1', TIDB_IDC1, '#1f77b4'),
        ('TiDB IDC Sim', TIDB_IDC_SIM, '#ff7f0e'),
        ('TiDB GCP Sim', TIDB_GCP_SIM, '#2ca02c'),
    ], 'TiDB RPS (Raw)')

    grouped(axes[1], [
        ('TiProxy IDC*1', TIPROXY_IDC1, '#1f77b4'),
        ('TiProxy IDC Sim', TIPROXY_IDC_SIM, '#ff7f0e'),
        ('TiProxy GCP Sim', TIPROXY_GCP_SIM, '#2ca02c'),
    ], 'TiProxy RPS (Raw)')

    fig.suptitle('TiDB & TiProxy multi_thread_multi_conn RPS (Raw Values)')
    fig.tight_layout(rect=[0,0,1,0.94])
    fig.savefig(OUTPUT_PNG, dpi=160)
    print(f'[OK] Saved {OUTPUT_PNG}')
    return True


def main():
    plot()


if __name__ == '__main__':
    main()
