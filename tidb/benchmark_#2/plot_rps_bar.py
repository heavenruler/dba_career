#!/usr/bin/env python3
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv("bench_result.csv")

# 建立圖與雙 Y 軸
fig, ax1 = plt.subplots(figsize=(10,6))

# 左 Y 軸：RPS 長條圖
ax1.bar(df["Threads"], df["RPS"], color="skyblue", label="RPS")
ax1.set_xlabel("Threads")
ax1.set_ylabel("RPS", color="blue")
ax1.tick_params(axis="y", labelcolor="blue")

# 右 Y 軸：CPU 折線
ax2 = ax1.twinx()
ax2.plot(df["Threads"], df["TidbCPU%"], color="red", marker="o", label="TiDB CPU%")
ax2.plot(df["Threads"], df["TiProxyCPU%"], color="green", marker="s", label="TiProxy CPU%")
ax2.set_ylabel("CPU Usage (%)", color="red")
ax2.tick_params(axis="y", labelcolor="red")

# 標題與圖例
fig.suptitle("RPS vs CPU Usage")
fig.legend(loc="upper left", bbox_to_anchor=(0.1,0.9))

plt.tight_layout()
plt.savefig("bench_rps_cpu.png")
plt.show()

