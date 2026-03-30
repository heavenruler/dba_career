# Multi-Region 同 Key 同時寫入機制比較（TiDB vs YugabyteDB）

## 0. TL;DR

- `same key` 的多地同時寫入，本質是單 key 序列化（serialization）問題，不只是多區部署問題
- TiDB 以 **PD 配發 TSO** 作為全域排序基礎，再透過 **Percolator + 2PC + lock** 處理衝突
- YugabyteDB 在單一 universe 內，以 **Raft leader / log order** 決定單 tablet 寫入順序，HLC 主要提供單調遞增時間戳給 MVCC、快照讀取與複寫使用
- 若是 **單一 cluster / 單一 transaction domain**，兩者都可做到強一致，但都必須接受跨區寫入延遲
- 若是 **active-active 雙向寫同 key**，兩者都不適合當成強一致方案；YugabyteDB xCluster non-transactional 僅能做到 **最後寫入者勝出（LWW）**，不保證完整交易一致性
- TiDB 的核心風險是 **hotspot key 導致 lock contention / retry storm**；YugabyteDB 的核心風險是 **leader 位置與 clock skew 造成延遲放大**

### 一句話判斷

```text
TiDB：時間主導，先用 TSO 排序，再用 lock / 2PC 解決衝突
YugabyteDB：位置主導，先由 leader 排序，再用交易衝突控制與 HLC 管理版本時間
```

## 目錄

- [1. 問題定義](#1-問題定義)
- [2. TiDB 機制（TSO + Percolator 2PC）](#2-tidb-機制tso--percolator-2pc)
  - [2.1 排序機制（TSO）](#21-排序機制tso)
  - [2.2 寫入流程（簡化）](#22-寫入流程簡化)
  - [2.3 衝突處理（核心）](#23-衝突處理核心)
  - [2.4 commit_ts 角色](#24-commit_ts-角色)
  - [2.5 MVCC](#25-mvcc)
  - [2.6 commit latency](#26-commit-latency)
  - [2.7 特性總結](#27-特性總結)
- [3. YugabyteDB 機制（Raft + HLC + MVCC）](#3-yugabytedb-機制raft--hlc--mvcc)
  - [3.1 排序機制](#31-排序機制)
  - [3.2 寫入流程](#32-寫入流程)
  - [3.3 衝突處理](#33-衝突處理)
  - [3.4 Hybrid Logical Clock（HLC）](#34-hybrid-logical-clockhlc)
  - [3.5 MVCC](#35-mvcc)
  - [3.6 commit latency](#36-commit-latency)
  - [3.7 特性總結](#37-特性總結)
- [4. xCluster（YugabyteDB 雙向寫）補充](#4-xclusteryugabytedb-雙向寫補充)
- [5. TiDB vs YugabyteDB 對照](#5-tidb-vs-yugabytedb-對照)
- [6. 核心差異（一句話）](#6-核心差異一句話)
- [7. 架構判斷（DBaaS / Multi-Region）](#7-架構判斷dbaas--multi-region)
- [8. DBA 實務結論](#8-dba-實務結論)
- [9. 延伸關鍵風險](#9-延伸關鍵風險)
- [10. 最終結論](#10-最終結論)

## 1. 問題定義

在 Taiwan / Japan 同時對「同一筆資料（same key）」進行寫入時，系統需解決：

- **Ordering（排序）**：誰先誰後
- **Conflict Resolution（衝突仲裁）**：誰成功、誰失敗
- **Consistency（一致性）**：是否強一致
- **Latency（延遲）**：跨區寫入成本

---

## 2. TiDB 機制（TSO + Percolator 2PC）

### 2.1 排序機制（TSO）

- 由 **PD（Placement Driver）發 TSO**
- 全域唯一且單調遞增


```text
TSO = physical_time(ms) + logical_counter
```

更精確地說，TiDB 的 TSO 可理解為：

```text
[ high bits ] = physical time（milliseconds）
[ low bits  ] = logical counter
```

#### 2.1.1 TiDB TSO 的產生原理

TiDB 由 PD 作為全域時間戳服務，client / TiDB server 在交易開始與提交時向 PD 取得 TSO。

可簡化理解為：

```text
TSO = (physical_ms << logical_bits) + logical_counter
```

產生流程：

1. PD 先讀取目前 wall clock，得到 `physical_ms`
2. 若目前毫秒大於上一個 TSO 的 physical 部分，PD 將 logical counter 歸零或重置到新區間
3. 若仍在同一毫秒內，PD 只遞增 `logical_counter`
4. 回傳組合後的 TSO，保證全域單調遞增

重點：

- `physical_ms` 反映實際時間
- `logical_counter` 解決同一毫秒內多筆請求的排序問題
- 因為由 **單一 PD TSO 服務** 配發，所以 TiDB 屬於 **集中式排序（centralized ordering）**
- transaction 的 `start_ts`、`commit_ts` 都是向 PD 取得的 TSO


👉 結論：

- 所有 transaction 透過 TSO 排序
- 屬於 **集中式排序（centralized ordering）**

---

### 2.2 寫入流程（簡化）

```text
取得 start_ts（PD）
prewrite（寫 lock + value）
commit（取得 commit_ts + 寫入）
```

---

### 2.3 衝突處理（核心）

- 使用 **Percolator 模型**
- 關鍵：**primary lock**

#### 範例


```text
T1 (TW) start_ts = 100
T2 (JP) start_ts = 105

T1: prewrite 成功（拿 lock）
T2: 發現 lock → wait / rollback / retry
```


👉 結論：

- **先拿到 lock 的 transaction 贏**
- start_ts 小者通常較有優勢

---

### 2.4 commit_ts 角色


```text
commit_ts = 新 TSO
且 commit_ts > start_ts
```


用途：

- MVCC 可見性
- 快照讀取（snapshot read）

⚠️ 不用來決定衝突勝負

---

### 2.5 MVCC


```text
(key, commit_ts) → value
```


用途：

- 快照讀取（snapshot read）
- 版本管理

👉 不負責衝突仲裁

---

### 2.6 commit latency

```text
PD (start_ts)
prewrite（Raft）
PD (commit_ts)
commit（Raft）
```

👉 延遲來源：

- PD RTT
- Raft replication
- 2PC

---

### 2.7 特性總結

- 強一致（Snapshot Isolation）
- 集中式時間戳排序（centralized timestamp ordering）
- 衝突 → retry / backoff
- hotspot key → 高衝突風險

---

## 3. YugabyteDB 機制（Raft + HLC + MVCC）

### 3.1 排序機制

👉 **Raft leader（per-tablet）**

- 每個 key 屬於一個 tablet
- 該 tablet 只有一個 leader


```text
所有寫入 → leader → Raft log 排序
```


👉 分散式排序（decentralized ordering, per shard）

---

### 3.2 寫入流程


```text
Client → tablet leader
→ Raft replicate
→ commit（多數派）
```


---

### 3.3 衝突處理

- 使用 **交易衝突控制（transaction conflict control）**
- isolation level：
  - Repeatable Read
  - Serializable

機制：

- fail-on-conflict
- transaction priority
- wound / wait / abort

👉 結果：

- **其中一方會被 abort**
- 非最後寫入者勝出（last-writer-wins, LWW）

---

### 3.4 Hybrid Logical Clock（HLC）


```text
HybridTime = physical + logical
```

更精確地說，YugabyteDB 內部可視為：

```text
[ upper 52 bits ] = physical time（microseconds since epoch）
[ lower 12 bits ] = logical counter
```


用途：

- MVCC 時間戳（MVCC timestamp）
- 快照讀取（snapshot read）
- CDC / replication LSN

👉 HLC 提供**單調遞增的時間戳**，但單一 tablet 內的寫入先後，仍以 **Raft leader / log order** 為主

#### 3.4.1 `yb_get_current_hybrid_time_lsn()` 產生原理

YSQL 可透過以下函式讀到目前節點的 hybrid time：

```sql
SELECT yb_get_current_hybrid_time_lsn();
```

它回傳的是一個 `bigint`，本質上是目前 **HLC 的 64-bit 整數表示**，不是 PostgreSQL WAL LSN。

產生方式可簡化理解為：

```text
hybrid_time_lsn = (physical_microseconds << 12) | logical_counter
```

說明：

- `physical_microseconds` 來自節點 wall clock（epoch microseconds）
- `logical_counter` 用來處理同一微秒內的多事件，或節點收到比本地時鐘更大的時間戳時，維持單調遞增
- 因為高 52 bits 是 physical、低 12 bits 是 logical，所以可直接比較整數大小來判斷新舊

可用下列 SQL 拆解其內容：

```sql
SELECT
  yb_get_current_hybrid_time_lsn() AS hybrid_time_lsn,
  (yb_get_current_hybrid_time_lsn() >> 12) AS physical_usec,
  to_timestamp((yb_get_current_hybrid_time_lsn() >> 12) / 1000000.0) AS physical_ts,
  (yb_get_current_hybrid_time_lsn() & ((1 << 12) - 1)) AS logical_counter;
```

重點：

- 多數低負載場景下，`logical_counter` 常為 `0`
- 高併發、同微秒多事件，或 replica/leader 需要追上更高時間戳時，`logical_counter` 才會增加
- 在 xCluster active-active 的 最後寫入者勝出（last-writer-wins, LWW）情境，實務上就是比較這個 hybrid time 大小

#### 3.4.2 `yb_get_current_hybrid_time_lsn()` 與 xCluster 最後寫入者勝出（LWW）關係

在 xCluster 雙向寫、且採 non-transactional replication 時，可簡化理解為：

```text
Region A update key=K
  -> assign HLC_A
  -> replicate to Region B

Region B update key=K
  -> assign HLC_B
  -> replicate to Region A

conflict resolution:
  compare HLC_A vs HLC_B
  larger hybrid time wins
```

判斷邏輯：

- 若 `HLC_A > HLC_B`，保留 A 版本
- 若 `HLC_B > HLC_A`，保留 B 版本
- 因為 hybrid time 可直接比較大小，所以能實作 **最後寫入者勝出（last-writer-wins, LWW）**

注意：

- 這只適用於 **xCluster non-transactional / active-active 類場景**
- 這不是單一 universe 內 YSQL transaction 的衝突處理方式
- 因為只是版本覆蓋，不保證 index、constraint、跨列/跨表一致性

---

### 3.5 MVCC

- key 尾端帶 timestamp（DocDB）
- 多版本並存

用途：

- 快照讀取（snapshot read）
- 一致性讀取（consistent read，無需 lock）

---

### 3.6 commit latency

#### 單 shard：


```text
1 次 Raft roundtrip
```


#### multi-region：

```text
client → leader RTT
leader → followers RTT（majority）
```

#### global transaction：

- 額外 transaction coordination 成本

---

### 3.7 特性總結

- 強一致（Serializable / RR）
- 分片內 leader 排序（per-shard leader ordering）
- 衝突 → abort（非 retry-first）
- latency 受 leader location 影響

---

## 4. xCluster（YugabyteDB 雙向寫）補充

⚠️ 非同一 transaction domain

- transactional xCluster → 不允許雙向寫
- non-transactional → **最後寫入者勝出（last-writer-wins, by hybrid time）**

風險：

- index inconsistency
- constraint violation

👉 不適合 active-active 同 key 強一致

---

## 5. TiDB vs YugabyteDB 對照

| 面向 | TiDB | YugabyteDB |
| --- | --- | --- |
| 排序來源 | TSO（PD） | Raft leader（per tablet） |
| 排序模型 | 集中式（centralized） | 分散式（decentralized） |
| 衝突仲裁 | lock + start_ts | 衝突控制（conflict control, abort） |
| 是否最後寫入者勝出（LWW） | ❌ | ❌（單 universe） |
| MVCC 角色 | 版本管理 | 版本管理 |
| commit 決策點 | 2PC（client） | Raft（leader） |
| latency 核心來源 | PD + 2PC + Raft | Raft quorum |
| hotspot 行為 | lock contention + retry storm | leader bottleneck |
| multi-region 寫入 | 可，但延遲高 | 可，但依 leader location |
| active-active 同 key | 不建議 | 不建議（需單 universe） |

### 5.1 TiDB TSO vs YugabyteDB HLC

| 面向 | TiDB TSO | YugabyteDB HLC |
| --- | --- | --- |
| 主要用途 | 全域交易排序、`start_ts` / `commit_ts` | 單調時間戳、MVCC、快照讀取、replication ordering 輔助 |
| 產生位置 | PD（集中式） | 各節點本地 HLC（分散式） |
| physical 單位 | milliseconds | microseconds |
| logical 用途 | 同一毫秒內區分先後 | 同一微秒內區分先後，並維持 causality / monotonicity |
| 編碼概念 | `physical_ms + logical` | `physical_usec + logical` |
| 代表函式/介面 | 向 PD 取 TSO | `yb_get_current_hybrid_time_lsn()`、tserver hybrid time |
| 是否是主排序來源 | 是，TiDB 全域排序核心 | 否，單 tablet 仍以 Raft log order 為主 |
| 衝突處理角色 | 提供 `start_ts` / `commit_ts` 供 MVCC 與 2PC 使用 | 提供版本時間；xCluster active-active 可用於 最後寫入者勝出（LWW） |
| 架構特性 | 集中式時間戳服務（centralized timestamp oracle） | 分散式混合邏輯時鐘（decentralized hybrid clock） |

#### 5.2 位元層級直觀對照

```text
TiDB TSO:
  [ physical ms | logical counter ]
  由 PD 集中配發

YugabyteDB HLC:
  [ physical usec (52 bits) | logical counter (12 bits) ]
  由各節點本地維護，但需保持 monotonicity
```

---

## 6. 核心差異（一句話）


```text
TiDB = 用 TSO 做全域排序，再用 lock 解決衝突
YugabyteDB = 用 Raft leader 做排序，再用交易衝突控制（transaction conflict control）解衝突
```


---

## 7. 架構判斷（DBaaS / Multi-Region）

### 若需求是：

#### ✔ 強一致 + 同 key 多地寫

👉 建議：

- 單一 cluster（TiDB / YugabyteDB 都可）
- 接受跨區 latency

---

#### ✖ 雙向 active-active（同 key）

👉 兩者都不適合

原因：

- TiDB → lock contention / retry storm
- YugabyteDB → xCluster 非強一致

---

## 8. DBA 實務結論


```text
同 key 多地寫 ≠ 分散式問題
本質是：單 key 序列化（serialization）問題
```


---

## 9. 延伸關鍵風險

### TiDB

- hotspot → retry storm
- PD 成為排序瓶頸（ordering bottleneck）

---

### YugabyteDB

- leader region 選錯 → latency 爆炸
- clock skew → transaction latency 上升

---

## 10. 最終結論


```text
TiDB：時間主導（TSO ordering）
YugabyteDB：位置主導（leader ordering）

兩者都會收斂到「單 key 單序列化點」
```
