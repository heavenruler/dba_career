# 導入繪圖套件
import matplotlib.pyplot as plt

# OLTP 測試類型
oltp_types = [
    'oltp_read_only',
    'oltp_read_write',
    'oltp_write_only',
    'select_random_points',
    'select_random_ranges'
]


# Mix GCP / IDC Galera Cluster
avg_latency1 = [94.99, 31.88, 16.87, 6.04, 5.87]
queries_per_sec1 = [1347.26, 5027.75, 2844.80, 1324.68, 1361.37]
transactions_per_sec1 = [84.20, 250.86, 474.13, 1324.68, 1361.37]

# IDC * 2 + GCP * 3 Benchmark from TiProxy with IDC (離峰時段)
avg_latency2 = [64.67, 111.16, 39.93, 11.79, 10.84]
queries_per_sec2 = [1978.59, 1438.38, 1201.83, 678.31, 737.90]
transactions_per_sec2 = [123.66, 71.92, 200.30, 678.31, 737.90]

plt.figure(figsize=(12, 7))

# Galera: 藍色系
plt.plot(oltp_types, avg_latency1, marker='o', linestyle='--', color='#4F81BD', label='Latency - Galera')
plt.plot(oltp_types, queries_per_sec1, marker='s', linestyle='-', color='#5B9BD5', label='QPS - Galera')
plt.plot(oltp_types, transactions_per_sec1, marker='^', linestyle='-', color='#A5C6EF', label='TPS - Galera')
# TiProxy: 橘色系
plt.plot(oltp_types, avg_latency2, marker='o', linestyle='--', color='#F79646', label='Latency - TiProxy')
plt.plot(oltp_types, queries_per_sec2, marker='s', linestyle='-', color='#FFB366', label='QPS - TiProxy')
plt.plot(oltp_types, transactions_per_sec2, marker='^', linestyle='-', color='#FFD9B3', label='TPS - TiProxy')

# 標示數據
for x, y in zip(oltp_types, avg_latency1):
    plt.text(x, y, f'{y:.2f}', color='#4F81BD', fontsize=9, ha='center', va='bottom')
for x, y in zip(oltp_types, queries_per_sec1):
    plt.text(x, y, f'{y:.2f}', color='#5B9BD5', fontsize=9, ha='center', va='bottom')
for x, y in zip(oltp_types, transactions_per_sec1):
    plt.text(x, y, f'{y:.2f}', color='#A5C6EF', fontsize=9, ha='center', va='bottom')
for x, y in zip(oltp_types, avg_latency2):
    plt.text(x, y, f'{y:.2f}', color='#F79646', fontsize=9, ha='center', va='top')
for x, y in zip(oltp_types, queries_per_sec2):
    plt.text(x, y, f'{y:.2f}', color='#FFB366', fontsize=9, ha='center', va='top')
for x, y in zip(oltp_types, transactions_per_sec2):
    plt.text(x, y, f'{y:.2f}', color='#FFD9B3', fontsize=9, ha='center', va='top')

plt.title('OLTP Benchmark Comparison: Galera vs TiProxy (IDC*2+GCP*3 離峰)')
plt.xlabel('OLTP Type')
plt.ylabel('Value')
plt.legend()
plt.grid(True)
plt.tight_layout()
plt.show()
