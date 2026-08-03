# P-A Placement — 2-IDC + 1-GCP (majority IDC)

Placement spec (P-A).

## 結構

```
shard         RF=3 voter 位置
────────────────────────────────────────────────────
shard-1   ├── voter-1 @ idc-dbhost-1 (LEADER preferred)
          ├── voter-2 @ idc-dbhost-2
          └── voter-3 @ gcp-dbhost-1   ← follower only
shard-2   ├── voter-1 @ idc-dbhost-2 (LEADER preferred)
          ├── voter-2 @ idc-dbhost-3
          └── voter-3 @ gcp-dbhost-2
shard-3   ├── voter-1 @ idc-dbhost-3 (LEADER preferred)
          ├── voter-2 @ idc-dbhost-1
          └── voter-3 @ gcp-dbhost-3
```

## 屬性

- **Majority in IDC**：每 shard quorum = 2 voters in IDC → IDC 兩 voter ACK 即可 commit（正常健康狀態下）
- **GCP 是投票成員，只是通常不在 critical path 上**：GCP voter 仍是 Raft 意義上的投票成員（非非同步/非投票的 replica），只是正常健康、兩個最快 ACK 都來自 IDC 時，raft commit 不必等 GCP ACK
- **預期 tpmC 衝擊**：~10–30% drop vs IDC-only 6-node（WAN replication 仍存在，但不阻塞）
- **IDC 整區故障（2026-08-03 補充，Critical 2 修正相關）**：IDC 持有
  每個 shard 的 2-voter majority，若 IDC 整區故障，GCP 僅剩 1/3
  voter，**未達 quorum(2)，無法自動選出新 leader 或 commit**，需人工
  介入（如強制副本恢復，有資料遺失風險）。P-A 設計本身**不提供**
  IDC 整區故障的自動 failover，詳見
  [`P-A-vs-P-B-explainer.md`](../P-A-vs-P-B-explainer.md) §1/§2。

## 用途

- **正常運營形態**（DR replica 在 GCP，主 workload 在 IDC）
- 適用 workload：`single-writer (IDC)`、`A/S`（IDC main, GCP standby）

## 落地指令（每家 DB；本輪 spec only）

### TiDB

```sql
-- placement label hint (TiDB)
ALTER TABLE warehouse PLACEMENT POLICY = `p_a_idc_majority`;
-- requires:
CREATE PLACEMENT POLICY p_a_idc_majority
  PRIMARY_REGION = "idc"
  REGIONS = "idc,gcp"
  FOLLOWERS = 2;
```

### CockroachDB

```sql
ALTER DATABASE tpcc CONFIGURE ZONE USING constraints = '[+region=idc]',
                                       voter_constraints = '[+region=idc: 2, +region=gcp: 1]',
                                       lease_preferences = '[[+region=idc]]';
```

### YugabyteDB

```bash
yb-admin --master_addresses idc-master,gcp-master \
  modify_placement_info idc.zone1:2,gcp.zone1:1 3
```

## 驗證 gate（待 dry-run-confirm 補）

- placement actual ≠ config → fail-closed（Track E 新增 hard gate，0602.md §6 中表）
- `idc-dbhost-{1,2,3}` 為實際 leaseholder（非 gcp-dbhost-N）

## 對應 workload

- `workload-profiles/A-S.md`（建議搭配）
- 任何 `single-writer (IDC)` scenario
