# TiDB Intro

----

## [RPS 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md)

- **MySQL 跨區中併發易掉速（-7%〜-33%）**  
- **TiDB 低併發吞吐可比 MySQL 快 +290%**  
- **跨區高併發（500 threads）TiDB 在 GCP 可快 +402%**  
- **同區高併發（GCP Local vs IDC）TiDB 可快 +518%**  
- **TiDB 跨區穩定度極高：10〜250 threads 僅 ±1%〜2% 波動**  
- **TiDB Scale-Out 成效顯著，可呈接近線性成長**  
- **跨區併發時，負載會自然傾向 TiDB 表現較佳的一側（多為 GCP）**

----

## [Sysbench 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-2.md)

### **==== Single Instance（基準比較） ====**

- **MySQL 在單機效能上全面領先 TiDB（差距 40%～80%）**
  - **OLTP 比較（16 threads TPS 對照）**
    | 類型 | MySQL TPS | TiDB TPS | 差異 |
    |------|-----------|-----------|-----------|
    | read_only | 1342.52 | 559.71 | **-58.3%** |
    | random_points | 18096.01 | 3403.69 | **-81%** |
    | random_ranges | 18309.55 | 4424.09 | **-75%** |
    | write_only | 2625.10 | 1108.85 | **-58%** |
    | update_index | 4015.32 | 2704.83 | **-33%** |
    | read_write | 1003.99 | 354.22 | **-59%** |

- 原因在於：
  - **MySQL：單節點、無 RPC、無 2PC → 本地記憶體路徑極快**
  - **TiDB：SQL Layer → RPC → TiKV → RocksDB → Raft → 固定開銷大**

### **==== Scale-Up（4 → 8 vCPU）vs Scale-Out（單機 → Cluster） ====**

- **MySQL Multi-Primary：Scale-Up 無效益（InnoDB-bound）**
  8 vCPU 改善有限甚至下降：
  - read_only：-3.6%
  - write_only：-5%
  - read_write：-10%
  - 說明
    ```
    - Multi-Primary 凸顯 InnoDB 的競爭瓶頸，屬非 CPU-bound。
    - ProxySQL 只能分流，不是擴容
    ```

- **TiDB：Scale-Up 有效（CPU-bound）**
  8 vCPU 性能提升 **20%～40%**：
  - read_only：+23%
  - write_only：+32%
  - update_index：+29%
  - read_write：**+41%**
  - 說明
    ```
    - SQL 層可多線程併行 → CPU 推動更多 RPC / Goroutine 優勢越大
    - SQL Layer 能以更多 CPU 執行 RPC / Coprocessor 排程
    ```

### **總覽**

| 項目 | MySQL Multi-Primary（4v → 8v） | 差異 | TiDB（單 SQL 多 KV）（4v → 8v） | 差異 | 整體觀察 |
|------|-------------------------------|--------|----------------------------------|--------|-----------|
| **Read-heavy** | 1812.85 → 1746.58 TPS | **-3.7%** | 783.54 → 965.52 TPS | **+23.2%** | TiDB SQL 層併行能力遠優於 MySQL |
| **Write-heavy（write_only）** | 830.24 → 786.62 TPS | **-5.3%** | 1500.30 → 1988.00 TPS | **+32.5%** | MySQL 卡 InnoDB；TiDB 增長幅度高 |
| **Write-heavy（update_index）** | 3434.72 → 3285.13 TPS | **-4.4%** | 3371.89 → 4374.26 TPS | **+29.7%** | MySQL 無擴張性；TiDB 提升穩定 |
| **Mixed（oltp_read_write）** | 862.51 → 770.19 TPS | **-10.7%** | 503.92 → 712.43 TPS | **+41.4%** | TiDB Mixed 對 CPU 擴張最敏感 |
| **CPU 擴張效果** | 無效 / 負向 | - | 明顯有效 | - | MySQL 非 CPU-bound；TiDB CPU-sensitive |
| **本質瓶頸** | InnoDB（BufferPool / Redo / B+Tree） | - | KV（Raft / RocksDB） | - | 架構本質完全不同 |

----

### **==== TiDB Scale-Out（單 SQL 多 KV → 多 SQL 單 KV） ====**

> TiDB 的 Scale-Out 本質是 **SQL 層可橫向擴張 × KV 層可分片化分擔負載**

| 工作負載 | 單 SQL 多 KV（TPS） | 多 SQL 單 KV（TPS） | 差異幅度 |
|----------|----------------------------|----------------------------|------------|
| **Read-heavy（read_only）** | 783.54 | 830.14 | **+6%** |
| **Read-heavy（points）** | 5097.07 | 5538.02 | **+8.6%** |
| **Read-heavy（ranges）** | 5598.35 | 7026.91 | **+25.5%** |
| **Write-heavy（update_index）** | 3371.89 | 3946.03 | **+17.1%** |
| **Write-heavy（write_only）** | 1500.30 | 1782.03 | **+18.8%** |
| **Mixed（read_write）** | 503.92 | 561.45 | **+11.4%** |

----

### **==== 跨區延遲與寫入競爭（IDC vs IDC+GCP） ====**

> **MySQL 用「Excpetion＋Retry」換取跨區 TPS；TiDB 用「容忍高延遲」換取零錯誤與一致性。**

### **IDC+GCP 雙邊壓測比較**

| 工作負載 | MySQL (IDC) | MySQL (GCP) | MySQL (總合) | 相對 IDC | TiDB (IDC) | TiDB (GCP) | TiDB (總合) | 相對 IDC |
|----------|-------------|-------------|----------------|----------|------------|------------|-------------|----------|
| oltp_read_write | 374.98 | 467.21 | **842.19** | **+9%** | 186.33 | 106.95 | **293.28** | **-59%** |
| oltp_write_only | 483.67 | 444.60 | **928.27** | **+18%** | 561.22 | 332.54 | **893.76** | **-55%** |

## **MySQL Multi-Primary：**
  - IDC+GCP 跨區併發時，**表面 TPS 可略增**，但 sysbench 顯示大量 `ignored errors`（寫入衝突／重試）。
  - 實際「成功寫入 TPS」打折，穩定性明顯下降。
    ```
    - IDC+GCP 測試（log_test25 / log_test26）中：
      - `oltp_read_write` 在 8 / 16 threads 時，**ignored errors 每秒上升到 0.4～1.8/sec**。
      - `oltp_write_only` 在 8 / 16 threads 時，**ignored errors 最多達 2.3/sec**。
      - `oltp_update_index` 亦在 4 / 8 / 16 threads 出現持續 `ignored errors`。
    ```

### **MySQL IDC 單區基準**

| 類型（16 threads） | IDC TPS |
|--------------------|---------|
| oltp_read_write    | **770.19** |
| oltp_write_only    | **786.62** |

### **MySQL IDC+GCP 雙點同時壓測**

| 類型（16 threads） | IDC TPS | GCP TPS | 總 TPS（IDC+GCP） | 相對 IDC 基準 |
|--------------------|---------|---------|--------------------|----------------|
| oltp_read_write    | 374.98  | 467.21  | **842.19**         | **+9%** vs 770.19 |
| oltp_write_only    | 483.67  | 444.60  | **928.27**         | **+18%** vs 786.62 |


## **TiDB（TiProxy + TiDB + TiKV）：**
  - IDC+GCP 跨區下，**TPS 顯著下降（受 RTT + Raft 影響）**，但 sysbench 全程 **`ignored errors = 0`**。
  - 在高併發與跨區延遲下仍維持一致性與零錯誤行為。

### **TiDB IDC 單區基準**

| 類型（16 threads） | IDC TPS |
|--------------------|---------|
| oltp_read_write    | **712.43** |
| oltp_write_only    | **1988.00** |

### **TiDB IDC+GCP 雙點同時壓測**

| 類型（16 threads） | IDC TPS | GCP TPS | 總 TPS（IDC+GCP） | 相對 IDC 基準 |
|--------------------|---------|---------|--------------------|----------------|
| oltp_read_write    | 186.33  | 106.95  | **293.28**         | **-59%** vs 712.43 |
| oltp_write_only    | 561.22  | 332.54  | **893.76**         | **-55%** vs 1988.00 |

----











## [Failover Scenario](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-4.md)

## Chaos engineering for leased-line quality across multiple data centers

## Staging AC-API 整合測試紀錄

## Other
