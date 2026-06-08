# phase-crossregion — backup / migration future scope

> Status: **deferred from v1**（2026-06-08 user 拍板 Q8）
> Decision: 記錄要做但權重低；v1 不含 backup/migration profile；列出 prereq 以待後續啟動。

## 1. Scope

| Item | 內容 | 量測指標 |
|---|---|---|
| **backup** | DB-native backup tool 在 W=128 TPCC 背景跑 | backup elapsed / tpmC 受影響幅度 / latency p99 退化 |
| **migration** | 動態 placement re-balance 或 add/drop node | re-balance time / workload disruption window |

## 2. backup — 各 DB 工具 + 外部儲存需求

### TiDB (BR)
| 項 | 值 |
|---|---|
| Tool | `br backup db --pd <pd> --storage <uri>` |
| Storage | GCS bucket / S3 bucket / local FS |
| Backup size (W=128 TPCC) | **~5 GiB** (estimated) |
| Restore tool | `br restore db --pd <pd> --storage <uri>` |

### CockroachDB
| 項 | 值 |
|---|---|
| Tool | `cockroach sql -e 'BACKUP DATABASE tpcc INTO "<uri>"'` |
| Storage | GCS / S3 / Azure / userfile |
| Backup size | ~3 GiB |
| Restore tool | `cockroach sql -e 'RESTORE DATABASE tpcc FROM "<uri>"'` |

### YugabyteDB
| 項 | 值 |
|---|---|
| Tool | `yb-admin ... export_snapshot` |
| Storage | local snapshot dir → upload to S3/GCS by hand |
| Backup size | ~8 GiB |
| Restore tool | `yb-admin ... import_snapshot` |

## 3. 外部儲存 prereq (啟動 backup scope 時需備妥)

### GCS bucket（推薦，所有 3 DB 都支援）
```
bucket name: poc-dba-backup-2026
region: asia-east1 (與 GCP VM 同 region 省 egress)
storage class: STANDARD
retention: 30 day
lifecycle: delete after 30d
```

### Service Account
```
SA name: poc-dba-backup-sa@<project>.iam.gserviceaccount.com
roles:
  - roles/storage.objectAdmin (限定 bucket)
JSON key: 下載放 .31 / GCP VM /root/.gcp/backup-sa.json (chmod 600)
```

### Action items (assistant 端準備)
- [ ] Terraform module: GCS bucket + SA + key creation (gitignored creds path)
- [ ] ansible playbook: distribute SA JSON to relevant clients
- [ ] backup-runner script per DB family

## 4. migration scope

### Re-balance 量測
- TiDB: PD scheduler-triggered region move (auto or `pd-ctl operator add`)
- CRDB: `cockroach node decommission` / `ALTER ZONE CONFIGURE` re-balance
- YBDB: `yb-admin modify_placement_info` re-balance

### 量測指標
- elapsed time (re-balance start → completion)
- workload tpmC drop during re-balance
- latency p99 spike duration

### 不需外部儲存（純 cluster-internal）

## 5. 啟動 timing

| Trigger | Action |
|---|---|
| User 拍板 backup/migration 進入 v1.x scope | assistant 補 prereq (Section 3) → 寫 spec → 進 P4/P5 stage |
| v1 跑完且 base metric 有空檔 | 可考慮加跑 backup-only (TiDB BR) 作為 lighter follow-up |

## 6. v1 工作不阻塞

phase-crossregion v1 完全不依賴 backup/migration prereq。本檔案只為 future scope 預備。
