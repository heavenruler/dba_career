# P-B Placement — 散區（per-shard leader 各區，RF=3 全 voter）

Placement spec (P-B).

## 結構

每個 shard 的三個 replica 分散到 IDC / GCP / IDC 或 GCP / IDC / GCP，讓各 shard leader 分佈在不同區。
**三家 DB 沒有 arbiter 概念**——所有三個 replica 都是完整投票成員（full voter）。

```
shard         RF=3 full-voter 位置
────────────────────────────────────────────────────
shard-1   ├── voter-1 @ idc-dbhost-1  (leader)
          ├── voter-2 @ gcp-dbhost-1
          └── voter-3 @ idc-dbhost-2
shard-2   ├── voter-1 @ gcp-dbhost-2  (leader)
          ├── voter-2 @ idc-dbhost-2
          └── voter-3 @ gcp-dbhost-3
shard-3   ├── voter-1 @ idc-dbhost-3  (leader)
          ├── voter-2 @ gcp-dbhost-1
          └── voter-3 @ idc-dbhost-1
```

> 以上為示意分佈；實際 leader 位置由各 DB 自身 raft/consensus 決定，不保證與圖示一致。

## 各家 DB 對應術語

| DB | 投票成員 | Leader 角色 | 備注 |
|---|---|---|---|
| **TiDB** | TiKV voter（Region peer） | Raft leader（PD 自動 balance，不指定 PRIMARY_REGION） | `placement-p-b.sql` 用 `FOLLOWERS=2` + CIDR constraints；no PRIMARY_REGION |
| **CRDB** | Range voter（raft 成員） | Range leaseholder（`lease_preferences` 設定偏好區） | `CONFIGURE ZONE USING lease_preferences` 可讓不同 range 的 leaseholder 散到不同區 |
| **YBDB** | Tablet peer（raft 成員） | Tablet leader（由 yb-master 透過 `modify_placement_info` 管理分布） | YBDB 無 arbiter；`modify_placement_info idc.zone1:1,gcp.zone1:1,idc.zone2:1 3` 三副本全 full |

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
- per-shard voter set 含 IDC + GCP 兩區的 full voter（無 arbiter / witness-only 角色）

## 對應 workload

- `workload-profiles/A-A.md`
- `workload-profiles/A-A-RO.md`
- chaos C1 (GCP partition) — P-B 比 P-A 對 WAN drop 更敏感
