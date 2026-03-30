# 分散式資料庫 Workload 適用性分析

## 1. 概述

本文針對三種典型 workload 進行適用性分析，並提供實務設計建議：

- 多寫少讀（Write-heavy）
- 多讀少寫（Read-heavy）
- 高併發（High Concurrency）

分析重點不放在特定分散式資料庫產品，而是聚焦於資料特性、衝突型態、延遲來源、擴展方式與常見風險，以判斷特定 workload 是否適合採用分散式資料庫。

---

## 2. 核心結論

分散式資料庫是否適用，關鍵不在產品品牌，而在以下三件事：

1. **資料是否能有效 partition**
2. **是否能避免 hot key / hot row**
3. **是否能接受一致性、延遲與跨區成本之間的取捨**

若無法滿足上述條件，即使底層資料庫能力再強，也可能被 workload 本身的特性拖垮。

---

## 3. 多寫少讀（Write-heavy）

### 3.1 特性

此類 workload 常見於以下場景：

- 訂單寫入
- 事件流入庫
- 遊戲狀態更新
- IoT 資料上報
- 金流交易記錄

其核心特徵包括：

- 寫入頻率高
- transaction 衝突機率高
- index 維護成本高
- commit latency 容易受到 network RTT、consensus 與 replication 影響

---

### 3.2 適用性判斷

#### 適合

當以下條件成立時，分散式資料庫通常可支撐多寫少讀場景：

- 寫入流量可以有效 partition
- 同一筆資料不會在多個區域被同時更新
- 可以接受分散式 transaction 帶來的額外成本
- schema 與 key 設計足以避開 hotspot

#### 不適合

以下情況通常不適合直接採用分散式資料庫：

- 同一個 key 在多地同時被高頻寫入
- counter 類資料集中寫入單一節點
- 缺乏 shard key / partition key
- 業務邏輯高度依賴單筆資料的即時強一致更新

---

### 3.3 主要風險

#### Hotspot

這是最常見且最致命的問題之一。

例如：

- `user_id=100` 被大量 update
- `order_status` 寫入集中在特定熱門訂單
- 自增主鍵造成尾端寫入集中

#### Lock Contention

若多個 transaction 同時修改同一 row / key，常見後果包括：

- lock wait
- abort
- retry
- tail latency 明顯升高

#### Retry Storm

若 application 在失敗後無節制重試，可能形成以下惡性循環：

`fail -> retry -> 更多 fail -> 系統雪崩`

---

### 3.4 設計建議

#### 建議 1：先做 partition，再選擇資料庫

可優先從以下切分方式評估：

- 依 `tenant_id`
- 依 `region`
- 依 `bucket`
- 依時間分桶

#### 建議 2：避免單調遞增 key

不建議直接使用：

- auto_increment
- timestamp-only key

可改用：

- hash key
- bucket + sequence
- snowflake 類型 ID

#### 建議 3：控制 index 數量

在多寫場景中，每增加一個 index，都會放大寫入成本。

建議原則如下：

- 僅保留必要的 PK / UK
- 二級索引只保留實際會被使用的查詢路徑

#### 建議 4：將集中更新改為分散累加

例如，避免使用：

```sql
UPDATE counter SET val = val + 1 WHERE id = 1;
```

可改為：

```sql
UPDATE counter_shard_003 SET val = val + 1 WHERE id = 1;
```

最後於讀取階段再進行聚合。

### 3.5 結論

多寫少讀場景下，分散式資料庫可以發揮作用，但前提是：

- 能有效 partition
- 能避開 hotspot
- 能控制 retry
- 能接受分散式 transaction latency

否則真正的瓶頸通常不在資料庫引擎，而在資料模型設計本身。

---

## 4. 多讀少寫（Read-heavy）

### 4.1 特性

此類 workload 常見於以下場景：

- 後台查詢系統
- 報表系統
- 商品目錄查詢
- 內容平台
- dashboard / BI 查詢

其核心特徵包括：

- 讀取量遠大於寫入量
- 某些場景可接受 stale read
- cache 命中率通常是關鍵指標
- replica / analytical replica 具備高價值

### 4.2 適用性判斷

#### 適合

分散式資料庫通常適合此類 workload，原因包括：

- 可透過 read replica / follower read 擴展讀取能力
- 可透過 cache 大幅降低主資料庫壓力
- 可透過 HTAP / analytical replica 分離 OLTP 與查詢流量

#### 不適合

若 workload 以以下查詢為主，則單靠分散式 OLTP DB 未必是最佳解：

- 大量複雜跨表 join
- 超大範圍掃描
- 長時間批次分析
- 多資料源彙整查詢

此時通常仍需搭配外部 OLAP / warehouse。

### 4.3 主要風險

#### Stale Read

當讀取 replica / follower 時，可能讀到尚未同步完成的舊資料。

#### Cache Inconsistency

若 cache 與 DB 的更新流程設計不完整，常見問題包括：

- cache hit 舊值
- cache penetration
- cache avalanche

#### Query Fan-out

若查詢條件未對齊 partition key，分散式查詢可能同時打到多個 shard / region，導致延遲明顯上升。

### 4.4 設計建議

#### 建議 1：優先使用 replica / follower read

應將讀流量與寫流量分離，以提升整體可擴展性。

#### 建議 2：在前層導入 cache

典型模式如下：

`read -> cache -> miss -> db -> 回填 cache`

#### 建議 3：讓查詢條件對齊 shard key

否則查詢很容易退化成 scatter-gather，增加延遲與資源消耗。

#### 建議 4：將報表查詢與交易查詢拆開

若查詢特性偏向 scan-heavy 或 aggregation-heavy，建議採用：

- analytical replica
- CDC 至 ClickHouse / BigQuery / Snowflake
- warehouse / lakehouse

### 4.5 結論

多讀少寫是分散式資料庫最容易發揮價值的場景之一。

但若查詢已偏向分析型，仍應優先規劃：

- cache
- replica
- OLAP 分流

不應將所有讀流量都壓在 transactional layer。

---

## 5. 高併發（High Concurrency）

### 5.1 核心定義

高併發不等於高 QPS。

真正需要關注的是：

- 同時有多少 transaction 在競爭同一批資源
- contention 是否可控
- 連線數、鎖競爭與重試是否會放大風險

### 5.2 常見場景

- 秒殺 / 搶購
- 熱門活動報名
- 熱門商品庫存扣減
- 大量 API 同時寫入同一類資料
- 高頻 session / state 更新

### 5.3 主要風險

#### Hot Key / Hot Row

高併發場景最怕單一資料成為全域集中點。

例如：

- 單一庫存 row
- 單一熱門商品
- 單一 user session key
- 單一排行榜紀錄

#### Connection Storm

當大量 client 同時打入 DB，常見問題包括：

- connection 建立成本高
- context switch 增加
- `max_connections` 被耗盡

#### Retry Storm

高併發下，任何 timeout / conflict 都可能被放大成連鎖重試。

#### Tail Latency

即使 P50 正常，若 P95 / P99 明顯惡化，業務端的體感仍會非常明顯。

### 5.4 設計建議

#### 建議 1：先做流量治理

至少應具備：

- rate limit
- queue
- backpressure
- circuit breaker

不要把流量保護責任完全丟給資料庫承擔。

#### 建議 2：使用 connection pool / proxy

常見做法包括：

- ProxySQL
- PgBouncer
- app-side pool

目標是避免大量短連線直接衝擊 DB。

#### 建議 3：拆散共享狀態

例如在庫存扣減場景中，不應讓所有請求同時更新同一 row。

可考慮：

- 預扣庫存分桶
- token bucket
- queue serialize
- async reconcile

#### 建議 4：設計 exponential backoff

重試必須具備退避機制，避免失敗後立即重打。

例如：

`10ms -> 20ms -> 40ms -> 80ms`

#### 建議 5：觀察 tail latency，而非只看平均值

在高併發場景中，只看 AVG 幾乎沒有意義，至少應持續觀察：

- P50
- P95
- P99
- timeout rate
- abort / retry rate

### 5.5 結論

高併發場景下，分散式資料庫不是不能用，而是無法單獨解決問題。

真正需要一起設計的，是下列配套能力：

- 應用限流
- 佇列化
- partition
- 快取
- 重試控制
- 熱點分散

否則，再強的分散式資料庫也只是把 contention 放大成更難處理的分散式問題。

---

## 6. 三種 Workload 對照

| Workload | 核心問題 | 主要風險 | 建議解法 |
| --- | --- | --- | --- |
| 多寫少讀 | transaction 衝突、commit latency | hotspot、lock contention、retry storm | shard、降低 index、分散寫入 |
| 多讀少寫 | read scale、查詢分流 | stale read、cache inconsistency、fan-out query | replica、cache、OLAP 分流 |
| 高併發 | contention、連線與重試放大 | hot key、connection storm、tail latency | 限流、queue、pool、backoff |

## 7. 補充建議

### 7.1 先定義資料 Ownership

若目標架構為 multi-region 或 multi-writer，應先明確定義：

- 哪個 region 擁有哪類資料的寫入權
- 是否允許同一 key 跨區同時寫入
- 發生衝突時由誰仲裁

若這些規則沒有先定義清楚，後續無論選用哪一套 DB，都只是延後問題爆發。

### 7.2 先看資料模型，不要先看產品型錄

產品介紹常讓人誤以為，只要具備以下能力：

- 支援 multi-region
- 支援 ACID
- 支援 horizontal scaling

就代表 workload 一定可以撐住。

但實際上，真正決定成敗的通常是：

- key 設計
- partition 設計
- transaction 邊界
- index 策略
- 熱點是否可拆

### 7.3 POC 不要只測 QPS

POC 至少應涵蓋以下觀察項目：

- contention
- hotspot
- retry rate
- failover 後的延遲變化
- 跨區 RTT 影響
- P95 / P99 latency
- rebalancing 期間的服務抖動

### 7.4 觀察指標要完整

建議至少納入以下指標：

- QPS / TPS
- commit latency
- lock wait
- abort / retry count
- hot region / hot tablet / hot shard
- connection count
- CPU / memory / disk IO / network RTT

### 7.5 不要把所有需求都壓在同一種資料庫

若 workload 差異很大，應考慮分層架構，例如：

- OLTP database
- cache
- queue / stream
- OLAP / warehouse

不要期待單一 distributed SQL database 同時完美解決所有問題。

## 8. 最終結論

分散式資料庫的適用性可以收斂成一句話：

能否正確 partition 資料、避開熱點、控制 contention，遠比選擇哪一套分散式資料庫更重要。

對應到三種 workload，可進一步簡化為：

- 多寫少讀：先解決衝突與寫入分散
- 多讀少寫：先解決 replica、cache 與查詢分流
- 高併發：先解決熱點、限流、連線與重試控制

若這些前提沒有先處理，分散式資料庫只會把原本的單機瓶頸，放大成更複雜的分散式事故。
