# 分散式資料庫 Workload 適用性分析

## 核心結論

分散式資料庫是否適用，重點不在產品品牌，而在 workload 是否符合下列前提。

| 判斷項目 | 要問的問題 | 不符合時常見後果 |
| --- | --- | --- |
| Partition 能力 | 資料能否依 `tenant_id`、`region`、時間或 bucket 拆散？ | hotspot、單點瓶頸、擴展失效 |
| 熱點控制 | 是否存在 hot key、hot row、單一熱門商品 / 帳號？ | lock contention、tail latency、retry storm |
| 一致性取捨 | 是否能接受 stale read、跨區寫入成本、quorum latency？ | 延遲升高、衝突增加、使用者體感變差 |
| 交易範圍 | transaction 是否常跨 shard / region？ | 2PC 成本高、abort 增加、吞吐下降 |
| 流量治理 | 應用端是否有 rate limit、queue、backoff、pooling？ | connection storm、重試放大、系統雪崩 |

## Workload 對照

| Workload | 典型場景 | 適合採用分散式資料庫的條件 | 主要風險 | 主要設計重點 |
| --- | --- | --- | --- | --- |
| 多寫少讀 | 訂單、事件流、IoT、遊戲狀態、交易記錄 | 寫入可 partition、同 key 不跨區同寫、可接受 transaction 成本 | hotspot、lock contention、retry storm | shard key、避免單調 key、降低 index、分散寫入 |
| 多讀少寫 | 商品目錄、後台查詢、內容平台、dashboard | 可用 replica / follower read、可接受部分 stale read、可做 cache 分流 | stale read、cache inconsistency、fan-out query | replica、cache、查詢對齊 shard key、OLAP 分流 |
| 高併發 | 秒殺、搶購、熱門報名、庫存扣減、session 更新 | 熱點可拆散、應用端可控流量、共享狀態可序列化 | hot key、connection storm、retry storm、tail latency | rate limit、queue、pool、backoff、共享狀態拆散 |

## 多寫少讀

| 面向 | 內容 |
| --- | --- |
| 核心特性 | 高寫入頻率、高衝突機率、index 維護成本高、commit latency 易受 RTT / consensus / replication 影響 |
| 適合條件 | 寫入流量可有效 partition；同筆資料不在多區同時更新；schema 與 key 能避開 hotspot |
| 不適合條件 | 同 key 多地高頻寫入；集中式 counter；缺乏 shard key；高度依賴單筆即時強一致更新 |
| 主要風險 | hotspot、lock contention、retry storm |
| 設計建議 | 先做 partition 再選 DB；避免 `auto_increment` / timestamp-only key；只保留必要 index；把集中更新改成分桶累加 |
| 一句話 | 能分散寫入就適合，不能分散寫入就會先被資料模型拖垮 |

## 多讀少寫

| 面向 | 內容 |
| --- | --- |
| 核心特性 | 讀多寫少、可接受部分 stale read、cache 命中率重要、replica 有價值 |
| 適合條件 | 可透過 read replica / follower read 擴展；可透過 cache 降低壓力；可分離交易查詢與分析查詢 |
| 不適合條件 | 查詢以大範圍掃描、複雜 join、長批次分析、多資料源整合為主 |
| 主要風險 | stale read、cache inconsistency、query fan-out |
| 設計建議 | 優先做 replica / follower read；前層加 cache；讓查詢條件對齊 shard key；分析查詢分流至 OLAP / warehouse |
| 一句話 | 讀流量很適合分散式 DB，但分析型查詢不要硬塞進 OLTP 層 |

## 高併發

| 面向 | 內容 |
| --- | --- |
| 核心定義 | 重點不是 QPS，而是同時間有多少 transaction 在競爭同一批資源 |
| 常見場景 | 秒殺、搶購、熱門商品庫存扣減、大量 API 同時寫入同一類資料 |
| 主要風險 | hot key / hot row、connection storm、retry storm、tail latency |
| 設計建議 | 先做 rate limit、queue、backpressure、circuit breaker；用 connection pool / proxy；拆散共享狀態；重試必須 exponential backoff；持續看 P95 / P99 |
| 一句話 | 高併發問題通常不是 DB 單獨能解，必須連應用治理一起做 |

## 設計原則

| 主題 | 建議 |
| --- | --- |
| Ownership | 先定義哪個 region 擁有哪類資料寫入權，是否允許同 key 跨區同時寫入 |
| Data Model | 先看 key、partition、transaction 邊界與熱點，而不是先看產品型錄 |
| Query Path | 查詢條件盡量對齊 shard key，避免 scatter-gather |
| Index Strategy | 多寫場景下 index 要節制，只保留必要查詢路徑 |
| Workload Separation | OLTP、cache、queue / stream、OLAP / warehouse 應視需求分層 |

## POC 檢查表

| 檢查項目 | 至少要回答的問題 |
| --- | --- |
| Contention | 是否出現 lock wait、abort、retry 放大？ |
| Hotspot | 是否有 hot key、hot shard、hot region？ |
| Latency | P50 / P95 / P99 是否可接受？跨區 RTT 影響多大？ |
| Failover | failover 後延遲、錯誤率、恢復時間如何變化？ |
| Rebalancing | 節點擴縮容或 rebalance 期間是否明顯抖動？ |
| Read Consistency | follower read / replica read 是否影響 read-after-write？ |
| Write Path | 寫入成功的定義是 local ack、quorum ack，還是 global durable ack？ |

## 觀察指標

| 類別 | 指標 |
| --- | --- |
| Throughput | QPS、TPS |
| Latency | commit latency、query latency、P95、P99 |
| Concurrency | lock wait、abort count、retry count |
| Hotspot | hot tablet、hot shard、hot region |
| Resource | connection count、CPU、memory、disk IO、network RTT |
| Replication | replica lag、apply lag、failover recovery time |

## 最終結論

| Workload | 最優先先解的問題 |
| --- | --- |
| 多寫少讀 | 衝突控制、寫入分散、避免 hotspot |
| 多讀少寫 | replica、cache、查詢分流 |
| 高併發 | 熱點拆散、限流、連線與重試控制 |

一句話總結：能正確 partition、避開熱點、控制 contention，分散式資料庫才會帶來擴展性；否則只是把單機瓶頸放大成更複雜的分散式事故。
