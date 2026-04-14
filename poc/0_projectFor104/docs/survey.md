# 分散式資料庫 Survey 評估面向

候選系統：TiDB、YugabyteDB、Vitess

## 1. 系統定位

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| DB 類型 | NewSQL / Distributed SQL | NewSQL / Distributed SQL | Sharding middleware | 以 (O) self-managed / (X) K8s 部署為前提 |
| 一致性模型 | 強一致交易，預設 Snapshot Isolation | 強一致交易，YSQL 可提供 Serializable / RC | 單 shard 依 MySQL，一致性不延伸為全域分散式模型 | 需確認實際採用 isolation level 與 client 設定 |
| Transaction 模型 | Percolator + 2PC，底層 Region 用 Raft | Distributed transaction + DocDB intents + Raft | 單 shard local transaction，跨 shard 由 VTGate 協調 | Vitess 是否啟用跨 shard 交易需在 PoC 確認 |
| Timestamp 機制 | PD TSO | HLC / Hybrid Time | 無 global timestamp | 以目前主流版本與官方預設行為為假設 |

## 2. Multi-Region 寫入模型

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| 是否支援 multi-region 同時寫入同一筆資料 | 可，任一 region 的 TiDB server 都可收寫入，但真正序列化點在該 row 所在 Region leader | 可，任一 region 的 YSQL gateway 可收寫入，但真正序列化點在 tablet leader / txn status tablet | 不建議視為可；同一 row 最終只會落到單一 shard primary | 需用同一 row cross-region concurrent update 驗證 |
| commit path | 取得 TSO -> prewrite primary/secondary keys -> commit primary -> async/parallel finalize；每個 key 所在 Region 需 Raft quorum | txn record / intents -> write to involved tablets -> Raft majority replicate -> commit/apply；跨 tablet txn 需協調 | 單 shard 走 MySQL commit；跨 shard 需 VTGate 協調，`TWOPC` 才有 atomic commit | 需搭配 tracing / statement metrics 驗證實際 path |
| 是否跨 region quorum | 若 replica / leader 分散於多 region，會跨 region quorum | 會，尤其 RF=3 且跨 3 regions 時，leader 需拿 majority | MySQL shard 本身若跨區 semi-sync 可跨區；但不是 Vitess 原生分散式提交 | 假設 RF=3 且節點分散於 3 regions |
| commit latency 來源 | PD TSO、primary key 所在 leader RTT、各 Region quorum RTT、2PC 協調 | tablet leader RTT、txn status tablet RTT、各 involved tablet majority RTT、HLC safe time | shard primary RTT；若跨 shard 再加 VTGate 協調與各 shard primary RTT | 需收 p95 commit latency 與 cross-region RTT 對照 |
| 是否依賴 global time ordering | 是，依賴 TSO | 是，依賴 HLC / hybrid time | 否，無全域 ordering | 以官方架構行為為前提 |

## 3. 衝突處理機制

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| 衝突 detection | MVCC + lock / write conflict，Percolator prewrite 時檢查 | DocDB intents + conflict manager + MVCC；可能出現 serialization failure / restart | 由 InnoDB row lock / gap lock / MVCC 檢查；跨 shard 無全域衝突管理 | 需以同一 row 高併發 update 驗證錯誤型態 |
| 衝突 resolution | abort / retry 為主；write conflict 直接失敗或 client retry | abort / restart / retry；YSQL 常見 `could not serialize access` / restart read required | 單 shard 為 MySQL lock wait / deadlock rollback；跨 shard 由各 shard 個別決定 | 需統計 retry count / abort rate |
| deterministic ordering | 由 TSO + lock key 順序間接形成 | 由 hybrid time + txn priority / conflict resolution | 無全域 deterministic ordering | 細節可能因版本差異略有不同 |
| 是否存在 last-write-win | 否 | 否 | 非系統級；僅應用層自行以 timestamp update 才會變相出現 | 假設未自行實作應用層 LWW |

## 4. MVCC 與 Read 行為

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| MVCC 層級 | transaction-level snapshot | transaction-level snapshot | 依底層 MySQL；無全域 MVCC | 以預設 transaction 模式為前提 |
| follower read | 有，強一致 follower read，但需 `ReadIndex` | 有 | 無原生 distributed follower read；通常僅讀 replica | 需量測 follower read latency 與 staleness |
| stale read | 有，`AS OF TIMESTAMP` / bounded staleness | 有，follower reads / read replica / time-travel 類能力可驗證 | 無全域 stale read；僅能讀 replica 延遲資料 | YugabyteDB 需依實際 API / 版本確認操作方式 |
| read-your-write | 有，同 transaction / session 正常 | 有 | 單 shard 有；跨 shard 不保證全域一致視圖 | 需以 session 連線模型實測 |
| read consistency 等級 | 強一致、follower strong、stale snapshot | 強一致、serializable / RC、follower / stale | primary read 強一致；replica read 為最終一致 | Vitess 需區分 primary read 與 replica read 路徑 |

## 5. Failover / HA

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| leader election 機制 | TiKV Region 用 Raft；PD 也用 Raft | Tablet Raft leader election；master metadata 也有 HA | MySQL primary failover 常搭配 VTOrc / Orchestrator；Vitess 負責路由與拓樸 | 假設採用官方建議 HA 拓樸 |
| failover 時間（RTO） | 單 Region leader failover 常見約 `3-10s` | 單 tablet / shard leader failover 常見約 `3-10s` | 依 MySQL HA 設定，常見 `5-30s` | 實際 RTO 需以 kill leader / node failure 驗證 |
| 是否支援 region-level failover | 有條件支援，前提是 replica placement 讓 quorum 尚存 | 有條件支援，geo-placement 正確時可 | 取決於各 shard MySQL 複寫拓樸；非原生整體 region failover | 需預先定義 region failure 情境與 quorum 條件 |

## 6. 擴展與 Hotspot

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| shard / tablet / region 切分方式 | Region，key-range，自動 split / merge / rebalance | Tablet，支援 hash / range sharding，自動 split / rebalance | Shard，預先定義或透過 resharding 調整 | 需確認是否使用預設切分策略 |
| hotspot 是否會自動 re-balance | 可 rebalance，但同一 key 熱點無法被切散 | 可 rebalance / split，但同一 key 熱點無法被切散 | shard 級可分流，但同一 row 熱點仍集中於單一 primary | 需設計 hot row / hot partition workload 驗證 |
| 同一 key 高併發寫入行為 | leader 單點序列化，衝突率與延遲快速上升 | tablet leader 單點序列化，可能出現 restart storm | MySQL row lock hot row，吞吐最早撞牆 | 需量測 conflict rate 與 p95 latency |

## 7. DDL / Schema 行為

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| online DDL 能力 | 強 | 中高 | 強 | 需以 add column / add index / modify schema 實測 |
| schema change 是否 blocking | 一般低，但 add index / backfill 期間仍需觀察 workload 影響 | 多數可線上執行，但仍需逐項驗證 | 可用 Online DDL 降低 blocking | 需搭配持續寫入 workload 驗證 |
| metadata lock 風險 | 低於傳統 MySQL | 受 PG catalog 行為影響，需驗證 | 可降低 MySQL metadata lock 風險，是強項 | 需實測 DDL 對長交易與高併發讀寫影響 |

## 8. 運維能力

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| 是否有 Operator（K8s） | 有，成熟 | 有，成熟 | 有，但整體運維複雜度較高 | 以 K8s 作為主要 PoC 平台假設 |
| backup / restore / PITR | 有 | 有 | 可做，但較依賴 MySQL 與 Vitess workflow 組合 | 需驗證備份視窗、還原時間與一致性 |
| rolling upgrade 能力 | 有 | 有 | 可行，但需分 vtgate / vttablet / mysql / topo 規劃 | 需確認升級期間是否影響寫入 SLA |
| observability（metrics / tracing） | Prometheus / Grafana / TiDB Dashboard 完整 | Prometheus / Grafana / ASH / pg stats 類能力完整 | 指標充足，但需同時觀察 vtgate / vttablet / mysql / replication | 需先定義 PoC 必收 metrics 清單 |

## 9. 成本模型

| 項目 | TiDB | YugabyteDB | Vitess | 待驗證 / 假設 |
| --- | --- | --- | --- | --- |
| compute / storage 是否分離 | SQL 層與存儲層分離，但 TiKV 仍為 shared-nothing 儲存節點 | 可支援更明顯的 compute / storage decouple，需視版本與部署模式確認 | vtgate 與 MySQL 可分開擴，但 storage 仍在 MySQL shard | 需以本次 PoC 採用版本與部署型態為準 |
| scale out 模型 | 加 TiDB / TiKV / TiFlash | 加 tserver / read replica / gateway | 加 shard / MySQL replica / vtgate | 需評估是否能線上擴容且對業務透明 |
| 成本主要來自哪裡（IO / network） | 跨區網路、Raft 複寫、SSD IOPS | 跨區網路、Raft 複寫、SSD IOPS | MySQL primary / replica 數量、跨區複寫與平台營運人力 | 需後續補上實際節點數、規格與網路流量估算 |
