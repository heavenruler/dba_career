#!/usr/bin/env python3
"""
RPS scale comparison (raw values only, no percentage annotations)

Datasets (multi_thread_multi_conn):
  TiDB   : #5-1 (IDC*3 baseline), #9-5 (IDC simultaneous), #9-7 (GCP simultaneous)
  TiProxy: #5-2 (IDC*3 baseline), #9-6 (IDC simultaneous), #9-8 (GCP simultaneous)

Output: #5-1_#9-5_#9-7_#5-2_#9-6_#9-8_scale_compare.png
"""
from __future__ import annotations

import math  # reserved for future calculations

try:
    import matplotlib.pyplot as plt
except Exception:  # pragma: no cover
    plt = None

# (threads, rps)
THREADS = [1, 100, 200, 250, 500, 750, 1000]

# From #5-1.py (TiDB IDC*3 Off-Peak?) multi_thread_multi_conn
TIDB_IDC3 = {1: 661.34, 100: 3788.97, 200: 7137.34, 250: 3653.09, 500: 2428.03, 750: 2731.68, 1000: 2869.28}
# From #9-5.py (TiDB IDC simultaneous)
TIDB_IDC_SIM = {1: 591.14, 100: 3938.95, 200: 9545.70, 250: 4028.54, 500: 2719.85, 750: 2809.31, 1000: 2229.57}
# From #9-7.py (TiDB GCP simultaneous)
TIDB_GCP_SIM = {1: 938.11, 100: 2907.39, 200: 5703.00, 250: 2650.38, 500: 4337.12, 750: 1980.50, 1000: 3224.52}

# From #5-2.py (TiProxy IDC*3 dataset)
TIPROXY_IDC3 = {1: 384.32, 100: 5899.92, 200: 3839.15, 250: 5693.22, 500: 3126.86, 750: 4265.93, 1000: 3188.79}
# From #9-6.py (TiProxy IDC simultaneous)
TIPROXY_IDC_SIM = {1: 394.48, 100: 2693.88, 200: 2626.27, 250: 5156.92, 500: 3387.40, 750: 4017.87, 1000: 3126.35}
# From #9-8.py (TiProxy GCP simultaneous)
TIPROXY_GCP_SIM = {1: 610.76, 100: 2581.78, 200: 3853.03, 250: 2365.68, 500: 3233.98, 750: 1807.05, 1000: 2577.48}

OUTPUT_PNG = '#5-1_#9-5_#9-7_#5-2_#9-6_#9-8_scale_compare.png'


def plot():
    if not plt:  # pragma: no cover
        print('[WARN] matplotlib not available; cannot create plot.')
        return False
    fig, axes = plt.subplots(2, 1, figsize=(11, 10), sharex=True)

    def grouped(ax, datasets, title):
        bar_w = 0.25
        x_idx = list(range(len(THREADS)))
        for i, (label, data, color) in enumerate(datasets):
            offs = [x + (i-1)*bar_w for x in x_idx]
            vals = [data[t] for t in THREADS]
            bars = ax.bar(offs, vals, width=bar_w, label=label, color=color, alpha=0.85)
            for b, v in zip(bars, vals):
                ax.text(b.get_x()+b.get_width()/2, v*1.01, f'{int(round(v))}', ha='center', va='bottom', fontsize=7)
        ax.set_xticks(x_idx, THREADS)
        ax.set_ylabel('RPS')
        ax.set_title(title)
        ax.grid(axis='y', alpha=0.3)
        ax.legend(fontsize=8)

    grouped(axes[0], [
        ('TiDB IDC*3', TIDB_IDC3, '#1f77b4'),
        ('TiDB IDC Sim', TIDB_IDC_SIM, '#ff7f0e'),
        ('TiDB GCP Sim', TIDB_GCP_SIM, '#2ca02c'),
    ], 'TiDB RPS (Raw)')

    grouped(axes[1], [
        ('TiProxy IDC*3', TIPROXY_IDC3, '#1f77b4'),
        ('TiProxy IDC Sim', TIPROXY_IDC_SIM, '#ff7f0e'),
        ('TiProxy GCP Sim', TIPROXY_GCP_SIM, '#2ca02c'),
    ], 'TiProxy RPS (Raw)')

    axes[1].set_xlabel('Threads')
    fig.suptitle('TiDB & TiProxy multi_thread_multi_conn RPS (Raw Values)')
    fig.tight_layout(rect=[0,0,1,0.94])
    fig.savefig(OUTPUT_PNG, dpi=160)
    print(f'[OK] Saved {OUTPUT_PNG}')
    return True


def main():
    plot()


if __name__ == '__main__':
    main()
