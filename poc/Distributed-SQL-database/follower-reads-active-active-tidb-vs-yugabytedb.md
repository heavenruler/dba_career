# Follower Reads 能承接 Read 流量（TiDB vs YugabyteDB）以 Active / Active 概念為主

## 0. 3 分鐘摘要

```text
Follower reads 可以分攤 read 流量，但不等於 active/active 寫入。
TiDB 與 YugabyteDB 都能用 follower/replica read 承接跨區讀流量，
但 write path 仍會收斂到 leader / primary transaction path。
```

- follower reads / replica reads 可以承接多地 read 流量，讓不同 region 使用者就近讀取資料
- 這種能力可視為 **Active/Active Read** 的一部分，但**不等於 Active/Active Write**
- TiDB 與 YugabyteDB 都能利用 follower / replica 承接 read，但 write 仍會回到 leader / transaction coordination 路徑
- 若需求只是降低跨區 read latency、分攤 leader 壓力，兩者都可行
- 若需求是多地同 key 同時寫入且要強一致，不能只看 follower reads，必須回到 transaction ordering、conflict resolution 與 consistency model

### 一句話判斷

```text
Follower reads 能做好 active/active read，
但做不到 active/active write。
```

## 目錄

- [1. 問題核心](#1-問題核心)
- [2. 用 Active / Active 角度看 follower reads](#2-用-active--active-角度看-follower-reads)
- [3. TiDB：Follower Read 的定位](#3-tidbfollower-read-的定位)
- [4. YugabyteDB：Follower Reads / Replica Reads 的定位](#4-yugabytedbfollower-reads--replica-reads-的定位)
- [5. TiDB vs YugabyteDB 對照](#5-tidb-vs-yugabytedb-對照)
- [6. DBA / 架構師應如何表述](#6-dba--架構師應如何表述)
- [7. 架構建議](#7-架構建議)
- [8. 部署範例圖（ASCII）](#8-部署範例圖ascii)
- [9. 最終結論](#9-最終結論)

## 1. 問題核心

在 multi-region 架構裡，很多人會把以下概念混在一起：

- `Follower reads / replica reads`：讀請求可由非 leader / follower replica 處理
- `Active / Active Read`：多地都可就近承接讀流量
- `Active / Active Write`：多地都可接受寫入，且同時保證一致性

要先分清楚：

- **Follower reads 解的是 read scaling / read locality 問題**
- **不是 write conflict / multi-master consistency 問題**

也就是說：

```text
Follower reads = Active/Active Read 的一部分能力
Follower reads ≠ Active/Active Write
```

---

## 2. 用 Active / Active 角度看 follower reads

若從使用者體感來看，multi-region 常希望做到：

1. Taiwan 使用者讀台灣
2. Japan 使用者讀日本
3. 兩地都能快速回應 read request
4. 若可行，也希望兩地都能寫入

其中前 3 點，`follower reads` 很適合處理；第 4 點則不是 follower reads 能解決的。

因此更精確的說法應該是：

- **Follower reads 有助於實現 Active/Active Read**
- **Follower reads 本身不構成 Active/Active Database**

---

## 3. TiDB：Follower Read 的定位

> 備註：
> TiDB 若要由 follower 承接 read 流量，通常前提是業務可接受一定程度的 stale read（非最新資料）。
> 若需求是最強一致、最新值優先，讀取策略通常仍需回到 leader 或受一致性讀取模式限制。

### 3.1 核心概念

TiDB 底層由 TiKV + Raft 組成，每個 Region 有：

- 1 個 leader
- 多個 follower

一般情況下：

- write 送到 Region leader
- 強一致 read 多半也依賴 leader 或受一致性機制控制
- 若使用 follower read，可由 follower 承接部分 read request

### 3.2 Active / Active Read 視角

若 TiDB cluster 跨 Taiwan / Japan 部署，且副本分散在兩地：

- Taiwan 應用可優先讀取 Taiwan 本地 follower / replica
- Japan 應用可優先讀取 Japan 本地 follower / replica

這代表：

- 可以降低跨區 read latency
- 可以分攤 leader read 壓力
- 可以把讀流量分散到各地副本

### 3.3 限制

但 TiDB follower read 有前提：

- 讀到的資料可能不是最新版本
- 是否可接受，取決於 staleness / consistency 要求
- transaction write path 仍然依賴 primary path、TSO、2PC、lock

所以從 Active / Active 概念看：

```text
TiDB follower read = 支援多地 active/active read
TiDB write path     = 仍是單一一致性寫入路徑，不是 multi-master write
```

### 3.4 架構判讀

TiDB 比較適合：

- 多地讀多、寫集中或可接受跨區寫延遲
- 希望 local read、global consistency
- 希望把 follower 當 read capacity pool

不應誤解成：

- Taiwan / Japan 都能各自獨立寫同一筆資料而沒有衝突成本

---

## 4. YugabyteDB：Follower Reads / Replica Reads 的定位

> 備註：
> YugabyteDB 若要由 follower / replica 承接 read 流量，通常前提是業務可接受一定程度的 stale read（非最新資料）。
> 若需求是最強一致、最新值優先，讀流量通常仍需回到 leader 或受一致性讀取策略限制。

### 4.1 核心概念

YugabyteDB 每個 tablet 由 Raft 複寫，包含：

- 1 個 leader
- 多個 follower

一般情況下：

- write 由 tablet leader 接收並排序
- 若要讀取最新且最一致的資料，通常仍偏向 leader 路徑
- 若使用 follower / replica reads，則可由非 leader replica 回應讀請求

### 4.2 Active / Active Read 視角

若 YugabyteDB cluster 橫跨 Taiwan / Japan：

- Taiwan client 可就近讀 Taiwan replica
- Japan client 可就近讀 Japan replica

效果上等同：

- 多地都在 active serving read traffic
- read 流量不必全集中到 leader 所在區域
- 跨區 read RTT 可下降

### 4.3 限制

但 YugabyteDB 也一樣：

- follower / replica read 不等於多主寫入
- 單 tablet 的寫入順序仍由 leader / Raft log 決定
- 若要求最強一致讀，通常不能無限制地把所有讀都導向 follower

因此從 Active / Active 概念看：

```text
YugabyteDB follower/replica read = 支援多地 active/active read
YugabyteDB write path            = 仍以 leader 為序列化核心
```

### 4.4 特別注意 xCluster

若把 YugabyteDB 的 xCluster 雙向寫拿來理解成 active/active：

- 那是另一個議題
- 與 follower reads 無直接等價關係
- xCluster non-transactional 可做最後寫入者勝出（LWW）
- 但不等於單一 universe 內的強一致 active/active write

---

## 5. TiDB vs YugabyteDB 對照

| 面向 | TiDB | YugabyteDB |
| --- | --- | --- |
| follower reads 是否能承接 read 流量 | 可以 | 可以 |
| 是否有助於 multi-region local read | 是 | 是 |
| 是否可視為 Active/Active Read 能力 | 是，部分成立 | 是，部分成立 |
| 是否等於 Active/Active Write | 否 | 否 |
| write 最終序列化位置 | TiDB transaction path + TiKV leader/2PC | tablet leader + Raft |
| 適合場景 | 讀多寫少、跨區讀優化 | 讀多寫少、依 replica 位置優化 |
| 主要風險 | stale read、leader hotspot、跨區 commit latency | stale read、leader placement、跨區 leader RTT |

---

## 6. DBA / 架構師應如何表述

若要對業務或架構團隊講清楚，建議這樣說：

### 正確說法

```text
我們可以用 follower reads / replica reads 讓 Taiwan 與 Japan 都能就近承接讀流量，
也就是做到 active/active read。

但資料庫的寫入仍不是雙主自由寫入；
同一筆資料的衝突控制與一致性，仍要回到 leader / transaction coordination 機制。
```

### 錯誤說法

```text
因為有 follower reads，所以這個資料庫就是 active/active。
```

這句話不夠精確，因為它忽略了：

- read path
- write path
- conflict resolution
- consistency model

這四件事是分開看的。

---

## 7. 架構建議

### 若需求是「多地承接讀流量」

兩者都可以考慮：

- TiDB follower read
- YugabyteDB follower / replica read

適合目標：

- local read
- 降低跨區 read latency
- 分攤 leader 壓力

### 若需求是「多地同 key 同時寫入，還要強一致」

就不能只看 follower reads，必須看：

- TiDB 的 TSO + 2PC + lock 成本
- YugabyteDB 的 leader placement + transaction conflict control

也就是：

```text
Follower reads 決定 read scalability
不是 write conflict strategy
```

---

## 8. 部署範例圖（ASCII）

### 8.1 Active/Active Read，但不是 Active/Active Write

```text
               +---------------- Global Cluster ----------------+
               |                                                |
               |        write path -> leader / txn path         |
               |        read path  -> local follower/replica    |
               |                                                |
               +------------------------------------------------+

     Taiwan Region                                      Japan Region
  +------------------+                               +------------------+
  | App Servers      |                               | App Servers      |
  | read: local      |                               | read: local      |
  | write: global    |                               | write: global    |
  +--------+---------+                               +---------+--------+
           |                                                   |
           v                                                   v
  +------------------+                               +------------------+
  | local follower / |<--------- replication ------->| local follower / |
  | replica read     |                               | replica read     |
  +------------------+                               +------------------+
           \                                                 /
            \                                               /
             \------------- write coordinated -------------/
                            through leader / txn path
```

解讀：

- 兩地都可 active serving read traffic
- 寫入不會因為 follower reads 而變成雙主自由寫入
- 同 key 寫入衝突仍由資料庫一致性機制處理

### 8.2 TiDB 視角

```text
Taiwan App -> local follower read
Japan  App -> local follower read

write:
  App -> TiDB -> PD(TSO) -> TiKV leader -> 2PC / Raft
```

重點：

- 讀可在本地承接
- 寫仍依賴 PD、transaction ordering、TiKV leader 與 2PC

### 8.3 YugabyteDB 視角

```text
Taiwan App -> local replica/follower read
Japan  App -> local replica/follower read

write:
  App -> tablet leader -> Raft quorum -> commit
```

重點：

- 讀可在本地 replica 承接
- 寫仍由 tablet leader 排序並提交

## 9. 最終結論

```text
Follower reads 能讓 TiDB 與 YugabyteDB 在 multi-region 架構下承接更多 read 流量，
也能實現接近 active/active read 的效果。

但它只改善讀，不解決寫。
若目標是 active/active write，仍要另外處理 leader、transaction ordering、
conflict resolution 與一致性模型。
```
