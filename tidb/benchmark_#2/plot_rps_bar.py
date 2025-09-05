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
threads = df["Threads"]
rps = df["RPS"]
bars = ax1.bar([str(t) for t in threads], rps, color="#1f77b4", alpha=0.78, label="RPS")
ax1.set_xlabel("Threads")
ax1.set_ylabel("Requests / sec", color="#003A70")
ax1.tick_params(axis="y", labelcolor="#003A70")

# Baseline: choose first thread >= min threshold (e.g.  threads sorted, commonly 1 or 100). Prefer 100 if present
baseline_val = None
if 100 in set(threads):
	baseline_val = float(df.loc[df["Threads"]==100, "RPS"].iloc[0])
elif len(rps):
	baseline_val = float(rps.iloc[0])
if baseline_val:
	ax1.axhline(baseline_val, color="#666", linestyle="--", linewidth=1, label=("100-thread baseline" if 100 in set(threads) else "baseline"))

# Annotate each bar with RPS and delta vs baseline
for b, t, val in zip(bars, threads, rps):
	if baseline_val and baseline_val > 0:
		delta_pct = (val - baseline_val) / baseline_val * 100.0
		delta_str = f"{delta_pct:+.1f}%" if (t != 100 or baseline_val != val) else "+0.0%"
		color = "#d62728" if delta_pct > 0 else ("#2ca02c" if delta_pct < 0 else "#000000")
		ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{val:.0f}\n{delta_str}",
				 ha='center', va='bottom', fontsize=8, color=color, linespacing=0.9)
	else:
		ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{val:.0f}", ha='center', va='bottom', fontsize=8)

lines, labels = ax1.get_legend_handles_labels()

ax2 = ax1.twinx()
if "TidbCPU%" in df.columns:
	l1 = ax2.plot([str(t) for t in threads], df["TidbCPU%"], color="#d62728", marker="o", linewidth=2, label="TiDB CPU%")
	lines += l1; labels += ["TiDB CPU%"]
if "TiProxyCPU%" in df.columns:
	l2 = ax2.plot([str(t) for t in threads], df["TiProxyCPU%"], color="#2ca02c", marker="s", linewidth=2, label="TiProxy CPU%")
	lines += l2; labels += ["TiProxy CPU%"]
ax2.set_ylabel("CPU %", color="#d62728")
ax2.tick_params(axis="y", labelcolor="#d62728")

fig.suptitle("RPS & CPU Usage Scaling")
if lines:
	fig.legend(lines, labels, loc="upper left", bbox_to_anchor=(0.08,0.92))

plt.tight_layout()
plt.savefig(args.out)
print(f"Saved {args.out}")
if args.show:
	plt.show()

