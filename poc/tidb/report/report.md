# TiDB PoC Report

- [PoC 架構設計原則](https://hackmd.io/iWx0brzWQ2W7Xs7gYpRFFQ?view#PoC-%E6%9E%B6%E6%A7%8B%E8%A8%AD%E8%A8%88%E5%8E%9F%E5%89%87)
- [RPS 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#-rps-%E6%95%88%E8%83%BD%E5%B0%8D%E7%85%A7%E8%A7%A3%E6%9E%90)
- [Sysbench 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#-sysbench-%E6%95%88%E8%83%BD%E5%B0%8D%E7%85%A7%E8%A7%A3%E6%9E%90-)
- [Failover Scenario](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#-failover-scenario-)
- [Chaos engineering for leased-line quality across multiple data centers](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#-chaos-engineering-for-leased-line-quality-across-multiple-data-centers)
- [Staging AC-API 整合測試紀錄](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#-staging-ac-api-%E6%95%B4%E5%90%88%E6%B8%AC%E8%A9%A6%E7%B4%80%E9%8C%84-)
- [Final](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#-final-)

----

## ==== **[RPS 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md)**====
[Back](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#tidb-poc-report)

### **TiDB 跨區穩定度高：10〜250 threads 僅 ±1%〜2% 波動**

### **MySQL 跨區中併發易掉速（-7%〜-33%）**

  - [S3-1-3：MySQL 4 vCPU — IDC+GCP 共同壓測：跨區併發，mysqlslap SELECT 1](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md#%E6%95%B8%E6%93%9A%E5%B0%8D%E7%85%A7%E8%A1%A8s3-1-3mysql-4-vcpu--idcgcp-%E5%85%B1%E5%90%8C%E5%A3%93%E6%B8%AC%E8%B7%A8%E5%8D%80%E4%BD%B5%E7%99%BCmysqlslap-select-1)

    | threads | RPS(A) 跨區@IDC | RPS(B) 跨區@GCP | 差異%(B 對 A) |
    | ------- | ---------------- | ---------------- | -------------- |
    | 10      | 25462.57         | 30937.40         | +21.5%         |
    | 50      | 77559.46         | 62643.56         | -19.2%         |
    | 100     | 94696.97         | 62866.72         | -33.6%         |
    | 250     | 57926.24         | 46649.04         | -19.5%         |
    | 500     | 25737.82         | 31928.48         | +24.1%         |
    | 1000    | 11687.25         | 25027.11         | +114.2%        |

### **TiDB 低併發吞吐可比 MySQL 快 +290%**

  - [S1-3A：IDC 8 vCPU MySQL Cluster vs TiDB Cluster #1，mysqlslap SELECT 1](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md#%E6%95%B8%E6%93%9A%E5%B0%8D%E7%85%A7%E8%A1%A8s1-3aidc-8-vcpu-mysql-cluster-vs-tidb-cluster-1mysqlslap-select-1)

    | threads | RPS(A) MySQL | RPS(B) TiDB | 差異%(B 對 A) |
    | ------- | ------------- | ----------- | -------------- |
    | 10      | 24962.56      | 97560.98    | +291.0%        |
    | 50      | 84080.72      | 96587.25    | +14.9%         |
    | 100     | 99272.01      | 94132.41    | -5.2%          |
    | 250     | 69573.28      | 46977.76    | -32.5%         |
    | 500     | 24785.19      | 11862.40    | -52.1%         |
    | 1000    | 10648.12      | 7773.63     | -27.0%         |

### **跨區高併發（500 threads）TiDB 在 GCP 可快 +402%**

  - [S3-2-3：TiDB 4 vCPU #1 — IDC+GCP 共同壓測（跨區併發），mysqlslap SELECT 1](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md#%E6%95%B8%E6%93%9A%E5%B0%8D%E7%85%A7%E8%A1%A8s3-2-3tidb-4-vcpu-1--idcgcp-%E5%85%B1%E5%90%8C%E5%A3%93%E6%B8%AC%E8%B7%A8%E5%8D%80%E4%BD%B5%E7%99%BCmysqlslap-select-1)

    | threads | RPS(A) 跨區@IDC | RPS(B) 跨區@GCP | 差異%(B 對 A) |
    | ------- | ---------------- | ---------------- | -------------- |
    | 10      | 97276.26         | 97751.71         | +0.5%          |
    | 50      | 95147.48         | 95268.34         | +0.1%          |
    | 100     | 93370.68         | 92478.42         | -1.0%          |
    | 250     | 46490.00         | 85372.79         | +83.6%         |
    | 500     | 8687.34          | 43649.06         | +402.4%        |
    | 1000    | 8417.74          | 21226.92         | +152.2%        |

### **同區高併發（GCP Local vs IDC）TiDB 可快 +518%**

  - [S4-2-2：TiDB 8 vCPU #1 — IDC+GCP（IDC vs GCP 壓測），mysqlslap SELECT 1](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md#%E6%95%B8%E6%93%9A%E5%B0%8D%E7%85%A7%E8%A1%A8s4-2-2tidb-8-vcpu-1--idcgcpidc-vs-gcp-%E5%A3%93%E6%B8%ACmysqlslap-select-1)

    | threads | RPS(A) IDC Local | RPS(B) GCP Local | 差異%(B 對 A) |
    | ------- | ----------------- | ---------------- | -------------- |
    | 10      | 97181.73          | 98328.42         | +1.2%          |
    | 50      | 96308.19          | 97055.97         | +0.8%          |
    | 100     | 95298.60          | 95510.98         | +0.2%          |
    | 250     | 47199.50          | 91687.04         | +94.2%         |
    | 500     | 10590.23          | 65445.03         | +518.0%        |
    | 1000    | 8412.79           | 37005.06         | +339.9%        |

### **TiDB Scale-Out 成效顯著，可呈接近線性成長**

  - [S2-3B：TiDB Scale-Out（8 vCPU，SQL-heavy vs KV-heavy），mysqlslap SELECT 1](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md#%E6%95%B8%E6%93%9A%E5%B0%8D%E7%85%A7%E8%A1%A8s2-3btidb-scale-out8-vcpusql-heavy-vs-kv-heavymysqlslap-select-1)

    | threads | RPS(A) KV-heavy | RPS(B) SQL-heavy | 差異%(B 對 A) |
    | ------- | ---------------- | ---------------- | -------------- |
    | 10      | 97560.98         | 97560.98         | +0.0%          |
    | 50      | 96587.25         | 72797.86         | -24.6%         |
    | 100     | 94132.41         | 72236.94         | -23.2%         |
    | 250     | 46977.76         | 35928.14         | -23.5%         |
    | 500     | 11862.40         | 10588.73         | -10.7%         |
    | 1000    | 7773.63          | 9223.67          | +18.7%         |

----

## ==== **[Sysbench 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-2.md)** ====
[Back](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#tidb-poc-report)

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
  - **MySQL：單節點、無 RPC → 本地記憶體路徑極快**
  - **TiDB：SQL Layer → RPC → TiKV → RocksDB → Raft → 固定開銷大**

### ** Scale-Up（4 → 8 vCPU）vs Scale-Out（單機 → Cluster） **

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

### ** TiDB Scale-Out（單 SQL 多 KV → 多 SQL 單 KV） **

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

### ** 跨區延遲與寫入競爭（IDC vs IDC+GCP） **

> **MySQL 用「Excpetion＋Retry」換取跨區 TPS；TiDB 用「容忍高延遲」換取零錯誤與一致性。**

### **IDC vs IDC+GCP 雙邊壓測比較 (凸顯跨專線後的叢集效能影響)**

| 類型（16 threads, TPS） | MySQL IDC | MySQL IDC+GCP | 相對 IDC | TiDB IDC | TiDB IDC+GCP | 相對 IDC |
|--------------------|------------|----------------|----------|----------|--------------|----------|
| oltp_read_write    | 770.19     | 842.19         | **+9%**  | 712.43   | 293.28       | **-59%** |
| oltp_write_only    | 786.62     | 928.27         | **+18%** | 1988.00  | 893.76       | **-55%** |

#### 解讀

- MySQL 跨區靠 GCP 節點提供額外 TPS，總量提升但同時伴隨 `ignored errors` 與 retry，實際「成功寫入 TPS」打折，穩定性明顯下降。
- TiDB 跨區受受 RTT + Raft 開銷影響，TPS 明顯下降但保持 `ignored errors = 0`，在高併發與跨區延遲下仍維持一致性與零錯誤行為。

----

## ==== **[Failover Scenario](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-4.md)** ====
[Back](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#tidb-poc-report)

> 目前測試條件尚不嚴謹，待完整腳本與案例設計完成後再更新完整合理 RTO / RPO 數據。

### **SQL 層（TiDB + Tiproxy）**
- 單一 TiDB 停機（[影片](https://youtu.be/DYmA5Ne3nrE)）：故障 0，初步顯示 Tiproxy / TiDB 重新路由或重連於壓測流量下無感；但因僅為簡化流量情境，仍需模擬貼近線上負載後再更新正式數據。
- 同時停所有 TiDB（[影片](https://youtu.be/92OqEJydPP8)）：出現 1 段 28,008 ms 中斷視窗；此為 SQL 層最壞 RTO，恢復後 `rto_seq` 持續運行。

### **PD 層（Leader / Follower 切換）**
- 關閉 follower、leader 或整組 PD（含舊連線、新連線；[影片1](https://youtu.be/irOAXQ6ETKk), [影片2](https://youtu.be/Yi_WWKZMXwo), [影片3](https://youtu.be/h9d9Vumfjhs), [影片4](https://youtu.be/-9gCAvybCG0)）皆無故障段，RTO = 0，證實 PD failover 對 SQL 服務透明。

### **TiKV 層（Region / Store 故障）**
- 寫入與讀取同時監控（[影片](https://youtu.be/bG8OAF1RtC8)）皆觀測到 41,124 ms 的中斷視窗。

----

## ==== **[Chaos engineering for leased-line quality across multiple data centers](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-3.md)**====
[Back](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#tidb-poc-report)

### [現有專線規格](https://hackmd.io/2e84sGrITxuSSmwrROnuTA#%E6%B8%AC%E8%A9%A6%E7%B5%90%E6%9E%9C)

測試結果揭示了系統對於網路延遲（RTT）和頻寬（Bandwidth）瓶頸的敏感度差異，尤其在**高併發（Concurrency 1000）**情境下，對應用程式層（TiProxy/TiDB）和儲存層寫入（TiKV Write）的影響最為顯著。

TiDB 集群的效能受制於網路品質的兩大決定性因素：

*   **高延遲 (RTT)：** 主要衝擊**前端應用層**（TiProxy/TiDB）的高併發處理能力，導致 QPS 顯著下降（90% 左右）。
*   **低頻寬 (Bandwidth)：** 對**後端儲存層的寫入**操作（TiKV Write）影響甚重，使其成為系統在高併發環境下維持運作的最大瓶頸。

#### **一、 網路延遲情境下的效能差異 (RTT 6 / 50 / 100 / 200 ms)**

> TiDB、PD Leader、TiKV 之間逐層注入額外延遲觀察。

| 組件 (Component) | 基準 QPS (Default RTT) | RTT 50 ms QPS | RTT 50 ms 效能下降比例 | RTT 100 ms QPS | RTT 100 ms 效能下降比例 | RTT 200 ms QPS | RTT 200 ms 效能下降比例 |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **TiProxy** | 41631.97 | 10988.21 | 73.69% | 6201.94 | 85.08% | 2608.58 | 93.73% |
| **TiDB** | 38870.17 | 15673.98 | 59.66% | 9707.17 | 75.04% | 5217.21 | 86.58% |
| **PD Leader** | 38709.68 | 33452.27 | 13.60% | 28710.88 | 25.80% | 19373.59 | 49.95% |
| **TiKV Write** | 7874.02 | 5386.00 | 31.60% | 4792.33 | 39.14% | 3024.19 | 61.58% |
| **TiKV Read** | 8086.25 | 8426.97 | -4.21% (上升) | 7915.57 | 2.11% | 8645.53 | -6.92% (上升) |

### RTT 情境分析重點 (Concurrency 1000):

1.  **前端層衝擊：** 在 RTT 200 ms 條件下，TiProxy 的 QPS 衰退最為嚴重，高達 **93.73%**。TiDB 也下降了 **86.58%**。
2.  **寫入效能：** TiKV Write 的 QPS 在 RTT 200 ms 時下降了 **61.58%**。
3.  **讀取穩定性：** TiKV Read 在所有 RTT 測試中表現穩定，效能下降極微或甚至微幅上升。

----

#### **二、 頻寬瓶頸情境下的效能差異 (30 / 10 / 5 Mbps)**

> 此情境針對 TiProxy / TiDB / TiKV 進行限速，期望在低頻寬下仍維持運作，並同步觀察 TiKV `region` pending 情況。

| 組件 (Component) | 基準 QPS (Default) | 10 Mbps QPS | 10 Mbps 效能下降比例 | 5 Mbps QPS | 5 Mbps 效能下降比例 |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **TiProxy** | 41631.97 | 7733.55 | 81.42% | 6697.62 | 83.92% |
| **TiDB** | 38870.17 | 8161.27 | 79.01% | 6117.33 | 84.24% |
| **PD Leader** | 38709.68 | 8390.43 | 78.33% | 5984.32 | 84.55% |
| **TiKV Write** | 7874.02 | 6109.98 | 22.39% | 814.77 | 89.65% |
| **TiKV Read** | 8086.25 | 8042.90 | 0.54% | 7853.40 | 2.88% |

### 頻寬情境分析重點 (Concurrency 1000):

1.  **寫入瓶頸：** 當頻寬限制到 5 Mbps 時，TiKV Write 的 QPS 暴跌 **89.65%** ，遠高於其他組件在此情境下的跌幅，這使其成為高併發低頻寬下的最大瓶頸。
2.  **前端層一致性：** 在 10 Mbps 條件下，TiProxy、TiDB 和 PD Leader 的 QPS 下降比例都集中在 78% 至 81% 之間。
3.  **讀取穩定性：** TiKV Read 在 5 Mbps 頻寬限制下，效能下降僅 **2.88%** ，確認讀取操作對於頻寬的敏感度極低。

----

## ==== **[Staging AC-API 整合測試紀錄](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-5.md)** ====
[Back](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#tidb-poc-report)

### 流量架構示意圖

![image](https://hackmd.io/_uploads/SJF-xiwGWg.png)

### Staging AC 基礎量 壓力測試 觀測總結

在相同壓測來源，兩者於 CPU、Network、IO、QPS、Latency 呈現明顯差異，可歸納如下：

| 效能指標 | ProxySQL + MariaDB (P+M) 集中式數據 | TiDB Cluster (TiDB) 分佈式數據 | P+M 相較 TiDB 的差異比例 (約略值) | 關鍵差異點 |
| :--- | :--- | :--- | :--- | :--- |
| **CPU 負載 (儲存層)** | MariaDB MAX **11.5%** | TiKV MAX **5.8%** | P+M 核心節點 CPU 負載約高 **1.98 倍** | MariaDB 單點瓶頸在集中架構呈現較明顯。 |
| **I/O 寫入 (儲存層)** | MariaDB Disk Write **1.9 MB/s** | TiKV sdb throughput current **316.00 KB/s** | P+M I/O 寫入集中度約高 **6.0 倍** | TiDB 將 I/O 寫入分散到 TiKV 節點。 |
| **網路流量 (Outbound)** | ProxySQL Outbound AVG **11.64 MB/s** | TiDB/Proxy/PD Outbound current **587 KB/s** | 參考數據 | Outbound 去 NULL 與正確回應的差異。 |
| **P+M 查詢量 (Client Questions)** | ProxySQL 接收 AVG **5.85K** ; MariaDB 處理 AVG **2K** | TiDB Select QPS 113 | P+M 核心處理量約高 17.7 倍 | MariaDB 實際查詢量: (2K) 約為 TiDB Select QPS (113) 的 17.7 倍。但負載僅多 TiDB 1.98 倍差異。 |

----

## ==== **Final** ====
[Back](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md#tidb-poc-report)

### 性能差異與選型建議

#### 主要性能差異總結

| 特性 | MySQL (傳統單體) | TiDB (分散式架構) | 導入啟示 |
| :--- | :--- | :--- | :--- |
| **單機基準效能** | **全面領先 TiDB 40%～80%** 。路徑極快（單節點、無 RPC）。 | 單機效能較差，因固定開銷大（SQL Layer → RPC → TiKV → RocksDB → Raft]。 | 適用於追求絕對單機效能的場景。 |
| **垂直擴展（Scale-Up）** | 無效益/負向（-3.6%～-10%），受限於 InnoDB 競爭瓶頸。 | **明顯有效（+20%～+41%）** ，特別是 Mixed 負載最敏感。 | TiDB 屬 CPU-sensitive，擴容 CPU 可有效提升性能。 |
| **水平擴展（Scale-Out）** | 難以實現，ProxySQL 僅能分流，非擴容。 | **成效顯著** ，可呈接近線性成長，讀寫負載可提升 6% 至 25.5%。 | 這是 TiDB 的核心優勢，適合處理高併發和大規模數據。 |

#### MySQL 優勢突出 ; 跨專線短板明顯

* **MySQL 單機優勢突出：** 在單節點基準測試中，MySQL 在讀寫操作（`read_write`）的 TPS 比 TiDB 高 **59%** 。
* **跨專線短板明顯：**
  * MySQL 在跨區中併發（50～250 threads）測試中容易掉速（-7%〜-33%）。例如在 100 threads 時，RPS 下降 **33.6%** 。
  * 雖然 MySQL 跨區寫入時，總 TPS 可能提升 (+9% 至 +18%)，但這伴隨著 `ignored errors` 與 retry 的發生 ，**穩定性明顯下降** 。

#### TiDB 分散式儲存與穩定性優勢，巨大資料量體合適

* **核心價值**

  * **跨區高穩定度：** TiDB 跨區穩定度高，在 10 至 250 threads 之間僅有 **±1%〜2% 的波動** 。
  * **一致性優先：** 在跨區延遲環境下，TiDB 犧牲部分 TPS（-55%至-59%），但能保持 `ignored errors = 0`，**嚴格維持一致性與零錯誤行為** 。
  * **高併發處理能力：** 在跨區高併發情境（500 threads），TiDB 在 GCP 可比 IDC 快 **+402.4%** 。同區高併發情境，TiDB 可快 **+518%** 。

#### 性能瓶頸 (網路敏感性)

分散式架構的性能極度依賴網路品質：

* **高延遲 (RTT)：** 主要衝擊**前端應用層**（TiProxy/TiDB）的高併發處理能力 。在 RTT 200 ms 條件下，TiProxy 的 QPS 衰退高達 **93.73%** ，TiDB 也衰退 **86.58%** 。
* **低頻寬 (Bandwidth)：** 主要衝擊**後端儲存層的寫入**操作（TiKV Write）。當頻寬限制到 5 Mbps 時，TiKV Write 的 QPS 暴跌 **89.65%** ，使其成為高併發低頻寬下的最大瓶頸。
* **讀取穩定性：** TiKV Read 在所有 RTT (單純 Insert Into 測試情境下) 測試中表現穩定 ，且在 5 Mbps 頻寬限制下，效能下降僅 **2.88%** 。

#### 數據壓縮比分析

- MySQL：
  - Table size 約 2.14 GB 資料 + 0.15 GB 索引 ≈ 2.29 GB，多為單一 .ibd 檔案。
  - 實際磁碟空間 ~2.3 GB（du /data/mysql/data/sbtest/）。
- TiDB：
  - information_schema 展示 sbtest1 只有 152.6 MB 資料 + 76.3 MB 索引 ≈ 228.9 MB，整個 sbtest schema 也只有 228.9 MB。
  - TiKV/RocksDB 實體檔案分散在多個 SST 檔，總佔用約 2.0 GB（但包含所有 Region 的 metadata 與空間 placeholder）。
- 結論：
TiDB 在 OLTP 表的邏輯佔用率大幅優於 MySQL（約 10:1），來源在於 RocksDB 的列式壓縮與 Region 分片導致的高效儲存；
即便底層資料切割進多個 SST，對應的物理總量仍略小於 MySQL，展現 TiDB 在壓縮比與儲存密度上的優勢，對需要節省容量或加快備份/傳輸的場景特別有利。

----

### 未來維運的幾個已知可能風險

## Public Mirror Site 不穩定 ; 且為 tiup 前置既定程序

![image](https://hackmd.io/_uploads/Sk-6RkOzbx.png)
![image](https://hackmd.io/_uploads/ByTC0kOzWg.png)
![image](https://hackmd.io/_uploads/rJuyyxOMZx.png)

![](https://codimd.104.com.tw/image/s3/key/n2e8k4ys4wncbr1f6jjzx9qgn.png)
![](https://codimd.104.com.tw/image/s3/key/tuz5q2sa75kjvuyady3skxmyq.png)
![](https://codimd.104.com.tw/image/s3/key/rru76wuzww9lemqvf2elhxisp.png)

```
date ; tiup cluster display tidb-demo
Checking updates for component cluster... Timedout (after 2s)
Error: fetch /timestamp.json from mirror(https://tiup-mirrors.pingcap.com) failed: download from https://tiup-mirrors.pingcap.com/timestamp.json failed: Get "https://tiup-mirrors.pingcap.com/timestamp.json": EOF
```

確認 mirror 來源
```
wn.lin@2740-mac13 ~ % date ; bash test.sh
2025年11月 7日 星期五 14時12分20秒 CST
DNS_SERVER,IP,COUNTRY,REGION
10.0.1.5,128.1.102.113,Taiwan,Kaohsiung
10.0.1.5,107.155.58.204,Taiwan,Taipei City
10.0.1.5,175.99.198.25,Taiwan,Taiwan
10.0.1.5,23.236.104.178,Taiwan,Taipei City
10.0.1.5,107.155.58.219,Taiwan,Taipei City
10.0.1.5,128.1.102.212,Taiwan,Kaohsiung
168.95.1.1,23.236.104.178,Taiwan,Taipei City
168.95.1.1,175.99.198.25,Taiwan,Taiwan
168.95.1.1,107.155.58.219,Taiwan,Taipei City
168.95.1.1,128.1.102.113,Taiwan,Kaohsiung
168.95.1.1,128.1.102.212,Taiwan,Kaohsiung
168.95.1.1,107.155.58.204,Taiwan,Taipei City
8.8.8.8,43.152.2.144,United States,Florida
8.8.8.8,43.152.2.154,United States,Florida
8.8.8.8,43.174.143.248,United States,New Mexico
8.8.8.8,43.175.170.163,United States,New Mexico
8.8.8.8,43.152.48.139,United States,Texas
8.8.8.8,43.159.79.166,United States,New Mexico
```

- [Manifest format and repository layout 說明](https://github.com/pingcap/tiup/blob/master/doc/design/manifest.md)

![image](https://hackmd.io/_uploads/r11Ikluf-g.png)
![](https://codimd.104.com.tw/image/s3/key/gjnlfgp0bqj69e633uw3l78yp.png)

- Solution: [Create a Private Mirror](https://docs.pingcap.com/tidb/stable/tiup-mirror/)

----

### 總結與未來規劃

- 下一階段的分散式資料庫架構投資方向 ; [Reference](https://landscape.cncf.io/guide#app-definition-and-development--database)
![](https://codimd.104.com.tw/image/s3/key/uashd412g1c34ylela5gpbffp.png)
  - [TiKV](https://github.com/tikv/tikv)
  - [Vitess](https://github.com/vitessio/vitess)
  - 或直接參考其他已完成的實踐 [TiDB集群可用区级别改造的探索与实践](https://mp.weixin.qq.com/s/c_Kh6mPSVvwvByoRyNBTyw)

![](https://mmbiz.qpic.cn/sz_mmbiz_png/DEWdgLnJps5XkW83iatFMUZXicxd881dAiaAVEiciasLcRpKMhPut7JyfbMaPbricrv0yO9gk5XOwHXJfRlkckaYD0mA/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=6)

![](https://mmbiz.qpic.cn/sz_mmbiz_png/DEWdgLnJps5XkW83iatFMUZXicxd881dAiaCAicqj0fDUicosZlVW9VYtoeVib902l0JUogqKuL2jKou17GVwicQelXsA/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=11)

![](https://mmbiz.qpic.cn/sz_mmbiz_png/DEWdgLnJps5XkW83iatFMUZXicxd881dAiaOZx4E7Jn7cUcYdgbqJfw77bibKF5siasHlV1kp8Qmn0BmVjtwx9H9aXQ/640?wx_fmt=png&tp=webp&wxfrom=5&wx_lazy=1#imgIndex=12)

- 分散式資料庫的應用在台灣普及率普遍不高 ; 如果需要導入，我們需要哪些資源？
  - [TiDB 2024 年度报告：增长的故事](https://cn.pingcap.com/company-activity/tidb-2024-annual-report-growth-story/) & [Customer Stories](https://www.pingcap.com/customers/)
  - [Pricing](https://www.pingcap.com/pricing/)
![](https://codimd.104.com.tw/image/s3/key/g34kv5tyrq3rd3cglwuz4t2rk.png)
  - Contact: [Howard Cheng (Market Strategist) @ SG](https://www.linkedin.com/in/cheng-hao/) & [Andy Hsu (Key Account Sales) @ TW](https://www.linkedin.com/in/andy-hsu-206836114/)