# Workload Profile: backup

## 定義

定期將 IDC primary cluster 資料備份至 GCP；測量 backup 期間對 TPCC tpmC 的衝擊 + restore 一致性。

## 三家 backup 方式

### TiDB

```bash
br backup full --pd=idc-pd:2379 --storage=gs://lab-dba-backup/tpcc-{TS}/
# requires: gcp-bucket access via service account
```

### CockroachDB

```sql
BACKUP DATABASE tpcc TO 'gs://lab-dba-backup/tpcc-{TS}/?AUTH=implicit'
  WITH revision_history;
```

### YugabyteDB

```bash
yb-admin -master_addresses idc-master create_snapshot_schedule 60 60 ysql.tpcc
# + use ybcli for gcs upload
```

## 預期觀察點

| 維度 | 觀察 |
|---|---|
| Backup 期間 tpmC drop | 預期 -10~30%（IO + WAN）|
| Backup duration | 視 dataset size + WAN bandwidth |
| Backup file size on GCS | bytes（per-day growth）|
| Restore time | for DR exercise |
| Cross-region replication 是否同步進行 | 兩條鏈路同時擠 WAN ⇒ 高干擾 |

## 建議搭配 placement

- P-A 或 P-B 任一；backup 對 placement 不敏感
- 但 P-A 下 raft 不擠 WAN，backup 是唯一 WAN consumer ⇒ 較易看訊號

## Metrics 增補

- `backup/timeline.txt`（start / progress / done / restore checkpoint）
- `wan/runtime-bytes.txt` 與 backup IO 重疊

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | (本) | 初版 spec |
