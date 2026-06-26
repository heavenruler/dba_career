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

- **Majority in IDC**：每 shard quorum = 2 voters in IDC → IDC 兩 voter ACK 即可 commit
- **GCP 不擋 critical path**：GCP voter 為 follower，raft commit 不等 GCP ACK（raft 設計：majority quorum 已足）
- **預期 tpmC 衝擊**：~10–30% drop vs IDC-only 6-node（WAN replication 仍存在，但不阻塞）

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
