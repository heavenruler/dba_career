# phase-crossregion — IDC ↔ GCP 跨區 / 跨專線 PoC

## 目的（一句話）

驗證 IDC ↔ GCP 跨專線下，三家 distributed SQL DB（TiDB / CRDB / YBDB）的 raft / replication / placement / failover 行為。

`baseline_family: crossregion` → `baseline_eligible: false` → **任何輸出不可入 README VM 主表或 K8s 對照表**（純探索性，不當正式 baseline）。

---

## 閱讀脈絡（從哪讀起）

本目錄文件依「先懂為什麼 → 再懂怎麼跑 → 最後查跑過什麼」分層。新進者建議順序：

| # | 讀這個 | 得到什麼 |
|---|---|---|
| 1 | **本 README** | scope、topology×workload 矩陣、Make 執行方式、phase 狀態 |
| 2 | [`decisions-2026-06-08.md`](./decisions-2026-06-08.md) | 決策 log of record（Q1–Q14 拍板紀錄）— 「為什麼這樣設計」 |
| 3 | [`REPLAN-2026-06-15.md`](./REPLAN-2026-06-15.md) | 施工計畫（**ARCHIVED**；§0–§7 已落地為 scripts，保留 blocker 溯源 + Agent 硬規則 + 執行順序）|
| 4 | [`P-A-vs-P-B-explainer.md`](./P-A-vs-P-B-explainer.md) | placement 商業級說明（給主管 / app owner）|
| 5 | `topology/*.md` + `workload-profiles/*.md` | 各 placement / workload 的技術 spec |
| 6 | [`PRE-FLIGHT-TEST-PLAN-2026-06-17.md`](./PRE-FLIGHT-TEST-PLAN-2026-06-17.md) | 正式 sweep 前環境驗證 checklist（A–J 10 階段）|
| 7 | [`failover/RTO-RPO-methodology.md`](./failover/RTO-RPO-methodology.md) + `chaos/*.md` + `failover/F1.md` | 故障切換 / 混沌工程 spec（**planner-only**）|
| 8 | [`SESSION-HISTORY.md`](./SESSION-HISTORY.md) | 執行歷史歸檔（跑過什麼、踩過什麼坑、durable 結論）|
| 9 | [`../results/x-cross/pipeline-log.md`](../results/x-cross/pipeline-log.md) | **採信數據 of record**（哪些數據可引用、哪些只是 smoke）|
| 10 | [`../results/x-cross/demo/x-cross-report-demo.md`](../results/x-cross/demo/x-cross-report-demo.md) | 決策探索性報告（合成多份 spec 為單一決策視圖）|

> 全域命名 / scope 規則見 [`../results/PHASES.md`](../results/PHASES.md)。決策脈絡追溯見 [`../1_MeetingMinutes/0602-decisions-track-E.md`](../1_MeetingMinutes/0602-decisions-track-E.md)。

---

## 必要條件（取自 manifest.yaml）

| 欄位 | 值 |
|---|---|
| result_scope | `X-CROSS` |
| baseline_family | `crossregion` |
| baseline_eligible | `false` |
| allowed_topology | `vm-6node-P-A`, `vm-6node-P-B` |
| isolation | `rc` only |
| W / warmup / threads / rounds | `128` / `20min` / `16-128` / `5×5min` |
| metrics_hosts | 6 logical id：`idc-dbhost-{1,2,3}` + `gcp-dbhost-{1,2,3}` |
| artifact_prefix | `results/x-cross/` |

詳 [`manifest.yaml`](./manifest.yaml)。

---

## Topology × Workload 矩陣

**正交關係**：`placement (P-A/P-B)` 決定 raft voter 位置；`workload (A-A / A-A-RO / A-S / backup / migration)` 決定 client 行為。

|  | P-A (2-IDC + 1-GCP，majority IDC) | P-B (RF=3 全 full voter，跨 IDC/GCP 散置；無 arbiter) |
|---|---|---|
| single-writer (IDC) | **P0 deploy + smoke** | — |
| A/S (active-standby) | **P1**（IDC main, GCP standby）| — |
| A/A-RO (active-active RO) | — | **P2**（IDC write, GCP read）|
| A/A (active-active) | — | **P3**（兩邊都寫）|
| backup | **P4**（placement 任一）| 同 |
| migration | **P5**（placement 任一）| 同 |
| chaos C1/C4/C7 | **P6** lab mode | lab mode |

→ 規劃排序 = P0 → P1 → P2 → P3 → P4 → P5 → P6（chaos plan only）。

placement / workload / chaos spec：
- placement：[`topology/P-A.md`](./topology/P-A.md) · [`topology/P-B.md`](./topology/P-B.md)
- workload：[`A-A`](./workload-profiles/A-A.md) · [`A-A-RO`](./workload-profiles/A-A-RO.md) · [`A-S`](./workload-profiles/A-S.md) · [`backup`](./workload-profiles/backup.md) · [`migration`](./workload-profiles/migration.md)
- chaos（lab mode / planner-only）：[`C1`](./chaos/C1.md) GCP partition · [`C4`](./chaos/C4.md) IDC leader die · [`C7`](./chaos/C7.md) write reject · [`索引`](./chaos/README.md)

C3（GCP region quorum loss）已於 2026-06 Q4 review 淘汰，spec 移除。

---

## 執行方式（Make targets）

實際執行鏈（per-cell：deploy → W=128 N=5 sweep → 每 cell 靜態閘 → teardown → 下一 DB）：

```
make phase-crossregion-tidb-validate   # TiDB P-A W=128 workflow 驗證（DRY_RUN=1，不跑 go-tpc benchmark）
make phase-crossregion-w128-suite      # 三家 P-A × W=128 × N=5 正式 sweep
make phase-crossregion-w128-suite-pb   # 三家 P-B × W=128 × N=5（checklist #2）
make phase-crossregion-all             # 全鏈：phase1→2→3 deploy→result→phase8.5 per-cell gate→teardown
make phase-crossregion-promotion-gate  # 升級 checklist #9 最終閘（#1/#2/#7/#8）
```

底層 phase 步驟（供除錯 / 單步執行）：

```
phase1                # VM 重建（destroy + apply IDC + GCP）+ 等 startup
phase2                # bootstrap（ansible ping / dns-fix / ssh-prime）
phase3-tidb-deploy    # TiDB 6-node 部署（CRDB=phase5 / YBDB=phase4）
phase6-tidb-result    # TiDB W=128 N=5 sweep（CRDB=phase8 / YBDB=phase7）
phase8.5-static-check # Q12 per-cell 靜態閘 #8（每個 DB cell 跑完就閘）
teardown-tidb         # 拆該 cell（同理 crdb / ybdb）
```

> ⚠ per REPLAN §0：正式 sweep 內部 chain 須用 `phase1-wait-via-31`（.31 jump），**不走** IAP tunnel `localhost:1221x`。

---

## 執行限制（hard rules）

- **不修改**檔案內容：`iac-gcp/terraform.tfvars`（明文密碼，gitignored、本機 only）/ `terraform.tfstate`
- **機敏資訊**（vsphere_password / token / 私鑰）不得出現在任何訊息、log、檔案
- 環境檢查一律走 `ssh root@172.24.40.31` jump，**絕不走** IAP tunnel `localhost:1221x`
- chaos / F1 **planner-only**，嚴禁 `--execute` flag（實跑須單獨開 PR + DBA review label）
- **不 push**（human 負責）；不重命名 artifact 目錄；不改 IDC 端執行檔
- determinism：W=4 短測變異 ±50% 不可作排名；須 W=128 baseline，CV ≤ 10% 通過

---

## Phase 狀態

| Phase | 內容 | 狀態 |
|---|---|---|
| Pre-P0 | WAN 隨 workload inline 採樣（per Q2，原 B4 hard gate 已取消）+ chrony drift <100ms gate + placement rule + dry-run gate | ✅ 框架落地（`wan/`, `freeze/`, gate scripts）|
| P0 | IDC-only 6-node baseline（非必要可跳）| deploy/smoke target 就緒 |
| P1 | P-A × A-S（W=128 正式）| ⏳ 待 operator 觸發正式 sweep |
| P2 | P-B × A-A-RO | ⏳ 待觸發（`w128-suite-pb`）|
| P3 | P-B × A-A | ⏳ 待觸發 |
| P4 / P5 | backup / migration workload | spec only（TBD）|
| P6 | chaos C1/C4/C7 + F1 failover | ✅ planner-only 落地；實跑須 DBA review |

**已知阻擋**（詳 [`SESSION-HISTORY.md`](./SESSION-HISTORY.md) 關鍵結論速查）：
- `results/x-cross/` 現有數據多為 W=4 same-cluster determinism，**不可作正式跨家排名**（pipeline-log §1 已標註）
- probe driver + wall-clock wrapper script 已實裝（`scripts/probe-rto-driver/`, `scripts/wall-clock-wrapper.sh`），但尚未串入 Makefile runtime chain（RTO/RPO 實測前置；升級實跑須 PR + DBA review）

---

## 決策來源

- 15 項 B+C 決策：[`../1_MeetingMinutes/0602-decisions-track-E.md`](../1_MeetingMinutes/0602-decisions-track-E.md)
- Track E 整體規劃：[`../1_MeetingMinutes/0602.md`](../1_MeetingMinutes/0602.md) §10
- 本階段 Q1–Q14 拍板：[`decisions-2026-06-08.md`](./decisions-2026-06-08.md)

---

## 變更歷史

| 日期 | 變更 |
|---|---|
| 2026-06-06 | 初版 spec-only：README + manifest + placement × workload 矩陣 + chaos plan + WAN baseline plan + inventory template |
| 2026-07-01 | 文件彙整：README 改為閱讀脈絡樞紐（加閱讀導引 + 更新 Make targets 與 phase 狀態）；4 份 SESSION 日誌併入 `SESSION-HISTORY.md`；`NEXT-STEPS.md` 進度摺入本檔 phase 狀態表後刪除 |
| 2026-07-02 | 第二輪審計修正（SQL/artifact 為權威）：P-B 拓撲更正為「RF=3 全 full voter，無 arbiter」（README/methodology/C7 同步）；WAN B4 hard gate 標記為 Q2 已取消；REPLAN 標 ARCHIVED；probe/wall-clock 實裝狀態更新；Makefile SSOT 註解修正 |
