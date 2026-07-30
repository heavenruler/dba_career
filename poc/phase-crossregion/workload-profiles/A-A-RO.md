# Workload Profile: A/A-RO (active-active read-only)

## 定義

兩區 client 同時 read；write 只在 IDC 端。GCP 端 read-only follower。

## Client 配置

| Region | Client | TPCC W 分配 | Threads | Endpoint | 行為 |
|---|---|---|---|---|---|
| IDC | go-tpc @ idc-client (.31) | W=1-128（全）| 16/32/64/128 | idc-haproxy | full TPCC standard mix（read + write）|
| GCP | go-tpc @ gcp-client (g-test-poc-5) | W=1-128（全；read-only mode）| 16/32/64/128 | gcp-haproxy（routed to followers）| read-only mix `--mix DELIVERY:NEW_ORDER:ORDER_STATUS:PAYMENT:STOCK_LEVEL=0:0:50:0:50`（per `decisions-2026-06-08.md` Q6；GCP 端只跑 ORDER_STATUS + STOCK_LEVEL，**NEW_ORDER 是 write txn，不在 RO mix**）|

→ 兩側 W 重疊但 GCP 走 follower read / stale read（NEW_ORDER 留在 IDC writer 側）。

## 預期觀察點

| 維度 | 觀察 |
|---|---|
| IDC tpmC | 與 IDC-only baseline 相近（write path 不變）|
| GCP read tpm | 視 follower read 一致性 mode |
| Stale read latency | follower read 預期 stale ~ replication lag |
| Replication lag | per-shard raft applied index gap |

## Follower read / stale read 機制（per DB）

### TiDB

```sql
SET tidb_replica_read = 'follower';
-- 或:
SET tidb_replica_read = 'closest-replicas';
```

### CockroachDB

```sql
SELECT ... AS OF SYSTEM TIME follower_read_timestamp();
-- 或: SET TRANSACTION AS OF SYSTEM TIME ...
```

### YugabyteDB

```sql
SET yb_follower_read_staleness_ms = 30000;
SET yb_follower_reads = ON;
SET default_transaction_read_only = ON;
```

## 建議搭配 placement

- **P-B**（leader 散）→ GCP 端 follower 在 voter set 中，跨區 read 觀察清楚
- P-A 下 GCP 端純 follower，亦可

## Metrics 增補

- 每家 follower-read 一致性 mode 必標於 manifest 或 run-args
- P-A：`placement/leader-region.txt` 確認 IDC 為 leader
- P-B：leader 依表/分區跨區混合（見 `topology/P-B.md`），無單一固定
  leader region 可核對；改用 `check-nearread.sh --placement P-B`／
  `check-nearread-realtxn.sh --placement P-B`（2026-07-30 補上 P-B 語意
  分支，見 `SESSION-HISTORY.md` 同期節）驗證 GCP 端近讀對 idc-lease 與
  gcp-lease 兩種資料皆生效

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (本) | 初版 spec |
| 2026-07-30 | (本) | 補 P-B 近讀驗證方式（check-nearread 系列腳本已支援 `--placement`） |
