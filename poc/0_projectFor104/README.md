# [分散式資料庫架構 PoC](https://104corp.atlassian.net/browse/ITDBA-3596)

```
opencode -s ses_28f349b65ffesqMOs3ScraWUt4
```

## 1. PoC 目標

本 PoC 用於驗證分散式資料庫架構是否可滿足 104Corp 既有業務系統需求。

北極星目標：分散式資料庫部署不應因任何因素（例如停機維護）導致服務中止或暫停。

- 可用性：單點故障時可持續提供服務
- 擴充性：可支援資料量與流量成長
- 一致性：確認交易、複寫與故障切換行為
- 維運性：備援、監控、告警、備份與還原流程可操作
- 成本可行性：評估導入與營運成本是否合理

## 2. 文件結構

### 2.1 需求與範圍

- 業務場景與痛點
- RTO / RPO 目標
- 吞吐量、延遲、併發需求
- 可用性與資料一致性要求
- 成功判定條件
- 本次 PoC 驗證範圍
- 不納入項目
- 既有系統限制
- 版本、硬體、網路與授權假設

### 2.2 架構選型

- 候選方案比較
- 優缺點、風險、導入複雜度
- 與現況整合方式
- 選型理由

### 2.2.1 Survey 評估面向

- 系統定位
- Multi-Region 寫入模型
- 衝突處理機制
- MVCC 與 Read 行為
- Failover / HA
- 擴展與 Hotspot
- DDL / Schema 行為
- 運維能力
- 成本模型

#### 1. 系統定位

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| DB 類型 | NewSQL / Distributed SQL | NewSQL / Distributed SQL | Sharding middleware |
| 一致性模型 | 強一致交易，預設 Snapshot Isolation | 強一致交易，YSQL 可提供 Serializable / RC | 單 shard 依 MySQL，一致性不延伸為全域分散式模型 |
| Transaction 模型 | Percolator + 2PC，底層 Region 用 Raft | Distributed transaction + DocDB intents + Raft | 單 shard local transaction，跨 shard 由 VTGate 協調 |
| Timestamp 機制 | PD TSO | HLC / Hybrid Time | 無 global timestamp |

#### 2. Multi-Region 寫入模型

- TiDB：可由任一 region 的 TiDB server 收寫入，但實際序列化點在對應 Region leader。
- YugabyteDB：可由任一 region 的 YSQL gateway 收寫入，但實際序列化點在 tablet leader 與 transaction status tablet。
- Vitess：寫入最終仍落在單一 MySQL shard primary，不適合作為 multi-region active-active database。
- TiDB / YugabyteDB 的 commit latency 主要來自跨 region quorum、leader RTT、transaction 協調成本。
- Vitess 的 commit latency 主要來自 shard primary RTT，跨 shard 僅能透過額外協調補強 atomicity。

#### 3. 衝突處理機制

- TiDB：以 MVCC + lock / write conflict 為主，衝突通常以 abort / retry 解決。
- YugabyteDB：以 DocDB intents + conflict manager 處理，常見 transaction restart / serialization failure。
- Vitess：單 shard 衝突行為基本等同 MySQL InnoDB row lock / deadlock；跨 shard 無全域衝突管理。
- 三者皆非 last-write-win 預設模型；若出現 last-write-win，多半是應用層自行設計結果。

#### 4. MVCC 與 Read 行為

- TiDB：transaction-level MVCC，支援 follower read、stale read、read-your-write。
- YugabyteDB：transaction-level MVCC，支援強一致讀與 follower read 類能力。
- Vitess：依底層 MySQL 提供讀行為，沒有全域 MVCC 與全域 stale read 模型。
- TiDB follower read 為強一致讀，但需經過 `ReadIndex`，延遲會高於 leader read。
- Vitess 若讀 replica，本質上是在觀察 replication lag，而非 distributed SQL follower read。

#### 5. Failover / HA

- TiDB：TiKV Region 以 Raft 選主，PD 自身也具 HA。
- YugabyteDB：tablet 以 Raft 選主，metadata 服務亦具高可用架構。
- Vitess：通常搭配 VTOrc / Orchestrator 處理 MySQL primary failover。
- TiDB / YugabyteDB 單節點故障常見可在秒級恢復，但實際 RTO 仍依 client retry 與部署方式而定。
- Region-level failover 是否可寫，取決於 replica placement 與 quorum 是否仍存在。

#### 6. 擴展與 Hotspot

- TiDB 切分單位為 Region，YugabyteDB 為 Tablet，Vitess 為 Shard。
- TiDB / YugabyteDB 可自動 split / rebalance；Vitess 偏向平台操作式 reshard。
- 三者都無法真正解決單一 hot key / hot row 問題。
- 同一 key 高併發寫入時，最終都會回到單一 leader / primary 序列化瓶頸。

#### 7. DDL / Schema 行為

- TiDB：online DDL 能力強，但 `ADD INDEX` 與熱寫入欄位並行時仍可能出現 write conflict。
- YugabyteDB：多數 schema change 可線上執行，但需逐項驗證對 workload 的影響。
- Vitess：online schema change 是強項，特別適合大規模 MySQL 分片環境。
- 若以 DBaaS 平台角度看，Vitess 與 TiDB 在不停機 schema change 的產品化成熟度較突出。

#### 8. 運維能力

- TiDB：TiDB Operator、backup / restore / PITR、Dashboard 與監控體系成熟。
- YugabyteDB：具 Operator、backup / restore / PITR、Prometheus / Grafana / ASH 類觀測能力。
- Vitess：可做平台化運維，但需同時管理 vtgate / vttablet / MySQL / topo，複雜度最高。
- 若目標是 DBaaS，一體化產品能力上 TiDB / YugabyteDB 通常比 Vitess 更直接。

#### 9. 成本模型

- TiDB：成本主要來自 TiKV 副本數、SSD IOPS、跨 region 網路流量。
- YugabyteDB：成本同樣集中在同步複寫帶來的 network 與 storage 成本。
- Vitess：基礎軟體成本可低，但平台工程與營運人力成本最高。
- 真正影響 multi-region 成本的關鍵通常不是 CPU，而是 cross-region network、replica 數量與儲存 IO。

#### Survey 初步結論

- 若目標是 Multi-Region Active-Active 技術選型，YugabyteDB 最接近 Spanner 類問題模型。
- 若目標是 MySQL 生態延伸至 distributed SQL 並兼顧產品成熟度，TiDB 為主要候選。
- 若目標是 MySQL 分片平台 / DBaaS，而非真正 distributed SQL，Vitess 才是合理候選。

### 2.3 架構與環境設計

- 邏輯架構圖與實體部署圖
- 節點角色與責任
- 寫入 / 讀取 / 複寫路徑
- 故障切換流程
- 主機規格、OS、儲存配置
- 網路 / 網段相關規劃
- 容量估算與成長預留

### 2.4 測試與驗證

- 功能測試
- TPC-C 壓力測試
- 穩定性測試
- 故障注入與切換測試
- 備份還原測試
- 驗收門檻

### 2.5 維運規劃

- 備份策略設計 & 規劃

### 2.6 風險與結論

- 風險清單
- 已知限制
- 待解議題
- 對應緩解措施
- 測試結果摘要
- 達標 / 未達標項目
- 是否建議正式導入
- 導入前必要補強事項
