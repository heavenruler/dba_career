# Distributed Database Issues For Check
```
opencode -s ses_289a25007ffein3qXFK6gcTM7l
```

## Scope

聚焦在 multi-region、active-active、distributed SQL / NewSQL 類系統常見原理與風險。
表格可作為 PoC、架構評估、設計審查時的檢查清單。

## Risk Checklist

| 風險名稱 | 觸發條件 | 影響 | 緩解方式 | 適用系統例子 |
| --- | --- | --- | --- | --- |
| `multi-region-same-key-write-conflict` | 同一筆資料在不同 region 近乎同時寫入 | 資料衝突、覆寫、業務狀態不一致 | 定義 conflict resolution policy；限制單 key 寫入主區；使用 idempotency key；必要時改成單寫多讀 | TiDB、YugabyteDB、Cosmos DB multi-write |
| `follower-reads-active-active` | 啟用 follower read 或 local read，但要求跨區多活一致語意 | 讀到舊資料；破壞 read-after-write、monotonic read、session consistency | 對關鍵流程強制 leader / leaseholder read；標記可接受 stale read 的查詢；在 app 端帶 session token / read timestamp | TiDB stale read、YugabyteDB read replica、CockroachDB follower reads |
| `network-partition-split-brain` | region 間網路中斷、抖動、仲裁失效 | 雙主、重複寫入、服務不可用或錯誤 failover | 明確選擇 CP 或 AP；使用 quorum 與 lease；設計 witness / tie-breaker；定期演練分區故障 | TiDB Raft、YugabyteDB Raft、Etcd / Raft 類系統 |
| `clock-skew-timestamp-ordering` | 節點時鐘偏移過大，交易排序依賴 physical / hybrid clock | snapshot 錯亂、commit ordering 異常、TTL / lease 判斷失準 | 部署 NTP / PTP；監控 clock offset；設定 max clock skew 保護；交易層避免過度依賴本地時間 | TiDB PD TSO、YugabyteDB HybridTime、CockroachDB HLC、Spanner TrueTime |
| `quorum-latency-write-amplification` | 寫入需跨區 quorum；任一副本延遲升高 | P99 / tail latency 惡化、吞吐下降、寫入 timeout 增加 | 將 write quorum 侷限於同洲；區分 sync / async replica；調整 replica placement；壓測 tail latency | 所有 consensus-based distributed SQL / KV |
| `replica-lag-stale-read` | 非同步複寫或 follower apply 落後 | 查詢結果過舊、業務誤判、報表與線上結果不同 | 曝露 replication lag 指標；對關鍵查詢讀主；定義 staleness SLA；功能區分交易查詢與分析查詢 | MySQL async replica、PostgreSQL replica、分散式 read replica |
| `cross-region-transaction-cost` | 單筆交易跨多 region / shard；涉及 2PC、鎖與重試 | 延遲高、deadlock 難查、abort rate 升高 | 將交易資料共置；減少跨區 join；限制交易範圍；改用 saga / outbox 等補償模式 | TiDB、YugabyteDB、Spanner、CockroachDB |
| `global-secondary-index-consistency` | 全域索引跨 shard / region 維護；唯一鍵需全域檢查 | base table 與 index 暫時不一致；寫入放大；unique 驗證成本高 | 評估是否真的需要 global index；偏好 local index；唯一鍵用集中配置或業務分區 | 分散式 SQL、全球二級索引設計 |
| `hotspot-partition-skew` | 遞增 key、熱門租戶、單一大客戶、熱門商品集中 | 少數 partition 過熱、單點延遲飆升、auto-balance 效果有限 | key 加鹽；hash / composite key；tenant-aware sharding；監控 top hot ranges | TiKV regions、YugabyteDB tablets、HBase、CockroachDB ranges |
| `rebalancing-resharding-impact` | 節點擴縮容、region 加入退出、資料重分片 | latency spike、IO 爆量、cache miss、背景 compaction 干擾前台流量 | 設定搬遷節流；離峰執行；先壓測再擴容；觀察 rebalance queue 與 compaction | 所有自動 rebalancing 系統 |
| `failover-semantics-rpo-rto-gap` | 故障切換時未明確定義 RPO / RTO 與 ack 語意 | 已回應成功的寫入可能遺失；服務恢復慢；切回後發生資料衝突 | 明定 ack 條件；文件化 RPO / RTO；定期 drill failover / failback；驗證 client routing 收斂時間 | TiDB、YugabyteDB、主從與 multi-region primary 架構 |
| `pd-tso-availability-single-site` | TiDB Route A：IDC 全數斷線，GCP 節點無法連回 PD 取得 TSO | GCP 節點無法開始新交易，寫入停止；即使存儲層 quorum 仍存在也無法繼續服務 | Route A 限定 IDC 為 primary 站台（設計預期）；Route B 改為 GCP 持有 PD majority；S4 場景必須先切換至 Route B 再驗證 | TiDB（PD TSO 中央授時架構特有） |
| `transaction-restart-storm` | YugabyteDB 高衝突 workload（同一 row 高併發更新）；內部 restart 次數快速累積 | 吞吐驟降至接近 0；大量 `could not serialize access` 回給 client；retry backoff 加劇衝突 | 降低衝突熱點（key 設計、queue 化）；適當設定 retry backoff；監控 `transaction_restart` 指標；TC-01 壓測時觀察此行為 | YugabyteDB DocDB（intent-based conflict resolution 特有） |
| `duplicate-write-retry-semantics` | client timeout 後重試；網路抖動導致結果未知 | 重複扣款、重複下單、補償邏輯混亂 | 設計 idempotency key；去重表；把外部副作用改成可重試流程 | 金流、訂單、訊息驅動系統 |
| `schema-change-distributed-upgrade-risk` | 線上 DDL、rolling upgrade、schema version 並存 | 新舊節點行為不一致；backfill 壓垮叢集；查詢計畫波動 | 採 expand / contract；先相容再切換；分批 backfill；觀察 schema lease 與 metadata propagation | TiDB Online DDL、YugabyteDB DDL、分散式 SQL 跨版本升級 |
| `backup-restore-consistency-gap` | 各節點分別備份，未保證同一 snapshot | 還原後資料互相對不上；跨表交易邊界破壞 | 使用一致性 snapshot backup；驗證 PITR；定期演練全區與單區 restore | 所有分散式資料庫 |
| `observability-troubleshooting-blind-spot` | 缺少 per-region、per-shard、per-transaction 觀測 | 問題定位慢；偶發延遲與重試無法歸因 | 建立 tracing、replication lag、abort / retry、lock wait、clock offset、quorum failure 指標 | 所有分散式資料庫 |

## Discussion Angles

可用以下問題快速檢查設計是否合理：

1. 哪些表或 key 可以接受 `stale read`，哪些不行？
2. 同一筆資料是否可能在不同 region 被同時更新？若會，衝突規則是什麼？
3. 寫入成功的定義是 local ack、quorum ack，還是 global durable ack？
4. 跨 region 交易占比多少？能否藉由 data locality 降到最低？
5. failover 後是否可能遺失「已回應成功」的資料？
6. schema change、rebalance、backup restore 是否做過實際演練？
7. 目前監控是否能看出 clock skew、replica lag、retry rate、lock wait、quorum failure？

## Suggested Grouping

若要持續擴充，建議按以下主題整理：

1. 一致性風險（`multi-region-same-key-write-conflict`、`follower-reads-active-active`、`clock-skew-timestamp-ordering`、`replica-lag-stale-read`、`global-secondary-index-consistency`、`duplicate-write-retry-semantics`）
2. 延遲與效能風險（`quorum-latency-write-amplification`、`cross-region-transaction-cost`、`hotspot-partition-skew`、`rebalancing-resharding-impact`、`transaction-restart-storm`）
3. 分區容錯與故障切換風險（`network-partition-split-brain`、`failover-semantics-rpo-rto-gap`、`pd-tso-availability-single-site`）
4. 分片與資料模型風險（`hotspot-partition-skew`、`global-secondary-index-consistency`）
5. 維運、升級、備援風險（`schema-change-distributed-upgrade-risk`、`backup-restore-consistency-gap`、`observability-troubleshooting-blind-spot`）
