# phase-crossregion — IDC ↔ GCP 跨區 / 跨專線 PoC

## 本輪 scope（T106 commit）

**spec-only**：本 commit 只落 README + manifest + topology × workload spec + chaos plan + WAN baseline measurement plan + inventory template。**不 deploy、不 benchmark、不碰 `iac-gcp/terraform.tfvars` / `terraform.tfstate`**。

runtime phase（P0 deploy 起）為後續 commit，依 `0602-decisions-track-E.md` 8 階段排序執行。

## 目的

驗證 IDC ↔ GCP 跨專線下，三家 distributed SQL DB 的 raft / replication / placement / failover 行為。

`baseline_family: crossregion` → `baseline_eligible: false` → 任何輸出不可入 README VM 主表或 K8s 對照表。

## 必要條件（取自 manifest.yaml）

| 欄位 | 值 |
|---|---|
| result_scope | `X-CROSS` |
| baseline_family | `crossregion` |
| baseline_eligible | `false` |
| allowed_topology | `vm-6node-P-A`, `vm-6node-P-B` |
| isolation | `rc` only |
| W / warmup / threads / rounds | 沿用 baseline（128 / 20min / 16-128 / 5x5min）|
| metrics_hosts | 6 logical id：`idc-dbhost-{1,2,3}` + `gcp-dbhost-{1,2,3}` |
| artifact_prefix | `results/{db}-tc1/X-CROSS/` |

詳 [`manifest.yaml`](./manifest.yaml) + [`../results/PHASES.md`](../results/PHASES.md)。

## Topology × Workload 矩陣

**正交關係**：`placement (P-A/P-B)` 決定 raft voter 位置；`workload (A-A / A-A-RO / A-S / backup / migration)` 決定 client 行為。

|  | P-A (2-IDC + 1-GCP，majority IDC) | P-B (1-IDC + 1-GCP + 1-arbiter，散) |
|---|---|---|
| single-writer (IDC) | **P0 deploy + smoke** | — |
| A/S (active-standby) | **P1**（IDC main, GCP standby）| — |
| A/A-RO (active-active RO) | — | **P2**（IDC write, GCP read）|
| A/A (active-active) | — | **P3**（兩邊都寫）|
| backup | **P4**（placement 任一）| 同 |
| migration | **P5**（placement 任一）| 同 |
| chaos C1/C4/C7 | **P6** lab mode | lab mode |

→ runtime phase 排序 = P0 → P1 → P2 → P3 → P4 → P5 → P6（chaos plan only）。

placement spec：
- [`topology/P-A.md`](./topology/P-A.md)
- [`topology/P-B.md`](./topology/P-B.md)

workload spec：
- [`workload-profiles/A-A.md`](./workload-profiles/A-A.md)
- [`workload-profiles/A-A-RO.md`](./workload-profiles/A-A-RO.md)
- [`workload-profiles/A-S.md`](./workload-profiles/A-S.md)
- [`workload-profiles/backup.md`](./workload-profiles/backup.md)
- [`workload-profiles/migration.md`](./workload-profiles/migration.md)

chaos spec（lab mode；本輪 planner-only / 不實跑）：
- [`chaos/C1.md`](./chaos/C1.md) — GCP partition (WAN drop)
- [`chaos/C4.md`](./chaos/C4.md) — IDC leader die
- [`chaos/C7.md`](./chaos/C7.md) — cluster write reject
- [`chaos/README.md`](./chaos/README.md) — planner runner index

C3（GCP region quorum loss）已於 2026-06 Q4 review 淘汰，spec 移除。

## WAN baseline measurement (B4 Pre-P0 hard gate)

詳 [`wan/baseline-measurement.md`](./wan/baseline-measurement.md)。

包含 `iperf3` + `ping p50/p99` + MTU 探測 + 飽和 packet loss；多時段（business hour vs off-peak）。

## Inventory

cross-region inventory template：[`inventory/crossregion.ini.template`](./inventory/crossregion.ini.template)

合併兩區 host groups（`[idc_db]` + `[gcp_db]` + `[idc_gcp_cluster]` union），供 ansible `--inventory` 使用。

## 決策來源

- 15 項 B+C 決策：[`../1_MeetingMinutes/0602-decisions-track-E.md`](../1_MeetingMinutes/0602-decisions-track-E.md)
- Track E 整體規劃：[`../1_MeetingMinutes/0602.md`](../1_MeetingMinutes/0602.md) §10

## Pending runtime work（後續 commit）

| Phase | 內容 | 估時 |
|---|---|---|
| Pre-P0 | WAN baseline 量測（B4 hard gate）+ TiDB 6-node ansible 重寫（C2）+ placement rule（B3）+ dry-run gate + results 子目錄 | 3 工作天 |
| P0 | IDC-only-6-node TiDB 5-cell（純 in-region 6-node baseline；非必要可跳）| ~3h × 5 cell |
| P1 | P-A × A/S | ~3h × 5 cell |
| P2 | P-B × A/A-RO | ~3h × 5 cell |
| P3 | P-B × A/A | ~3h × 5 cell |
| P4 | backup workload | TBD |
| P5 | migration workload | TBD |
| P6 | chaos 3 場景 lab mode（C1/C4/C7；planner-only 已落地） | ~半天 × 3 |

## Make target（本輪）

```
make phase-crossregion-plan        # read-only echo manifest + 拓樸矩陣 (本 commit 有效)
make phase-crossregion-deploy      # NOT YET IMPLEMENTED (Pre-P0 task 2)
make phase-crossregion-run         # NOT YET IMPLEMENTED (P0+)
make phase-crossregion-chaos-plan  # 列出 4 chaos scenario spec 路徑
make phase-crossregion-chaos-{deploy,run}  # NOT YET IMPLEMENTED
```

## 執行限制（codex v2 constraint #7）

- **不修改** `iac-gcp/terraform.tfvars`（plaintext password 已 gitignored，本機 only）
- **不修改** `iac-gcp/terraform.tfstate`（GCP state 目前 empty，需 init 由 user 控）
- **不執行** `terraform apply` / `terraform destroy`
- 此 phase 任何 deploy / run target 一律 `exit 1` 直到後續 commit 補完

## 變更歷史

| 日期 | commit | 變更 |
|---|---|---|
| 2026-06-06 | （本 commit）| 初版 spec-only：README + manifest + topology × workload 矩陣 + chaos plan + WAN baseline plan + inventory template |
