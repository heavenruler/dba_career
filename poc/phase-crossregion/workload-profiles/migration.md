# Workload Profile: migration

## 定義

線上遷移：將 cluster shard / table / database 從某 region (IDC) 移至另一 region (GCP)；驗 zero-downtime + 一致性。

## 三家 migration 機制

### TiDB

- **TiDB scheduler** placement re-balance：移 region 由 PD 控
- 程序：`ALTER TABLE ... PLACEMENT POLICY ...` → PD schedule region 移
- 觀察：`pd-ctl region check miss-peer/extra-peer`

### CockroachDB

- **CRDB zone config change**：`ALTER DATABASE ... CONFIGURE ZONE USING ...`
- 程序：改 voter_constraints → allocator schedule lease + voter 移
- 觀察：`SHOW CLUSTER RANGES`（v26.2.0）

### YugabyteDB

- **yb-admin tablet move**：
  ```
  yb-admin --master_addresses ... move_leader <tablet_id> <new_tserver_uuid>
  ```
- 觀察：`yb-admin list_tablet_servers` + tablet leader count

## 預期觀察點

| 維度 | 觀察 |
|---|---|
| Migration 期間 tpmC drop | 預期 -20~50%（depends on rate limit）|
| Migration duration | for 9 tables × 3 tablets/region |
| Replication consistency | 0 lost row（讀 row count before/after）|
| Settle window | rebalance complete (`under_replicated==0` 連續 N 秒) |

## 建議搭配 placement

- **migration 起點 = P-A**（majority IDC）
- **migration 終點 = P-B**（或全 GCP，視測試目標）

## Metrics 增補

- `migration/timeline.txt`（per-step start/done timestamps）
- `placement/voter-region.txt` 前後對比
- `prepare/settle-window.txt`（rebalance complete time）

## 緊急 abort

migration 失敗時須能 rollback：
- TiDB: re-apply 原 placement policy
- CRDB: re-issue 原 zone config
- YBDB: `move_leader` 回原 tserver

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (本) | 初版 spec |
