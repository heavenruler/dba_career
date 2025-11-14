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

## (移除 ScaleEff 與 baseline，僅保留純 RPS 顯示)

# 標註每個 bar 的 RPS 數字（移除 baseline / delta）
for b, val in zip(bars, rps):
	ax1.text(b.get_x()+b.get_width()/2, b.get_height()*1.01, f"{val:.0f}",
			 ha='center', va='bottom', fontsize=8, color="#000000")

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

# 動態標題：若存在 Timestamp 欄位，加入起訖時間
title = "RPS & CPU Usage Scaling"
if 'Timestamp' in df.columns and len(df['Timestamp']) > 0:
	try:
		ts = pd.to_datetime(df['Timestamp'])
		start_ts = ts.iloc[0]
		end_ts = ts.iloc[-1]
		if start_ts.date() == end_ts.date():
			# 同一天：顯示 日期 與 時間區間
			title += f" ({start_ts.strftime('%Y-%m-%d')} {start_ts.strftime('%H:%M:%S')} ~ {end_ts.strftime('%H:%M:%S')})"
		else:
			# 不同天：各自完整時間
			title += f" ({start_ts.strftime('%Y-%m-%d %H:%M:%S')} ~ {end_ts.strftime('%Y-%m-%d %H:%M:%S')})"
	except Exception:
		pass
fig.suptitle(title)
if lines:
	fig.legend(lines, labels, loc="upper left", bbox_to_anchor=(0.08,0.92))

plt.tight_layout()
plt.savefig(args.out)
print(f"Saved {args.out}")
if args.show:
	plt.show()

