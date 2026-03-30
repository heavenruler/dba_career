# Multi-Region 同 Key 同時寫入機制比較（TiDB vs YugabyteDB）

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


👉 結論：

- 所有 transaction 透過 TSO 排序
- 屬於 **centralized ordering**

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
- snapshot read

⚠️ 不用來決定衝突勝負

---

### 2.5 MVCC


```text
(key, commit_ts) → value
```


用途：

- snapshot read
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
- centralized timestamp ordering
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


👉 decentralized ordering（per shard）

---

### 3.2 寫入流程


```text
Client → tablet leader
→ Raft replicate
→ commit（多數派）
```


---

### 3.3 衝突處理

- 使用 **transaction conflict control**
- isolation level：
  - Repeatable Read
  - Serializable

機制：

- fail-on-conflict
- transaction priority
- wound / wait / abort

👉 結果：

- **其中一方會被 abort**
- 非 last-writer-wins

---

### 3.4 Hybrid Logical Clock（HLC）


```text
HybridTime = physical + logical
```


用途：

- MVCC timestamp
- snapshot read
- CDC / replication LSN

👉 **不是排序主體**

---

### 3.5 MVCC

- key 尾端帶 timestamp（DocDB）
- 多版本並存

用途：

- snapshot read
- consistent read（無需 lock）

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
- per-shard leader ordering
- 衝突 → abort（非 retry-first）
- latency 受 leader location 影響

---

## 4. xCluster（YugabyteDB 雙向寫）補充

⚠️ 非同一 transaction domain

- transactional xCluster → 不允許雙向寫
- non-transactional → **last-writer-wins（by hybrid time）**

風險：

- index inconsistency
- constraint violation

👉 不適合 active-active 同 key 強一致

---

## 5. TiDB vs YugabyteDB 對照

| 面向 | TiDB | YugabyteDB |
| --- | --- | --- |
| 排序來源 | TSO（PD） | Raft leader（per tablet） |
| 排序模型 | centralized | decentralized |
| 衝突仲裁 | lock + start_ts | conflict control（abort） |
| 是否 last-writer-wins | ❌ | ❌（單 universe） |
| MVCC 角色 | 版本管理 | 版本管理 |
| commit 決策點 | 2PC（client） | Raft（leader） |
| latency 核心來源 | PD + 2PC + Raft | Raft quorum |
| hotspot 行為 | lock contention + retry storm | leader bottleneck |
| multi-region 寫入 | 可，但延遲高 | 可，但依 leader location |
| active-active 同 key | 不建議 | 不建議（需單 universe） |

---

## 6. 核心差異（一句話）


```text
TiDB = 用 TSO 做全域排序，再用 lock 解決衝突
YugabyteDB = 用 Raft leader 做排序，再用 transaction control 解衝突
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
本質是：單 key serialization 問題
```


---

## 9. 延伸關鍵風險

### TiDB

- hotspot → retry storm
- PD 成為 ordering bottleneck

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
