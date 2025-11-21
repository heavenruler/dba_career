# TiDB Intro for DBA #5-2

----

# Sysbench 效能對照解析

## TL;DR

### **1. 單機：MySQL 一定贏；TiDB 固定開銷大**
> 單機比較不在相同架構基礎，TiDB 非設計給單節點效能。

### **2. Scale-Up：TiDB 有效；MySQL 效益有限且放大寫入競爭現象**

### **3. Scale-Out：TiDB 擴張因效能擴增；MySQL 擴張性因 HA 考量**

### **4. 跨區：MySQL Error Rate 爆量；TiDB 仍 0 Error**
> 跨區寫入 → MySQL 死鎖/衝突不可避免  
> TiDB → 跨區仍可維持完全成功交易

----

# **MySQL vs TiDB（Single Instance → Scale-Up → Scale-Out → 跨區）整合結論**

1. **Single Instance（基準比較）**
2. **Scale-Up / Scale-Out（擴展能力比較）**
3. **跨區延遲與寫入競爭（IDC vs IDC+GCP）— sysbench TPS & Error Rate 視角**

# ## **1. MySQL vs TiDB（Single Instance 基準比較）**

## **核心結論**
- **MySQL 在單機效能上全面領先 TiDB（差距 40%～80%）**
- 原因在於：
  - **MySQL：單節點、無 RPC → 本地記憶體路徑極快**
  - **TiDB：SQL Layer → RPC → TiKV → RocksDB → Raft → 固定開銷大**

## **OLTP 比較（16 threads TPS 對照）**
| 類型 | MySQL TPS | TiDB TPS | 差異 |
|------|-----------|-----------|-----------|
| read_only | 1342.52 | 559.71 | **-58.3%** |
| random_points | 18096.01 | 3403.69 | **-81%** |
| random_ranges | 18309.55 | 4424.09 | **-75%** |
| write_only | 2625.10 | 1108.85 | **-58%** |
| update_index | 4015.32 | 2704.83 | **-33%** |
| read_write | 1003.99 | 354.22 | **-59%** |

# ## **2. Scale-Up（4 → 8 vCPU）vs Scale-Out（單機 → Cluster）**

## **MySQL：Scale-Up 無效（InnoDB-bound）**
8 vCPU 改善有限甚至下降：
- read_only：-3.6%
- write_only：-5%
- read_write：-10%

## **TiDB：Scale-Up 有效（CPU-bound）**
8 vCPU 性能提升 **20%～40%**：
- read_only：+23%
- write_only：+32%
- update_index：+29%
- read_write：**+41%**

## **Scale-Out 結論：TiDB 能擴張；MySQL 幾乎無擴張性**

### **MySQL Multi-Primary**
- 多 Primary 無法線性擴張
- InnoDB 仍是每個 Primary 的瓶頸
- ProxySQL 只能分流，不是擴容

### **TiDB Scale-Out（單 SQL 多 KV → 多 SQL 單 KV）**

| 類型 | TPS（單 SQL 多 KV → 多 SQL 單 KV） | 差異 |
|------|--------------------------------------|--------|
| read_only | 783.54 → 830.14 | **+6%** |
| points | 5097.07 → 5538.02 | **+8.6%** |
| ranges | 5598.35 → 7026.91 | **+25.5%** |
| update_index | 3371.89 → 3946.03 | **+17.1%** |
| write_only | 1500.30 → 1782.03 | **+18.8%** |
| read_write | 503.92 → 561.45 | **+11.4%** |

# ## **3. 跨區延遲與寫入競爭（IDC vs IDC+GCP）**

# ### **3.1 MySQL（跨 IDC+GCP）→ TPS 下跌 + Error Rate 激增**

## **跨區後行為（明顯特徵）**
- Read-only 類 TPS **仍高**（因為本地快取）
- Write 類 TPS **下降 30～60%**
- 出現大量 **ignored errors（寫衝突、死鎖、lock wait timeout）**

# ### **3.2 TiDB（跨 IDC+GCP）→ TPS 下降，但永遠 0 Error**

## **跨區後行為**
- TPS 下降（因為跨區 RTT + Raft 協議）
- 但：
  - **沒有 row lock**
  - **沒有死鎖**
  - **沒有 ignored errors**
  - **高併發 read_write / write_only 仍維持完全成功**

========================================================================================================================================
# **MySQL vs TiDB（Single Instance 基準比較）**

## **核心結論（Single Instance）**
- **MySQL 在所有 Read-heavy／Write-heavy／Mixed 類型皆全面領先 TiDB**
- MySQL 具 **本地記憶體路徑、無 RPC hop、無 2PC 成本** → 單機效率極高
- TiDB 必經 **SQL Layer → RPC → TiKV → RocksDB → Raft** → 單機固定開銷顯著

因此兩者不是同一類型的引擎，**單機比較本就會呈現 MySQL 極大優勢**。

# **總覽（Single Instance：MySQL vs TiDB）**

| 類型 | MySQL TPS (16 Threads) | TiDB TPS (16 Threads) | 差異 |
|------|------------------|------------------|--------|
| **Read-heavy：read_only** | **1342.52** | 559.71 | **-58.3%** |
| **Read-heavy：random_points** | **18096.01** | 3403.69 | **-81.2%** |
| **Read-heavy：ranges** | **18309.55** | 4424.09 | **-75.8%** |
| **Write-heavy：write_only** | **2625.10** | 1108.85 | **-57.7%** |
| **Write-heavy：update_index** | **4015.32** | 2704.83 | **-32.7%** |
| **Mixed：read_write** | **1003.99** | 354.22 | **-64.7%** |

----

# **小結 A：Read-heavy（read_only / points / ranges）**

## **原始 TPS 數據（16 threads）**

| 類型 | MySQL TPS | TiDB TPS | 差異 |
|------|------------|------------|--------|
| oltp_read_only | **1342.52** | 559.71 | **-58.3%** |
| select_random_points | **18096.01** | 3403.69 | **-81.2%** |
| select_random_ranges | **18309.55** | 4424.09 | **-75.8%** |

## **分析**
- **MySQL → 純本地記憶體路徑（Handler / BufferPool / Index page）**
- **TiDB → 每次查詢都必須經 RPC + 多副本 TiKV + RocksDB**
- 單節點下，RPC/Region hop 成本完全被放大

## **結論（Read-heavy）**
**單機 Read-heavy：MySQL 壓倒性領先；TiDB 為架構固定成本無解。**

----

# **小結 B：Write-heavy（write_only / update_index）**

## **原始 TPS 數據（16 threads）**

| 類型 | MySQL TPS | TiDB TPS | 差異 |
|------|------------|------------|--------|
| write_only | **2625.10** | 1108.85 | **-57.7%** |
| update_index | **4015.32** | 2704.83 | **-32.7%** |

## **分析**
**TiDB 分散式協議成本在單機無法被分攤，TPS 自然劣化。**

## **結論（Write-heavy）**
**MySQL 單機寫入更快；TiDB 單機寫入固定成本大，TPS 不可能追上 MySQL。**

----

# **小結 C：Mixed（read_write）**

## **原始 TPS 數據（16 threads）**

| 類型 | MySQL TPS | TiDB TPS | 差異 |
|------|------------|------------|--------|
| read_write | **1003.99** | 354.22 | **-64.7%** |

## **效能現象**
- TiDB 在 Mixed 的 TPS 落後 MySQL **近六成**
- Mixed 同時增加 read（RPC hop）與 write（2PC）成本
- MySQL 依靠 CPU 與 BufferPool 仍可線性提升

## **原因分析**
- TiDB：查詢與寫入路徑皆需要 RPC，延遲固定且無法靠 CPU 改善
- MySQL：純本地 I/O 與記憶體存取，延遲極低

## **結論（Mixed）**
**Mixed 讓 TiDB 的讀寫雙成本同時暴露 → TPS 大幅落後 MySQL。**

========================================================================================================================================

# ** Scale-Up（4 → 8 vCPU）vs Scale-Out（單機 → Cluster → 跨 IDC/GCP）**

# **Scale-Up（4 → 8 vCPU）效能對照解析：MySQL Multi-Primary 架構**

## **核心結論（MySQL Scale-Up（4 → 8 vCPU））**

> **MySQL Multi-Primary 的主要瓶頸來自 InnoDB，屬於非 CPU-bound。
> 因此 Scale-Up 無法改善效能，8vCPU 反而普遍低於 4vCPU。**

| 類型         | Scale-Up 成效 | 原因摘要 |
|--------------|----------------|-----------|
| Read-heavy   | 無提升／微降   | BufferPool 分散 |
| Write-heavy  | 下降           | 讀寫瓶頸疊加、協調成本 |
| Mixed        | 下降最明顯     | 讀寫瓶頸疊加、協調成本 |
| Multi-Primary| 無法獲得線性增益  | 每個 Primary 仍是單機 InnoDB |

----

# **小結 A：Read-heavy（oltp_read_only / points / ranges）**

## **效能現象（4 → 8 vCPU）**
| 類型                         | 4 vCPU（TPS） | 8 vCPU（TPS） | 變化   |
|------------------------------|---------------|---------------|--------|
| oltp_read_only               | 1812.85       | 1746.58       | -3.7%  |
| select_random_points         | 22796.93      | 21912.82      | -3.9%  |
| select_random_ranges         | 25762.70      | 25394.81      | -1.4%  |

## **結論（Read-heavy）**
- 單純查詢型負載下，QPS **全面下降**（約 -1%～-4%）; 讀取路徑主要耗在 ** InnoDB BufferPool 熱點** ; CPU 增加不會改善以上負載型態。

----

# **小結 B：Write-heavy（write_only / update_index）**

## **效能現象（16 threads, TPS）**

| 類型               | 4 vCPU（TPS） | 8 vCPU（TPS） | 變化   |
|--------------------|---------------|---------------|--------|
| write_only         | 830.24        | 786.62        | -5.3%  |
| update_index       | 3434.72       | 3285.13       | -4.3%  |

## **結論（Write-heavy）**
**MySQL 寫入路徑的限制完全來自 InnoDB，Multi Primary 甚至更容易引發寫入競爭，本質不會因 CPU 增加而改善。**

----

# **小結 C：Mixed（oltp_read_write）**

## **效能現象（16 threads, TPS）**

| 類型                 | 4 vCPU（TPS） | 8 vCPU（TPS） | 變化    |
|----------------------|---------------|---------------|---------|
| read_write           | 862.51        | 770.19        | -10.7%  |

## **結論（Mixed）**
**Mixed 更突顯 Multi-Primary 的不擴展性；Scale-Up 反而使內部競爭更劇烈。**

========================================================================================================================================

# **Scale-Up（4 → 8 vCPU）效能對照解析：TiDB（單 SQL 多 KV）**

## **核心結論（TiDB Scale-Up（4 → 8 vCPU））**

> **SQL 層可多線程併行 → CPU 越多優勢越大**
> **TiDB 的效能主要受 SQL 層 CPU 併行能力主導；Scale-Up 對 TiDB 屬「有效擴張」。**
> **8 vCPU 全面優於 4 vCPU，對 Read / Write / Mixed 三類負載皆有明顯提升。**

| 負載類型 | Scale-Up 成效（4 → 8 vCPU） | 說明 |
|----------|------------------------------|--------|
| Read-heavy | **+18～23%** | SQL 層 CPU 增加，排程更有效率 |
| Write-heavy | **+29～32%** | KV/RAFT 限制仍在，但可增長 |
| Mixed | **+41% 以上** | SQL 層改善明顯，KV 為主瓶頸 |
| 整體行為 | **全類型皆有感提升** | TiDB 對 CPU 敏感度高，可自然 scale-up |

----

# **小結 A：Read-heavy（read_only / points / ranges）**

## **效能數據（單 SQL 多 KV, 16 threads）**

| 類型                         | 4 vCPU（TPS） | 8 vCPU（TPS） | 變化   |
|------------------------------|---------------|---------------|--------|
| oltp_read_only               | 783.54        | 965.52        | +23.2% |
| select_random_points         | 5097.07       | 5798.88       | +13.8% |
| select_random_ranges         | 5598.35       | 6808.54       | +21.6% |

## **效能現象**
- Read-heavy 在 8 vCPU 明顯成長
- SQL Layer 能以更多 CPU 執行 RPC / Coprocessor 排程
- 越多 threads 越能看出 CPU 擴張效益

## **結論（Read-heavy）**
**Scale-Up 對 Read-heavy 完全有效；TiDB SQL 層對 CPU 擴張高度敏感。**

----

# **小結 B：Write-heavy（write_only / update_index）**

## **效能數據（單 SQL 多 KV, 16 threads）**

| 類型               | 4 vCPU（TPS） | 8 vCPU（TPS） | 變化   |
|--------------------|---------------|---------------|--------|
| update_index       | 3371.89       | 4374.26       | +29.7% |
| write_only         | 1500.30       | 1988.00       | +32.5% |

## **效能現象**
- SQL 層 CPU 增加 → TSO / Commit 等流程加速
- 雖然最終瓶頸在 TiKV（Raft/RocksDB），但 **SQL 層越強 → 能推動更多寫入**

## **結論（Write-heavy）**
**TiDB 寫入在 Scale-Up 有明顯提升，但 TiKV 仍是後段限制，提升屬有限度成長。**

----

# **小結 C：Mixed（read_write）**

## **效能數據（單 SQL 多 KV, 16 threads）**

| 類型          | 4 vCPU（TPS） | 8 vCPU（TPS） | 變化   |
|---------------|---------------|---------------|--------|
| read_write    | 503.92        | 712.43        | +41.4% |

## **效能現象**
- Mixed 同時包含 SQL 查詢（Read-heavy）與 KV 寫入（Write-heavy）
- SQL 層擴張直接提升整體吞吐
- TiKV 仍為瓶頸，但 8 vCPU SQL 層仍能拉起整體 TPS

## **結論（Mixed）**
**Mixed 對 CPU 擴張最敏感；8 vCPU 提升最為明顯（+41%）。**

========================================================================================================================================

# **Scale-Up（4 → 8 vCPU）最終對照：MySQL Multi-Primary vs TiDB（單 SQL 多 KV）**

## **核心對照結論**

- **MySQL Multi-Primary：Scale-Up 無效甚至下降**
  → Multi-Primary 凸顯 InnoDB 的競爭瓶頸，屬非 CPU-bound。
  → 升級至 8 vCPU 反而使 TPS 全面下降（-3% ～ -10%）。

- **TiDB（單 SQL 多 KV）：Scale-Up 效果顯著**
  → SQL Layer 對 CPU 高敏感度，8 vCPU 可推動更多 RPC / Goroutine。
  → Write-heavy / Mixed 類型甚至能提升 +30% ～ +41%。

**MySQL：Scale-Up 效益有限；TiDB：Scale-Up 有效。**
不是測試問題，而是兩種儲存引擎架構本質不同。

# **總覽**

| 項目 | MySQL Multi-Primary（4v → 8v） | 差異 | TiDB（單 SQL 多 KV）（4v → 8v） | 差異 | 整體觀察 |
|------|-------------------------------|--------|----------------------------------|--------|-----------|
| **Read-heavy** | 1812.85 → 1746.58 TPS | **-3.7%** | 783.54 → 965.52 TPS | **+23.2%** | TiDB SQL 層併行能力遠優於 MySQL |
| **Write-heavy（write_only）** | 830.24 → 786.62 TPS | **-5.3%** | 1500.30 → 1988.00 TPS | **+32.5%** | MySQL 卡 InnoDB；TiDB 增長幅度高 |
| **Write-heavy（update_index）** | 3434.72 → 3285.13 TPS | **-4.4%** | 3371.89 → 4374.26 TPS | **+29.7%** | MySQL 無擴張性；TiDB 提升穩定 |
| **Mixed（oltp_read_write）** | 862.51 → 770.19 TPS | **-10.7%** | 503.92 → 712.43 TPS | **+41.4%** | TiDB Mixed 對 CPU 擴張最敏感 |
| **CPU 擴張效果** | 無效 / 負向 | - | 明顯有效 | - | MySQL 非 CPU-bound；TiDB CPU-sensitive |
| **本質瓶頸** | InnoDB（BufferPool / Redo / B+Tree） | - | KV（Raft / RocksDB） | - | 架構本質完全不同 |

----

## **1. Read-heavy（oltp_read_only）**

| 系統 | 4 vCPU (TPS) | 8 vCPU (TPS) | 變化 |
|------|------------|------------|-------|
| **MySQL Multi-Primary** | 1812.85 | 1746.58 | **-3.7%** |
| **TiDB（單 SQL 多 KV）** | 783.54 | 965.52 | **+23.2%** |

## **2. Write-heavy（write_only / update_index）**

### write_only（16 threads）
| 系統 | 4 vCPU (TPS) | 8 vCPU (TPS) | 變化 |
|------|------------|------------|-------|
| **MySQL** | 830.24 | 786.62 | **-5.3%** |
| **TiDB**  | 1500.30 | 1988.00 | **+32.5%** |

### update_index（16 threads）
| 系統 | 4 vCPU (TPS) | 8 vCPU (TPS) | 變化 |
|------|------------|------------|-------|
| **MySQL** | 3434.72 | 3285.13 | **-4.4%** |
| **TiDB**  | 3371.89 | 4374.26 | **+29.7%** |

## **3. Mixed（oltp_read_write）**

| 系統 | 4 vCPU (TPS) | 8 vCPU (TPS) | 變化 |
|------|------------|------------|-------|
| **MySQL Multi-Primary** | 862.51 | 770.19 | **-10.7%** |
| **TiDB（單 SQL 多 KV）** | 503.92 | 712.43 | **+41.4%** |

========================================================================================================================================

# **Scale-Out 效能對照解析：TiDB（單 SQL 多 KV vs 多 SQL 單 KV）**

目的：觀察 TiDB 在「橫向擴張」時，SQL 層與 KV 層的 **負載分布差異** 對效能的影響。

# **結論**

> TiDB 的 Scale-Out 本質是 **SQL 層可橫向擴張 × KV 層可分片化分擔負載**。
> 兩者皆能提升效能，但 **SQL 層擴張的收益遠大於 KV 層擴張**。

| 工作負載 | 單 SQL 多 KV（TPS） | 多 SQL 單 KV（TPS） | 差異幅度 |
|----------|----------------------------|----------------------------|------------|
| **Read-heavy（read_only）** | 783.54 | 830.14 | **+6%** |
| **Read-heavy（points）** | 5097.07 | 5538.02 | **+8.6%** |
| **Read-heavy（ranges）** | 5598.35 | 7026.91 | **+25.5%** |
| **Write-heavy（update_index）** | 3371.89 | 3946.03 | **+17.1%** |
| **Write-heavy（write_only）** | 1500.30 | 1782.03 | **+18.8%** |
| **Mixed（read_write）** | 503.92 | 561.45 | **+11.4%** |

----

# **小結 A：Read-heavy（read_only / points / ranges）**

## **效能比較（16 threads）**

| 類型 | 單 SQL 多 KV (TPS) | 多 SQL 單 KV (TPS) | 差異 |
|------|----------------|--------------|--------|
| read_only | 783.54 | 830.14 | **+6%** |
| points | 5097.07 | 5538.02 | **+8.6%** |
| ranges | 5598.35 | 7026.91 | **+25.5%** |

## **效能現象**
- 多 SQL 單 KV 全面高於單 SQL 多 KV
- 特別是 **範圍查詢（ranges）差異最大**
- SQL 層並行能力是主導因素，KV 層瓶頸影響較少

## **結論（Read-heavy）**
**Read-heavy 更吃 SQL 層可併行能力 → 多 SQL 單 KV 更有利。**

----

# **小結 B：Write-heavy（write_only / update_index）**

## **效能比較（16 threads）**

| 類型 | 單 SQL 多 KV (TPS) | 多 SQL 單 KV (TPS) | 差異 |
|------|-----------------|-------------|--------|
| update_index | 3371.89 | 3946.03 | **+17.1%** |
| write_only | 1500.30 | 1782.03 | **+18.8%** |

## **效能現象**
- 多 SQL 單 KV 持續領先
- 原因在於 SQL 層能更快送出 Prewrite / Commit
- 雖然 KV（Raft + RocksDB）是主要瓶頸，但 SQL 層壓力越分散越吃香

## **結論（Write-heavy）**
**寫入類型同樣由多 SQL 單 KV 勝出，但差距不如 Read-heavy 明顯。**

----

# **小結 C：Mixed（read_write）**

## **效能比較（16 threads）**

| 類型 | 單 SQL 多 KV (TPS) | 多 SQL 單 KV (TPS) | 差異 |
|------|----------------|--------------|--------|
| read_write | 503.92 | 561.45 | **+11.4%** |

## **效能現象**
- Mixed 同時壓 SQL 與 KV
- 多 SQL 單 KV 能更好利用 SQL 層 CPU
- 差距相較 Read-heavy 稍小（瓶頸在 KV 端逐漸顯現）

## **結論（Mixed）**
**多 SQL 單 KV 仍略優，但因 KV 是瓶頸，Scale-Out 效益有限。**

========================================================================================================================================

# **跨區延遲與寫入競爭影響（IDC vs IDC+GCP，sysbench TPS 視角）**

## **核心結論**

> **MySQL 用「丟錯＋重試」換取跨區 TPS；TiDB 用「容忍高延遲」換取零錯誤與一致性。**

- **MySQL Multi-Primary：**
  - IDC+GCP 跨區併發時，**表面 TPS 可略增**，但 sysbench 顯示大量 `ignored errors`（寫入衝突／重試）。
  - 實際「成功寫入 TPS」打折，穩定性明顯下降。

- **TiDB（TiProxy + TiDB + TiKV）：**
  - IDC+GCP 跨區下，**TPS 顯著下降（受 RTT + Raft 影響）**，但 sysbench 全程 **`ignored errors = 0`**。
  - 在高併發與跨區延遲下仍維持一致性與零錯誤行為。

## **1. MySQL：IDC vs IDC+GCP（sysbench TPS + Error Rate）**

### **1-1. IDC 單區基準（log_test6，8 vCPU）**

| 類型（16 threads） | IDC TPS |
|--------------------|---------|
| oltp_read_write    | **770.19** |
| oltp_write_only    | **786.62** |

### **1-2. IDC+GCP 雙點同時壓測（log_test25 + log_test26）**

> 下表為「IDC + GCP 兩端 TPS 相加」的聚合視角。

| 類型（16 threads） | IDC TPS | GCP TPS | 總 TPS（IDC+GCP） | 相對 IDC 基準 |
|--------------------|---------|---------|--------------------|----------------|
| oltp_read_write    | 374.98  | 467.21  | **842.19**         | **+9%** vs 770.19 |
| oltp_write_only    | 483.67  | 444.60  | **928.27**         | **+18%** vs 786.62 |

### **1-3. Error Rate（sysbench）**

- IDC+GCP 測試（log_test25 / log_test26）中：
  - `oltp_read_write` 在 8 / 16 threads 時，**ignored errors 每秒上升到 0.4～1.8/sec**。
  - `oltp_write_only` 在 8 / 16 threads 時，**ignored errors 最多達 2.3/sec**。
  - `oltp_update_index` 亦在 4 / 8 / 16 threads 出現持續 `ignored errors`。

### **MySQL 跨區行為解讀**

- 跨 IDC+GCP 後：
  - 表面聚合 TPS **看似略高**（+9%～+18%），
    但伴隨大量 ignored errors，代表：
    - 寫入競爭（PK/UK 衝突、Multi-Primary 延遲導致衝突頻發）。
    - sysbench 部分寫入被視為錯誤丟棄或重試，實際有效 TPS 低於表面值。
- 對業務角度：
  - **吞吐「看起來」沒掉很多，但可靠度明顯變差。**

========================================================================================================================================

## **2. TiDB：IDC vs IDC+GCP（sysbench TPS + Error Rate）**

### **2-1. IDC 單區基準（log_test7，8 vCPU）**

| 類型（16 threads） | IDC TPS |
|--------------------|---------|
| oltp_read_write    | **712.43** |
| oltp_write_only    | **1988.00** |

### **2-2. IDC+GCP 雙點同時壓測（log_test13 + log_test14）**

同樣以「IDC + GCP TPS 相加」呈現：

| 類型（16 threads） | IDC TPS | GCP TPS | 總 TPS（IDC+GCP） | 相對 IDC 基準 |
|--------------------|---------|---------|--------------------|----------------|
| oltp_read_write    | 186.33  | 106.95  | **293.28**         | **-59%** vs 712.43 |
| oltp_write_only    | 561.22  | 332.54  | **893.76**         | **-55%** vs 1988.00 |

### **2-3. Error Rate（sysbench）**

- 檢查 TiDB 跨區 sysbench 日誌（log_test13 / log_test14）Error Rate 為 0

### **2-4. TiDB (IDC+GCP) 跨區行為解讀**

- TPS 明顯下滑（約 -55%～-60%），符合：
  - 每次交易需跨區請求 PD / TiKV / Raft，多數寫入變成「跨機房共識」。
  - 專線規格 RTT 成為主瓶頸。
- 在高併發下：
  - 無寫入錯誤、無 ignored errors。
  - 每一筆寫入都走完整 2PC+Raft 流程，保證一致性與完整性。
- 對業務角度：
  - 吞吐明顯降低，但「寫入正確性」完全維持。

========================================================================================================================================

## Sysbench Testing for TPS/QPS

## 版本 & 測試參數交代
```
root@l-wn-test-1 ~ $ sysbench --version
sysbench 1.1.0-3ceba0b
```
```
**Dataset Preparation:**
- Number of tables: `10`
- Rows per table: `100,000`
```
```
**Execution Setup:**
- Each test was executed three times using **sysbench**, and the **average runtime (avg[s])** represents the mean value across all three runs.
- Benchmark types included:
  - `oltp_read_write`
  - `oltp_read_only`
  - `oltp_write_only`
  - `oltp_update_index`
  - `select_random_points`
  - `select_random_ranges`
- Warm-up duration before measurement: **30 seconds**
- Thread concurrency levels tested: **(2, 4, 8, 16)**

These tests aim to evaluate transaction per second (TPS) and query per second (QPS) performance under varying concurrency levels, assessing how the system scales with read-heavy, write-heavy, and mixed OLTP workloads.
```

## MySQL + ProxySQL @ Single Instance with 4 vCPU @ log_test1
| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 302.34   | 4837.44  | 3            |
| oltp_read_only       | 4       | 533.29   | 8532.66  | 3            |
| oltp_read_only       | 8       | 897.07   | 14353.05 | 3            |
| oltp_read_only       | 16      | 1342.52  | 21480.41 | 3            |
| oltp_read_write      | 2       | 235.37   | 4707.44  | 3            |
| oltp_read_write      | 4       | 392.11   | 7842.13  | 3            |
| oltp_read_write      | 8       | 659.67   | 13193.45 | 3            |
| oltp_read_write      | 16      | 1003.99  | 20079.88 | 3            |
| oltp_update_index    | 2       | 886.88   | 886.88   | 3            |
| oltp_update_index    | 4       | 1201.48  | 1201.48  | 3            |
| oltp_update_index    | 8       | 2174.41  | 2174.41  | 3            |
| oltp_update_index    | 16      | 4015.32  | 4015.32  | 3            |
| oltp_write_only      | 2       | 696.99   | 4181.97  | 3            |
| oltp_write_only      | 4       | 1144.85  | 6869.10  | 3            |
| oltp_write_only      | 8       | 1444.99  | 8669.94  | 3            |
| oltp_write_only      | 16      | 2625.10  | 15750.60 | 3            |
| select_random_points | 2       | 3749.14  | 3749.14  | 3            |
| select_random_points | 4       | 7236.85  | 7236.85  | 3            |
| select_random_points | 8       | 12289.93 | 12289.93 | 3            |
| select_random_points | 16      | 18096.01 | 18096.01 | 3            |
| select_random_ranges | 2       | 4764.67  | 4764.67  | 3            |
| select_random_ranges | 4       | 8070.39  | 8070.39  | 3            |
| select_random_ranges | 8       | 12924.42 | 12924.42 | 3            |
| select_random_ranges | 16      | 18309.55 | 18309.55 | 3            |

## MySQL + ProxySQL @ IDC Cluster with 4 vCPU @ log_test5

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 305.18   | 4883.03  | 3            |
| oltp_read_only       | 4       | 553.35   | 8853.62  | 3            |
| oltp_read_only       | 8       | 1031.26  | 16500.27 | 3            |
| oltp_read_only       | 16      | 1812.85  | 29005.73 | 3            |
| oltp_read_write      | 2       | 222.57   | 4451.52  | 3            |
| oltp_read_write      | 4       | 399.49   | 7989.92  | 3            |
| oltp_read_write      | 8       | 701.18   | 14023.60 | 3            |
| oltp_read_write      | 16      | 862.51   | 17250.35 | 3            |
| oltp_update_index    | 2       | 1862.88  | 1862.88  | 3            |
| oltp_update_index    | 4       | 2842.90  | 2842.90  | 3            |
| oltp_update_index    | 8       | 3086.18  | 3086.18  | 3            |
| oltp_update_index    | 16      | 3434.72  | 3434.72  | 3            |
| oltp_write_only      | 2       | 526.82   | 3160.91  | 3            |
| oltp_write_only      | 4       | 906.72   | 5440.54  | 3            |
| oltp_write_only      | 8       | 858.06   | 5148.47  | 3            |
| oltp_write_only      | 16      | 830.24   | 4981.81  | 3            |
| select_random_points | 2       | 3724.84  | 3724.84  | 3            |
| select_random_points | 4       | 6924.96  | 6924.96  | 3            |
| select_random_points | 8       | 12526.13 | 12526.13 | 3            |
| select_random_points | 16      | 22796.93 | 22796.93 | 3            |
| select_random_ranges | 2       | 3824.42  | 3824.42  | 3            |
| select_random_ranges | 4       | 8078.57  | 8078.57  | 3            |
| select_random_ranges | 8       | 15069.66 | 15069.66 | 3            |
| select_random_ranges | 16      | 25762.70 | 25762.70 | 3            |

## MySQL + ProxySQL @ IDC Cluster with 8 vCPU @ log_test6

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 284.27   | 4548.35  | 3            |
| oltp_read_only       | 4       | 527.59   | 8441.51  | 3            |
| oltp_read_only       | 8       | 925.94   | 14815.18 | 3            |
| oltp_read_only       | 16      | 1746.58  | 27945.40 | 3            |
| oltp_read_write      | 2       | 220.40   | 4408.04  | 3            |
| oltp_read_write      | 4       | 412.44   | 8248.74  | 3            |
| oltp_read_write      | 8       | 700.60   | 14012.19 | 3            |
| oltp_read_write      | 16      | 770.19   | 15403.94 | 3            |
| oltp_update_index    | 2       | 1678.68  | 1678.68  | 3            |
| oltp_update_index    | 4       | 2707.94  | 2707.94  | 3            |
| oltp_update_index    | 8       | 3166.76  | 3166.76  | 3            |
| oltp_update_index    | 16      | 3285.13  | 3285.13  | 3            |
| oltp_write_only      | 2       | 481.47   | 2888.85  | 3            |
| oltp_write_only      | 4       | 783.78   | 4702.73  | 3            |
| oltp_write_only      | 8       | 800.99   | 4806.01  | 3            |
| oltp_write_only      | 16      | 786.62   | 4719.91  | 3            |
| select_random_points | 2       | 3153.53  | 3153.53  | 3            |
| select_random_points | 4       | 6436.83  | 6436.83  | 3            |
| select_random_points | 8       | 11891.92 | 11891.92 | 3            |
| select_random_points | 16      | 21912.82 | 21912.82 | 3            |
| select_random_ranges | 2       | 3114.00  | 3114.00  | 3            |
| select_random_ranges | 4       | 6652.85  | 6652.85  | 3            |
| select_random_ranges | 8       | 13273.24 | 13273.24 | 3            |
| select_random_ranges | 16      | 25394.81 | 25394.81 | 3            |

## MySQL + ProxySQL @ IDC + GCP Cluster with 4 vCPU @ 

### mysqlslap on 172.24.40.16 @ log_test27

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 329.65   | 5274.47  | 3            |
| oltp_read_only       | 4       | 577.25   | 9236.14  | 3            |
| oltp_read_only       | 8       | 1060.84  | 16973.41 | 3            |
| oltp_read_only       | 16      | 1901.20  | 30419.35 | 3            |
| oltp_read_write      | 2       | 121.68   | 2433.75  | 3            |
| oltp_read_write      | 4       | 256.96   | 5139.31  | 3            |
| oltp_read_write      | 8       | 291.18   | 5823.70  | 3            |
| oltp_read_write      | 16      | 132.33   | 2646.69  | 3            |
| oltp_update_index    | 2       | 620.40   | 620.40   | 3            |
| oltp_update_index    | 4       | 1258.01  | 1258.01  | 3            |
| oltp_update_index    | 8       | 3027.44  | 3027.44  | 3            |
| oltp_update_index    | 16      | 4092.33  | 4092.33  | 3            |
| oltp_write_only      | 2       | 192.61   | 1155.79  | 3            |
| oltp_write_only      | 4       | 394.69   | 2368.15  | 3            |
| oltp_write_only      | 8       | 555.61   | 3333.79  | 3            |
| oltp_write_only      | 16      | 240.23   | 1441.45  | 3            |
| select_random_points | 2       | 3525.52  | 3525.52  | 3            |
| select_random_points | 4       | 7136.97  | 7136.97  | 3            |
| select_random_points | 8       | 13431.37 | 13431.37 | 3            |
| select_random_points | 16      | 22977.11 | 22977.11 | 3            |
| select_random_ranges | 2       | 4430.76  | 4430.76  | 3            |
| select_random_ranges | 4       | 8239.28  | 8239.28  | 3            |
| select_random_ranges | 8       | 15342.12 | 15342.12 | 3            |
| select_random_ranges | 16      | 27379.50 | 27379.50 | 3            |

### mysqlslap on 10.160.152.14 @ log_test28

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 363.61   | 5817.79  | 3            |
| oltp_read_only       | 4       | 679.94   | 10879.17 | 3            |
| oltp_read_only       | 8       | 1277.80  | 20444.79 | 3            |
| oltp_read_only       | 16      | 2184.19  | 34947.12 | 3            |
| oltp_read_write      | 2       | 151.74   | 3035.43  | 3            |
| oltp_read_write      | 4       | 283.69   | 5678.05  | 3            |
| oltp_read_write      | 8       | 526.73   | 10547.28 | 3            |
| oltp_read_write      | 16      | 747.75   | 14999.31 | 2            |
| oltp_update_index    | 2       | 311.84   | 311.84   | 3            |
| oltp_update_index    | 4       | 496.88   | 496.88   | 3            |
| oltp_update_index    | 8       | 953.54   | 953.54   | 3            |
| oltp_update_index    | 16      | 993.75   | 993.75   | 3            |
| oltp_write_only      | 2       | 244.18   | 1465.37  | 3            |
| oltp_write_only      | 4       | 429.02   | 2576.26  | 3            |
| oltp_write_only      | 8       | 758.16   | 4556.15  | 3            |
| oltp_write_only      | 16      | 789.90   | 4757.17  | 2            |
| select_random_points | 2       | 4656.68  | 4656.68  | 3            |
| select_random_points | 4       | 8835.00  | 8835.00  | 3            |
| select_random_points | 8       | 16614.01 | 16614.01 | 3            |
| select_random_points | 16      | 25840.46 | 25840.46 | 3            |
| select_random_ranges | 2       | 4932.72  | 4932.72  | 3            |
| select_random_ranges | 4       | 9550.49  | 9550.49  | 3            |
| select_random_ranges | 8       | 17817.02 | 17817.02 | 3            |
| select_random_ranges | 16      | 29518.49 | 29518.49 | 3            |

### mysqlslap between 172.24.40.16 (log_test29) & 10.160.152.14 (log_test30)

@172.24.40.16

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 282.97   | 4527.61  | 3            |
| oltp_read_only       | 4       | 553.11   | 8849.90  | 3            |
| oltp_read_only       | 8       | 1001.44  | 16023.16 | 3            |
| oltp_read_only       | 16      | 1820.94  | 29135.02 | 3            |
| oltp_read_write      | 2       | 139.86   | 2797.26  | 3            |
| oltp_read_write      | 4       | 247.87   | 4957.82  | 3            |
| oltp_read_write      | 8       | 352.61   | 7053.13  | 3            |
| oltp_read_write      | 16      | 350.58   | 7012.85  | 3            |
| oltp_update_index    | 2       | 473.65   | 473.65   | 3            |
| oltp_update_index    | 4       | 769.59   | 769.59   | 3            |
| oltp_update_index    | 8       | 491.85   | 491.85   | 3            |
| oltp_update_index    | 16      | 933.31   | 933.31   | 3            |
| oltp_write_only      | 2       | 207.90   | 1247.43  | 3            |
| oltp_write_only      | 4       | 263.75   | 1582.54  | 3            |
| oltp_write_only      | 8       | 330.10   | 1980.66  | 3            |
| oltp_write_only      | 16      | 416.55   | 2499.56  | 3            |
| select_random_points | 2       | 3622.36  | 3622.36  | 3            |
| select_random_points | 4       | 7042.05  | 7042.05  | 3            |
| select_random_points | 8       | 12965.80 | 12965.80 | 3            |
| select_random_points | 16      | 22187.24 | 22187.24 | 3            |
| select_random_ranges | 2       | 4210.68  | 4210.68  | 3            |
| select_random_ranges | 4       | 7736.91  | 7736.91  | 3            |
| select_random_ranges | 8       | 15367.80 | 15367.80 | 3            |
| select_random_ranges | 16      | 26361.18 | 26361.18 | 3            |

@10.160.152.14

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 357.94   | 5727.04  | 3            |
| oltp_read_only       | 4       | 678.65   | 10858.37 | 3            |
| oltp_read_only       | 8       | 1278.22  | 20451.58 | 3            |
| oltp_read_only       | 16      | 2190.81  | 35052.98 | 3            |
| oltp_read_write      | 2       | 149.50   | 2990.81  | 3            |
| oltp_read_write      | 4       | 278.51   | 5574.87  | 3            |
| oltp_read_write      | 8       | 419.89   | 8409.08  | 3            |
| oltp_read_write      | 16      | 453.92   | 9110.65  | 2            |
| oltp_update_index    | 2       | 299.17   | 299.17   | 3            |
| oltp_update_index    | 4       | 499.00   | 499.00   | 3            |
| oltp_update_index    | 8       | 712.50   | 712.50   | 3            |
| oltp_update_index    | 16      | 644.12   | 644.12   | 3            |
| oltp_write_only      | 2       | 213.62   | 1281.77  | 3            |
| oltp_write_only      | 4       | 297.82   | 1788.60  | 3            |
| oltp_write_only      | 8       | 447.95   | 2692.18  | 2            |
| oltp_write_only      | 16      | 483.14   | 2910.84  | 3            |
| select_random_points | 2       | 4627.93  | 4627.93  | 3            |
| select_random_points | 4       | 8879.32  | 8879.32  | 3            |
| select_random_points | 8       | 16184.66 | 16184.66 | 3            |
| select_random_points | 16      | 25245.08 | 25245.08 | 3            |
| select_random_ranges | 2       | 4819.09  | 4819.09  | 3            |
| select_random_ranges | 4       | 9337.70  | 9337.70  | 3            |
| select_random_ranges | 8       | 17484.57 | 17484.57 | 3            |
| select_random_ranges | 16      | 29195.98 | 29195.98 | 3            |

## MySQL + ProxySQL @ IDC + GCP Cluster with 8 vCPU @ 

### mysqlslap on 172.24.40.16 @ log_test23

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 332.40   | 5318.51  | 3            |
| oltp_read_only       | 4       | 617.98   | 9887.71  | 3            |
| oltp_read_only       | 8       | 1155.40  | 18486.40 | 3            |
| oltp_read_only       | 16      | 2069.00  | 33104.08 | 3            |
| oltp_read_write      | 2       | 136.09   | 2721.90  | 3            |
| oltp_read_write      | 4       | 261.10   | 5222.02  | 3            |
| oltp_read_write      | 8       | 416.44   | 8328.80  | 3            |
| oltp_read_write      | 16      | 852.69   | 17054.35 | 3            |
| oltp_update_index    | 2       | 1067.75  | 1067.75  | 3            |
| oltp_update_index    | 4       | 1476.86  | 1476.86  | 3            |
| oltp_update_index    | 8       | 3538.36  | 3538.36  | 3            |
| oltp_update_index    | 16      | 5347.27  | 5347.27  | 3            |
| oltp_write_only      | 2       | 214.70   | 1288.22  | 3            |
| oltp_write_only      | 4       | 398.88   | 2393.35  | 3            |
| oltp_write_only      | 8       | 708.68   | 4252.10  | 3            |
| oltp_write_only      | 16      | 893.32   | 5360.09  | 3            |
| select_random_points | 2       | 3653.08  | 3653.08  | 3            |
| select_random_points | 4       | 7268.89  | 7268.89  | 3            |
| select_random_points | 8       | 14159.92 | 14159.92 | 3            |
| select_random_points | 16      | 24670.69 | 24670.69 | 3            |
| select_random_ranges | 2       | 4706.24  | 4706.24  | 3            |
| select_random_ranges | 4       | 8929.58  | 8929.58  | 3            |
| select_random_ranges | 8       | 15996.76 | 15996.76 | 3            |
| select_random_ranges | 16      | 30930.49 | 30930.49 | 3            |

### mysqlslap on 10.160.152.14 @ log_test24

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 425.84   | 6813.47  | 3            |
| oltp_read_only       | 4       | 838.17   | 13410.76 | 3            |
| oltp_read_only       | 8       | 1562.64  | 25002.25 | 3            |
| oltp_read_only       | 16      | 2840.88  | 45454.04 | 3            |
| oltp_read_write      | 2       | 159.23   | 3185.57  | 3            |
| oltp_read_write      | 4       | 298.80   | 5976.96  | 2            |
| oltp_read_write      | 8       | 556.67   | 11149.72 | 3            |
| oltp_read_write      | 16      | 701.90   | 14077.15 | 2            |
| oltp_update_index    | 2       | 1077.89  | 1077.89  | 3            |
| oltp_update_index    | 4       | 1593.10  | 1593.10  | 3            |
| oltp_update_index    | 8       | 3713.25  | 3713.25  | 3            |
| oltp_update_index    | 16      | 3908.01  | 3908.01  | 3            |
| oltp_write_only      | 2       | 232.49   | 1395.21  | 3            |
| oltp_write_only      | 4       | 427.84   | 2567.05  | 2            |
| oltp_write_only      | 8       | 703.79   | 4230.17  | 2            |
| oltp_write_only      | 16      | 513.19   | 3091.03  | 3            |
| select_random_points | 2       | 5861.19  | 5861.19  | 3            |
| select_random_points | 4       | 10958.26 | 10958.26 | 3            |
| select_random_points | 8       | 20712.86 | 20712.86 | 3            |
| select_random_points | 16      | 37681.08 | 37681.08 | 3            |
| select_random_ranges | 2       | 5511.65  | 5511.65  | 3            |
| select_random_ranges | 4       | 10685.18 | 10685.18 | 3            |
| select_random_ranges | 8       | 20880.90 | 20880.90 | 3            |
| select_random_ranges | 16      | 39139.31 | 39139.31 | 3            |

### Error Rate

```
root@l-wn-test-1 sysbench $ egrep -Ri 'ignored errors' log_test23 | grep -vi '0.00 per sec.'
log_test23/oltp_read_write_16threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test23/oltp_read_write_16threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
log_test23/oltp_write_only_4threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test23/oltp_write_only_16threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test23/oltp_write_only_16threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
log_test23/oltp_write_only_16threads_run3.log:    ignored errors:                      1      (0.03 per sec.)
log_test23/oltp_update_index_16threads_run1.log:    ignored errors:                      2      (0.07 per sec.)
log_test23/oltp_update_index_16threads_run3.log:    ignored errors:                      3      (0.10 per sec.)
root@l-wn-test-1 sysbench $ egrep -Ri 'ignored errors' log_test24 | grep -vi '0.00 per sec.'
log_test24/oltp_read_write_2threads_run3.log:    ignored errors:                      4      (0.13 per sec.)
log_test24/oltp_read_write_4threads_run3.log:    ignored errors:                      3      (0.10 per sec.)
log_test24/oltp_read_write_8threads_run1.log:    ignored errors:                      29     (0.97 per sec.)
log_test24/oltp_read_write_8threads_run2.log:    ignored errors:                      23     (0.77 per sec.)
log_test24/oltp_read_write_8threads_run3.log:    ignored errors:                      26     (0.87 per sec.)
log_test24/oltp_read_write_16threads_run2.log:    ignored errors:                      62     (2.07 per sec.)
log_test24/oltp_read_write_16threads_run3.log:    ignored errors:                      62     (2.07 per sec.)
log_test24/oltp_write_only_2threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test24/oltp_write_only_2threads_run3.log:    ignored errors:                      3      (0.10 per sec.)
log_test24/oltp_write_only_8threads_run1.log:    ignored errors:                      42     (1.40 per sec.)
log_test24/oltp_write_only_8threads_run3.log:    ignored errors:                      48     (1.60 per sec.)
log_test24/oltp_write_only_16threads_run1.log:    ignored errors:                      62     (2.07 per sec.)
log_test24/oltp_write_only_16threads_run2.log:    ignored errors:                      100    (3.33 per sec.)
log_test24/oltp_write_only_16threads_run3.log:    ignored errors:                      55     (1.83 per sec.)
log_test24/oltp_update_index_2threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test24/oltp_update_index_2threads_run2.log:    ignored errors:                      5      (0.17 per sec.)
log_test24/oltp_update_index_2threads_run3.log:    ignored errors:                      3      (0.10 per sec.)
log_test24/oltp_update_index_4threads_run1.log:    ignored errors:                      7      (0.23 per sec.)
log_test24/oltp_update_index_4threads_run2.log:    ignored errors:                      8      (0.27 per sec.)
log_test24/oltp_update_index_4threads_run3.log:    ignored errors:                      2      (0.07 per sec.)
log_test24/oltp_update_index_8threads_run1.log:    ignored errors:                      32     (1.07 per sec.)
log_test24/oltp_update_index_8threads_run2.log:    ignored errors:                      21     (0.70 per sec.)
log_test24/oltp_update_index_8threads_run3.log:    ignored errors:                      33     (1.10 per sec.)
log_test24/oltp_update_index_16threads_run1.log:    ignored errors:                      66     (2.20 per sec.)
log_test24/oltp_update_index_16threads_run2.log:    ignored errors:                      64     (2.13 per sec.)
log_test24/oltp_update_index_16threads_run3.log:    ignored errors:                      49     (1.63 per sec.)

```

### mysqlslap between 172.24.40.16 (log_test25) & 10.160.152.14 (log_test26)

@172.24.40.16

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 308.53   | 4936.50  | 3            |
| oltp_read_only       | 4       | 568.58   | 9097.27  | 3            |
| oltp_read_only       | 8       | 1010.51  | 16168.23 | 3            |
| oltp_read_only       | 16      | 1932.89  | 30926.24 | 3            |
| oltp_read_write      | 2       | 143.61   | 2872.33  | 3            |
| oltp_read_write      | 4       | 261.84   | 5236.87  | 3            |
| oltp_read_write      | 8       | 341.39   | 6828.54  | 3            |
| oltp_read_write      | 16      | 374.98   | 7501.60  | 3            |
| oltp_update_index    | 2       | 536.53   | 536.53   | 3            |
| oltp_update_index    | 4       | 659.51   | 659.51   | 3            |
| oltp_update_index    | 8       | 521.95   | 521.95   | 3            |
| oltp_update_index    | 16      | 1851.54  | 1851.54  | 3            |
| oltp_write_only      | 2       | 201.69   | 1210.17  | 3            |
| oltp_write_only      | 4       | 324.93   | 1949.68  | 3            |
| oltp_write_only      | 8       | 292.03   | 1752.50  | 3            |
| oltp_write_only      | 16      | 483.67   | 2902.24  | 3            |
| select_random_points | 2       | 3674.38  | 3674.38  | 3            |
| select_random_points | 4       | 7297.43  | 7297.43  | 3            |
| select_random_points | 8       | 14462.80 | 14462.80 | 3            |
| select_random_points | 16      | 26040.81 | 26040.81 | 3            |
| select_random_ranges | 2       | 4352.02  | 4352.02  | 3            |
| select_random_ranges | 4       | 8911.74  | 8911.74  | 3            |
| select_random_ranges | 8       | 16424.70 | 16424.70 | 3            |
| select_random_ranges | 16      | 28791.39 | 28791.39 | 3            |

@10.160.152.14

| Test_Type            | Threads | AVG_TPS  | AVG_QPS  | Sample_Count |
| -------------------- | ------- | -------- | -------- | ------------ |
| oltp_read_only       | 2       | 404.44   | 6471.14  | 3            |
| oltp_read_only       | 4       | 785.74   | 12571.93 | 3            |
| oltp_read_only       | 8       | 1471.37  | 23541.91 | 3            |
| oltp_read_only       | 16      | 2657.16  | 42514.60 | 3            |
| oltp_read_write      | 2       | 164.97   | 3299.90  | 3            |
| oltp_read_write      | 4       | 295.24   | 5908.25  | 3            |
| oltp_read_write      | 8       | 471.44   | 9443.59  | 3            |
| oltp_read_write      | 16      | 467.21   | 9376.93  | 3            |
| oltp_update_index    | 2       | 295.92   | 295.92   | 3            |
| oltp_update_index    | 4       | 564.43   | 564.43   | 3            |
| oltp_update_index    | 8       | 790.01   | 790.01   | 3            |
| oltp_update_index    | 16      | 751.98   | 751.98   | 3            |
| oltp_write_only      | 2       | 227.27   | 1363.78  | 3            |
| oltp_write_only      | 4       | 405.43   | 2434.22  | 2            |
| oltp_write_only      | 8       | 556.23   | 3341.22  | 1            |
| oltp_write_only      | 16      | 444.60   | 2678.92  | 2            |
| select_random_points | 2       | 5602.87  | 5602.87  | 3            |
| select_random_points | 4       | 10768.79 | 10768.79 | 3            |
| select_random_points | 8       | 20211.36 | 20211.36 | 3            |
| select_random_points | 16      | 36903.74 | 36903.74 | 3            |
| select_random_ranges | 2       | 5642.49  | 5642.49  | 3            |
| select_random_ranges | 4       | 10759.18 | 10759.18 | 3            |
| select_random_ranges | 8       | 20845.33 | 20845.33 | 3            |
| select_random_ranges | 16      | 39335.53 | 39335.53 | 3            |

### Error Rate

```
root@l-wn-test-1 sysbench $ egrep -Ri 'ignored errors' log_test25 | grep -vi '0.00 per sec.'
log_test25/oltp_read_write_8threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test25/oltp_read_write_8threads_run3.log:    ignored errors:                      2      (0.07 per sec.)
log_test25/oltp_read_write_16threads_run1.log:    ignored errors:                      3      (0.10 per sec.)
log_test25/oltp_read_write_16threads_run2.log:    ignored errors:                      4      (0.13 per sec.)
log_test25/oltp_read_write_16threads_run3.log:    ignored errors:                      2      (0.07 per sec.)
log_test25/oltp_write_only_4threads_run3.log:    ignored errors:                      2      (0.07 per sec.)
log_test25/oltp_write_only_8threads_run1.log:    ignored errors:                      3      (0.10 per sec.)
log_test25/oltp_write_only_8threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
log_test25/oltp_write_only_8threads_run3.log:    ignored errors:                      2      (0.07 per sec.)
log_test25/oltp_write_only_16threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
log_test25/oltp_write_only_16threads_run3.log:    ignored errors:                      3      (0.10 per sec.)
log_test25/oltp_update_index_4threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
log_test25/oltp_update_index_8threads_run1.log:    ignored errors:                      1      (0.03 per sec.)
log_test25/oltp_update_index_16threads_run1.log:    ignored errors:                      2      (0.07 per sec.)
log_test25/oltp_update_index_16threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
root@l-wn-test-1 sysbench $ egrep -Ri 'ignored errors' log_test26 | grep -vi '0.00 per sec.'
log_test26/oltp_read_write_2threads_run2.log:    ignored errors:                      2      (0.07 per sec.)
log_test26/oltp_read_write_4threads_run1.log:    ignored errors:                      5      (0.17 per sec.)
log_test26/oltp_read_write_4threads_run2.log:    ignored errors:                      8      (0.27 per sec.)
log_test26/oltp_read_write_4threads_run3.log:    ignored errors:                      3      (0.10 per sec.)
log_test26/oltp_read_write_8threads_run1.log:    ignored errors:                      13     (0.43 per sec.)
log_test26/oltp_read_write_8threads_run2.log:    ignored errors:                      34     (1.13 per sec.)
log_test26/oltp_read_write_8threads_run3.log:    ignored errors:                      23     (0.77 per sec.)
log_test26/oltp_read_write_16threads_run1.log:    ignored errors:                      54     (1.80 per sec.)
log_test26/oltp_read_write_16threads_run2.log:    ignored errors:                      54     (1.80 per sec.)
log_test26/oltp_read_write_16threads_run3.log:    ignored errors:                      47     (1.57 per sec.)
log_test26/oltp_write_only_2threads_run1.log:    ignored errors:                      3      (0.10 per sec.)
log_test26/oltp_write_only_4threads_run2.log:    ignored errors:                      13     (0.43 per sec.)
log_test26/oltp_write_only_4threads_run3.log:    ignored errors:                      8      (0.27 per sec.)
log_test26/oltp_write_only_8threads_run1.log:    ignored errors:                      23     (0.77 per sec.)
log_test26/oltp_write_only_16threads_run2.log:    ignored errors:                      69     (2.30 per sec.)
log_test26/oltp_write_only_16threads_run3.log:    ignored errors:                      68     (2.26 per sec.)
log_test26/oltp_update_index_2threads_run3.log:    ignored errors:                      1      (0.03 per sec.)
log_test26/oltp_update_index_4threads_run1.log:    ignored errors:                      4      (0.13 per sec.)
log_test26/oltp_update_index_4threads_run2.log:    ignored errors:                      1      (0.03 per sec.)
log_test26/oltp_update_index_4threads_run3.log:    ignored errors:                      2      (0.07 per sec.)
log_test26/oltp_update_index_8threads_run1.log:    ignored errors:                      4      (0.13 per sec.)
log_test26/oltp_update_index_8threads_run2.log:    ignored errors:                      9      (0.30 per sec.)
log_test26/oltp_update_index_8threads_run3.log:    ignored errors:                      5      (0.17 per sec.)
log_test26/oltp_update_index_16threads_run1.log:    ignored errors:                      13     (0.43 per sec.)
log_test26/oltp_update_index_16threads_run2.log:    ignored errors:                      13     (0.43 per sec.)
log_test26/oltp_update_index_16threads_run3.log:    ignored errors:                      18     (0.60 per sec.)
```

----

## TiDB + TiProxy @ Single Instance with 4 vCPU @ log_test2
| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 150.55  | 2408.90 | 3            |
| oltp_read_only       | 4       | 279.83  | 4477.31 | 3            |
| oltp_read_only       | 8       | 434.59  | 6953.47 | 3            |
| oltp_read_only       | 16      | 559.71  | 8955.42 | 3            |
| oltp_read_write      | 2       | 116.84  | 2336.89 | 3            |
| oltp_read_write      | 4       | 200.75  | 4014.96 | 3            |
| oltp_read_write      | 8       | 275.15  | 5503.14 | 3            |
| oltp_read_write      | 16      | 354.22  | 7084.41 | 3            |
| oltp_update_index    | 2       | 855.58  | 855.58  | 3            |
| oltp_update_index    | 4       | 1282.60 | 1282.60 | 3            |
| oltp_update_index    | 8       | 1900.33 | 1900.33 | 3            |
| oltp_update_index    | 16      | 2704.83 | 2704.83 | 3            |
| oltp_write_only      | 2       | 391.22  | 2347.33 | 3            |
| oltp_write_only      | 4       | 579.48  | 3476.91 | 3            |
| oltp_write_only      | 8       | 770.36  | 4622.20 | 3            |
| oltp_write_only      | 16      | 1108.85 | 6653.09 | 3            |
| select_random_points | 2       | 1108.90 | 1108.90 | 3            |
| select_random_points | 4       | 1943.98 | 1943.98 | 3            |
| select_random_points | 8       | 2821.04 | 2821.04 | 3            |
| select_random_points | 16      | 3403.69 | 3403.69 | 3            |
| select_random_ranges | 2       | 1362.07 | 1362.07 | 3            |
| select_random_ranges | 4       | 2403.03 | 2403.03 | 3            |
| select_random_ranges | 8       | 3380.50 | 3380.50 | 3            |
| select_random_ranges | 16      | 4424.09 | 4424.09 | 3            |

## TiDB + TiProxy @ IDC Cluster with 4 vCPU #1 @ log_test3
```
tiproxy_servers:
  - host: 172.24.40.17
tidb_servers:
  - host: 172.24.40.17
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
tikv_servers:
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 172.24.40.20
```

| Test_Type            | Threads | AVG_TPS | AVG_QPS  | Sample_Count |
| -------------------- | ------- | ------- | -------- | ------------ |
| oltp_read_only       | 2       | 160.71  | 2571.44  | 3            |
| oltp_read_only       | 4       | 271.77  | 4348.46  | 3            |
| oltp_read_only       | 8       | 463.06  | 7408.92  | 3            |
| oltp_read_only       | 16      | 783.54  | 12536.78 | 3            |
| oltp_read_write      | 2       | 115.02  | 2300.39  | 3            |
| oltp_read_write      | 4       | 194.04  | 3880.89  | 3            |
| oltp_read_write      | 8       | 317.65  | 6353.00  | 3            |
| oltp_read_write      | 16      | 503.92  | 10078.50 | 3            |
| oltp_update_index    | 2       | 760.78  | 760.78   | 3            |
| oltp_update_index    | 4       | 1356.62 | 1356.62  | 3            |
| oltp_update_index    | 8       | 2093.70 | 2093.70  | 3            |
| oltp_update_index    | 16      | 3371.89 | 3371.89  | 3            |
| oltp_write_only      | 2       | 344.18  | 2065.11  | 3            |
| oltp_write_only      | 4       | 590.91  | 3545.51  | 3            |
| oltp_write_only      | 8       | 972.33  | 5833.99  | 3            |
| oltp_write_only      | 16      | 1500.30 | 9001.83  | 3            |
| select_random_points | 2       | 1060.08 | 1060.08  | 3            |
| select_random_points | 4       | 1834.69 | 1834.69  | 3            |
| select_random_points | 8       | 3154.18 | 3154.18  | 3            |
| select_random_points | 16      | 5097.07 | 5097.07  | 3            |
| select_random_ranges | 2       | 1291.76 | 1291.76  | 3            |
| select_random_ranges | 4       | 2132.42 | 2132.42  | 3            |
| select_random_ranges | 8       | 3791.80 | 3791.80  | 3            |
| select_random_ranges | 16      | 5598.35 | 5598.35  | 3            |

## TiDB + TiProxy @ IDC Cluster with 4 vCPU #2 @ log_test4
```
tiproxy_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
tidb_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
tikv_servers:
  - host: 172.24.40.20
```

| Test_Type            | Threads | AVG_TPS | AVG_QPS  | Sample_Count |
| -------------------- | ------- | ------- | -------- | ------------ |
| oltp_read_only       | 2       | 153.85  | 2461.60  | 3            |
| oltp_read_only       | 4       | 297.89  | 4766.32  | 3            |
| oltp_read_only       | 8       | 510.26  | 8164.20  | 3            |
| oltp_read_only       | 16      | 830.14  | 13282.32 | 3            |
| oltp_read_write      | 2       | 111.55  | 2230.99  | 3            |
| oltp_read_write      | 4       | 203.25  | 4065.11  | 3            |
| oltp_read_write      | 8       | 348.96  | 6979.14  | 3            |
| oltp_read_write      | 16      | 561.45  | 11229.18 | 3            |
| oltp_update_index    | 2       | 897.85  | 897.85   | 3            |
| oltp_update_index    | 4       | 1602.30 | 1602.30  | 3            |
| oltp_update_index    | 8       | 2499.55 | 2499.55  | 3            |
| oltp_update_index    | 16      | 3946.03 | 3946.03  | 3            |
| oltp_write_only      | 2       | 373.28  | 2239.70  | 3            |
| oltp_write_only      | 4       | 673.46  | 4040.75  | 3            |
| oltp_write_only      | 8       | 1096.54 | 6579.26  | 3            |
| oltp_write_only      | 16      | 1782.03 | 10692.21 | 3            |
| select_random_points | 2       | 1057.32 | 1057.32  | 3            |
| select_random_points | 4       | 1992.40 | 1992.40  | 3            |
| select_random_points | 8       | 3368.80 | 3368.80  | 3            |
| select_random_points | 16      | 5538.02 | 5538.02  | 3            |
| select_random_ranges | 2       | 1331.89 | 1331.89  | 3            |
| select_random_ranges | 4       | 2421.44 | 2421.44  | 3            |
| select_random_ranges | 8       | 4314.57 | 4314.57  | 3            |
| select_random_ranges | 16      | 7026.91 | 7026.91  | 3            |

## TiDB + TiProxy @ IDC Cluster with 8 vCPU #1 @ log_test7
```
tiproxy_servers:
  - host: 172.24.40.17
tidb_servers:
  - host: 172.24.40.17
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
tikv_servers:
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 172.24.40.20
```

| Test_Type            | Threads | AVG_TPS | AVG_QPS  | Sample_Count |
| -------------------- | ------- | ------- | -------- | ------------ |
| oltp_read_only       | 2       | 163.09  | 2609.47  | 3            |
| oltp_read_only       | 4       | 304.30  | 4868.77  | 3            |
| oltp_read_only       | 8       | 581.51  | 9304.31  | 3            |
| oltp_read_only       | 16      | 965.52  | 15448.48 | 3            |
| oltp_read_write      | 2       | 115.46  | 2309.24  | 3            |
| oltp_read_write      | 4       | 204.88  | 4097.65  | 3            |
| oltp_read_write      | 8       | 401.19  | 8023.95  | 3            |
| oltp_read_write      | 16      | 712.43  | 14248.62 | 3            |
| oltp_update_index    | 2       | 792.48  | 792.48   | 3            |
| oltp_update_index    | 4       | 1418.77 | 1418.77  | 3            |
| oltp_update_index    | 8       | 2533.37 | 2533.37  | 3            |
| oltp_update_index    | 16      | 4374.26 | 4374.26  | 3            |
| oltp_write_only      | 2       | 370.07  | 2220.44  | 3            |
| oltp_write_only      | 4       | 671.99  | 4031.94  | 3            |
| oltp_write_only      | 8       | 1140.60 | 6843.61  | 3            |
| oltp_write_only      | 16      | 1988.00 | 11927.99 | 3            |
| select_random_points | 2       | 1058.07 | 1058.07  | 3            |
| select_random_points | 4       | 1773.16 | 1773.16  | 3            |
| select_random_points | 8       | 3186.89 | 3186.89  | 3            |
| select_random_points | 16      | 5798.88 | 5798.88  | 3            |
| select_random_ranges | 2       | 1282.32 | 1282.32  | 3            |
| select_random_ranges | 4       | 1963.23 | 1963.23  | 3            |
| select_random_ranges | 8       | 3788.41 | 3788.41  | 3            |
| select_random_ranges | 16      | 6808.54 | 6808.54  | 3            |

## TiDB + TiProxy @ IDC Cluster with 8 vCPU #2 @ log_test8
```
tiproxy_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
tidb_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
tikv_servers:
  - host: 172.24.40.20
```

| Test_Type            | Threads | AVG_TPS | AVG_QPS  | Sample_Count |
| -------------------- | ------- | ------- | -------- | ------------ |
| oltp_read_only       | 2       | 149.48  | 2391.74  | 3            |
| oltp_read_only       | 4       | 297.48  | 4759.74  | 3            |
| oltp_read_only       | 8       | 537.24  | 8595.95  | 3            |
| oltp_read_only       | 16      | 971.84  | 15549.46 | 3            |
| oltp_read_write      | 2       | 117.98  | 2359.64  | 3            |
| oltp_read_write      | 4       | 219.93  | 4398.68  | 3            |
| oltp_read_write      | 8       | 407.81  | 8156.34  | 3            |
| oltp_read_write      | 16      | 716.43  | 14328.71 | 3            |
| oltp_update_index    | 2       | 940.75  | 940.75   | 3            |
| oltp_update_index    | 4       | 1701.65 | 1701.65  | 3            |
| oltp_update_index    | 8       | 2980.07 | 2980.07  | 3            |
| oltp_update_index    | 16      | 4947.12 | 4947.12  | 3            |
| oltp_write_only      | 2       | 383.60  | 2301.65  | 3            |
| oltp_write_only      | 4       | 727.90  | 4367.42  | 3            |
| oltp_write_only      | 8       | 1288.40 | 7730.40  | 3            |
| oltp_write_only      | 16      | 2161.54 | 12969.26 | 3            |
| select_random_points | 2       | 1032.66 | 1032.66  | 3            |
| select_random_points | 4       | 2174.07 | 2174.07  | 3            |
| select_random_points | 8       | 4097.45 | 4097.45  | 3            |
| select_random_points | 16      | 7162.81 | 7162.81  | 3            |
| select_random_ranges | 2       | 1274.49 | 1274.49  | 3            |
| select_random_ranges | 4       | 2514.27 | 2514.27  | 3            |
| select_random_ranges | 8       | 4462.97 | 4462.97  | 3            |
| select_random_ranges | 16      | 8913.89 | 8913.89  | 3            |

## TiDB + TiProxy @ IDC + GCP Cluster with 4 vCPU #1 @ 

```
tiproxy_servers:
  - host: 172.24.40.17
  - host: 10.160.152.21
tidb_servers:
  - host: 172.24.40.17
  - host: 10.160.152.21
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
tikv_servers:
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 172.24.40.20
  - host: 10.160.152.22
  - host: 10.160.152.23
  - host: 10.160.152.24
```

### sysbench on 172.24.40.25 @ log_test15

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 107.34  | 1717.47 | 3            |
| oltp_read_only       | 4       | 45.84   | 733.42  | 3            |
| oltp_read_only       | 8       | 31.43   | 502.91  | 3            |
| oltp_read_only       | 16      | 33.21   | 531.46  | 3            |
| oltp_read_write      | 2       | 21.59   | 431.85  | 3            |
| oltp_read_write      | 4       | 38.04   | 760.85  | 3            |
| oltp_read_write      | 8       | 90.01   | 1800.36 | 3            |
| oltp_read_write      | 16      | 169.98  | 3399.68 | 3            |
| oltp_update_index    | 2       | 126.11  | 126.11  | 3            |
| oltp_update_index    | 4       | 203.02  | 203.02  | 3            |
| oltp_update_index    | 8       | 357.10  | 357.10  | 3            |
| oltp_update_index    | 16      | 776.55  | 776.55  | 3            |
| oltp_write_only      | 2       | 53.85   | 323.10  | 3            |
| oltp_write_only      | 4       | 97.12   | 582.75  | 3            |
| oltp_write_only      | 8       | 188.13  | 1128.83 | 3            |
| oltp_write_only      | 16      | 403.22  | 2419.35 | 3            |
| select_random_points | 2       | 159.40  | 159.40  | 3            |
| select_random_points | 4       | 344.43  | 344.43  | 3            |
| select_random_points | 8       | 625.77  | 625.77  | 3            |
| select_random_points | 16      | 974.47  | 974.47  | 3            |
| select_random_ranges | 2       | 140.09  | 140.09  | 3            |
| select_random_ranges | 4       | 199.64  | 199.64  | 3            |
| select_random_ranges | 8       | 400.15  | 400.15  | 3            |
| select_random_ranges | 16      | 887.47  | 887.47  | 3            |

### sysbench on 10.160.152.26 @ log_test16

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 47.59   | 761.50  | 3            |
| oltp_read_only       | 4       | 61.90   | 990.37  | 3            |
| oltp_read_only       | 8       | 124.34  | 1989.43 | 3            |
| oltp_read_only       | 16      | 261.47  | 4183.61 | 3            |
| oltp_read_write      | 2       | 32.49   | 649.93  | 3            |
| oltp_read_write      | 4       | 65.04   | 1300.76 | 3            |
| oltp_read_write      | 8       | 138.08  | 2761.65 | 3            |
| oltp_read_write      | 16      | 260.15  | 5203.15 | 3            |
| oltp_update_index    | 2       | 296.69  | 296.69  | 3            |
| oltp_update_index    | 4       | 422.69  | 422.69  | 3            |
| oltp_update_index    | 8       | 690.57  | 690.57  | 3            |
| oltp_update_index    | 16      | 1397.89 | 1397.89 | 3            |
| oltp_write_only      | 2       | 54.58   | 327.48  | 3            |
| oltp_write_only      | 4       | 130.43  | 782.61  | 3            |
| oltp_write_only      | 8       | 301.77  | 1810.61 | 3            |
| oltp_write_only      | 16      | 736.06  | 4416.38 | 3            |
| select_random_points | 2       | 1710.78 | 1710.78 | 3            |
| select_random_points | 4       | 2821.00 | 2821.00 | 3            |
| select_random_points | 8       | 4432.80 | 4432.80 | 3            |
| select_random_points | 16      | 5757.00 | 5757.00 | 3            |
| select_random_ranges | 2       | 1542.61 | 1542.61 | 3            |
| select_random_ranges | 4       | 2318.72 | 2318.72 | 3            |
| select_random_ranges | 8       | 1695.93 | 1695.93 | 3            |
| select_random_ranges | 16      | 2930.37 | 2930.37 | 3            |

### sysbench between 172.24.40.25 (log_test17) & 10.160.152.26 (log_test18)

@172.24.40.25

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 21.42   | 342.71  | 3            |
| oltp_read_only       | 4       | 35.00   | 560.00  | 3            |
| oltp_read_only       | 8       | 85.48   | 1367.80 | 3            |
| oltp_read_only       | 16      | 118.97  | 1903.59 | 3            |
| oltp_read_write      | 2       | 12.33   | 246.57  | 3            |
| oltp_read_write      | 4       | 21.71   | 434.26  | 3            |
| oltp_read_write      | 8       | 44.02   | 880.51  | 3            |
| oltp_read_write      | 16      | 82.71   | 1654.22 | 3            |
| oltp_update_index    | 2       | 105.40  | 105.40  | 3            |
| oltp_update_index    | 4       | 184.34  | 184.34  | 3            |
| oltp_update_index    | 8       | 423.43  | 423.43  | 3            |
| oltp_update_index    | 16      | 818.69  | 818.69  | 3            |
| oltp_write_only      | 2       | 53.28   | 319.69  | 3            |
| oltp_write_only      | 4       | 85.73   | 514.38  | 3            |
| oltp_write_only      | 8       | 134.38  | 806.27  | 3            |
| oltp_write_only      | 16      | 322.83  | 1937.00 | 3            |
| select_random_points | 2       | 84.52   | 84.52   | 3            |
| select_random_points | 4       | 124.80  | 124.80  | 3            |
| select_random_points | 8       | 329.87  | 329.87  | 3            |
| select_random_points | 16      | 572.89  | 572.89  | 3            |
| select_random_ranges | 2       | 133.75  | 133.75  | 3            |
| select_random_ranges | 4       | 167.64  | 167.64  | 3            |
| select_random_ranges | 8       | 456.20  | 456.20  | 3            |
| select_random_ranges | 16      | 979.20  | 979.20  | 3            |

@10.160.152.26

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 46.70   | 747.22  | 3            |
| oltp_read_only       | 4       | 78.78   | 1260.48 | 3            |
| oltp_read_only       | 8       | 189.82  | 3037.14 | 3            |
| oltp_read_only       | 16      | 266.69  | 4266.99 | 3            |
| oltp_read_write      | 2       | 136.96  | 2739.25 | 3            |
| oltp_read_write      | 4       | 241.08  | 4821.72 | 3            |
| oltp_read_write      | 8       | 362.03  | 7240.72 | 3            |
| oltp_read_write      | 16      | 211.41  | 4228.30 | 3            |
| oltp_update_index    | 2       | 193.66  | 193.66  | 3            |
| oltp_update_index    | 4       | 346.19  | 346.19  | 3            |
| oltp_update_index    | 8       | 837.42  | 837.42  | 3            |
| oltp_update_index    | 16      | 1606.77 | 1606.77 | 3            |
| oltp_write_only      | 2       | 143.26  | 859.55  | 3            |
| oltp_write_only      | 4       | 254.76  | 1528.56 | 3            |
| oltp_write_only      | 8       | 433.98  | 2603.87 | 3            |
| oltp_write_only      | 16      | 591.82  | 3550.95 | 3            |
| select_random_points | 2       | 518.50  | 518.50  | 3            |
| select_random_points | 4       | 674.40  | 674.40  | 3            |
| select_random_points | 8       | 1703.79 | 1703.79 | 3            |
| select_random_points | 16      | 3130.14 | 3130.14 | 3            |
| select_random_ranges | 2       | 1737.88 | 1737.88 | 3            |
| select_random_ranges | 4       | 2854.22 | 2854.22 | 3            |
| select_random_ranges | 8       | 3643.36 | 3643.36 | 3            |
| select_random_ranges | 16      | 4370.36 | 4370.36 | 3            |

## TiDB + TiProxy @ IDC + GCP Cluster with 4 vCPU #2 @ 

```
tiproxy_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
tidb_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
tikv_servers:
  - host: 172.24.40.20
  - host: 10.160.152.24
```

### sysbench on 172.24.40.25 @ log_test19

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 21.75   | 348.07  | 3            |
| oltp_read_only       | 4       | 43.49   | 695.89  | 3            |
| oltp_read_only       | 8       | 87.06   | 1393.02 | 3            |
| oltp_read_only       | 16      | 171.93  | 2750.98 | 3            |
| oltp_read_write      | 2       | 15.53   | 310.74  | 3            |
| oltp_read_write      | 4       | 30.99   | 619.81  | 3            |
| oltp_read_write      | 8       | 65.65   | 1313.15 | 3            |
| oltp_read_write      | 16      | 131.61  | 2632.31 | 3            |
| oltp_update_index    | 2       | 72.56   | 72.56   | 3            |
| oltp_update_index    | 4       | 134.43  | 134.43  | 3            |
| oltp_update_index    | 8       | 323.02  | 323.02  | 3            |
| oltp_update_index    | 16      | 689.50  | 689.50  | 3            |
| oltp_write_only      | 2       | 59.29   | 355.74  | 3            |
| oltp_write_only      | 4       | 112.46  | 674.81  | 3            |
| oltp_write_only      | 8       | 198.60  | 1191.58 | 3            |
| oltp_write_only      | 16      | 290.91  | 1745.51 | 3            |
| select_random_points | 2       | 78.06   | 78.06   | 3            |
| select_random_points | 4       | 175.51  | 175.51  | 3            |
| select_random_points | 8       | 438.05  | 438.05  | 3            |
| select_random_points | 16      | 898.15  | 898.15  | 3            |
| select_random_ranges | 2       | 274.05  | 274.05  | 3            |
| select_random_ranges | 4       | 545.62  | 545.62  | 3            |
| select_random_ranges | 8       | 1130.69 | 1130.69 | 3            |
| select_random_ranges | 16      | 2224.60 | 2224.60 | 3            |

### sysbench on 10.160.152.26 @ log_test20

| Test_Type            | Threads | AVG_TPS | AVG_QPS  | Sample_Count |
| -------------------- | ------- | ------- | -------- | ------------ |
| oltp_read_only       | 2       | 115.41  | 1846.61  | 3            |
| oltp_read_only       | 4       | 221.02  | 3536.48  | 3            |
| oltp_read_only       | 8       | 391.93  | 6270.90  | 3            |
| oltp_read_only       | 16      | 652.10  | 10433.64 | 3            |
| oltp_read_write      | 2       | 64.24   | 1284.84  | 3            |
| oltp_read_write      | 4       | 114.53  | 2290.66  | 3            |
| oltp_read_write      | 8       | 202.61  | 4052.18  | 3            |
| oltp_read_write      | 16      | 335.91  | 6718.20  | 3            |
| oltp_update_index    | 2       | 151.68  | 151.68   | 3            |
| oltp_update_index    | 4       | 233.90  | 233.90   | 3            |
| oltp_update_index    | 8       | 514.77  | 514.77   | 3            |
| oltp_update_index    | 16      | 946.63  | 946.63   | 3            |
| oltp_write_only      | 2       | 78.85   | 473.13   | 3            |
| oltp_write_only      | 4       | 149.40  | 896.42   | 3            |
| oltp_write_only      | 8       | 288.70  | 1732.21  | 3            |
| oltp_write_only      | 16      | 555.80  | 3334.80  | 3            |
| select_random_points | 2       | 208.06  | 208.06   | 3            |
| select_random_points | 4       | 308.46  | 308.46   | 3            |
| select_random_points | 8       | 708.41  | 708.41   | 3            |
| select_random_points | 16      | 1227.60 | 1227.60  | 3            |
| select_random_ranges | 2       | 265.02  | 265.02   | 3            |
| select_random_ranges | 4       | 391.47  | 391.47   | 3            |
| select_random_ranges | 8       | 402.65  | 402.65   | 3            |
| select_random_ranges | 16      | 1142.67 | 1142.67  | 3            |

### sysbench between 172.24.40.25 (log_test21) & 10.160.152.26 (log_test22)

@172.24.40.25

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 22.12   | 353.94  | 3            |
| oltp_read_only       | 4       | 43.90   | 702.47  | 3            |
| oltp_read_only       | 8       | 88.30   | 1412.89 | 3            |
| oltp_read_only       | 16      | 160.75  | 2572.05 | 3            |
| oltp_read_write      | 2       | 15.60   | 312.11  | 3            |
| oltp_read_write      | 4       | 32.02   | 640.41  | 3            |
| oltp_read_write      | 8       | 63.94   | 1278.80 | 3            |
| oltp_read_write      | 16      | 120.19  | 2403.88 | 3            |
| oltp_update_index    | 2       | 105.73  | 105.73  | 3            |
| oltp_update_index    | 4       | 209.78  | 209.78  | 3            |
| oltp_update_index    | 8       | 413.36  | 413.36  | 3            |
| oltp_update_index    | 16      | 801.97  | 801.97  | 3            |
| oltp_write_only      | 2       | 59.07   | 354.45  | 3            |
| oltp_write_only      | 4       | 116.35  | 698.13  | 3            |
| oltp_write_only      | 8       | 217.67  | 1306.05 | 3            |
| oltp_write_only      | 16      | 431.30  | 2587.79 | 3            |
| select_random_points | 2       | 149.68  | 149.68  | 3            |
| select_random_points | 4       | 319.73  | 319.73  | 3            |
| select_random_points | 8       | 653.42  | 653.42  | 3            |
| select_random_points | 16      | 1295.15 | 1295.15 | 3            |
| select_random_ranges | 2       | 284.77  | 284.77  | 3            |
| select_random_ranges | 4       | 569.79  | 569.79  | 3            |
| select_random_ranges | 8       | 1136.45 | 1136.45 | 3            |
| select_random_ranges | 16      | 2277.48 | 2277.48 | 3            |

@10.160.152.26

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 116.77  | 1868.44 | 3            |
| oltp_read_only       | 4       | 223.65  | 3578.55 | 3            |
| oltp_read_only       | 8       | 399.54  | 6392.72 | 3            |
| oltp_read_only       | 16      | 589.87  | 9437.92 | 3            |
| oltp_read_write      | 2       | 61.31   | 1226.39 | 3            |
| oltp_read_write      | 4       | 113.90  | 2278.00 | 3            |
| oltp_read_write      | 8       | 207.60  | 4152.12 | 3            |
| oltp_read_write      | 16      | 301.83  | 6036.68 | 3            |
| oltp_update_index    | 2       | 150.50  | 150.50  | 3            |
| oltp_update_index    | 4       | 262.37  | 262.37  | 3            |
| oltp_update_index    | 8       | 505.78  | 505.78  | 3            |
| oltp_update_index    | 16      | 945.86  | 945.86  | 3            |
| oltp_write_only      | 2       | 84.42   | 506.56  | 3            |
| oltp_write_only      | 4       | 159.77  | 958.65  | 3            |
| oltp_write_only      | 8       | 277.93  | 1667.59 | 3            |
| oltp_write_only      | 16      | 533.18  | 3199.09 | 3            |
| select_random_points | 2       | 212.86  | 212.86  | 3            |
| select_random_points | 4       | 412.74  | 412.74  | 3            |
| select_random_points | 8       | 742.39  | 742.39  | 3            |
| select_random_points | 16      | 1438.08 | 1438.08 | 3            |
| select_random_ranges | 2       | 295.65  | 295.65  | 3            |
| select_random_ranges | 4       | 479.99  | 479.99  | 3            |
| select_random_ranges | 8       | 759.46  | 759.46  | 3            |
| select_random_ranges | 16      | 1450.77 | 1450.77 | 3            |

## TiDB + TiProxy @ IDC + GCP Cluster with 8 vCPU #1

```
tiproxy_servers:
  - host: 172.24.40.17
  - host: 10.160.152.21
tidb_servers:
  - host: 172.24.40.17
  - host: 10.160.152.21
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
tikv_servers:
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 172.24.40.20
  - host: 10.160.152.22
  - host: 10.160.152.23
  - host: 10.160.152.24
```

### sysbench on 172.24.40.25 @ log_test11


| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 52.01   | 832.28  | 3            |
| oltp_read_only       | 4       | 75.19   | 1203.15 | 3            |
| oltp_read_only       | 8       | 155.11  | 2481.83 | 3            |
| oltp_read_only       | 16      | 183.68  | 2938.95 | 3            |
| oltp_read_write      | 2       | 18.92   | 378.39  | 3            |
| oltp_read_write      | 4       | 34.65   | 693.00  | 3            |
| oltp_read_write      | 8       | 87.98   | 1759.61 | 3            |
| oltp_read_write      | 16      | 216.04  | 4320.86 | 3            |
| oltp_update_index    | 2       | 167.64  | 167.64  | 3            |
| oltp_update_index    | 4       | 385.10  | 385.10  | 3            |
| oltp_update_index    | 8       | 731.24  | 731.24  | 3            |
| oltp_update_index    | 16      | 1342.53 | 1342.53 | 3            |
| oltp_write_only      | 2       | 38.87   | 233.22  | 3            |
| oltp_write_only      | 4       | 102.93  | 617.61  | 3            |
| oltp_write_only      | 8       | 244.49  | 1466.98 | 3            |
| oltp_write_only      | 16      | 331.66  | 1989.99 | 3            |
| select_random_points | 2       | 232.05  | 232.05  | 3            |
| select_random_points | 4       | 479.27  | 479.27  | 3            |
| select_random_points | 8       | 963.05  | 963.05  | 3            |
| select_random_points | 16      | 1964.36 | 1964.36 | 3            |
| select_random_ranges | 2       | 1282.81 | 1282.81 | 3            |
| select_random_ranges | 4       | 2251.27 | 2251.27 | 3            |
| select_random_ranges | 8       | 4112.19 | 4112.19 | 3            |
| select_random_ranges | 16      | 7167.64 | 7167.64 | 3            |

### sysbench on 10.160.152.26 @ log_test12

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 24.53   | 392.57  | 3            |
| oltp_read_only       | 4       | 57.57   | 921.13  | 3            |
| oltp_read_only       | 8       | 131.73  | 2107.83 | 3            |
| oltp_read_only       | 16      | 246.55  | 3944.92 | 3            |
| oltp_read_write      | 2       | 22.12   | 442.37  | 3            |
| oltp_read_write      | 4       | 36.95   | 739.11  | 3            |
| oltp_read_write      | 8       | 77.78   | 1555.61 | 3            |
| oltp_read_write      | 16      | 97.98   | 1959.58 | 3            |
| oltp_update_index    | 2       | 130.76  | 130.76  | 3            |
| oltp_update_index    | 4       | 264.63  | 264.63  | 3            |
| oltp_update_index    | 8       | 469.24  | 469.24  | 3            |
| oltp_update_index    | 16      | 619.03  | 619.03  | 3            |
| oltp_write_only      | 2       | 69.42   | 416.56  | 3            |
| oltp_write_only      | 4       | 117.31  | 703.90  | 3            |
| oltp_write_only      | 8       | 209.91  | 1259.46 | 3            |
| oltp_write_only      | 16      | 384.45  | 2306.71 | 3            |
| select_random_points | 2       | 128.43  | 128.43  | 3            |
| select_random_points | 4       | 299.74  | 299.74  | 3            |
| select_random_points | 8       | 665.91  | 665.91  | 3            |
| select_random_points | 16      | 1389.59 | 1389.59 | 3            |
| select_random_ranges | 2       | 159.97  | 159.97  | 3            |
| select_random_ranges | 4       | 263.20  | 263.20  | 3            |
| select_random_ranges | 8       | 555.53  | 555.53  | 3            |
| select_random_ranges | 16      | 1043.94 | 1043.94 | 3            |

### sysbench between 172.24.40.25 (log_test13) & 10.160.152.26 (log_test14)

@172.24.40.25

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 21.23   | 339.80  | 3            |
| oltp_read_only       | 4       | 51.27   | 820.45  | 3            |
| oltp_read_only       | 8       | 105.53  | 1688.61 | 3            |
| oltp_read_only       | 16      | 231.45  | 3703.26 | 3            |
| oltp_read_write      | 2       | 37.69   | 753.85  | 3            |
| oltp_read_write      | 4       | 58.62   | 1172.50 | 3            |
| oltp_read_write      | 8       | 43.36   | 867.29  | 3            |
| oltp_read_write      | 16      | 186.33  | 3726.63 | 3            |
| oltp_update_index    | 2       | 171.01  | 171.01  | 3            |
| oltp_update_index    | 4       | 306.90  | 306.90  | 3            |
| oltp_update_index    | 8       | 613.55  | 613.55  | 3            |
| oltp_update_index    | 16      | 1034.40 | 1034.40 | 3            |
| oltp_write_only      | 2       | 78.63   | 471.83  | 3            |
| oltp_write_only      | 4       | 176.54  | 1059.26 | 3            |
| oltp_write_only      | 8       | 331.12  | 1986.72 | 3            |
| oltp_write_only      | 16      | 561.22  | 3367.32 | 3            |
| select_random_points | 2       | 1109.03 | 1109.03 | 3            |
| select_random_points | 4       | 1914.22 | 1914.22 | 3            |
| select_random_points | 8       | 1950.41 | 1950.41 | 3            |
| select_random_points | 16      | 1418.03 | 1418.03 | 3            |
| select_random_ranges | 2       | 878.48  | 878.48  | 3            |
| select_random_ranges | 4       | 1868.27 | 1868.27 | 3            |
| select_random_ranges | 8       | 2428.37 | 2428.37 | 3            |
| select_random_ranges | 16      | 4648.76 | 4648.76 | 3            |

@10.160.152.26

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 26.39   | 422.34  | 3            |
| oltp_read_only       | 4       | 61.14   | 978.35  | 3            |
| oltp_read_only       | 8       | 126.00  | 2016.10 | 3            |
| oltp_read_only       | 16      | 271.00  | 4336.02 | 3            |
| oltp_read_write      | 2       | 11.31   | 226.17  | 3            |
| oltp_read_write      | 4       | 16.90   | 338.04  | 3            |
| oltp_read_write      | 8       | 14.33   | 286.78  | 3            |
| oltp_read_write      | 16      | 106.95  | 2139.20 | 3            |
| oltp_update_index    | 2       | 105.66  | 105.66  | 3            |
| oltp_update_index    | 4       | 160.59  | 160.59  | 3            |
| oltp_update_index    | 8       | 321.84  | 321.84  | 3            |
| oltp_update_index    | 16      | 558.86  | 558.86  | 3            |
| oltp_write_only      | 2       | 55.76   | 334.56  | 3            |
| oltp_write_only      | 4       | 104.04  | 624.27  | 3            |
| oltp_write_only      | 8       | 197.50  | 1185.02 | 3            |
| oltp_write_only      | 16      | 332.54  | 1995.26 | 3            |
| select_random_points | 2       | 43.98   | 43.98   | 3            |
| select_random_points | 4       | 68.33   | 68.33   | 3            |
| select_random_points | 8       | 353.61  | 353.61  | 3            |
| select_random_points | 16      | 486.87  | 486.87  | 3            |
| select_random_ranges | 2       | 132.47  | 132.47  | 3            |
| select_random_ranges | 4       | 241.89  | 241.89  | 3            |
| select_random_ranges | 8       | 432.54  | 432.54  | 3            |
| select_random_ranges | 16      | 791.88  | 791.88  | 3            |

### Error Rate

```
root@l-wn-test-1 sysbench $ date ; egrep -Ri 'ignored errors' log_test1[1,2,3,4] | grep -vi '0.00 per sec.' | wc -l
Wed Nov 12 10:05:02 CST 2025
0
```

## TiDB + TiProxy @ IDC + GCP Cluster with 8 vCPU #2

```
tiproxy_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
tidb_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
pd_servers:
  - host: 172.24.40.17
  - host: 172.24.40.18
  - host: 172.24.40.19
  - host: 10.160.152.21
  - host: 10.160.152.22
  - host: 10.160.152.23
tikv_servers:
  - host: 172.24.40.20
  - host: 10.160.152.24
```

### sysbench on 172.24.40.25 @ log_test9

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 68.67   | 1098.81 | 3            |
| oltp_read_only       | 4       | 130.37  | 2085.90 | 3            |
| oltp_read_only       | 8       | 287.17  | 4594.81 | 3            |
| oltp_read_only       | 16      | 541.93  | 8670.91 | 3            |
| oltp_read_write      | 2       | 4.76    | 95.33   | 3            |
| oltp_read_write      | 4       | 22.23   | 444.73  | 3            |
| oltp_read_write      | 8       | 47.26   | 945.19  | 3            |
| oltp_read_write      | 16      | 97.87   | 1957.47 | 3            |
| oltp_update_index    | 2       | 108.27  | 108.27  | 3            |
| oltp_update_index    | 4       | 214.59  | 214.59  | 3            |
| oltp_update_index    | 8       | 313.88  | 313.88  | 3            |
| oltp_update_index    | 16      | 693.21  | 693.21  | 3            |
| oltp_write_only      | 2       | 44.52   | 267.15  | 3            |
| oltp_write_only      | 4       | 39.33   | 235.98  | 3            |
| oltp_write_only      | 8       | 55.41   | 332.48  | 3            |
| oltp_write_only      | 16      | 323.63  | 1941.82 | 3            |
| select_random_points | 2       | 91.14   | 91.14   | 3            |
| select_random_points | 4       | 148.01  | 148.01  | 3            |
| select_random_points | 8       | 401.58  | 401.58  | 3            |
| select_random_points | 16      | 623.03  | 623.03  | 3            |
| select_random_ranges | 2       | 177.63  | 177.63  | 3            |
| select_random_ranges | 4       | 287.97  | 287.97  | 3            |
| select_random_ranges | 8       | 567.93  | 567.93  | 3            |
| select_random_ranges | 16      | 1088.38 | 1088.38 | 3            |

### sysbench on 10.160.152.26 @ log_test10

| Test_Type            | Threads | AVG_TPS | AVG_QPS | Sample_Count |
| -------------------- | ------- | ------- | ------- | ------------ |
| oltp_read_only       | 2       | 12.36   | 197.80  | 3            |
| oltp_read_only       | 4       | 11.63   | 186.09  | 3            |
| oltp_read_only       | 8       | 25.85   | 413.71  | 3            |
| oltp_read_only       | 16      | 216.84  | 3469.50 | 3            |
| oltp_read_write      | 2       | 8.61    | 172.33  | 3            |
| oltp_read_write      | 4       | 19.63   | 392.66  | 3            |
| oltp_read_write      | 8       | 19.21   | 384.26  | 3            |
| oltp_read_write      | 16      | 46.04   | 920.80  | 3            |
| oltp_update_index    | 2       | 97.70   | 97.70   | 3            |
| oltp_update_index    | 4       | 208.57  | 208.57  | 3            |
| oltp_update_index    | 8       | 373.78  | 373.78  | 3            |
| oltp_update_index    | 16      | 837.85  | 837.85  | 3            |
| oltp_write_only      | 2       | 64.22   | 385.32  | 3            |
| oltp_write_only      | 4       | 131.31  | 787.86  | 3            |
| oltp_write_only      | 8       | 277.43  | 1664.63 | 3            |
| oltp_write_only      | 16      | 569.83  | 3418.99 | 3            |
| select_random_points | 2       | 198.77  | 198.77  | 3            |
| select_random_points | 4       | 302.00  | 302.00  | 3            |
| select_random_points | 8       | 666.76  | 666.76  | 3            |
| select_random_points | 16      | 1412.16 | 1412.16 | 3            |
| select_random_ranges | 2       | 180.45  | 180.45  | 3            |
| select_random_ranges | 4       | 418.06  | 418.06  | 3            |
| select_random_ranges | 8       | 902.60  | 902.60  | 3            |
| select_random_ranges | 16      | 1655.37 | 1655.37 | 3            |


### Error Rate

```
root@l-wn-test-1 sysbench $ date ; egrep -Ri 'ignored errors' log_test9 | grep -vi '0.00 per sec.' | wc -l
Wed Nov 12 10:05:39 CST 2025
0
root@l-wn-test-1 sysbench $ date ; egrep -Ri 'ignored errors' log_test10 | grep -vi '0.00 per sec.' | wc -l
Wed Nov 12 10:05:43 CST 2025
0
```
