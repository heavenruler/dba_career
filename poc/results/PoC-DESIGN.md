# PoC 設計原則與規劃（v2026.05 / v4.7）

## 1. 文件用途

本文件為 TiDB / CockroachDB / YugabyteDB 三家分散式 DB 之 TPC-C-derived 對標 PoC 的**單一事實來源（SSOT）**。涵蓋對標原則、隔離級選擇、測試流程、Make target 規範、報告產出格式與 summary.json schema。所有實作（Makefile / ansible playbook / tests/common/ 腳本）必須對齊本文。

歷史紀錄（前一輪 TPC-C 結果摘要）見 [README.md](./README.md)。

## 2. PoC 目標

| 目標 | 衡量方式 |
|---|---|
| 三家分散式 DB 在相同硬體 / 工作負載下的**對標基準** | tpmC + P50/P95/P99 + retry/abort rate |
| **scale-out 能力差異** | vm-1node ↔ vm-3node tpmC ratio |
| **連線層代理（HAProxy）對吞吐的影響** | vm-3node-direct ↔ vm-3node-haproxy tpmC delta |
| **隔離級提升的成本** | vm-1node-rc ↔ vm-1node-strict tpmC delta |

**不在本輪 PoC 範圍**：K8s 容器化、跨區（IDC/GCP cross-zone）、Read replica、TLS 加密。

## 3. TPC-C compliance boundary（重要聲明）

本 PoC **不是 audited TPC-C，亦不宣稱 TPC-C compliant**。本測試為 **TPC-C-derived stress benchmark using go-tpc**，與官方 TPC-C 規範的關鍵差異：

| 維度 | 官方 TPC-C | 本 PoC |
|---|---|---|
| think time / keying time | 必須有（terminal-limited） | 0（持續高壓滿載） |
| measurement interval | ≥ 120 min | 5 min × 5 round |
| sustain duration | 8 hour | 不適用 |
| 全套 ACID / auditor procedure | 必須 | 不適用 |
| price/performance 報告 | 必須 | 不報 |

**對外解讀的合法範圍**：
- ✓ 三家 DB 在同硬體 / 同流程下的**相對比較**
- ✓ 同一 DB 的拓撲 scaling ratio
- ✗ 不可外推為「官方 TPC-C tpmC」
- ✗ 不可與 [TPC.org 官方測試結果](https://www.tpc.org/tpcc/results/tpcc_results5.asp)直接比較

報告所有對外用詞使用「**stress benchmark**」或「**TPC-C-derived workload**」，避免「TPC-C benchmark」單獨出現。

## 4. 對標原則

### 4.1 強制對齊

| 維度 | 設定 | 依據 |
|---|---|---|
| 硬體 | 每節點 4 vCPU / 16 GB RAM / 100 GB disk | 3VM 部署在同 vSphere datastore |
| OS | AlmaLinux 8.10 + kernel 4.18.0-553.124 | poc-template 已對齊 |
| 工作負載 | 128 warehouses（go-tpc 預設 mix） | |
| 併發 | 16 / 32 / 64 / 128 threads（4 個併發水位，每個水位跑 5 round） | 觀察飽和曲線；本輪取 64 threads 為主軸對標 |
| 主對標隔離級 | **READ COMMITTED**（三家共同 production-ready 層級） | 見 §5 |
| RF | vm-1node = RF=1；vm-3node = RF=3 | |
| **DB-process memory budget** | **16 GB × 70% ≈ 11 GB**（三家統一） | 對齊「總 memory envelope」而非個別 cache % |
| **WAL durable** | **三家強制 fsync-on-commit** | YBDB 需顯式 `--durable_wal_write=true --require_durable_wal_write=true` |
| **Auto-statistics** | **三家全部關閉**（benchmark control，非 production recommendation） | 每 round 前後 dump stats age / modified ratio，若 >10% 須重跑或標 plan-staleness risk |
| **prepare 後 ANALYZE** | **三家強制執行**，並 dump EXPLAIN | 排除 optimizer plan 隨機性 |
| Auth | 三家統一 **HBA trust / disabled auth**（不設密碼，避免 secure-only 操作失敗） | |

### 4.2 對齊政策（baseline vs controlled experiment 兩條線）

| 維度 | 對齊原則 | 理由 |
|---|---|---|
| Sharding — **vm-1node**（1 store/node 自然 = 1 shard） | 不需鎖定，採自然狀態 | 單節點唯一可能 |
| Sharding — **所有 vm-3node 子拓撲**（1s1r / 1s3r / 3s1r / 3s3r / haproxy-3s3r） | **全部為 controlled experiment，手動鎖 shard 數** | §6 為了隔離 sharding ↔ replication 各自貢獻必須鎖；具體方法見 §7.5 |
| CRDB load-based splitting | **vm-1node 不關**（自然不觸發）；**vm-3node 全部關**（`kv.range_split.by_load_enabled=false`） | controlled experiment 不能讓 split 干擾 shard 鎖定 |
| YBDB automatic tablet splitting | **vm-3node 全部關**（`enable_automatic_tablet_splitting=false`） | 同上 |
| TiDB Region size split | vm-3node 用 `coprocessor.region-split-size` 設極大避免 size split | 同上 |
| Memory 內部分配（block cache / SQL memory / heap） | 各 DB 內部分配策略不同，只對齊總額 11 GB | 對齊「總 memory envelope」可比 |
| Background compaction | 三家預設行為，**不關** | 反映真實 OLTP 行為 |

> **不存在「production default vs controlled」混合分類**：vm-3node 系列全部是 controlled experiment，目的是觀察「拆解後的純效應」，不是反映各家「拿出來就跑」的生產表現。生產表現的對標另案處理（非本輪範圍）。

### 4.3 vm-1node 限制聲明

vm-1node 拓撲使用 **single-node + RF=1**，三家都**排除了多副本 quorum 與跨節點 leader/follower 網路成本**（本文件不主張各產品完全跳過其內部 Raft / replication code path）。**本拓撲的數字不代表 production performance**，目的是：

1. 各家「本地引擎（SQL → storage）吞吐 baseline」對比
2. 與 vm-3node tpmC 計算 scale-out ratio（量化「分散式架構真實成本」）

**CRDB 特別聲明**：[官方文件](https://www.cockroachlabs.com/docs/stable/cockroach-start-single-node)明確標註 `start-single-node` 為 single-node cluster with replication disabled，**不適合 performance testing**。本 PoC 採用是為了與 TiDB `max-replicas=1` / YBDB RF=1 對齊對比基準，**不可外推為 CRDB production 數字**。

### 4.4 為何排除 vm-1node 1 shard × 3 replica（同 store 多 replica 不可行）

三家分散式 DB 的官方副本放置（replica placement）規則皆**強制要求一個 Region/Range/Tablet 的多個 replica 必須位於不同 store/node**。在 single-node 拓撲下強制 RF=3 屬於**架構違例**，不會產生有意義的 benchmark 數字，本 PoC 排除。

| DB | 副本放置規則 | 在 1-node 強制 RF=3 的後果 | 官方來源 |
|---|---|---|---|
| **TiDB** | PD `replication.max-replicas=N` 是 placement scheduling target；當可用 stores 數 < N 時，PD 無法滿足該 target，Region 持續 **under-replicated（pending peers）** | 設 `max-replicas=3` 但只有 1 個 TiKV store → 所有 Region 永遠 under-replicated；cluster 雖能 SELECT 但不是有效 perf 基準 | [PD Placement Rules](https://docs.pingcap.com/tidb/stable/configure-placement-rules/) / [`replication.max-replicas`](https://docs.pingcap.com/tidb/stable/pd-configuration-file/#max-replicas) |
| **CockroachDB** | Zone `num_replicas` 預設把每個 replica 放到 unique node；`start-single-node` 明確標註 single-node cluster with replication disabled，**不適合 production / performance testing** | 強行 `ALTER ... CONFIGURE ZONE USING num_replicas=3` 於 single-node cluster → CRDB 標記 ranges under-replicated，admin UI 持續告警，不會自動降級「同 node 多 replica」 | [Replication Controls — Replica Constraints](https://www.cockroachlabs.com/docs/stable/configure-replication-zones#replica-constraints) / [`cockroach start-single-node`](https://www.cockroachlabs.com/docs/stable/cockroach-start-single-node) |
| **YugabyteDB** | `--replication_factor` 受 master 強制：**RF ≤ 可用 tservers**；YB-TServer nodes must equal or exceed RF for table creation | `yugabyted start --rf 3` 於 single tserver → 初始化失敗 | [Key Concepts — Replication Factor](https://docs.yugabyte.com/stable/architecture/key-concepts/#replication-factor) / [yb-master `replication_factor`](https://docs.yugabyte.com/stable/reference/configuration/yb-master/#replication-factor) / [Manual Deployment — Start YB-Masters](https://docs.yugabyte.com/stable/deploy/manual-deployment/start-masters/) |

**設計結論**：vm-1node 拓撲固定 RF=1；多 replica 場景皆在 vm-3node 拓撲下測試（§6）。

## 5. 隔離級支援度與「為何選 READ COMMITTED」

### 5.1 隔離級全名對照

| 縮寫 | 全名 | 說明 |
|---|---|---|
| RU | **READ UNCOMMITTED** | 可讀未提交資料（最弱） |
| **RC** | **READ COMMITTED** | 只讀已提交資料 |
| RR | **REPEATABLE READ** | 同一交易內讀同筆資料不變 |
| **SER** | **SERIALIZABLE** | 等同序列化執行（最強） |
| SI | **Snapshot Isolation** | RR 的一種實作（基於快照） |

### 5.2 三家支援度矩陣

依官方文件實測整理：

| 隔離級 | TiDB v8.5 | CockroachDB v26.2 | YugabyteDB 2025.2 | 對標可行 |
|---|---|---|---|---|
| READ UNCOMMITTED | ❌ 不支援（spec 列為 not supported） | ❌ 不支援 | ❌ 自動升級為更嚴格層級 | ✗ |
| **READ COMMITTED** | ✅ 顯式支援；**僅在 `tidb_txn_mode=pessimistic` 下生效**，optimistic mode 仍走 SI | ✅ 顯式支援；**v26.2 預設已啟用** | ✅ 顯式支援；`yugabyted`/YBA/Aeon 部署的 v2025.2+ universe 預設 `yb_enable_read_committed_isolation=true` | **✓ 三家皆 production-ready** |
| REPEATABLE READ | ✅ 預設（實作為 Snapshot Isolation） | △ opt-in/preview：v24.3+ 加入 `sql.txn.repeatable_read_isolation.enabled`，**預設 false**，需手動開啟；CRDB 主述為 SER/RC 兩級 | ✅ 支援（Snapshot Isolation） | △ 三家可用，CRDB 為 preview |
| SERIALIZABLE | ❌ spec 標 not supported；client 可 SET 但實際走 SI | ✅ 預設 | ✅ 支援 | ✗ TiDB 無原生支援 |

**官方來源**：
- TiDB: [transaction-isolation-levels](https://docs.pingcap.com/tidb/stable/transaction-isolation-levels)
- CRDB: [read-committed docs](https://www.cockroachlabs.com/docs/stable/read-committed) / [v24.3 release notes](https://www.cockroachlabs.com/docs/releases/v24.3)
- YBDB: [read-committed architecture](https://docs.yugabyte.com/preview/architecture/transactions/read-committed/) / [yb-tserver config](https://docs.yugabyte.com/preview/reference/configuration/yb-tserver/)

### 5.3 為何主對標選 READ COMMITTED

| 理由 | 說明 |
|---|---|
| **三家 production-ready** | TiDB v8.5（pessimistic）/ CRDB v26.2（預設開啟）/ YBDB v2025.2 yugabyted（預設開啟）皆原生支援，非 client 端假象映射 |
| **語義最接近常見應用基準** | 與 MySQL / PostgreSQL 預設或常見設定一致，遷移成本與行為預期可預測 |
| **減少 retry 對引擎觀察的干擾** | SERIALIZABLE / REPEATABLE READ 在高熱點下 abort/retry 量會放大；RC 能讓本 PoC 看見**引擎本身**的吞吐而非隔離級開銷 |
| **本 PoC 為 benchmark control** | 選 RC 不是因 TPC-C 規範要求（CockroachDB 官方 TPC-C 數字其實是 SER），而是為了降低 retry/abort 對引擎吞吐觀察的干擾 |

### 5.4 補強拓撲：vm-1node-rr / vm-1node-strict（量化隔離成本）

為**體現「拉高隔離級的成本」**，本輪追加 2 個子拓撲：

| 拓撲 | TiDB | CRDB | YBDB |
|---|---|---|---|
| **vm-1node-rc**（主對標） | READ COMMITTED（pessimistic mode） | READ COMMITTED（v26.2 預設） | READ COMMITTED（yugabyted 預設） |
| **vm-1node-rr**（RR / SI 階） | **REPEATABLE READ**（預設，實作為 SI） | **REPEATABLE READ**（v24.3+ 需 opt-in `sql.txn.repeatable_read_isolation.enabled=true`；preview） | **REPEATABLE READ**（Snapshot Isolation） |
| **vm-1node-strict**（各家最強） | REPEATABLE READ（與 rr 同，TiDB native 最強）| **SERIALIZABLE**（預設） | **SERIALIZABLE** |

> 注意 1：vm-1node-strict 不是三家「對齊隔離級」的比較，而是「**各家在自家最強隔離下的 OLTP 表現**」。
> 注意 2：**TiDB rr 與 strict 完全等價**（TiDB 不支援 SERIALIZABLE，REPEATABLE READ 已是 native 最強）。本實作將 `tidb:strict` 在 `tests/common/lib/common.sh` alias 到 `tidb:rr`；為避免重跑同設定 ~3.6h 但無資訊增量，**TiDB strict artifact 略過**，後續報表以 `vm-1node-rr` 作 TiDB native strictest 代表（CRDB / YBDB 仍跑 strict，因有原生 SSI / SI）。
> 注意 3：**CRDB rr 為 preview feature**，需 cluster setting opt-in；行為與 SI/RR 標準語義可能有微差，報告須標 preview 警語。

**預期觀察（探索性假設，僅為設計時參考，非官方 benchmark spec，以實測為準）**：

| 對比 | TiDB | CRDB | YBDB |
|---|---|---|---|
| rr vs rc | -5% ~ +10% | -5% ~ +10% | -5% ~ +15% |
| strict vs rc | -5% ~ +10%（同 rr） | -5% ~ +10%（SER 預設） | 0% ~ -30% |

> **參考來源（非官方保證）**：[CockroachDB Isolation Levels 2024 PGConf](https://pgconf.in/files/presentations/2024/Isolation_levels_without_the_anomaly_table_Ben_Darnell_Cockroach_Labs.pdf) / [YugabyteDB Isolation Benchmark Blog](https://www.yugabyte.com/blog/cockroachdb-vs-aurora-vs-yugabyte-db-performance-benchmarks-isolation-level-effects/)

### 5.5 與 PACELC 的取捨

不採「CAP 都是 CP」這種粗略描述，改用更精確的 **PACELC**：

```
三家皆屬：強一致 + Raft/multi-Raft majority replication 分散式 SQL

PACELC 立場：
  P (partition)  → 對無法取得 quorum/leader 的分區，犧牲該分區可用性以維持一致性
  E (else)        → 正常狀態下，透過 leader placement / lease / follower-read /
                    isolation level / replica layout 在 latency 與 consistency/recency 間取捨
```

| DB | 自我定位（官方） |
|---|---|
| TiDB | strong consistency + high availability + Multi-Raft majority commit（[overview](https://docs.pingcap.com/tidb/stable/overview)） |
| CockroachDB | CP database（[FAQ](https://www.cockroachlabs.com/docs/stable/frequently-asked-questions)），CP availability 語義與「整體系統 HA」需分開談 |
| YugabyteDB | CP database with high availability（[design goals](https://docs.yugabyte.com/preview/architecture/design-goals/)） |

**Isolation 在 PACELC 內部的角色**：

```
              ┌─ READ UNCOMMITTED   最弱（不在三家選項內）
   Consistency│
   強度刻度   ├─ READ COMMITTED    ← 本 PoC 主對標
              │
              ├─ REPEATABLE READ / Snapshot Isolation
              │
              └─ SERIALIZABLE       最強

PACELC P 行為 → 三家對齊（犧牲分區 A 保 C）
Isolation     → PACELC E 內部的 latency-vs-consistency 刻度，可獨立選擇
```

**選 READ COMMITTED 的工程取捨**：

| 換來 | 付出 |
|---|---|
| 較高 tpmC（少 abort/retry/wait） | Non-repeatable read（同 txn 內讀同筆資料可能變） |
| 較低 P99 latency | Phantom read（範圍查詢可能多/少幾筆） |
| 較少 application retry 邏輯 | Lost update（應用需 SELECT FOR UPDATE 或 row-level retry） |
| 與 MySQL/PostgreSQL 行為一致，遷移成本低 | Write skew（SER 下會被擋，RC 下可能通過） |

## 6. 測試矩陣

### 6.1 拓撲總覽（shard × replica，全部 vm-3node 為 controlled experiment）

```
拓撲                          DB nodes    shards    replicas    本拓撲主目的
vm-1node-{rc,rr,strict}       1           1         1           本地引擎能力 baseline + 隔離級成本對照
vm-3node-1s1r-rc              3           1         1           3-node 但只 1 shard，1 replica；對比 vm-1node 觀察 cluster framework + remote coord 成本
vm-3node-1s3r-rc              3           1         3           1 shard，3 replicas（leader+2 follower）；對比 1s1r 觀察 Raft replication 成本
vm-3node-3s1r-rc              3           3         1           3 shards 各 1 replica（分散到 3 node）；對比 1s1r 觀察 sharding 對 OLTP 的效應
vm-3node-3s3r-rc              3           3         3           3 shards × 3 replicas（每節點都持有所有 shard 的副本）
vm-3node-haproxy-3s3r-rc      3 + HAProxy 3         3           3s3r 加 HAProxy 連線分散，對比 direct 觀察連線層效益
```

> **vm-1node 1s/3r 已排除**（§4.4）。
> **vm-3node 所有子拓撲皆為 controlled experiment**，shard 數靠 §7.5 方法強制鎖定 + prepare 後 hard gate 驗證。

### 6.2 變數隔離對照表（前提：shard 鎖定 hard gate 通過）

| 對比 | 隔離出的「純效應」 | 注意事項 |
|---|---|---|
| vm-1node-rc ↔ vm-3node-1s1r-rc | cluster framework + remote coordinator overhead | 不主張「只 1 節點持資料」；RF=1 在 3-node cluster 下 shard placement 由 PD/allocator 決定，可能落在任一 store。要與 vm-1node 直接比，本質上是「single-node engine vs 3-node cluster with single-shard data」 |
| vm-3node-1s1r-rc ↔ vm-3node-1s3r-rc | Raft 3-replica 寫入成本 | 前提：兩組 shard 都在同 node 上（leader placement 相同）；實務上難保證，gate 須抓 leader location 並標差異 |
| vm-3node-1s1r-rc ↔ vm-3node-3s1r-rc | sharding 對 OLTP 的效應（分散 ↔ 競爭） | 前提：shard 數確實鎖到 1 vs 3；不應允許 size/load split |
| vm-3node-3s3r-rc ↔ vm-3node-1s3r-rc | sharding 對 replication 集群的攤平效益 | 量化「橫向擴展」實際效益 |
| vm-3node-3s3r-rc ↔ vm-3node-3s1r-rc | replication 成本 in sharded cluster | 應與 1s3r ↔ 1s1r 線性近似；若差異大代表 sharding 與 replication 有 interaction |
| vm-3node-haproxy-3s3r-rc ↔ vm-3node-3s3r-rc | HAProxy 連線分散效益 | 原假設：TiDB 預期最大（SQL 層 stateless 可水平分散），YugabyteDB 預期最小（tserver 一體）；2026-05-25 YugabyteDB 3s3r HAProxy N=1 實測已推翻此假設（+79.1% tpmC）。YugabyteDB 數字為 artifact fact，跨家排序仍 pending，需待 TiDB / CockroachDB HAProxy 3s3r 完成後重排。 |

> ⚠️ 上述「純效應」皆假設 shard 數鎖定 hard gate 通過（§7.5）且 leader/leaseholder/tablet leader 分布在兩組對照之間相近。差異 > 20% 時須在報告標 placement-noisy 警語，不下「純 X 成本 = Y%」結論。

### 6.3 隔離級 × 拓撲

```
                              rc    rr    strict
vm-1node                       ✓     ✓     ✓
vm-3node-1s1r                  ✓     -     -
vm-3node-1s3r                  ✓     -     -
vm-3node-3s1r                  ✓     -     -
vm-3node-3s3r                  ✓     -     -
vm-3node-haproxy-3s3r          ✓     -     -
```

> **vm-3node 系列僅跑 RC**，避免測試組合爆炸（rr/strict ×  vm-3node = 30 組）。
>
> **嚴格限制聲明**：本 PoC 對「拉高隔離級的成本」量化只在 **vm-1node** 觀察。**不可外推到 Raft quorum 下**的 distributed transaction abort/retry 行為——quorum 下 SERIALIZABLE 的 conflict cost 可能與 single-node 不同數量級。

#### 6.3.1 vm-3node 用 RC 的實測驗證（vm-1node 9 組數據佐證，2026-05-21）

> 本段以 vm-1node 已完成的 9 組 (db × iso) 5-round mean 數據驗證 §6.3「vm-3node 全 RC」決策，避免日後 reviewer 重複質疑「為何不混 iso 跑 vm-3node」。

| Iso | TiDB tpmC / err rate | CockroachDB tpmC / err rate | YugabyteDB tpmC / err rate | 是否適合 vm-3node cross-DB baseline |
|-----|----------------------|------------------------------|------------------------------|-------------------------------------|
| **rc** | 13,064 / **0%** | 9,134 / **0%** | 11,436 / **0%** | ✅ **三家全零 error、皆 CPU/IO-bound、口徑乾淨** |
| rr | 13,874 / 0% | 3,788 / 0.300% | 1,879 / 0.149% | ❌ TiDB pessimistic 獨贏；CockroachDB / YugabyteDB 撞 SI retry storm（N−1 errors/round）|
| strict | — (alias to rr) | 10,830 / 0.051% | 1,130 / 0.248% | ❌ TiDB 無原生 SSI；CockroachDB / YugabyteDB strict 相差 ~10x（CockroachDB rc IO-bound 故 SSI 反而最快、YugabyteDB rc 已 CPU-bound 故 SSI 拖底）|

**判斷依據**：
1. **RC 是唯一所有三家「機制正常運作 + 零 error」的 iso** — vm-3node 的 primary 觀察是 `scale-out ratio / Raft replication 成本 / cross-zone latency`，這些訊號不該被 isolation cost 污染。
2. **RR 在 vm-3node 預期更糟**：YugabyteDB / CockroachDB 兩家 RR = optimistic SI，在 vm-3node 下 Raft quorum 跨 zone 確認延遲會放大 hot-row first-committer-wins 的 round trip → retry storm 從 vm-1node 的 N−1 errors/round 進一步惡化。
3. **strict 在 vm-3node 預期撕裂更大**：CockroachDB SSI 走 read-refresh 路徑、YugabyteDB SSI 多一道 serializable detector，兩家在 Raft commit latency 拉長後成本差異會被放大、跨 DB 對標失真。
4. **TiDB strict 即 RR**：跨 DB strict 對標時 TiDB 無 native SSI 可比，混 iso 即等於放棄 TiDB strict 軸。

**結論：vm-3node 12 cell (4 子拓撲 × 3 DB) 全跑 RC**，總時數約 12 × 3.5h = 42h（~2 工作日）。

**可選 stretch goal（非 spec 必要）**：在最複雜的 `vm-3node-3s3r` 子拓撲對 CockroachDB / YugabyteDB 補一組 strict、TiDB 補一組 rr，作 **vm-3node iso 排行是否承襲 vm-1node** 的 sanity check。+3 runs ≈ +10.5h，僅在前 12 cell 全完成後考慮。

### 6.3.2 vm-3node 元件分配與 dry-run gate（2026-05-21 決策）

> 本段定義 vm-3node 12 cell（4 子拓撲 × 3 DB）的物理元件落點與 dry-run 安全閘，避免 deploy 失敗未察直接燒掉 ~3.5h benchmark wall-clock。

#### 6.3.2.1 物理元件落點（3 顆 VM = .32 / .33 / .34）

| DB | .32（client 入口） | .33 | .34 | 客戶端連線 |
|---|---|---|---|---|
| **TiDB** | PD(2379) + TiKV(20160) + **TiDB(4000)** | PD + TiKV | PD + TiKV | `.32:4000`（單一 TiDB stateless 入口） |
| **CockroachDB** | cockroach node 1（init）:26257 | cockroach node 2 | cockroach node 3 | `.32:26257` |
| **YugabyteDB** | yb-master + yb-tserver:5433（cluster init） | yb-master + yb-tserver | yb-master + yb-tserver | `.32:5433` |

**設計理由**：
- **PD×3 / yb-master×3 = Raft quorum**：3 顆是最小可容錯 quorum（容忍 1 故障）。
- **TiKV×3 / cockroach×3 / yb-tserver×3 = RF=3 store 數要求**（§4.4 規則：replica 必須跨不同 store）。
- **TiDB 只 1 顆**：stateless 元件，3 顆需 HAProxy 才能受益；本 12 cell 為 direct 連線，1 顆已足；mem envelope 11 GB 也較寬鬆（PD ~1G + TiKV 5G + TiDB 3G = ~9G < 11G）。
- **client 統一入口 `.32`**：與 vm-1node 一致，summary.json 取數路徑不變。
- 3 顆 TiDB + HAProxy 屬 §6.4 Phase F 的 `vm-3node-haproxy-3s3r-rc`，不在本 12 cell 範圍。

#### 6.3.2.2 4 sub-topology × 3 DB 設定矩陣

| sub-topo | shard 數/表 | RF | TiDB | CRDB | YBDB |
|---|---:|---:|---|---|---|
| **1s1r** | 1 | 1 | `pd: replication.max-replicas=1`；無 SPLIT | `ALTER DB ... num_replicas=1`；無 SPLIT | `--rf=1`；pre-create `SPLIT INTO 1 TABLETS` |
| **1s3r** | 1 | 3 | `pd: replication.max-replicas=3`；無 SPLIT | `ALTER DB ... num_replicas=3`；無 SPLIT | `--rf=3`；pre-create `SPLIT INTO 1 TABLETS` |
| **3s1r** | 3 | 1 | `pd: replication.max-replicas=1`；prepare 後 SPLIT 9 表 × 3 region | `ALTER DB ... num_replicas=1`；prepare 後 SPLIT AT 9 表 | `--rf=1`；不 pre-create（3 tservers × 1 = 3 tablets 自然）|
| **3s3r** | 3 | 3 | `pd: replication.max-replicas=3`；prepare 後 SPLIT 9 表 × 3 region | `ALTER DB ... num_replicas=3`；prepare 後 SPLIT AT 9 表 | `--rf=3`；不 pre-create |

> shard 鎖定 SQL 與 hard gate 表清單見 §7.5（已寫明每家做法）。本表為 deploy 層級的差異總覽。

#### 6.3.2.3 Dry-run gate（deploy 後、prepare 前）

每 cell 預設跑到 deploy 完成即停在 `.dry-run.done` anchor，必須使用者顯式 `EXECUTE=1` 才放行進 prepare/run/collect/fetch。

**設計動機**：
- vm-3node deploy 任一失敗（PD quorum 沒對齊、node 沒 join、RF 沒設對）若直接進 prepare，會白燒 ~1h prepare + 20m warmup + 116m run，回到原點。
- dry-run anchor 把 deploy 後的 cluster topology / RF / iso preset / health 全 dump 出來，由人工 5 min review 換 ~3.5h benchmark 不浪費。

**Anchor 寫入位置**：`artifacts/<db>-vm-3node-<subtopo>-<iso>-<ts>/dry-run/`

**內容（dry-run-confirm.sh 產出）**：

| 檔案 | 內容 |
|---|---|
| `cluster-topology.txt` | TiDB: `tiup cluster display`；CRDB: `cockroach node status`；YBDB: `yb-admin list_all_tablet_servers` |
| `replication-factor.txt` | TiDB: `SHOW CONFIG WHERE NAME='replication.max-replicas'`；CRDB: `SHOW ZONE CONFIGURATION FROM DATABASE tpcc`（prepare 前可能還沒 tpcc，改 `defaultdb`）；YBDB: `yb-admin get_universe_config` |
| `cluster-health.txt` | TiDB: `SELECT 1`；CRDB: `cockroach node status --ranges`；YBDB: `curl :7000/cluster` |
| `iso-preset.txt` | conn-params probe（同 §7.4 Layer B），確認 `BEGIN; SHOW transaction_isolation;` 與預期一致 |
| `expected-vs-actual.txt` | 4 個項目逐項對比預期：node 數、PD/master quorum、RF、iso |
| `.dry-run.done` | JSON: `{topology, rf_expected, rf_actual, iso_expected, iso_actual, all_pass}` |

**流程**：
```
make vm3-tidb-1s1r-rc                  # 預設 dry-run only
  → new-idc-vms (~5min)
  → bootstrap-tpcc-client (~30s)
  → deploy-vm3-tidb-1s1r (~10min)
  → dry-run-confirm-vm3-tidb-1s1r-rc   # ~2min；dump topology+RF+iso+health
  → .dry-run.done 寫入；script exit 0；提示「review 通過後加 EXECUTE=1 重跑」

[人工 review]
  cat results/tidb-tc1/S-BASE/vm-3node-1s1r-rc/<ts>/dry-run/*.txt

make vm3-tidb-1s1r-rc EXECUTE=1        # 跳過 deploy（cluster 已在），直接接 prepare
  → prepare (含 §7.5 shard 鎖定 + hard gate; ~60min)
  → gate-isolation (~30s)
  → run (warmup 20min + 5round × 4threads × 5min = 136min)
  → collect (~3min)
  → fetch 由人工 make fetch-vm3-... TPCC_TS=<ts> 拉回
```

> **fail-closed**：dry-run 任一項目對不上預期 → `.dry-run.done` 寫 `"all_pass": false` + 列出哪項對不上，不允許 `EXECUTE=1` 跳過（gate 內 hard check）。

#### 6.3.2.4 切換 sub_topology / 換 DB：`destroy-vm3-all` 規範（2026-05-22 dispatch 實測加入）

`make vm3-${db}-${sub}-rc` chain 自動先呼叫 `destroy-vm3-all`，best-effort 清三家殘留：

| 家 | destroy 動作 | 為何需要這個 |
|---|---|---|
| TiDB | `tiup cluster destroy tpcc-tidb-vm3 --yes`（cluster 不存在就 skip） | TiUP-managed lifecycle |
| CRDB | `systemctl stop cockroach.service` + **wait `pgrep -x cockroach` 為空** + `pkill -9` + `rm /etc/systemd/system/cockroach.service` + `rm /data/crdb` | `cockroach start --background` daemonize 後 systemctl loses track；不等 process 真死就 rm，下次 deploy 會帶舊 cluster ID join，出現 `client cluster ID "X" doesn't match server cluster ID "Y"` 死循環 |
| YBDB | `pkill -KILL -x yb-master / yb-tserver / yugabyted-ui` + 對所有 `pgrep -x python3` 讀 `/proc/<pid>/cmdline` 過濾含 `bin/yugabyted` 的才 kill + `rm /var/yugabyte` | yugabyted 是 python3 wrapper；用 `pgrep -f yugabyted` 會自殺（pgrep 自己 cmdline 也含 "yugabyted"） |

> **2026-05-22 dispatch 紀錄**：12 cells 全綠，過程踩 4 個 deploy-time 坑 + 1 個 destroy race，commit 連發後固化於 playbook + Makefile。完整 commit 列表見 git log；artifact 索引見 `results/<db>-tc1/S-BASE/vm-3node-*/`。

### 6.4 本輪實作範圍與 wall-clock 估算

#### 6.4.1 Phase 切分

```
Phase A（本輪起手）：vm-1node-{rc, rr, strict}      = 9 case；實跑 8 組（TiDB strict 等同 rr，僅紀錄不重跑）
Phase B：           vm-3node-1s1r-rc               = 3 組
Phase C：           vm-3node-1s3r-rc               = 3 組
Phase D：           vm-3node-3s1r-rc               = 3 組
Phase E：           vm-3node-3s3r-rc               = 3 組
Phase F：           vm-3node-haproxy-3s3r-rc       = 3 組
                                                     合計 24 case；實跑 23 組
```

#### 6.4.2 每組 wall-clock 階段細項

| 階段 | vm-1node | vm-3node |
|---|---:|---:|
| prepare 128W + `--check-all` + ANALYZE + EXPLAIN dump + hotspot snapshot | ~30 min | ~60 min |
| cold-reset (stop / sync / drop_caches / start / health poll) + sleep 60 | ~3 min | ~3 min |
| warmup 20 min | 20 min | 20 min |
| run：4 threads × 5 round × 5 min run + 60s round sleep | ~116 min | ~116 min |
| collect artifacts + 結束 | ~3 min | ~3 min |
| **每組合計（SSOT 樂觀估）** | **~150 min** | **~180 min** |

> 116 min 計算：4 threads × (5 rounds × 5 min run + 4 × 60s round sleep) = 4 × 29 = 116 min。

#### 6.4.3 24 case 完整明細（實跑 23 組）

| # | Phase | 拓撲 | DB | iso | shard | repl | 工時 | 累計 |
|---:|---|---|---|---|---:|---:|---:|---:|
| 1 | A | vm-1node | TiDB | rc | 1 | 1 | 150 min | 2.5 h |
| 2 | A | vm-1node | TiDB | rr | 1 | 1 | 150 min | 5.0 h |
| 3 | A | vm-1node | TiDB | strict | 1 | 1 | 0 min | 5.0 h（等同 #2 RR，僅紀錄） |
| 4 | A | vm-1node | CRDB | rc | 1 | 1 | 150 min | 7.5 h |
| 5 | A | vm-1node | CRDB | rr | 1 | 1 | 150 min | 10.0 h |
| 6 | A | vm-1node | CRDB | strict | 1 | 1 | 150 min | 12.5 h |
| 7 | A | vm-1node | YBDB | rc | 1 | 1 | 150 min | 15.0 h |
| 8 | A | vm-1node | YBDB | rr | 1 | 1 | 150 min | 17.5 h |
| 9 | A | vm-1node | YBDB | strict | 1 | 1 | 150 min | **20.0 h ← Phase A 結束** |
| 10 | B | vm-3node-1s1r | TiDB | rc | 1 | 1 | 180 min | 23.0 h |
| 11 | B | vm-3node-1s1r | CRDB | rc | 1 | 1 | 180 min | 26.0 h |
| 12 | B | vm-3node-1s1r | YBDB | rc | 1 | 1 | 180 min | **29.0 h ← Phase B 結束** |
| 13 | C | vm-3node-1s3r | TiDB | rc | 1 | 3 | 180 min | 32.0 h |
| 14 | C | vm-3node-1s3r | CRDB | rc | 1 | 3 | 180 min | 35.0 h |
| 15 | C | vm-3node-1s3r | YBDB | rc | 1 | 3 | 180 min | **38.0 h ← Phase C 結束** |
| 16 | D | vm-3node-3s1r | TiDB | rc | 3 | 1 | 180 min | 41.0 h |
| 17 | D | vm-3node-3s1r | CRDB | rc | 3 | 1 | 180 min | 44.0 h |
| 18 | D | vm-3node-3s1r | YBDB | rc | 3 | 1 | 180 min | **47.0 h ← Phase D 結束** |
| 19 | E | vm-3node-3s3r | TiDB | rc | 3 | 3 | 180 min | 50.0 h |
| 20 | E | vm-3node-3s3r | CRDB | rc | 3 | 3 | 180 min | 53.0 h |
| 21 | E | vm-3node-3s3r | YBDB | rc | 3 | 3 | 180 min | **56.0 h ← Phase E 結束** |
| 22 | F | vm-3node-haproxy-3s3r | TiDB | rc | 3 | 3 | 180 min | 59.0 h |
| 23 | F | vm-3node-haproxy-3s3r | CRDB | rc | 3 | 3 | 180 min | 62.0 h |
| 24 | F | vm-3node-haproxy-3s3r | YBDB | rc | 3 | 3 | 180 min | **65.0 h ← Phase F 結束** |

> #3 TiDB strict 不另行作業：TiDB native 最強隔離級為 REPEATABLE READ，`strict` 在本 PoC 中 alias 到 `rr`，因此以 #2 `vm-1node / TiDB / rr` artifact 與報表紀錄代表，避免重跑同設定造成工時浪費與資料重複。

#### 6.4.4 SSOT 樂觀估 vs Conservative buffer

SSOT 樂觀估 65.0 h 為**單純階段累加**（24 case 中 TiDB strict 不另跑，實跑 23 組），實務上還有：

| 隱性成本 | 估時 | 累計影響 |
|---|---:|---|
| ssh / artifact rsync 來回開銷 | ~+3 min/實跑組 | +1.15 h |
| DB 啟動穩定（YBDB tablet rebalance、CRDB compaction、TiDB Region heartbeat），尤其 RF=3 + 3 shards | ~+5 min/組（vm-3node 15 組） | +1.25 h |
| §7.5 shard 鎖定 hard gate 通過前 retry 成本（若失敗 → 重 prepare + 重 cold-reset） | 1 次重跑 ≈ +30 min | 假設 4 次重跑：+2 h |
| 人工介入（log 檢查、noisy result 重跑） | 5 % buffer | +3.4 h |
| **Conservative buffer 合計** | | **+7.8 h** |

**對外承諾用估算**：

```
SSOT 樂觀估：       65.0 h
Conservative buffer：+7.8 h（+12%）
                    ─────────
合計（保守）：       ~73 h benchmark wall-clock
```

#### 6.4.5 排程方案

| 方案 | 跑法 | 時長 |
|---|---|---|
| A — 連續跑（24×7 模式） | 不停機，含夜間 | ~3 工作日（含 buffer 約 73 h） |
| B — 分 Phase 跑 | Phase A（20.0 h）→ Phase B–F（45 h）兩段 | ~3.5 工作日 |
| C — overnight only（每天 8–10 h） | 工作日結束才開跑，隔天停 | ~10 工作日 |

> 建議方案 B：Phase A 跑完先做中間 review（隔離級成本 baseline 出爐），確認流程無誤再進 Phase B–F。失敗重跑也只影響該 Phase。

## 7. 對齊參數（vm-1node）

> **重要原則**：隔離級**不在 DB 端設 default**（CRDB `root` user 對 role-level default exempt；YBDB DB-level default 會被 prepare DROP 洗掉）。改採 **go-tpc connection-string 帶 session 參數** 強制隔離級，並在 run 前以 **active transaction** （`BEGIN; SHOW transaction_isolation; COMMIT;`）驗證實際生效。
> Source（CRDB root exemption）: <https://www.cockroachlabs.com/docs/stable/alter-role>
> Source（PostgreSQL ALTER DATABASE 隨 DROP 消失）: <https://www.postgresql.org/docs/17/sql-alterdatabase.html>

### 7.1 TiDB（tiup cluster v8.5.x，1 PD + 1 TiKV + 1 TiDB）

**topology.yaml**：
```yaml
server_configs:
  tidb:
    mem-quota-query: 3221225472                  # 3 GB
    performance.feedback-probability: 0
  tikv:
    storage.block-cache.capacity: "5GB"
    raftstore.sync-log: true
  pd:
    replication.max-replicas: 1
    schedule.leader-schedule-limit: 0
    schedule.region-schedule-limit: 0
    schedule.replica-schedule-limit: 0
```

**deploy 完成後共同設定**（不含 isolation）：
```sql
SET GLOBAL tidb_enable_auto_analyze = OFF;
SET GLOBAL tidb_txn_mode = 'pessimistic';

-- 不設密碼；HBA / mysql.user 預設 root@'%' 即可（auth 預設未開）
```

**Isolation 控制：go-tpc connection-string**（MySQL DSN session vars）

| `<iso>` | go-tpc `--conn-params` |
|---|---|
| `rc` | `transaction_isolation=%27READ-COMMITTED%27&tidb_txn_mode=%27pessimistic%27` |
| `rr` / `strict` | `transaction_isolation=%27REPEATABLE-READ%27&tidb_txn_mode=%27pessimistic%27` |

> TiDB `rr` 與 `strict` 完全等價（REPEATABLE READ 已是 TiDB native 最強），共用同一組 conn-params。

> URL-encoded（`%27` = `'`）。go-tpc MySQL backend 透過 DSN 將其轉為 session vars。

### 7.2 CockroachDB（v26.2，cockroach start-single-node）

**啟動命令**：
```bash
cockroach start-single-node \
  --insecure \
  --listen-addr=0.0.0.0:26257 \
  --http-addr=0.0.0.0:8080 \
  --store=/data/crdb \
  --cache=5GiB \
  --max-sql-memory=3GiB \
  --background
# 2 * 3 GiB + 5 GiB = 11 GiB ≤ 80% * 16 GB = 12.8 GiB envelope
```

**deploy 完成後共同設定**（不含 isolation）：
```sql
-- v26.2 預設已 true，仍 SHOW 驗證防漂移
SHOW CLUSTER SETTING sql.txn.read_committed_isolation.enabled;  -- 預期 true

SET CLUSTER SETTING sql.stats.automatic_collection.enabled = false;

-- 注意：--insecure 下 ALTER ROLE ... WITH PASSWORD 不支援；
-- 用 HBA trust，root 預設無密碼
SET CLUSTER SETTING server.host_based_authentication.configuration = 'host all all all trust';
```

> ⚠️ **不用 `ALTER ROLE root SET default_transaction_isolation`**：CRDB 官方明說 `root` 對 role/all-role default session settings exempt，只受 connection-string 影響。

**RR tier 額外需 cluster setting opt-in**（僅 `<iso>=rr` 套）：
```sql
SET CLUSTER SETTING sql.txn.repeatable_read_isolation.enabled = true;
SHOW CLUSTER SETTING sql.txn.repeatable_read_isolation.enabled;  -- 預期 true
```
> CRDB v24.3+ 提供，預設 false；v26.2 仍為 preview feature。報告須加 preview 警語。
> Source: <https://www.cockroachlabs.com/docs/releases/v24.3>

**Isolation 控制：go-tpc connection-string**（PostgreSQL `options` 參數）

| `<iso>` | go-tpc `--conn-params` |
|---|---|
| `rc` | `options=-c%20default_transaction_isolation%3Dread%20committed` |
| `rr` | `options=-c%20default_transaction_isolation%3Drepeatable%20read` |
| `strict` | `options=-c%20default_transaction_isolation%3Dserializable` |

> URL-encoded（`%20` = space, `%3D` = `=`）。PostgreSQL libpq 將 `options=-c key=value` 轉為 session GUC。

### 7.3 YugabyteDB（v2025.2.x LTS，yugabyted RF=1）

**啟動命令**（vm-1node；vm-3node 子拓撲另見 §7.5 / §7.6）：
```bash
yugabyted start \
  --base_dir=/var/yugabyte \
  --advertise_address=172.24.40.32 \
  --tserver_flags="\
memory_limit_hard_bytes=11811160064,\
db_block_cache_size_percentage=50,\
durable_wal_write=true,\
require_durable_wal_write=true,\
yb_enable_read_committed_isolation=true,\
ysql_enable_auth=false,\
ysql_enable_auto_analyze=false,\
ysql_num_shards_per_tserver=1,\
enable_automatic_tablet_splitting=false"
```

> **flag 說明**：
> - `ysql_enable_auto_analyze` — YSQL auto-analyze 開關（v2025.2+ yugabyted/YBA 預設開啟，需顯式關）
> - `ysql_num_shards_per_tserver` — YSQL 預設 tablet 數 per tserver（注意：YCQL 用 `yb_num_shards_per_tserver`，與此不同）
> - `enable_automatic_tablet_splitting` — 自動 tablet split；vm-3node controlled experiment 必關
>
> Source: [yb-tserver config](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/)

**gate 驗證**（artifacts/gate/varz.txt）：
```bash
curl -s http://172.24.40.32:9000/varz | grep -E \
  'yb_enable_read_committed_isolation|ysql_enable_auto_analyze|durable_wal_write'
# 預期：
#   yb_enable_read_committed_isolation=true
#   ysql_enable_auto_analyze=false
#   durable_wal_write=true
```

**deploy 後**：無 DB 級 isolation 設定（DB-level setting 會隨 `DROP DATABASE` 洗掉）。隔離級控制走 connection-string，與 CRDB 同 PostgreSQL `options`。

**建立 tpcc database**（PostgreSQL 沒有 `CREATE DATABASE IF NOT EXISTS` 語法）：
```sql
-- 用 wrapper 邏輯
SELECT 1 FROM pg_database WHERE datname = 'tpcc';
-- 若無 row 則執行 CREATE DATABASE tpcc;
-- 或容忍 duplicate_database (SQLSTATE 42P04) error
```

> 但實務上：`prepare` 階段一律 `DROP DATABASE IF EXISTS tpcc; CREATE DATABASE tpcc;`，先 DROP 再 CREATE 是 idempotent 路徑。

**Isolation 控制：go-tpc connection-string**（與 CRDB 同 PostgreSQL options）

| `<iso>` | go-tpc `--conn-params` |
|---|---|
| `rc` | `options=-c%20default_transaction_isolation%3Dread%20committed` |
| `rr` | `options=-c%20default_transaction_isolation%3Drepeatable%20read` |
| `strict` | `options=-c%20default_transaction_isolation%3Dserializable` |

> YBDB RR 對應 Snapshot Isolation 實作。

### 7.5 Shard 鎖定方法（vm-3node 子拓撲專用，含 hard gate）

vm-3node-{1s1r, 1s3r, 3s1r, 3s3r, haproxy-3s3r} 全部需鎖 shard 數。三家方法不同，**prepare 後必須 hard gate 驗證實際 shard 數與預期一致**。

#### 7.5.1 TiDB（v8.5）

1. **關掉 size/load split**（cluster-level）：
   ```toml
   # tikv config
   [coprocessor]
   region-split-size = "128GB"   # 設極大，防 size split
   region-max-size = "128GB"
   ```
2. **預先確認 TPC-C 表的 primary key 形態**（go-tpc v1.0.12 TPC-C tables 多為複合 PK；clustered table 用 PRIMARY index 切，非 clustered 用 hidden _tidb_rowid）：
   ```sql
   SHOW CREATE TABLE tpcc.customer;     -- 確認 CLUSTERED 與否
   SHOW CREATE TABLE tpcc.orders;
   ```
   依結果選用 `INDEX PRIMARY` 或 row split。
3. **prepare 完成後手動 split**（依目標 shard 數，**用 INDEX PRIMARY 對複合 PK 才正確**）：
   ```sql
   -- 3 shards/table（所有 9 張 TPC-C 表全鎖；§7.5.4）
   SPLIT TABLE tpcc.warehouse  INDEX `PRIMARY` BETWEEN (1) AND (128) REGIONS 3;
   SPLIT TABLE tpcc.district   INDEX `PRIMARY` BETWEEN (1,1) AND (128,10) REGIONS 3;
   SPLIT TABLE tpcc.customer   INDEX `PRIMARY` BETWEEN (1,1,1) AND (128,10,3000) REGIONS 3;
   SPLIT TABLE tpcc.new_order  INDEX `PRIMARY` BETWEEN (1,1,2101) AND (128,10,3000) REGIONS 3;
   SPLIT TABLE tpcc.orders     INDEX `PRIMARY` BETWEEN (1,1,1) AND (128,10,3000) REGIONS 3;
   SPLIT TABLE tpcc.order_line INDEX `PRIMARY` BETWEEN (1,1,1,1) AND (128,10,3000,15) REGIONS 3;
   SPLIT TABLE tpcc.stock      INDEX `PRIMARY` BETWEEN (1,1) AND (128,100000) REGIONS 3;
   SPLIT TABLE tpcc.item       INDEX `PRIMARY` BETWEEN (1) AND (100000) REGIONS 3;
   SPLIT TABLE tpcc.history    INDEX `PRIMARY` BETWEEN (1) AND (3840000) REGIONS 3;
   -- 1 shard 不下 SPLIT（natural 1 region/table）
   ```
4. **hard gate**（只算 row data regions，過濾 secondary indexes）：
   ```sql
   SELECT TABLE_NAME, COUNT(*) AS region_count
     FROM information_schema.tikv_region_status
     WHERE DB_NAME = 'tpcc'
       AND IS_INDEX = 0          -- 只算 row data，不含 secondary index regions
     GROUP BY TABLE_NAME;
   -- 9 張表全鎖，每張 region_count == 預期 shard 數，否則 fail closed
   ```
   Source: [Split Region](https://docs.pingcap.com/tidb/stable/sql-statement-split-region/) / [TiKV Configuration `coprocessor.region-split-size`](https://docs.pingcap.com/tidb/stable/tikv-configuration-file/#region-split-size) / [information_schema.tikv_region_status](https://docs.pingcap.com/tidb/stable/information-schema-tikv-region-status/)

#### 7.5.2 CockroachDB（v26.2）

1. **關 load-based split + 設 range_max_bytes 大**：
   ```sql
   SET CLUSTER SETTING kv.range_split.by_load_enabled = false;
   ALTER DATABASE tpcc CONFIGURE ZONE USING
     range_max_bytes = 137438953472,  -- 128 GB
     range_min_bytes = 67108864;       -- 64 MB
   ```
2. **prepare 完成後手動 split**（9 張表全鎖；§7.5.4）：
   ```sql
   -- 3 shards: 每張表切兩刀（compound PK 用 prefix 即可）
   ALTER TABLE warehouse  SPLIT AT VALUES (43), (86);
   ALTER TABLE district   SPLIT AT VALUES (43, 1), (86, 1);
   ALTER TABLE customer   SPLIT AT VALUES (43, 1, 1), (86, 1, 1);
   ALTER TABLE new_order  SPLIT AT VALUES (43, 1, 2101), (86, 1, 2101);
   ALTER TABLE orders     SPLIT AT VALUES (43, 1, 1), (86, 1, 1);
   ALTER TABLE order_line SPLIT AT VALUES (43, 1, 1, 1), (86, 1, 1, 1);
   ALTER TABLE stock      SPLIT AT VALUES (43, 1), (86, 1);
   ALTER TABLE item       SPLIT AT VALUES (33334), (66667);
   ALTER TABLE history    SPLIT AT VALUES ('00000043'), ('00000086');  -- history PK 是 generated；實際以 SHOW CREATE TABLE 為準
   -- CRDB compound PK split 可只填 prefix
   -- 1 shard 不下 SPLIT
   ```
3. **設 replica zone**（依目標 RF）：
   ```sql
   -- RF=1
   ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas = 1;
   -- RF=3
   ALTER DATABASE tpcc CONFIGURE ZONE USING num_replicas = 3;
   ```
4. **hard gate**（只算 primary index，過濾 secondary）：
   ```sql
   SELECT table_name, count(*) AS range_count
     FROM crdb_internal.ranges
     WHERE database_name='tpcc'
       AND index_name='primary'    -- 只算 primary index ranges
     GROUP BY table_name;
   -- 9 張表全鎖，每張 range_count == 預期；replica 數另 SHOW RANGES 驗
   ```
   Source: [Load-Based Splitting](https://www.cockroachlabs.com/docs/stable/load-based-splitting) / [ALTER TABLE ... SPLIT AT](https://www.cockroachlabs.com/docs/stable/alter-table#split-at) / [CONFIGURE ZONE](https://www.cockroachlabs.com/docs/stable/configure-replication-zones)

#### 7.5.3 YugabyteDB（v2025.2 LTS）

YBDB tablet 數靠 **cluster flag `ysql_num_shards_per_tserver` × tserver 數** 與 **CREATE TABLE 時 `SPLIT INTO N TABLETS` override** 兩條路徑。go-tpc v1.0.12 **沒有 `--dropdata` flag**，且 TPC-C workload schema 用 **`CREATE TABLE IF NOT EXISTS`**（依 [go-tpc source](https://github.com/pingcap/go-tpc/blob/v1.0.12/tpcc/ddl.go) 確認），所以 **pre-create schema 不會被 go-tpc prepare 覆寫**。

**各拓撲 YBDB tablet 控制策略**（**vm-3node 一律 3 tservers**，與 §6.1 一致）：

| 拓撲 | tservers | RF | ysql_num_shards_per_tserver | pre-create with SPLIT INTO？ | 預期 tablets/表 |
|---|---:|---:|---:|---|---:|
| vm-3node-1s1r | 3 | 1 | 1 | **需要**：`SPLIT INTO 1 TABLETS` | 1 |
| vm-3node-1s3r | 3 | 3 | 1 | **需要**：`SPLIT INTO 1 TABLETS` | 1 |
| vm-3node-3s1r | 3 | 1 | 1 | **需要**：`SPLIT INTO 3 TABLETS` | 3 |
| vm-3node-3s3r | 3 | 3 | 1 | **需要**：`SPLIT INTO 3 TABLETS` | 3 |
| haproxy-3s3r | 3 | 3 | 1 | **需要**：`SPLIT INTO 3 TABLETS` | 3 |

> ⚠️ **2026-05-23 修正（cell 3 ybdb-3s1r dispatch 實測）**：原本以為「3 tservers × ysql_num_shards_per_tserver=1 = 3 自然 tablets」，**錯**。實測 RF=1 場景 `yugabyted configure data_placement --rf=1` 之後 placement 只覆蓋 1 個 tserver，table 自動 split 數 = `ysql_num_shards_per_tserver × num_tservers_in_placement = 1 × 1 = 1`。所以 3s*r 也必須 pre-create 帶 `SPLIT INTO 3 TABLETS`。修法：prepare.sh `sed s|SPLIT INTO 1 TABLETS|SPLIT INTO ${EXPECTED_SHARDS} TABLETS|g` substitute 既有 schema file，不重複維護兩個檔。

> ⚠️ **修正**：v4.6 把 vm-3node-1s1r 寫成 1 tserver 是錯。所有 vm-3node 都是 3 tservers；只是 RF 與 pre-create 策略不同。

**Prepare 流程（與 §9.2 一致，DROP 一定先做）**：
```
1. DROP DATABASE IF EXISTS tpcc; CREATE DATABASE tpcc;     # §9.2 強制
2. （vm-3node-1s1r / 1s3r 拓撲）pre-create 全 9 張表 with SPLIT INTO 1 TABLETS
3. go-tpc tpcc prepare ...                                 # 走 CREATE TABLE IF NOT EXISTS：
                                                            #   - 已 pre-create 的表 skip
                                                            #   - 未 pre-create 的表用 cluster default
                                                            #     (3s1r / 3s3r 走此路徑得 3 tablets/table)
4. ANALYZE / EXPLAIN dump
```

**cluster flag**（§7.3 已含）：
```
ysql_num_shards_per_tserver=1
enable_automatic_tablet_splitting=false
```

**Pre-create schema 範例**（vm-3node-1s1r 與 1s3r 都需要，全 9 張表都鎖到 1 tablet）：
```sql
\c tpcc;
CREATE TABLE IF NOT EXISTS warehouse  (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS district   (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS customer   (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS new_order  (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS orders     (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS order_line (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS stock      (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS item       (...) SPLIT INTO 1 TABLETS;
CREATE TABLE IF NOT EXISTS history    (...) SPLIT INTO 1 TABLETS;
```

實際 column 定義以 [go-tpc tpcc schema](https://github.com/pingcap/go-tpc/blob/v1.0.12/tpcc/ddl.go) 為準，wrapper 從 go-tpc source 抽 DDL 套上 `SPLIT INTO 1 TABLETS` 後 pre-create。

**hard gate**：
```bash
yb-admin --master_addresses=172.24.40.32:7100,...:7100 list_tablets ysql.tpcc
# 依 §7.5.4 表清單比對
```

Source: [CREATE TABLE — SPLIT INTO](https://docs.yugabyte.com/stable/api/ysql/the-sql-language/statements/ddl_create_table/) / [Tablet splitting](https://docs.yugabyte.com/stable/architecture/docdb-sharding/tablet-splitting/) / [`ysql_num_shards_per_tserver`](https://docs.yugabyte.com/stable/reference/configuration/yb-tserver/#ysql-num-shards-per-tserver)

#### 7.5.4 hard gate 表清單與 fail-closed 流程

**TPC-C schema 共 9 張表，本 PoC 全部鎖定**（取消「不鎖 item / history」的例外，因為 YBDB 3 tservers 預設不會自然 1 shard，且 history 是 Payment append 高頻寫入表）：

| TPC-C 表 | 性質 | 預期 row 數 | 1s 拓撲預期 | 3s 拓撲預期 |
|---|---|---:|---:|---:|
| warehouse | PK=w_id 1..128 | 128 | 1 | 3 |
| district | PK=d_w_id, d_id | 1,280 | 1 | 3 |
| customer | 主表 | 3,840,000 | 1 | 3 |
| new_order | 主表 | ~1,152,000 | 1 | 3 |
| orders | 主表 | 3,840,000 | 1 | 3 |
| order_line | 主表 | ~38,400,000 | 1 | 3 |
| stock | 主表 | 12,800,000 | 1 | 3 |
| item | 靜態 100K rows | 100,000 | 1 | 3 |
| history | append-only（Payment 寫入） | 不定 | 1 | 3 |

**hard gate 流程**：
```
prepare 完成 → 對 9 張表逐張查 shard 數（只算 primary index / row data，過濾 secondary）
            → 若任一表 shard 數 ≠ 預期 → fail-closed，abort 該組
            → 全 9 張表通過 → 寫 prepare/shard-count.txt → 繼續 ANALYZE
```

**Gate SQL（過濾 secondary index 後計數）**：

```sql
-- TiDB
SELECT TABLE_NAME, COUNT(*) AS region_count
  FROM information_schema.tikv_region_status
  WHERE DB_NAME='tpcc' AND IS_INDEX=0
  GROUP BY TABLE_NAME;

-- CRDB
SELECT table_name, count(*) AS range_count
  FROM crdb_internal.ranges
  WHERE database_name='tpcc' AND index_name='primary'
  GROUP BY table_name;

-- YBDB
yb-admin --master_addresses=... list_tablets ysql.tpcc <table_name>
```

每張表 shard 數 dump 寫入 `artifacts/prepare/shard-count.txt`，格式：
```
table=warehouse expected=3 actual=3 pass=true
table=district  expected=3 actual=3 pass=true
table=customer  expected=3 actual=3 pass=true
table=new_order expected=3 actual=3 pass=true
table=orders    expected=3 actual=3 pass=true
table=order_line expected=3 actual=3 pass=true
table=stock     expected=3 actual=3 pass=true
table=item      expected=3 actual=3 pass=true
table=history   expected=3 actual=3 pass=true
overall_pass=true
```

**TiDB / CRDB / YBDB split / pre-create SQL** 全部 9 張表都套用（§7.5.1 / §7.5.2 / §7.5.3）。

### 7.4 Active isolation gate（三家共用，兩層）

gate 採**兩層驗證**確保 go-tpc 實際 workload isolation 與宣稱一致：

#### Layer A — DB active gate（用 client 連線，BEGIN..COMMIT 內看 active 值）

**TiDB**（mysql client，DSN 與 go-tpc 同）：
```bash
mysql -h $TIDB_HOST -P $TIDB_PORT -u $TIDB_USER tpcc \
  -e "SET SESSION transaction_isolation='READ-COMMITTED'; \
      SET SESSION tidb_txn_mode='pessimistic'; \
      BEGIN; SELECT @@transaction_isolation, @@tidb_txn_mode; COMMIT;" \
  > artifacts/gate/isolation-db.txt
# Expected by iso:
#   rc     →  READ-COMMITTED  / pessimistic
#   rr     →  REPEATABLE-READ / pessimistic   (SET SESSION transaction_isolation='REPEATABLE-READ')
#   strict →  REPEATABLE-READ / pessimistic   (TiDB strict ≡ rr, native 最強)
```

**CRDB / YBDB**（psql 用 URL-style connection string 帶 `$ISO_CONN_PARAMS`，**不用 `PGOPTIONS`**）：
```bash
psql "postgres://${USER}@${HOST}:${PORT}/tpcc?${PG_CONN_RC}" \
  -c "BEGIN; SHOW transaction_isolation; COMMIT;" \
  > artifacts/gate/isolation-db.txt
# Expected by iso (using $PG_CONN_RC / $PG_CONN_RR / $PG_CONN_STRICT):
#   rc     →  read committed
#   rr     →  repeatable read
#   strict →  serializable
```

#### Layer B — driver DSN gate（用 go-tpc 同 binary probe，確保 driver 解析正確）

寫一個短 Go probe（或用 `go-tpc tpcc run --warehouses=1 --time=2s --threads=1 -d ...` 並 grep 啟動 log 內的 session var），確保 go-tpc 用的 driver 真的把 `--conn-params` 套到 session：

```bash
# 範例：用 go-tpc 同 binary 對同一 DSN 跑 2s probe
go-tpc tpcc run -d postgres \
  -H $HOST -P $PORT -U $USER -D tpcc \
  --conn-params "$PG_CONN_RC" \
  --warehouses=1 --time=2s --threads=1 \
  --output=/tmp/probe-stdout.txt 2>&1 | tee artifacts/gate/isolation-driver.txt
# probe 結束後，由 wrapper 在同 DSN 開連線執行 SHOW 驗證
```

任一層不符合 → 該組標 invalid，**fail closed**，不進入 run。

#### go-tpc `--isolation` 參數處理

go-tpc v1.0.12 有 `--isolation` flag（預設 `0` = 不設，讓 connection default 生效）。本 PoC **不使用 `--isolation`**（保留預設 0），完全靠 conn-params 控制。否則 driver 會用 `sql.TxOptions{Isolation: ...}` 覆寫每筆 transaction，shadowing connection default。
Source: <https://github.com/pingcap/go-tpc/blob/v1.0.12/tpcc/workload.go>

## 8. 測試流程

### 8.1 八階段

```
Phase 1  deploy       Ansible 部署 + 健康驗證
Phase 2  config       套對齊參數（WAL / auto-stats / pessimistic / cluster setting 防漂移）
                      — 不在此設 isolation default（走 connection-string）
Phase 3  prepare      強制 DROP+CREATE database → go-tpc prepare 128W → --check-all
                      → quiesce 5m → ANALYZE → dump EXPLAIN → hotspot snapshot
Phase 4  gate         OS gate + chrony gate + disk gate + cluster health + active isolation 驗證
                      （go-tpc 用的 conn-params 開連線後 BEGIN..SHOW..COMMIT）
Phase 5  run          1 次 cold-reset → warmup 20m → run 5m × 5 (per threads 水位)
                      go-tpc 帶 --conn-params 強制 isolation
Phase 6  collect      .31 端蒐 artifacts 到 /tmp/poc-tpcc/artifacts/<db>-vm-1node-<iso>-<ts>/
Phase 7  fetch        MAC rsync 拉回 → 清 .31:/tmp/poc-tpcc/artifacts/
Phase 8  report       render pipeline-log.md
```

### 8.2 Cold reset + warmup 設計

每組測試開始時做 1 次 cold reset，**5 round 之間不再重啟**：

```
[組開始]
  1. stop DB process（per-DB 指令）
  2. sync
  3. echo 3 > /proc/sys/vm/drop_caches
  4. start DB process
  5. poll until SELECT 1 OK
  6. sleep 60s
  7. warmup 20m（不收集數據）
[5 round 開始]
  for r in 1..5:
    run 5m, 收 go-tpc output + OS monitor + DB log diff + client monitor
    sleep 60s
  取 round 2-5 median tpmC（丟 round 1）
```

**設計依據**：原本選項是「每 round restart + drop_caches」，但會「低估」三家數字 3–25%（plan cache / metadata / lease 反覆重建），改採折衷拉長 warmup 並保留 round 1 → round 5 的穩態觀察。對應命名：`vm-1node-<iso> / RF=1 / steady-after-cold-reset`。

**Warmup 縮短影響（20m → 5m）**：

| 使用情境 | 允許性 | 影響 |
|---|---|---|
| Pipeline smoke test | 可接受 | 可快速驗證 deploy / gate / prepare / run / collect 是否串通 |
| Phase A vm-1node 正式數據 | 不建議 | tpmC 可能偏低，P95/P99 易混入 cold cache / plan cache / compaction 成本 |
| Phase B-F vm-3node 正式數據 | 禁止作正式比較 | 會放大 Region/Range/Tablet split、leader/lease placement、Raft cache 尚未穩定的差異 |

若為節省時間把 `WARMUP_SEC` 暫改為 `300`，該次結果必須在 `pipeline-log.md` 與 `summary.json` 標記為 `quick-run` 或 `smoke-test`，不得納入正式 median tpmC / scale-out ratio / HAProxy delta 結論。正式 PoC 數據仍以 `WARMUP_SEC=1200` 為準。

**Warmup threads 調整影響（64 → 128）**：

| 設定 | 適用性 | 影響 |
|---|---|---|
| `warmup_threads=64` | 正式 baseline | 壓力足以預熱 cache / plan / connection pool，但不把 warmup 本身變成最高壓測試 |
| `warmup_threads=128` | 僅限 exploratory / quick-run | 可能更快觸發熱點、compaction、split、Raft/lease 調整，但也可能留下 write backlog / compaction debt |

正式 PoC 固定 `warmup_threads=64`。若改用 `128`，該次結果必須在 `pipeline-log.md` 與 `summary.json` 標記 `warmup_threads=128` 與 `result_scope=exploratory`，不得與 `warmup_threads=64` 的正式結果混算 median tpmC、scale-out ratio 或 HAProxy delta。

### 8.3 Round 採樣策略

每個 `<db, iso, threads>` 組合跑 5 round × 5 min，**丟 round 1，取 round 2-5 的 median** 為代表 tpmC。本輪 4 個 threads 水位（16/32/64/128）各跑 5 round，每組合共 5 round → 每個 `<db, iso>` 共 20 round。

### 8.4 Retry / abort 統計口徑（必明確）

**go-tpc v1.0.12 執行參數**（依官方 CLI 實際 flag）：
```bash
# CRDB / YBDB (PostgreSQL 協定)
go-tpc tpcc run \
  -d postgres \
  -H $DB_HOST -P $DB_PORT -U $USER -D tpcc \
  --conn-params "$ISO_CONN_PARAMS" \
  --warehouses=128 \
  --time=5m \
  --threads=$THREADS \
  --output=plain \
  2>&1 | tee /tmp/poc-tpcc/artifacts/.../go-tpc-stdout.txt

# TiDB (MySQL 協定)
go-tpc tpcc run \
  -d mysql \
  -H $DB_HOST -P $DB_PORT -U root -D tpcc \
  --conn-params "$ISO_CONN_PARAMS" \
  --warehouses=128 \
  --time=5m \
  --threads=$THREADS \
  --output=plain \
  2>&1 | tee /tmp/poc-tpcc/artifacts/.../go-tpc-stdout.txt
```

`$ISO_CONN_PARAMS` 對應 §7.1–7.3 表格之值。

> **CLI 注意**（依 go-tpc v1.0.12 source `cmd/go-tpc/main.go` / `tpcc.go` 實證）：
> - **無 `--max-retries`** flag（僅 `prepare` 有 `--retry-count` / `--retry-interval`，`run` 不接受）
> - `--output` **是 style 不是 file**，合法值 `plain|table|json`；stdout 用 shell `tee` 落地
> - **不要設 `--isolation`**：預設 `0` = 由 connection default 決定（這正是本 PoC 想要的）。若設了 `--isolation`，driver 會在每筆 transaction 用 `sql.TxOptions{Isolation: ...}` 覆寫 conn-params 設的 session default。
>
> Sources:
> - <https://github.com/pingcap/go-tpc/blob/v1.0.12/cmd/go-tpc/main.go>
> - <https://github.com/pingcap/go-tpc/blob/v1.0.12/cmd/go-tpc/tpcc.go>
> - <https://github.com/pingcap/go-tpc/blob/v1.0.12/tpcc/workload.go>

**Retry 行為說明**：

go-tpc run 沒有顯式 retry flag；transaction 內部失敗（含 SERIALIZABLE conflict / deadlock）會由 driver 自然處理或視為 abort。本 PoC 的 retry/abort 統計依賴：
- go-tpc stdout 內 `Failed` / `Error` 計數行
- DB log diff 補抓 SQLSTATE 分類
- 若兩者都取不到 → 該欄位 `N/A`，禁止下「無 retry」結論

**資料來源映射**（每欄位明列來源）：

| 欄位 | 取自 | 取不到的 fallback |
|---|---|---|
| tpmC (raw) | go-tpc stdout `tpmC: ...` 行 | invalid round |
| New-Order / Payment / Delivery / Order-Status / Stock-Level mix % | go-tpc stdout `Summary` 段 | invalid round |
| P50 / P95 / P99 | go-tpc stdout per-transaction latency 區段（NewOrder 為主） | invalid round |
| retry count | go-tpc stdout `retry: N` 行（若版本未輸出，由 wrapper parse stderr 計數 `retry` 關鍵字） | 欄位標 **`N/A`**，禁止下「無 retry」結論 |
| abort count | go-tpc stdout `abort/error: N` 行 + DB log diff 計數 | 欄位標 **`N/A`** |
| SQLSTATE histogram | DB log diff（TiDB tidb.log / CRDB cockroach.log / YBDB postgres.log）grep `SQLSTATE=` | 欄位標 **`N/A`**，附 raw log 路徑 |
| retry rate | (retry count) / (success + retry)；若 retry=N/A 則 retry rate=N/A | — |
| tpmC (ex-abort) | tpmC raw × (1 − abort_count / total_txn)；若 abort=N/A 則 ex-abort=N/A | — |

retry **必須計入 transaction latency**（go-tpc 預設行為）。所有取不到的欄位以 `N/A` 顯示於 pipeline-log.md，**禁止根據缺失欄位下結論**。

## 9. Phase Idempotency（防狀態污染）

### 9.1 .phase-lock 機制

每個 phase 在 artifacts dir 寫 lock 檔，同一 `<db, topology, iso, ts>` 不允許並行：

```
artifacts/<db>-vm-1node-<iso>-<ts>/
├── .lock-deploy
├── .lock-prepare-db
├── .lock-config
├── .lock-gate
├── .lock-prepare
├── .lock-run
└── ...
```

每個 phase 開始時 `flock` 對應 lock 檔；結束後寫 `<phase>.done` 含 schema：
```json
{
  "phase": "prepare",
  "db": "tidb",
  "topology": "vm-1node",
  "iso": "rc",
  "ts": "2026-05-15T16:00:00+08:00",
  "db_version": "v8.5.4",
  "schema_checksum": "sha256:...",
  "warehouses": 128,
  "duration_sec": 1234
}
```

### 9.2 phase 前置驗證

| Phase | 前置驗證 | 行為 |
|---|---|---|
| config | 套對齊參數（**不含 isolation default，isolation 走 conn-params**） | 只設 auto-stats / pessimistic / cluster setting |
| prepare | **強制** `DROP DATABASE IF EXISTS tpcc; CREATE DATABASE tpcc;` 後 go-tpc prepare | 不接受「row count=0 就跳過 drop」；YSQL/CRDB 沒有 `CREATE IF NOT EXISTS` 語法，wrapper 應容忍 `duplicate_database` (SQLSTATE 42P04) error |
| prepare 完成 | 寫 `prepare.done` 含 DB version / iso / warehouse / schema checksum / conn-params hash | run 階段 verify |
| gate | 用 `<iso>` 對應的 conn-params 開連線，`BEGIN; SHOW transaction_isolation; COMMIT;` 與預期一致 | **fail closed**，不一致則 abort，不進入 run |
| run | 比對 `prepare.done` conn-params hash 與當前 run 的 conn-params 一致 | 不一致直接 fail |
| report | 只讀 immutable artifact dir | 除非 `FORCE=1` 否則禁止覆寫既有 report |

### 9.3 verify / clean targets

集中於 §11.2，命名 `verify-phase-vm1-<db>-<iso>` 與 `clean-tpcc-state-<db>`。

## 10. Gate 機制（測試前/中強制驗證）

### 10.1 OS gate（preflight，artifacts/gate/os-gate.txt）

```bash
# THP 必須為 [never]
grep -q '\[never\]' /sys/kernel/mm/transparent_hugepage/enabled || exit 1
[ "$(sysctl -n vm.swappiness)" -le 5 ] || exit 1
[ "$(sysctl -n vm.dirty_background_ratio)" -le 10 ] || exit 1
[ "$(sysctl -n vm.dirty_ratio)" -le 40 ] || exit 1
[ "$(ulimit -n)" -ge 65536 ] || exit 1
[ "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo performance)" = "performance" ] || exit 1
chronyc tracking | grep -E 'Stratum|System time'
```

### 10.2 chrony offset gate（artifacts/gate/chrony-gate.txt）

`.31` 與目標 DB node 時差 **< 100ms**：
```bash
ssh root@$DB_HOST 'chronyc tracking | grep "System time"'
# 與 .31 自己 chronyc tracking 比對 offset
```

### 10.3 cluster health + active isolation gate（artifacts/gate/cluster-health.txt + isolation.txt）

詳見 §7.4。重點：
- 用**與 go-tpc 相同的 conn-params** 開連線
- 在 `BEGIN..COMMIT` 內 `SHOW transaction_isolation`（CRDB 官方要求在 transaction 內看才是 active 值）
- 結果必須**完全等於** `<iso>` 預期；不一致 → fail closed
- 額外輔助驗證：
  - CRDB: `SHOW CLUSTER SETTING sql.txn.read_committed_isolation.enabled` = true
  - YBDB: `curl :9000/varz | grep yb_enable_read_committed_isolation|ysql_enable_auto_analyze|durable_wal_write`

### 10.4 Client (.31) saturation gate（artifacts/runs/round-N/client-cpu.txt）

run 期間在 `.31` 上同步監控（取代之前的 single-snapshot `top`）：
```bash
# run 期間整段 sampling，每秒 1 筆
mpstat 1 $((RUN_SEC + 5)) > artifacts/runs/round-N/mpstat.txt &
pidstat -u -p $GO_TPC_PID 1 $((RUN_SEC + 5)) > artifacts/runs/round-N/client-cpu.txt &
```

**Gate 條件**（run 結束後計算）：
- 從 mpstat 算 **host idle p95 ≥ 30%**
- 從 pidstat 算 **go-tpc process CPU p95 < vCPU 數 × 90%**（4 vCPU client → < 360%）

任一違反 → 該 round 標 **invalid**，pipeline-log 註明「client saturation」。

### 10.5 Hotspot / distribution snapshot（artifacts/prepare/hotspot.txt）

prepare 完成後 dump 三家分佈資料**作為觀察記錄**，**vm-1node 階段不作為 hard gate**（單節點 leader trivially 集中）：

```bash
# TiDB
mysql -e "SHOW TABLE tpcc.warehouse REGIONS;"
mysql -e "SHOW TABLE tpcc.stock REGIONS;"

# CRDB
cockroach sql --insecure -e "SHOW RANGES FROM DATABASE tpcc;"
cockroach sql --insecure -e "SELECT lease_holder, count(*) FROM crdb_internal.ranges WHERE database_name='tpcc' GROUP BY lease_holder;"

# YBDB
yb-admin --master_addresses ... list_tablets ysql.tpcc
curl -s http://$YBDB:9000/tablet-servers
```

> **vm-3node 階段**才執行 hot-shard gate：對 per-range/per-tablet write metrics 採樣，若單分片承載 > 20% write QPS → 標 hotspot 不橫向比較。本輪 vm-1node 僅記錄分佈供 baseline 對照。

### 10.6 TPC-C transaction mix 驗證（artifacts/runs/round-N/mix.txt）

依 [TPC-C v5.11 spec](https://www.tpc.org/tpc_documents_current_versions/pdf/tpc-c_v5.11.0.pdf) §5.2.3 最低 mix 要求：

| 交易類型 | 最低占比 |
|---|---|
| Payment | ≥ 43% |
| Order-Status | ≥ 4% |
| Delivery | ≥ 4% |
| Stock-Level | ≥ 4% |

New-Order 是 reported throughput（tpmC = New-Order TPM），**無最低占比要求**，典型 mix 約 45%。

每 round 從 go-tpc stdout `Summary` 段抽 mix %，違反任一最低值則該輪標 invalid。

## 11. Make target 規劃

### 11.1 命名規範

| Pattern | 範例 |
|---|---|
| `test-tpcc-<topo>-<db>-<iso>` | `test-tpcc-vm1-tidb-rc` / `test-tpcc-vm1-tidb-strict` |
| `test-tpcc-<topo>-all-<iso>` | `test-tpcc-vm1-all-rc` |
| `<phase>-<topo>-<db>-<iso>` | `deploy-vm1-tidb-rc` / `run-vm1-crdb-strict` |
| `drop-<topo>-<db>` | `drop-vm1-ybdb` |
| `clean-tpcc-<scope>` | `clean-tpcc-artifacts` / `clean-tpcc-state-tidb` |

`<topo>` ∈ { `vm1`, `vm3`, `vm3hap` }（本輪 `vm1`）
`<db>` ∈ { `tidb`, `crdb`, `ybdb` }
`<iso>` ∈ { `rc`, `rr`, `strict` }

### 11.2 Makefile 變數（SSOT 必明列，腳本不可自由發揮）

```makefile
# 客戶端
TPCC_CLIENT       := root@172.24.40.31
TPCC_BASE         := /tmp/poc-tpcc
TPCC_ARTIFACTS    := $(TPCC_BASE)/artifacts

# DB endpoints (vm-1node — 都跑在 172.24.40.32)
TIDB_HOST         := 172.24.40.32
TIDB_PORT         := 4000
TIDB_USER         := root
TIDB_DB           := tpcc

CRDB_HOST         := 172.24.40.32
CRDB_PORT         := 26257
CRDB_USER         := root
CRDB_DB           := tpcc

YBDB_HOST         := 172.24.40.32
YBDB_PORT         := 5433
YBDB_USER         := yugabyte
YBDB_DB           := tpcc

# Isolation conn-params (URL-encoded)
# TiDB（MySQL DSN session vars）
TIDB_CONN_RC      := transaction_isolation=%27READ-COMMITTED%27&tidb_txn_mode=%27pessimistic%27
TIDB_CONN_RR      := transaction_isolation=%27REPEATABLE-READ%27&tidb_txn_mode=%27pessimistic%27
TIDB_CONN_STRICT  := $(TIDB_CONN_RR)        # TiDB strict == rr (REPEATABLE READ 為 native 最強)

# CRDB / YBDB（PostgreSQL options GUC）
PG_CONN_RC        := options=-c%20default_transaction_isolation%3Dread%20committed
PG_CONN_RR        := options=-c%20default_transaction_isolation%3Drepeatable%20read
PG_CONN_STRICT    := options=-c%20default_transaction_isolation%3Dserializable

# CRDB RR tier 需先 opt-in（cluster setting）
CRDB_RR_OPTIN     := SET CLUSTER SETTING sql.txn.repeatable_read_isolation.enabled = true;

# go-tpc 參數
GOTPC_VERSION     := v1.0.12
GOTPC_BIN         := $(TPCC_BASE)/bin/go-tpc
GOTPC_SHA256      := <填入鎖定值，bootstrap 時驗證>
WAREHOUSES        := 128
THREADS_LIST      := 16 32 64 128
ROUNDS            := 5
WARMUP_SEC        := 1200      # 20m
RUN_SEC           := 300       # 5m
ROUND_SLEEP_SEC   := 60
# 注意：go-tpc v1.0.12 `run` 無 --max-retries flag（僅 prepare 有 --retry-count）
# Retry 行為由 driver / DB 內部處理，本 PoC 從 stdout + DB log 統計
```

### 11.3 本輪需新增的 targets

```
# 一鍵 end-to-end
test-tpcc-vm1-tidb-rc / -crdb-rc / -ybdb-rc           # 主對標
test-tpcc-vm1-tidb-rr / -crdb-rr / -ybdb-rr           # RR/SI 階對照
test-tpcc-vm1-tidb-strict / -crdb-strict / -ybdb-strict  # 各家最強
test-tpcc-vm1-all-rc                                   # 三家 RC 串跑
test-tpcc-vm1-all-rr                                   # 三家 RR 串跑
test-tpcc-vm1-all-strict                               # 三家 strict 串跑

# 細分 phase（可單獨重跑）
deploy-vm1-{tidb,crdb,ybdb}                            # 部署 DB process
config-vm1-{tidb,crdb,ybdb}                            # 套**非 isolation** 對齊參數
                                                       # (auto-stats / pessimistic / cluster setting)
                                                       # ⚠️ 不設 isolation default，isolation 走 conn-params
prepare-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}               # DROP+CREATE database + go-tpc prepare
                                                       # iso suffix 影響 artifact 路徑，不影響 DB 端設定
gate-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}                  # OS / chrony / disk preflight gate
run-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}                   # active isolation gate + cold-reset + warmup + 5 round × 4 threads
                                                       # go-tpc 帶對應 --conn-params
collect-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}
fetch-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}
report-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}

# Idempotency / utility
verify-phase-vm1-{tidb,crdb,ybdb}-{rc,rr,strict}          # 驗證 phase chain 完整
clean-tpcc-state-{tidb,crdb,ybdb}                      # 清 DB tpcc + artifacts
bootstrap-tpcc-client                                  # 一次性 .31 上 go-tpc + scripts 部署
drop-vm1-{tidb,crdb,ybdb}
clean-tpcc-artifacts                                   # 清 .31:/tmp/poc-tpcc/artifacts/
```

> Phase 順序（與目前 Make target 一致）：deploy → preflight gate → prepare → run（含 active isolation gate）→ collect → fetch → report。
> 注意 active isolation gate 由 `run.sh` 在 cold-reset 後、正式 warmup 前呼叫 `gate-isolation.sh`；`gate.sh` 僅做 OS / chrony / disk preflight。

### 11.4 MAC-detached suite execution（長時間 benchmark 的標準作業模型）

**問題**：MAC 是工作設備，會蓋上螢幕、切換網路、被 Codex / Claude Code session 中斷。
若 prepare / run（合計 ~2.5h/組）停在 MAC ssh foreground，session 一斷，benchmark 中斷，artifact 不完整。
24 case 測試（vm1 9 case / 實跑 8 組 + vm3 12 組 + vm3hap 3 組）若全用 foreground，工時碎片化機率極高。

**設計原則**：MAC 只負責「下發」，**.31 負責所有長時間作業**。

```
MAC (terraform / ansible / dispatch)         .31 (long-running benchmark)
─────────────────────────────────────────────────────────────────────
1. new-idc-vms          (terraform)
2. bootstrap-tpcc-client (rsync scripts) ──→  /tmp/poc-tpcc/scripts/
3. deploy-vm1-<db>      (ansible)
4. ssh .31 'launch-vm1-suite.sh ...'    ──→  nohup setsid run-vm1-suite.sh &
                                              ├─ gate.sh   (TS=X)
   ssh 立即 return（MAC 可關機）              ├─ prepare.sh (TS=X)
                                              ├─ run.sh    (TS=X)
                                              └─ collect.sh (TS=X)
5. (任意時間) make status-vm1-<db>-<iso>  ←── runlocks/.lock + .*.done markers
6. (網路穩定時) make fetch-vm1-<db>-<iso> TPCC_TS=X ←── rsync 指定 artifact 回 MAC
```

**Make targets**：

| Target | 角色 | 阻塞 |
|---|---|---|
| `make vm1-<db>-<iso>` | new-idc-vms + bootstrap + deploy + 遠端 detached suite 啟動 | MAC 阻塞至 deploy 完成（~10min） |
| `make status-vm1-<db>-<iso>` | 查 lock / artifact markers / log tail | 不阻塞，read-only |
| `make fetch-vm1-<db>-<iso> TPCC_TS=<ts>` | rsync 指定 artifact .31 → MAC | MAC 阻塞於 rsync（~minutes） |
| `make gate/prepare/run/collect-vm1-<db>-<iso>` | 個別 phase 重跑（除錯用）| 個別 phase 時長 |

**TPCC_TS 固定**：
`vm1-<db>-<iso>` 在 MAC 端用 `TPCC_TS := $(shell date ...)`（`:=` 確保只生成一次），透過 ssh `--ts $(TS)` 傳給 .31。run-vm1-suite.sh 將同一個 TS 依序傳給 gate / prepare / run / collect。
**禁止**在 .31 端重新生成 TS：lineage 一旦斷裂，後續 fetch 與報表分析會把 gate artifact 與 prepare / run artifact 切成不同目錄，造成 cross-phase 對照困難。

**Lock 與重複啟動防護**（`/tmp/poc-tpcc/runlocks/<db>-<topo>-<iso>.lock`）：

```
pid=<PID>
db=<db>
iso=<iso>
topology=<topo>
ts=<ts>
start_time=<ISO-8601>
log_path=<path>
```

- 啟動時若 lock 存在且 `kill -0 PID` 成功 → 拒絕第二次啟動（fail closed）
- Lock 存在但 PID 已死 → 視為 stale，**只提示人工確認，不自動清理**（避免覆蓋未完成 artifact）
- Suite 正常完成 → 刪除 lock；失敗 → 保留 lock 供 inspect

**Fetch 為什麼不在遠端 suite 內**：
.31 不一定能主動回連 MAC（DHCP 變動、VPN 斷線、MAC 在 NAT 後）。fetch 採「MAC 主動 pull」模型，使用者在網路穩定時手動執行，並建議帶 `TPCC_TS=<ts>` 精準拉回該次 suite artifact；未指定 `TPCC_TS` 時才使用既有 wildcard 拉回同組所有 artifact。
若未來需自動 fetch，前提是 .31 對 MAC SSH 可達（目前未保證）。

**狀態檢查（不啟動、不修改）**：
```bash
make status-vm1-tidb-rc
# 輸出：lock 狀態 + 五個 .*.done markers + 最近 20 行 log tail
```

## 12. Artifacts 結構

```
artifacts/<db>-vm-1node-<iso>-<ts>/
├── .lock-<phase>                    # 每 phase 的 lock
├── .<phase>.done                    # 每 phase 完成標記 + JSON checksum
├── env/
│   ├── db-version.txt
│   ├── go-tpc-version.txt           # version + sha256
│   ├── kernel.txt
│   ├── sysctl.txt
│   ├── thp.txt
│   ├── ulimit.txt
│   ├── governor.txt
│   ├── chrony-offset.txt
│   └── disk-fio.txt                 # 可選：fio 30s baseline
├── db-config/
│   ├── effective-config.txt
│   ├── cluster-settings.txt
│   └── isolation.txt                # 實測 SHOW transaction_isolation 結果
├── gate/
│   ├── os-gate.txt
│   ├── chrony-gate.txt
│   ├── disk-gate.txt
│   ├── cluster-health.txt
│   ├── isolation.txt                # 隔離級驗證（與 config 對應）
│   └── varz.txt                     # YBDB 限定
├── prepare/
│   ├── go-tpc-prepare.log
│   ├── check-all.log                # go-tpc tpcc check
│   ├── analyze.log
│   ├── explain-NewOrder.txt
│   ├── explain-Payment.txt
│   ├── explain-Delivery.txt
│   ├── hotspot.txt                  # region/range/tablet 分佈快照
│   └── stats-snapshot.txt           # row count / modified ratio
├── runs/
│   └── threads-<N>/                 # N ∈ {16,32,64,128}
│       └── round-<R>/               # R ∈ {1..5}，round-1 後續分析會被丟掉
│           ├── go-tpc-stdout.txt
│           ├── mix.txt              # transaction mix % 驗證結果
│           ├── retry-stats.txt      # retry/abort/SQLSTATE histogram
│           ├── vmstat-1s.txt
│           ├── iostat-1s.txt
│           ├── pidstat-1s.txt
│           ├── mpstat.txt           # client host idle 統計
│           ├── client-cpu.txt       # go-tpc process CPU
│           ├── sar-net.txt
│           ├── free-1m.txt
│           └── db-error-diff.txt    # run 起訖 DB log diff
└── summary.json                     # render-pipeline.sh 用的彙整數據（見 §13.2 schema）
```

## 13. 報告產出規範

### 13.1 pipeline-log.md 必含區塊

每組產出 `results/<db>-tc1/S-BASE/vm-1node-<iso>/pipeline-log.md`：

```markdown
## 0. Benchmark boundary 聲明（render-pipeline.sh 自動寫入）

> 本測試為 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C。
> （CRDB vm-1node 額外加 single-node 不適合 perf testing 聲明）

## 1. 版本資訊
- DB 版本 / commit / build date
- go-tpc 版本 + sha256
- OS / kernel
- Test timestamp / duration

## 2. 對齊設定快照
- Memory budget / WAL durable / Auto-statistics / 隔離級實測值 / pessimistic mode (TiDB)

## 3. Gate 結果
- OS / chrony offset / cluster health / isolation 驗證 / client saturation / disk

## 4. Prepare 階段
- prepare 耗時 / check-all 結果 / ANALYZE / EXPLAIN dump / hotspot snapshot / stats snapshot

## 5. Run 結果（每 threads 水位一張表）

### threads = 64（主軸對標）

| Round | tpmC raw | tpmC ex-abort | Mix NewOrder/Pay/OS/Del/SL % | P50 | P95 | P99 | retry | abort | SQLSTATE top | 備註 |
|---|---|---|---|---|---|---|---|---|---|---|
| 1 (丟) | ... | ... | ... | ... | ... | ... | ... | ... | ... | warmup recovery |
| 2 | ... | ... | ... | ... | ... | ... | ... | ... | ... | |
| 3-5 | ... | | | | | | | | | |
| **Median (2-5)** | ... | ... | ✓/✗ vs §10.6 minima | ... | ... | ... | ... | ... | ... | 代表值 |

（threads = 16 / 32 / 128 同表結構）

## 6. OS / DB 資源觀察
- 峰值 CPU%（DB process）/ 峰值 RSS / I/O wait %
- DB 內部錯誤 / retry 計數 / SQLSTATE histogram
- Client process 峰值 CPU% / host idle p95
```

### 13.2 summary.json schema（render-pipeline.sh 唯一資料來源）

```json
{
  "meta": {
    "db": "tidb|crdb|ybdb",
    "topology": "vm-1node|vm-3node-1s1r|vm-3node-1s3r|vm-3node-3s1r|vm-3node-3s3r|vm-3node-haproxy-3s3r",
    "iso": "rc|rr|strict",
    "timestamp": "ISO-8601",
    "db_version": "string",
    "gotpc_version": "string",
    "gotpc_sha256": "string",
    "kernel": "string",
    "warehouses": 128
  },
  "gates": {
    "os": "pass|fail",
    "chrony_offset_ms": 12,
    "isolation_expected": "READ-COMMITTED|REPEATABLE-READ|read committed|repeatable read|serializable",
    "isolation_actual": "string",
    "isolation_pass": true,
    "cluster_health": "pass|fail",
    "disk_free_gb": 80
  },
  "prepare": {
    "duration_sec": 1234,
    "check_all_pass": true,
    "analyze_pass": true,
    "hotspot_snapshot": "artifacts/.../hotspot.txt"
  },
  "runs": [
    {
      "threads": 64,
      "rounds": [
        {
          "round": 1,
          "valid": false,
          "invalid_reason": "warmup-recovery (discarded)",
          "tpmC_raw": 1234.5,
          "tpmC_ex_abort": 1230.1,
          "mix": {"NewOrder": 45.2, "Payment": 43.1, "OrderStatus": 4.0, "Delivery": 4.0, "StockLevel": 4.0},
          "mix_pass": true,
          "latency_ms": {"p50": 12.3, "p95": 45.6, "p99": 80.1},
          "retry": 12,
          "abort": 3,
          "sqlstate_top": [{"code": "40001", "count": 3}],
          "client_idle_p95": 65.2,
          "client_cpu_p95": 280.5
        }
      ],
      "median_round_2_5": {
        "tpmC_raw": 1230.1,
        "tpmC_ex_abort": 1225.0,
        "p99_ms": 81.3,
        "retry_rate": 0.012
      }
    }
  ]
}
```

欄位取不到 → 該欄位填 `null`，並在 `invalid_reason` 補說明。render-pipeline.sh 依此 schema 渲染 markdown，欄位為 `null` 顯示為 `N/A`。

### 13.3 RC vs RR vs strict 對照表（三組測完後追加在主 README）

```markdown
| DB | vm-1node-rc tpmC | vm-1node-rr tpmC | vm-1node-strict tpmC | rr Δ% | strict Δ% | strict 層級 | 備註 |
|----|------|------|------|------|------|------|------|
| TiDB | ... | ... | ... | ... | ... | RR (= rr) | TiDB rr ≡ strict |
| CRDB | ... | ... | ... | ... | ... | SERIALIZABLE | rr 為 preview |
| YBDB | ... | ... | ... | ... | ... | SERIALIZABLE | rr = SI |
```

## 14. 環境拓撲

```
MAC (orchestrator)
  └── Ansible deploy → IDC VMs (172.24.40.32/33/34)
                          ↓
.31 (TPC-C client, 172.24.40.31, 同 subnet 排除網路品質)
  └── go-tpc → DB node :port
       └── /tmp/poc-tpcc/
           ├── bin/go-tpc (sha256 鎖)
           ├── scripts/
           └── artifacts/<db>-vm-1node-<iso>-<ts>/  → rsync 拉回 MAC 後清除
```

## 15. 設計取捨記錄

| 取捨 | 選擇 | 為何 |
|---|---|---|
| 報表口徑 | 單口徑（不雙口徑） | 縮短維護成本；以「single-node RF=1 對齊基準」誠實揭露 |
| 主對標隔離級 | READ COMMITTED | 三家 production-ready；OLTP 主流；引擎能力非隔離開銷（§5） |
| 隔離成本對照 | 追加 vm-1node-rr 與 vm-1node-strict 兩階 | 量化「升一級 / 升到最強」對 tpmC 影響；TiDB rr ≡ strict（native 最強就是 RR）；CRDB rr 為 preview opt-in |
| Round 間 reset | 1 組 1 次 cold reset，5 round 不重啟 | 避免 round-restart 低估 3–25% |
| Warmup 長度 | 正式數據 20m；5m 僅限 quick-run / smoke-test | 5m 會讓 cold cache、plan cache、compaction、leader/lease placement 影響混入正式數字；見 §8.2 |
| Warmup 併發 | 正式數據固定 64 threads；128 threads 僅限 exploratory / quick-run | 128 threads 會讓 warmup 更接近最高壓，可能預熱更充分，也可能留下 backlog / compaction debt；見 §8.2 |
| Retry policy | go-tpc run 無 retry flag；retry 由 driver/DB 內部處理，從 stdout + DB log 統計 | go-tpc v1.0.12 CLI 實證 |
| TPC-C compliance | 明示為 stress benchmark，非 audited | 避免被質疑「假 TPC-C」 |
| Sharding 對齊 | vm-1node 自然 1 shard；**所有 vm-3node 子拓撲皆 controlled，手動鎖 shard 並 hard gate**（§7.5） | 「production default vs controlled」混合分類已棄用 |
| vm-1node 1 shard × 3 replica | **排除** | 三家官方副本放置規則禁止同 store/node 多 replica（§4.4） |
| 隔離級成本範圍 | 僅在 vm-1node 量化（rc/rr/strict 三 iso）；vm-3node 系列只跑 RC | 完整 quorum 下 isolation 行為非本輪範圍；§6.3 限制聲明 |
| Wall-clock 估算 | 24 case / 實跑 23 組，SSOT 樂觀估 **~65.0 h**；含 conservative buffer **~73 h**（TiDB strict 等同 RR，不另跑） | §6.4 |
| 排程方案 | 建議方案 B：Phase A → review → Phase B–F；分段跑可降低失敗成本 | §6.4.5 |
| CRDB load-based split | 不關 | 官方預設且生產建議；vm-1node 自然不觸發 |
| CRDB 密碼設定 | 不在 `--insecure` 下 SET PASSWORD | 官方不支援；用 HBA trust |
| YBDB auto-analyze flag | `ysql_enable_auto_analyze=false` | 2025.2 正確 flag 名 |
| **Isolation 控制方式** | **走 go-tpc `--conn-params`（PostgreSQL `options` GUC / MySQL DSN session vars）** | CRDB `root` 對 ALTER ROLE default exempt；YBDB DB-level setting 隨 DROP 洗掉；conn-params 是唯一可靠路徑 |
| Active isolation gate | 在 `BEGIN..COMMIT` 內 `SHOW transaction_isolation` 驗證 | CRDB 官方要求 active 值需 transaction 內看；防 default 與 active 不符 |
| Prepare clean | 強制 DROP DATABASE，不接受 row-count fallback；YSQL 容忍 duplicate_database error | 避免殘留 schema/stats 污染 |
| CAP / PACELC | 採 PACELC 描述 | 比 CAP 精確 |
| TiDB 部署模式 | tiup cluster（非 playground） | playground 為 local test，元件不透明 |
| TiDB RC 前提 | pessimistic mode 強制 + gate 驗證 | optimistic mode 下 RC 設定不生效 |
| Client saturation gate | mpstat / pidstat 整段 sampling，p95 為 gate | 避免 single snapshot 漏抓 |
| Hotspot gate 範圍 | vm-1node 僅 snapshot，vm-3node 才做 > 20% gate | 單節點 leader trivially 集中 |
| 客戶端位置 | 172.24.40.31 | 與 DB node 同 subnet，排除網路品質干擾 |
| K8s 與容器化 | 本輪不做 | 範圍聚焦 VM 場景 |

## 16. 後續階段 roadmap

| 階段 | 目標 | 對比意義 |
|---|---|---|
| **Phase A — vm-1node-{rc,rr,strict}**（本輪） | 三家 single-node 三 iso | local engine + 隔離成本對照 |
| Phase B — vm-3node-1s1r-rc | 1 shard / 1 replica，3 物理節點 | cluster framework + remote coord overhead |
| Phase C — vm-3node-1s3r-rc | 1 shard / 3 replica | Raft 3-replica 寫入成本（前提同 shard placement） |
| Phase D — vm-3node-3s1r-rc | 3 shard / 1 replica | sharding 對 OLTP 效應（前提：shard 數鎖定 gate 通過） |
| Phase E — vm-3node-3s3r-rc | 3 shard / 3 replica，direct | sharded + replicated 集群基準 |
| Phase F — vm-3node-haproxy-3s3r-rc | 3 shard / 3 replica + HAProxy | 連線分散效益 |

每階段完成後更新本文件「15. 設計取捨記錄」與 README.md 結果表。
