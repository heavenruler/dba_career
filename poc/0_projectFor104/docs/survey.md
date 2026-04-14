# 分散式資料庫 Survey 評估面向

候選系統：**TiDB**、**YugabyteDB**、Vitess

> Vitess 已排除於本次 PoC 實測範圍，保留於此作為選型參考對照。

---

## 1. 系統定位

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| 類型 | NewSQL / Distributed SQL | NewSQL / Distributed SQL | Sharding middleware | self-managed 部署（非 K8s） |
| 一致性模型 | 強一致，預設 Snapshot Isolation | 強一致，YSQL 支援 Serializable / RC | 單 shard 依 MySQL，無全域一致性 | isolation level 以官方預設為準 |
| Transaction 模型 | Percolator + 2PC，Region Raft | DocDB intents + Raft | 單 shard local txn；跨 shard 由 VTGate 協調 | Vitess 跨 shard atomic commit 需啟用 `TWOPC` |
| Timestamp 機制 | PD TSO（中央授時） | HLC / Hybrid Time（去中央化） | 無 global timestamp | — |

---

## 2. Multi-Site 寫入模型

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| 任意站點接受寫入 | ✅ 任一 TiDB 可收寫；序列化點在 Region leader | ✅ 任一 tserver 可收寫；序列化點在 tablet leader | ⚠️ 同 row 落單一 shard primary，不建議視為多站寫入 | RF=3，replica 跨 IDC / GCP |
| Commit path | TSO → prewrite keys → commit primary → finalize | intents → tablet Raft majority → commit/apply | MySQL commit（單 shard）；VTGate 協調（跨 shard） | 以 PoC 實際 tracing 驗證 |
| 是否跨站 quorum | ✅ replica 跨站時必然跨站 quorum | ✅ RF=3 跨 IDC/GCP 時 leader 需拿 majority | ⚠️ 僅在 semi-sync 跨站時部分成立 | — |
| Commit latency 主要來源 | PD TSO RTT + Region leader RTT + 2PC | tablet leader RTT + txn status tablet RTT + HLC safe time | shard primary RTT；跨 shard 再加 VTGate 協調 | 需對照 cross-site RTT 量測 |
| Global time ordering | ✅ TSO | ✅ HLC | ❌ 無 | — |

---

## 3. 衝突處理

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| 衝突 detection | MVCC + write conflict，Percolator prewrite 時檢查 | DocDB intents + conflict manager + MVCC | InnoDB row lock / gap lock；跨 shard 無全域衝突管理 | 以同 row 高併發 update 驗證 |
| 衝突 resolution | abort / client retry | abort / restart / retry；常見 `could not serialize access` | 單 shard：MySQL lock wait / deadlock rollback；跨 shard 各自決定 | — |
| Deterministic ordering | TSO + lock key 順序 | Hybrid time + txn priority | 無全域 ordering | 細節因版本可能有差異 |
| Last-write-win | ❌ | ❌ | ❌（系統級）；應用層自行實作才會出現 | — |

---

## 4. MVCC 與 Read 行為

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| MVCC 層級 | transaction-level snapshot | transaction-level snapshot | 依底層 MySQL；無全域 MVCC | — |
| Follower read | ✅ 強一致（需 `ReadIndex`） | ✅ | ❌ 無原生 distributed follower read | 需量測 latency 與 staleness |
| Stale read | ✅ `AS OF TIMESTAMP` / bounded staleness | ✅ follower reads / time-travel 類 | ❌ 僅 replica 延遲讀 | YugabyteDB 操作方式依版本確認 |
| Read-your-write | ✅ 同 session / txn | ✅ | ✅ 單 shard；跨 shard 不保證全域一致視圖 | — |
| Read consistency 等級 | 強一致 / follower strong / stale snapshot | 強一致 / Serializable / RC / follower / stale | primary 強一致；replica 最終一致 | — |

---

## 5. Failover / HA

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| Leader election | TiKV Region Raft + PD Raft | Tablet Raft + master Raft | MySQL failover（VTOrc / Orchestrator）+ Vitess 路由 | 官方建議 HA 拓樸 |
| 單節點 failover RTO | ~3–10s | ~3–10s | ~5–30s（依 MySQL HA 設定） | 需以 kill leader / node failure 實測 |
| Site-level failover | ✅ 有條件（quorum 尚存） | ✅ 有條件（geo-placement 正確） | ⚠️ 非原生；依各 shard MySQL 複寫拓樸 | 需明確定義 quorum 條件與 placement rule |

---

## 6. 擴展與 Hotspot

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| 切分方式 | Region（key-range），自動 split / merge / rebalance | Tablet（hash / range），自動 split / rebalance | Shard，預先定義或 resharding | 使用預設切分策略 |
| Hotspot auto-rebalance | ✅ 可 rebalance；同一 key 熱點無法切散 | ✅ 可 rebalance / split；同一 key 熱點無法切散 | shard 級可分流；同 row 熱點集中單一 primary | 需以 hot row workload 實測 |
| 同 key 高併發寫入 | leader 單點序列化，衝突率與延遲快速上升 | tablet leader 序列化，可能出現 restart storm | MySQL row lock；吞吐最早觸頂 | — |

---

## 7. DDL / Schema

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| Online DDL 能力 | 強 | 中高 | 強 | 以 add column / add index / modify schema 實測 |
| Schema change blocking | 低；add index backfill 期間需觀察 | 多數可線上執行；逐項驗證 | 可用 Online DDL 降低 blocking | 搭配持續寫入 workload 驗證 |
| Metadata lock 風險 | 低於傳統 MySQL | 受 PG catalog 行為影響 | 可降低 MySQL MDL 風險（強項） | 需實測對長交易與高併發讀寫的影響 |

---

## 8. 運維能力

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| K8s Operator | ✅ 成熟 | ✅ 成熟 | ✅ 但整體複雜度較高 | self-managed 部署，Operator 為參考 |
| Backup / Restore / PITR | ✅ | ✅ | ⚠️ 依賴 MySQL + Vitess workflow 組合 | 需驗證備份視窗、還原時間與一致性 |
| Rolling upgrade | ✅ | ✅ | ✅ 需分 vtgate / vttablet / mysql / topo 分段規劃 | 確認升級期間寫入 SLA 是否受影響 |
| Observability | Prometheus / Grafana / TiDB Dashboard | Prometheus / Grafana / ASH / pg_stat | 指標完整，但需同時觀察多層元件 | 以 PoC 必收 metrics 清單為基準 |

---

## 9. 成本模型

| 項目 | TiDB | YugabyteDB | Vitess | 前提假設 |
| --- | --- | --- | --- | --- |
| Compute / storage 分離 | SQL 與存儲分層；TiKV 仍為 shared-nothing | 支援 compute / storage decouple（依版本） | vtgate 與 MySQL 可分開擴；storage 仍在 shard | 以 PoC 採用版本與部署型態為準 |
| Scale-out 模型 | 加 TiDB / TiKV / TiFlash | 加 tserver / read replica / gateway | 加 shard / MySQL replica / vtgate | 需評估線上擴容是否對業務透明 |
| 成本主要來源 | 跨站網路、Raft 複寫、SSD IOPS | 跨站網路、Raft 複寫、SSD IOPS | MySQL 節點數、跨站複寫、營運人力 | 需補上節點規格與網路流量估算後試算 |
