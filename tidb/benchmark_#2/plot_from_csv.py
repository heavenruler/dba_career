#!/usr/bin/env python3
import os
import sys
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

csv_path = os.environ.get('LOCAL_FILE', 'test')
plot_out = os.environ.get('PLOT_OUT', 'plot.png')

if not os.path.isfile(csv_path):
    print(f"[error] CSV not found: {csv_path}", file=sys.stderr)
    sys.exit(1)

try:
    df = pd.read_csv(csv_path)
except Exception as e:
    print(f"[error] Failed to read CSV: {e}", file=sys.stderr)
    sys.exit(2)

required = {"Threads", "RPS"}
if not required.issubset(df.columns):
    print(f"[error] Missing required columns: {required - set(df.columns)}", file=sys.stderr)
    sys.exit(3)

fig, ax1 = plt.subplots(figsize=(8,5))
ax1.bar(df['Threads'], df['RPS'], color='#4DA6FF', label='RPS')
ax1.set_xlabel('Threads')
ax1.set_ylabel('RPS', color='#004C99')
ax1.tick_params(axis='y', labelcolor='#004C99')

if 'TidbCPU%' in df.columns or 'TiProxyCPU%' in df.columns:
    ax2 = ax1.twinx()
    if 'TidbCPU%' in df.columns:
        ax2.plot(df['Threads'], df['TidbCPU%'], color='red', marker='o', label='TiDB CPU%')
    if 'TiProxyCPU%' in df.columns:
        ax2.plot(df['Threads'], df['TiProxyCPU%'], color='green', marker='s', label='TiProxy CPU%')
    ax2.set_ylabel('CPU %')
    lines, labels = [], []
    for ax in (ax1, ax2):
        h, l = ax.get_legend_handles_labels()
        lines.extend(h); labels.extend(l)
    if lines:
        ax1.legend(lines, labels, loc='upper left')

fig.suptitle('RPS & CPU Usage')
plt.tight_layout()
plt.savefig(plot_out)
print(f"Saved chart to {plot_out}")
