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

### **Single Instance（基準比較）**

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

### **Scale-Up（4 → 8 vCPU）vs Scale-Out（單機 → Cluster）**

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



### **TiDB Scale-Out（單 SQL 多 KV → 多 SQL 單 KV）**











----

### **跨區延遲與寫入競爭（IDC vs IDC+GCP）**

#### MySQL（跨 IDC+GCP）→ TPS 下跌 + Error Rate 激增

- **跨區後行為（明顯特徵）**
  - Read-only 類 TPS **仍高**（因為本地快取）
  - Write 類 TPS **下降 30～60%**
  - 出現大量 **ignored errors（寫衝突、死鎖、lock wait timeout）**

#### **TiDB（跨 IDC+GCP）→ TPS 下降，但永遠 0 Error**

- **跨區後行為**
  - TPS 下降（因為跨區 RTT + Raft 協議）
  - 沒有 row lock
  - 沒有死鎖
  - 沒有 ignored errors
  - 高併發 read_write / write_only 仍維持完全成功


----


## [Failover Scenario](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-4.md)

## Chaos engineering for leased-line quality across multiple data centers

## Staging AC-API 整合測試紀錄

## Other