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

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| 是否支援 multi-region 同時寫入同一筆資料 | 可，任一 region 的 TiDB server 都可收寫入，但真正序列化點在該 row 所在 Region leader | 可，任一 region 的 YSQL gateway 可收寫入，但真正序列化點在 tablet leader / txn status tablet | 不建議視為可；同一 row 最終只會落到單一 shard primary |
| commit path | 取得 TSO -> prewrite primary/secondary keys -> commit primary -> async/parallel finalize；每個 key 所在 Region 需 Raft quorum | txn record / intents -> write to involved tablets -> Raft majority replicate -> commit/apply；跨 tablet txn 需協調 | 單 shard 走 MySQL commit；跨 shard 需 VTGate 協調，`TWOPC` 才有 atomic commit |
| 是否跨 region quorum | 若 replica / leader 分散於多 region，會跨 region quorum | 會，尤其 RF=3 且跨 3 regions 時，leader 需拿 majority | MySQL shard 本身若跨區 semi-sync 可跨區；但不是 Vitess 原生分散式提交 |
| commit latency 來源 | PD TSO、primary key 所在 leader RTT、各 Region quorum RTT、2PC 協調 | tablet leader RTT、txn status tablet RTT、各 involved tablet majority RTT、HLC safe time | shard primary RTT；若跨 shard 再加 VTGate 協調與各 shard primary RTT |
| 是否依賴 global time ordering | 是，依賴 TSO | 是，依賴 HLC / hybrid time | 否，無全域 ordering |

#### 3. 衝突處理機制

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| 衝突 detection | MVCC + lock / write conflict，Percolator prewrite 時檢查 | DocDB intents + conflict manager + MVCC；可能出現 serialization failure / restart | 由 InnoDB row lock / gap lock / MVCC 檢查；跨 shard 無全域衝突管理 |
| 衝突 resolution | abort / retry 為主；write conflict 直接失敗或 client retry | abort / restart / retry；YSQL 常見 `could not serialize access` / restart read required | 單 shard 為 MySQL lock wait / deadlock rollback；跨 shard 由各 shard 個別決定 |
| deterministic ordering | 由 TSO + lock key 順序間接形成 | 由 hybrid time + txn priority / conflict resolution | 無全域 deterministic ordering |
| 是否存在 last-write-win | 否 | 否 | 非系統級；僅應用層自行以 timestamp update 才會變相出現 |

#### 4. MVCC 與 Read 行為

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| MVCC 層級 | transaction-level snapshot | transaction-level snapshot | 依底層 MySQL；無全域 MVCC |
| follower read | 有，強一致 follower read，但需 `ReadIndex` | 有 | 無原生 distributed follower read；通常僅讀 replica |
| stale read | 有，`AS OF TIMESTAMP` / bounded staleness | 有，follower reads / read replica / time-travel 類能力可驗證 | 無全域 stale read；僅能讀 replica 延遲資料 |
| read-your-write | 有，同 transaction / session 正常 | 有 | 單 shard 有；跨 shard 不保證全域一致視圖 |
| read consistency 等級 | 強一致、follower strong、stale snapshot | 強一致、serializable / RC、follower / stale | primary read 強一致；replica read 為最終一致 |

#### 5. Failover / HA

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| leader election 機制 | TiKV Region 用 Raft；PD 也用 Raft | Tablet Raft leader election；master metadata 也有 HA | MySQL primary failover 常搭配 VTOrc / Orchestrator；Vitess 負責路由與拓樸 |
| failover 時間（RTO） | 單 Region leader failover 常見約 `3-10s` | 單 tablet / shard leader failover 常見約 `3-10s` | 依 MySQL HA 設定，常見 `5-30s` |
| 是否支援 region-level failover | 有條件支援，前提是 replica placement 讓 quorum 尚存 | 有條件支援，geo-placement 正確時可 | 取決於各 shard MySQL 複寫拓樸；非原生整體 region failover |

#### 6. 擴展與 Hotspot

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| shard / tablet / region 切分方式 | Region，key-range，自動 split / merge / rebalance | Tablet，支援 hash / range sharding，自動 split / rebalance | Shard，預先定義或透過 resharding 調整 |
| hotspot 是否會自動 re-balance | 可 rebalance，但同一 key 熱點無法被切散 | 可 rebalance / split，但同一 key 熱點無法被切散 | shard 級可分流，但同一 row 熱點仍集中於單一 primary |
| 同一 key 高併發寫入行為 | leader 單點序列化，衝突率與延遲快速上升 | tablet leader 單點序列化，可能出現 restart storm | MySQL row lock hot row，吞吐最早撞牆 |

#### 7. DDL / Schema 行為

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| online DDL 能力 | 強 | 中高 | 強 |
| schema change 是否 blocking | 一般低，但 add index / backfill 期間仍需觀察 workload 影響 | 多數可線上執行，但仍需逐項驗證 | 可用 Online DDL 降低 blocking |
| metadata lock 風險 | 低於傳統 MySQL | 受 PG catalog 行為影響，需驗證 | 可降低 MySQL metadata lock 風險，是強項 |

#### 8. 運維能力

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| 是否有 Operator（K8s） | 有，成熟 | 有，成熟 | 有，但整體運維複雜度較高 |
| backup / restore / PITR | 有 | 有 | 可做，但較依賴 MySQL 與 Vitess workflow 組合 |
| rolling upgrade 能力 | 有 | 有 | 可行，但需分 vtgate / vttablet / mysql / topo 規劃 |
| observability（metrics / tracing） | Prometheus / Grafana / TiDB Dashboard 完整 | Prometheus / Grafana / ASH / pg stats 類能力完整 | 指標充足，但需同時觀察 vtgate / vttablet / mysql / replication |

#### 9. 成本模型

| 項目 | TiDB | YugabyteDB | Vitess |
| --- | --- | --- | --- |
| compute / storage 是否分離 | SQL 層與存儲層分離，但 TiKV 仍為 shared-nothing 儲存節點 | 可支援更明顯的 compute / storage decouple，需視版本與部署模式確認 | vtgate 與 MySQL 可分開擴，但 storage 仍在 MySQL shard |
| scale out 模型 | 加 TiDB / TiKV / TiFlash | 加 tserver / read replica / gateway | 加 shard / MySQL replica / vtgate |
| 成本主要來自哪裡（IO / network） | 跨區網路、Raft 複寫、SSD IOPS | 跨區網路、Raft 複寫、SSD IOPS | MySQL primary / replica 數量、跨區複寫與平台營運人力 |

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
