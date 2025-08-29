#!/usr/bin/env python3
# -*- coding: utf-8 -*-
from __future__ import annotations
import matplotlib.pyplot as plt

def analyze(data):
    obs = []
    base_rps = None
    for row in data:
        threads, rps, avg_ms, total_time_s = row
        if threads == 1:
            base_rps = rps
            obs.append(f"單執行緒 RPS 基線: {rps:.2f}")
        else:
            eff = rps / (base_rps * threads) if base_rps else 0
            obs.append(f"{threads} 執行緒: RPS={rps:.2f}, 平均延遲={avg_ms:.2f}ms, 效率={eff:.2%}")
    return obs

def ascii_table(data):
    print("{:<8} {:>10} {:>10} {:>12}".format("Threads", "Req/sec", "Avg(ms)", "Total(s)"))
    for row in data:
        threads, rps, avg_ms, total_time_s = row
        print(f"{threads:<8} {rps:>10.2f} {avg_ms:>10.2f} {total_time_s:>12.3f}")

def make_plot(data, filename):
    threads = [row[0] for row in data]
    rps = [row[1] for row in data]
    avg_ms = [row[2] for row in data]
    fig, ax1 = plt.subplots(figsize=(10,6))
    color = 'tab:blue'
    ax1.set_xlabel('Threads')
    ax1.set_ylabel('Req/sec', color=color)
    ax1.bar(threads, rps, color=color, alpha=0.6, label='Req/sec')
    ax1.tick_params(axis='y', labelcolor=color)
    ax2 = ax1.twinx()
    color = 'tab:red'
    ax2.set_ylabel('Avg Response (ms)', color=color)
    ax2.plot(threads, avg_ms, color=color, marker='o', label='Avg(ms)')
    ax2.tick_params(axis='y', labelcolor=color)
    fig.tight_layout()
    plt.title('TiDB IDC 離峰 RPS/Latency')
    plt.savefig(filename)
    plt.close()

def main():
    # multi_thread_multi_conn rows only
    data = [
        (1, 650.82, 1.535, 15.365),
        (100, 10818.03, 7.330, 0.924),
        (200, 10507.58, 12.551, 0.952),
        (250, 10254.49, 14.146, 0.975),
        (500, 8414.04, 21.064, 1.188),
        (750, 6242.34, 11.970, 1.602),
        (1000, 4981.18, 12.104, 2.008),
    ]
    print("#2-1.py TiDB IDC 離峰 RPS/Latency")
    ascii_table(data)
    obs = analyze(data)
    print("\n觀察:")
    for o in obs:
        print(f"- {o}")
    make_plot(data, "#2-1.png")

if __name__ == "__main__":
    main()
