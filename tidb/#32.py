# 導入繪圖套件
import matplotlib.pyplot as plt

# Mix GCP / IDC Galera Cluster 數據
threads1 = [100, 1000]
rps1 = [4433.66, 4787.52]

# IDC * 3 + GCP * 2 RPS From TiProxy with GCP 數據
threads2 = [100, 1000]
rps2 = [2730.93, 3163.58]

# 繪製折線圖
plt.figure(figsize=(8, 5))
plt.plot(threads1, rps1, marker='o', linestyle='-', color='b', label='Mix GCP/IDC Galera Cluster')
for x, y in zip(threads1, rps1):
	plt.text(x, y, f'{y:.2f}', color='b', fontsize=10, ha='right', va='bottom')

plt.plot(threads2, rps2, marker='s', linestyle='--', color='r', label='IDC*3+GCP*2 TiProxy with GCP')
for x, y in zip(threads2, rps2):
	plt.text(x, y, f'{y:.2f}', color='r', fontsize=10, ha='left', va='top')
plt.title('RPS vs Threads')
plt.xlabel('Threads')
plt.ylabel('RPS')
plt.grid(True)
plt.legend()
plt.tight_layout()
plt.show()
