# P-B Placement — 1-IDC + 1-GCP + 1-arbiter (散，per-shard leader 各區)

## 結構

```
shard         RF=3 voter 位置
────────────────────────────────────────────────────
shard-1   ├── voter-1 @ idc-dbhost-1 (leader)
          ├── voter-2 @ gcp-dbhost-1
          └── voter-3 @ idc-dbhost-2   ← arbiter
shard-2   ├── voter-1 @ gcp-dbhost-2 (leader)
          ├── voter-2 @ idc-dbhost-2
          └── voter-3 @ gcp-dbhost-3   ← arbiter
shard-3   ├── voter-1 @ idc-dbhost-3 (leader)
          ├── voter-2 @ gcp-dbhost-1
          └── voter-3 @ idc-dbhost-1   ← arbiter
```

## 屬性

- **Leader 散區**：每 shard leader 不同區 → 部分寫走 WAN
- **WAN 互擾顯性**：兩區任一邊 write 都會觸發跨區 quorum → raft commit latency = round-trip RTT
- **預期 tpmC 衝擊**：~30–60% drop vs IDC-only 6-node（依 RTT 與 RR storm 行為）

## 用途

- **退化形態 / fail-over 形態** — 模擬 region 不可用後的 placement skew
- 適用 workload：`A/A-RO`（IDC write, GCP read）、`A/A`（兩邊都寫）

## 落地指令（每家 DB；本輪 spec only）

### TiDB

```sql
CREATE PLACEMENT POLICY p_b_spread
  CONSTRAINTS = "[+region=idc, +region=gcp]"
  FOLLOWERS = 2;
ALTER TABLE warehouse PLACEMENT POLICY = `p_b_spread`;
```

### CockroachDB

```sql
ALTER DATABASE tpcc CONFIGURE ZONE USING
  constraints = '[+region=idc: 1, +region=gcp: 1]',
  voter_constraints = '[+region=idc: 2, +region=gcp: 1]',
  lease_preferences = '[[+region=idc],[+region=gcp]]';
```

### YugabyteDB

```bash
yb-admin --master_addresses idc-master,gcp-master \
  modify_placement_info idc.zone1:1,gcp.zone1:1,idc.zone2:1 3
```

## 驗證 gate

- placement actual = expected：3 個 shard leader **不在同一區**（避免測試變相退化為 P-A）
- per-shard voter set 含一個 IDC + 一個 GCP + 一個 arbiter

## 對應 workload

- `workload-profiles/A-A.md`
- `workload-profiles/A-A-RO.md`
- chaos C1 (GCP partition) — P-B 比 P-A 對 WAN drop 更敏感
