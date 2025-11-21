# TiDB Intro

----

## ==== **[RPS 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md)**====

- **MySQL 跨區中併發易掉速（-7%〜-33%）**
- **TiDB 低併發吞吐可比 MySQL 快 +290%**

  - [S1-3A：IDC 8 vCPU MySQL Cluster vs TiDB Cluster #1，mysqlslap SELECT 1](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-1.md#%E6%95%B8%E6%93%9A%E5%B0%8D%E7%85%A7%E8%A1%A8s1-3aidc-8-vcpu-mysql-cluster-vs-tidb-cluster-1mysqlslap-select-1)

    | threads | RPS(A) MySQL | RPS(B) TiDB | 差異%(B 對 A) |
    | ------- | ------------- | ----------- | -------------- |
    | 10      | 24962.56      | 97560.98    | +291.0%        |
    | 50      | 84080.72      | 96587.25    | +14.9%         |
    | 100     | 99272.01      | 94132.41    | -5.2%          |
    | 250     | 69573.28      | 46977.76    | -32.5%         |
    | 500     | 24785.19      | 11862.40    | -52.1%         |
    | 1000    | 10648.12      | 7773.63     | -27.0%         |

- **跨區高併發（500 threads）TiDB 在 GCP 可快 +402%**
- **同區高併發（GCP Local vs IDC）TiDB 可快 +518%**
- **TiDB 跨區穩定度極高：10〜250 threads 僅 ±1%〜2% 波動**
- **TiDB Scale-Out 成效顯著，可呈接近線性成長**
- **跨區併發時，負載會自然傾向 TiDB 表現較佳的一側（多為 GCP）**

----

## ==== **[Sysbench 效能對照解析](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report-2.md)** ====

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

### **RPO（Recovery Point Objective）/ RTO（Recovery Time Objective）**
- 根據目前 `rto_seq` Heartbeat 表推算，紀錄皆為 0；但測試條件尚不嚴謹，待完整腳本與案例設計完成後再更新完整合理數據。

### **SQL 層（TiDB + Tiproxy）**
- 單一 TiDB 停機（[影片](https://youtu.be/DYmA5Ne3nrE)）：故障 0，初步顯示 Tiproxy / TiDB 重新路由或重連於壓測流量下無感；但因僅為簡化流量情境，仍需模擬貼近線上負載後再更新正式數據。
- 同時停所有 TiDB（[影片](https://youtu.be/92OqEJydPP8)）：出現 1 段 28,008 ms 中斷視窗；此為 SQL 層最壞 RTO，恢復後 `rto_seq` 持續運行。

### **PD 層（Leader / Follower 切換）**
- 關閉 follower、leader 或整組 PD（含舊連線、新連線；[影片1](https://youtu.be/irOAXQ6ETKk), [影片2](https://youtu.be/Yi_WWKZMXwo), [影片3](https://youtu.be/h9d9Vumfjhs), [影片4](https://youtu.be/-9gCAvybCG0)）皆無故障段，RTO = 0，證實 PD failover 對 SQL 服務透明。

### **TiKV 層（Region / Store 故障）**
- 寫入與讀取同時監控（[影片](https://youtu.be/bG8OAF1RtC8)）皆觀測到 41,124 ms 的中斷視窗。

----

## ==== **{FIXME}[Chaos engineering for leased-line quality across multiple data centers](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md)**====

### [現有專線規格](https://hackmd.io/2e84sGrITxuSSmwrROnuTA#%E6%B8%AC%E8%A9%A6%E7%B5%90%E6%9E%9C)

----

## ==== **{FIXME}[Staging AC-API 整合測試紀錄](https://github.com/heavenruler/dba_career/blob/master/poc/tidb/report/report.md)** ====

----

## ==== **Final

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

