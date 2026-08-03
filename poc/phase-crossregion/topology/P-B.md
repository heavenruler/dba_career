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
>
> **修正（2026-08-03，Major 5）**：上圖畫出「shard-2 是 2 GCP + 1 IDC」
> 只適用於**部分 TiDB 表**，不是三家共通實作，不應視為一張通用假想圖：
>
> - **CockroachDB／YugabyteDB**：`voter_constraints`／`replica_placement`
>   對**全部 9 個 table 固定為 idc:2 + gcp:1**（見下方各家 SQL），只有
>   `lease_preferences`／`leader_preference` 依 table 分組反轉方向。也就是
>   說，這兩家在 P-B 下**每個 shard 的 2-voter majority 恆在 IDC**，「散區」
>   只影響 leaseholder/tablet leader 的地理位置與延遲，**不影響**失去
>   GCP 或失去 IDC 時的 quorum 結果（失去 GCP 不影響 quorum；失去 IDC
>   一律失去 quorum，與 P-A 相同）。
> - **TiDB**：`PRIMARY_REGION` 依 table 分組不同（5 表 idc 優先／4 表 gcp
>   優先，見 `tests/tidb/placement-p-b.sql`），設計上可能同時影響 leader
>   **與** voter/follower 分佈方向，即「gcp 優先」那組表**有可能**其
>   2-voter majority 落在 GCP（如上圖 shard-2 示意）。**本節尚未逐表以
>   `SHOW PLACEMENT` 核實實際 voter 落點方向**，此為 pending validation，
>   不可逕自假設與 CRDB/YBDB 同構。

## 各家 DB 對應術語

| DB | 投票成員 | Leader 角色 | 備注 |
|---|---|---|---|
| **TiDB** | TiKV voter（Region peer） | Raft leader（PD 自動 balance，不指定 PRIMARY_REGION） | `placement-p-b.sql` 用 `FOLLOWERS=2` + CIDR constraints；no PRIMARY_REGION |
| **CRDB** | Range voter（raft 成員） | Range leaseholder（`lease_preferences` 設定偏好區） | `CONFIGURE ZONE USING lease_preferences` 可讓不同 range 的 leaseholder 散到不同區 |
| **YBDB** | Tablet peer（raft 成員） | Tablet leader（由 yb-master 透過 `modify_placement_info` 管理分布） | YBDB 無 arbiter；`modify_placement_info idc.zone1:1,gcp.zone1:1,idc.zone2:1 3` 三副本全 full |

## 屬性

- **Leader 散區**：每 shard leader 不同區（30-70% 混合分佈）→ 部分寫走 WAN
- **WAN 互擾**（2026-08-03 修正）：**只有當 leader 在 GCP、或該 shard
  的 quorum 湊滿需要跨區 ACK 時，才會觸發跨區 raft commit latency =
  round-trip RTT**；IDC-majority 且 leader 在 IDC 的 shard，兩個 IDC
  voter ACK 即可 commit，不必等 GCP——先前寫「兩區任一邊 write 都會
  觸發跨區 quorum」不準確，並非每筆寫都需要跨區。
- **預期 tpmC 衝擊**：~30–60% drop vs IDC-only 6-node（依 RTT 與 RR storm 行為）——此為 pre-sweep 預估，實測結果因 DB 而異且部分方向相反，見 [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](../XCROSS-PA-VS-PB-FINAL-COMPARISON.md)。
- **整區故障／quorum 澄清（2026-08-03 新增，Critical 2 修正）**：每個
  shard 仍是 2+1 voter 分布，只是 2-voter majority 方向可能因 shard
  而異（如上圖 shard-1/3 是 IDC majority、shard-2 是 GCP majority）。
  若任一 Region 整體失效，凡是該 Region 持有 2-voter majority 的
  shard 都會失去 quorum、不可 commit，**不是「另一區一定還有 leader
  →秒級接手」**；leader 已分散只能降低部分 shard 的 leader
  locality／re-election 成本，不能取代 quorum 的數學限制。若要支撐
  「整區故障仍可用」，需要第三 failure domain／witness 或更高 RF 與
  明確 quorum placement，是重新設計題，本 PoC 現行拓樸不提供此保證。

## 用途

- **退化形態 / fail-over 形態** — 模擬 region 不可用後的 placement skew
- 適用 workload：`A/A-RO`（IDC write, GCP read）、`A/A`（兩邊都寫）

## 落地指令（每家 DB；2026-08-03 更新落地狀態，Major 5 修正）

> TiDB／CRDB 已落地成可執行 SQL（`tests/{tidb,cockroach}/placement-p-b.sql`），
> 並由 `scripts/run-vm6-suite.sh` 的 placement watcher 在 prepare 後自動套用
> （非 spec only）。
>
> **YBDB 走兩層控制，`tests/yuga/placement-p-b.sql` 現在存在且已接進
> 執行鏈**（先前版本誤寫「從未接進執行鏈」「已於 2026-07-27 刪除」——
> 那是描述一支**更早、已淘汰的版本**，該版本假設 GCP 雙 zone
> `asia-east1-a`/`-b`，與 `ansible/playbooks/yugabyte-vm6.yml` 實際
> 單一 `zone=asia-east1` 攤平不符，確實已於 2026-07-27 刪除；但同一天
> **重建了對應單一 zone 假設的新版本**，這份新版本目前仍在 repo 中，
> README 已更新但 topology spec 一直沒同步，直到本次修正）：
>
> 1. **universe 層 base placement**：`Makefile phase4-ybdb-fix6n` 呼叫
>    `modify_placement_info idc.zone1:1,gcp.zone1:1,idc.zone2:1 3`
>    （deploy-time 執行），決定 RF=3 的 2 IDC + 1 GCP 基礎副本分布。
> 2. **per-table tablespace 層**：`tests/yuga/placement-p-b.sql` 建立
>    `ts_p_b_leader_idc`/`ts_p_b_leader_gcp` 兩個 tablespace，並對不同
>    表 `ALTER TABLE ... SET TABLESPACE` 分組；`scripts/run-vm6-suite.sh`
>    的 YBDB placement watcher 搭配主動 `leader_stepdown` enforcer，在
>    執行期間持續把各表 tablet leader 導向對應 tablespace 指定的
>    Region，藉此做出 leader 30-70% 混合分佈（單靠 universe 層設定
>    無法表達這種機率式混合，這正是三家共通的設計缺口，見 §7
>    `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md`）。
>
> 兩層缺一不可：只有 universe 層只能決定副本落點，不能決定 leader
> 混合比例；只有 tablespace 層沒有 universe 層的 base placement，
> 表資料本身就不會落到正確的 IDC/GCP 分布。

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
