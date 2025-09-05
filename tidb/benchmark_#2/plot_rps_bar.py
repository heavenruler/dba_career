#!/usr/bin/env python3
import argparse
import os
import sys
import pandas as pd
import matplotlib
matplotlib.use("Agg")  # 可避免無 DISPLAY 時失敗
import matplotlib.pyplot as plt

parser = argparse.ArgumentParser(description="Plot RPS bar and CPU lines from CSV")
parser.add_argument("--csv", default="bench_result.csv", help="Input CSV (default: bench_result.csv)")
parser.add_argument("--out", default="bench_rps_cpu.png", help="Output image file")
parser.add_argument("--show", action="store_true", help="Also display window (needs GUI)")
args = parser.parse_args()

if not os.path.isfile(args.csv):
	print(f"[error] CSV not found: {args.csv}", file=sys.stderr)
	sys.exit(1)

df = pd.read_csv(args.csv)
required_cols = {"Threads","RPS","TidbCPU%","TiProxyCPU%"}
missing = required_cols - set(df.columns)
if missing:
	print(f"[warn] Missing columns: {missing} (plotting available ones)")

fig, ax1 = plt.subplots(figsize=(10,6))
ax1.bar(df["Threads"], df["RPS"], color="skyblue", label="RPS")
ax1.set_xlabel("Threads")
ax1.set_ylabel("RPS", color="blue")
ax1.tick_params(axis="y", labelcolor="blue")

lines, labels = ax1.get_legend_handles_labels()

ax2 = ax1.twinx()
if "TidbCPU%" in df.columns:
	l1 = ax2.plot(df["Threads"], df["TidbCPU%"], color="red", marker="o", label="TiDB CPU%")
	lines += l1; labels += ["TiDB CPU%"]
if "TiProxyCPU%" in df.columns:
	l2 = ax2.plot(df["Threads"], df["TiProxyCPU%"], color="green", marker="s", label="TiProxy CPU%")
	lines += l2; labels += ["TiProxy CPU%"]
ax2.set_ylabel("CPU Usage (%)", color="red")
ax2.tick_params(axis="y", labelcolor="red")

fig.suptitle("RPS vs CPU Usage")
if lines:
	fig.legend(lines, labels, loc="upper left", bbox_to_anchor=(0.1,0.9))

plt.tight_layout()
plt.savefig(args.out)
print(f"Saved {args.out}")
if args.show:
	plt.show()

