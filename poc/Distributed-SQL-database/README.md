# 分散式資料庫 Workload 適用性分析

## 1. 概述

本文件針對三種典型 workload 進行適用性分析與補充建議：

- 多寫少讀（Write-heavy）
- 多讀少寫（Read-heavy）
- 高併發（High concurrency）

重點不放在特定分散式資料庫產品，而是從資料特性、衝突型態、延遲來源、擴展方式與實務風險來判斷是否適用。

---

## 2. 核心結論

分散式資料庫是否適用，關鍵不在品牌，而在以下三件事：

1. **資料是否能有效 partition**
2. **是否能避免 hot key / hot row**
3. **是否能接受一致性、延遲與跨區成本的交換**

若做不到上述三點，再強的分散式資料庫也會被 workload 打爆。

---

## 3. 多寫少讀（Write-heavy）

## 3.1 特性

此類 workload 常見於：

- 訂單寫入
- 事件流入庫
- 遊戲狀態更新
- IoT 資料上報
- 金流交易記錄

核心特徵：

- 寫入頻率高
- transaction 衝突機率高
- index 維護成本高
- commit latency 會明顯受 network RTT、consensus、replication 影響

---

## 3.2 適用性判斷

### 適合
適合分散式資料庫的前提：

- 寫入可以被 partition
- 同一筆資料不會被多區域同時更新
- 可以接受分散式 transaction 成本
- schema 與 key 設計能避開 hotspot

### 不適合
以下情況不適合直接上分散式資料庫：

- 同一個 key 在多地同時高頻寫入
- counter 類資料集中寫入單點
- 無 shard key / partition key
- 業務邏輯高度依賴單筆即時強一致更新

---

## 3.3 主要風險

### Hotspot
最常見也最致命。

例如：

- `user_id=100` 被大量 update
- `order_status` 集中寫某些熱門訂單
- 自增主鍵造成尾端寫入集中

### Lock Contention
若多個 transaction 同時改同一 row / key，會造成：

- lock wait
- abort
- retry
- tail latency 飆高

### Retry Storm
失敗後若 application 無節制重試，會形成：

`fail -> retry -> 更多 fail -> 系統雪崩`

---

## 3.4 設計建議

### 建議 1：先做 partition，而不是先選 DB
例如：

- 依 `tenant_id`
- 依 `region`
- 依 `bucket`
- 依時間分桶

### 建議 2：避免單調遞增 key
不要直接使用：

- auto_increment
- timestamp-only key

可改為：

- hash key
- bucket + sequence
- snowflake 類型 ID

### 建議 3：減少 index 數量
多寫場景下，每多一個 index，寫入放大就更嚴重。

原則：

- 先保留必要 PK / UK
- 二級索引只保留真正會用到的查詢

### 建議 4：把集中更新改為分散累加
例如不要：

```sql
UPDATE counter SET val = val + 1 WHERE id = 1;
```

改成：
```sql
UPDATE counter_shard_003 SET val = val + 1 WHERE id = 1;
```
最後讀取時再聚合。

3.5 結論

多寫少讀場景下，分散式資料庫可以用，但前提是：

能 partition
能避開 hotspot
能控制 retry
能接受分散式 transaction latency

否則最終瓶頸不是 DB 引擎，而是資料模型本身。

4. 多讀少寫（Read-heavy）
4.1 特性

此類 workload 常見於：

後台查詢系統
報表系統
商品目錄查詢
內容平台
dashboard / BI 查詢

核心特徵：

讀遠大於寫
可接受某些場景 stale read
cache 命中率通常很重要
replica / analytical replica 很有價值
4.2 適用性判斷
適合

分散式資料庫通常很適合此類 workload，因為：

可透過 read replica / follower read 擴展
可透過 cache 大幅減輕壓力
可透過 HTAP / analytical replica 分離 OLTP 與查詢流量
不適合

若 workload 是：

大量複雜跨表 join
超大範圍掃描
長時間批次分析
多資料源彙整查詢

則單靠分散式 OLTP DB 未必是最佳解，通常仍需外部 OLAP / warehouse。

4.3 主要風險
Stale Read

讀 replica/follower 時可能讀到舊資料。

Cache Inconsistency

若 cache 與 DB 更新流程沒設計好，會出現：

cache hit 舊值
cache penetration
cache avalanche
Query Fan-out

若查詢條件沒有對齊 partition key，分散式查詢會打到很多 shard / region，延遲上升。

4.4 設計建議
建議 1：優先用 replica / follower read

把讀流量與寫流量分開。

建議 2：前面加 cache

典型模式：

read -> cache -> miss -> db -> 回填 cache
建議 3：查詢條件對齊 shard key

否則每次查詢都會變成 scatter-gather。

建議 4：報表與交易拆開

若查詢是 scan-heavy、aggregation-heavy，建議：

analytical replica
CDC 到 ClickHouse / BigQuery / Snowflake
warehouse / lakehouse
4.5 結論

多讀少寫是分散式資料庫最容易發揮價值的場景之一。

但若查詢偏分析型，仍應考慮：

cache
replica
OLAP 分流

不要把所有讀都壓在 transactional layer。

5. 高併發（High Concurrency）
5.1 核心定義

高併發不等於高 QPS。

真正的問題是：

同時有多少 transaction 在競爭同一批資源
contention 是否可控
連線數、鎖、重試是否會放大風險
5.2 常見場景
秒殺 / 搶購
熱門活動報名
熱門商品庫存扣減
大量 API 同時寫入同一類資料
高頻 session / state 更新
5.3 主要風險
Hot Key / Hot Row

高併發最怕單一資料成為全集中點。

例如：

單一庫存 row
單一熱門商品
單一 user session key
單一排行榜紀錄
Connection Storm

大量 client 同時打入 DB：

connection 建立成本高
context switch 增加
max_connections 撐爆
Retry Storm

高併發下任何 timeout / conflict 都可能放大成連鎖重試。

Tail Latency

P50 看起來正常，但 P95 / P99 爆掉，對業務體感非常明顯。

5.4 設計建議
建議 1：先做流量治理

一定要有：

rate limit
queue
backpressure
circuit breaker

不是靠資料庫硬扛。

建議 2：使用 connection pool / proxy

例如：

ProxySQL
PgBouncer
app-side pool

避免大量短連線直接打 DB。

建議 3：把單筆共享狀態拆散

例如庫存扣減，不要所有請求都更新同一 row。

可考慮：

預扣庫存分桶
token bucket
queue serialize
async reconcile
建議 4：設計 exponential backoff

重試一定要退避，不能立即重打。

例如：

10ms -> 20ms -> 40ms -> 80ms
建議 5：觀察 tail latency，而不是只看平均值

高併發場景只看 AVG 沒意義，至少要看：

P50
P95
P99
timeout rate
abort / retry rate
5.5 結論

高併發場景下，分散式資料庫不是不能用，而是不能單獨解問題。

真正要一起設計的是：

應用限流
佇列化
partition
快取
重試控制
熱點分散

否則再好的分散式資料庫也只是在幫你放大 contention。

6. 三種 workload 對照
Workload	核心問題	主要風險	建議解法
多寫少讀	transaction 衝突、commit latency	hotspot、lock contention、retry storm	shard、降 index、分散寫入
多讀少寫	read scale、查詢分流	stale read、cache inconsistency、fan-out query	replica、cache、OLAP 分流
高併發	contention、連線與重試放大	hot key、connection storm、tail latency	限流、queue、pool、backoff
7. 補充建議
7.1 先問資料 ownership

若是 multi-region 或 multi-writer 架構，先定義：

哪個 region 擁有哪類資料寫入權
是否允許同 key 跨區同時寫
衝突發生時誰仲裁

若這題沒定義清楚，後面選任何 DB 都只是延後爆炸。

7.2 先看資料模型，不要先看產品型錄

產品比較常讓人誤以為：

支援 multi-region
支援 ACID
支援 horizontal scaling

就代表 workload 一定能撐住。

事實上真正決定成敗的是：

key 設計
partition 設計
transaction 邊界
index 策略
熱點是否可拆
7.3 POC 不要只測 QPS

POC 至少要測：

contention
hotspot
retry rate
failover 後延遲變化
跨區 RTT 影響
P95 / P99 latency
rebalancing 期間的服務抖動
7.4 觀察指標要完整

至少包含：

QPS / TPS
commit latency
lock wait
abort / retry count
hot region / hot tablet / hot shard
connection count
CPU / memory / disk IO / network RTT
7.5 不要把所有需求都壓成同一種資料庫

若 workload 差異很大，應考慮分層：

OLTP database
cache
queue / stream
OLAP / warehouse

而不是期待單一 distributed SQL database 同時完美解決所有問題。

8. 最終結論

分散式資料庫的適用性可收斂為一句話：

能否正確 partition 資料、避開熱點、控制 contention，遠比選哪一套分散式資料庫更重要。

對應到三種 workload：

多寫少讀：先解決衝突與寫入分散
多讀少寫：先解決 replica、cache 與查詢分流
高併發：先解決熱點、限流、連線與重試控制

若這些前提沒有先處理，分散式資料庫只會把問題從單機瓶頸，放大成分散式事故。
