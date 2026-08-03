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

> **Pre-P0**：WAN 隨 workload inline 採樣（per Q2，原 B4 hard gate 已取消）+
> chrony drift <100ms gate + placement rule + dry-run gate ——
> ✅ 框架落地（`wan/`, `freeze/`, gate scripts）。

### Placement P-A（2-IDC + 1-GCP majority）進度

| Workload | 狀態 | 已採用批次 | 代表數字（t128） | 追溯 |
|---|---|---|---|---|
| single-writer（P0，IDC-only baseline，非必要可跳） | ⚪ 未見獨立正式執行紀錄（非必要） | — | — | — |
| A/S（IDC main, GCP standby） | ✅ 完成且已採用 | `TPCC_TS=20260717T143238+0800` | tpmC：TiDB 12,526.5／CRDB 10,163.4／YBDB 12,769.5 | [XCROSS-CLOSING-REPORT-DRAFT.md](./XCROSS-CLOSING-REPORT-DRAFT.md) |
| A/A-RO（IDC write, GCP read） | ✅ 完成且已採用（範圍超出 07-17 原規劃，見下方追記） | `TPCC_TS=20260723T133843+0800`（aaro#2） | IDC tpmC：TiDB 11,680.0／YBDB 10,661.5／CRDB 10,694.1；GCP read_tpmTotal：TiDB 16,511.4／YBDB 12,817.2／CRDB 40,328.9 | [XCROSS-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-AARO-CLOSING-REPORT-DRAFT.md) |
| A/A（兩邊都寫） | ⚪ 未開始，待排程 | — | — | [`results/README.md` 目前總覽](../results/README.md#目前總覽) |
| backup / migration | ⚪ spec only（TBD） | — | — | [`workload-profiles/backup.md`](./workload-profiles/backup.md) / [`migration.md`](./workload-profiles/migration.md) |
| chaos C1/C4/C7 + F1 | 🟡 planner-only 落地；實跑須 DBA review | — | — | [`chaos/README.md`](./chaos/README.md) |

### Placement P-B（散置，RF=3 全 voter，無 arbiter）進度

| Workload | 狀態 | 已採用批次 | 代表數字（t128） | 追溯 |
|---|---|---|---|---|
| A/S（placement 單因子對照，per G6） | ✅ 完成且已採用 | `TPCC_TS=20260727T223650+0800` | tpmC：TiDB 15,107.4／YBDB 2,485.6／CRDB 11,640.0；idc/gcp 分佈皆落 30-70% 窗口（CRDB 實測 50/50） | [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md) |
| A/A-RO | ✅ 完成且已採用 | `TPCC_TS=20260730T094406+0800` | IDC tpmC：TiDB 5,699.7（⚠ th=128 崩潰，見報告 §3）／YBDB 11,989.8／CRDB 13,777.1；GCP read_tpmTotal：TiDB 23,120.0／YBDB 42,116.4／CRDB 38,194.9 | [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md) |
| A/A | ✅ 完成且已採用 | `TPCC_TS=20260731T204801+0800` | IDC tpmC：TiDB 4,413.9（⚠ th=64/128 劣化，見報告 §3）／YBDB 11,605.5／CRDB 9,880.6；GCP tpmC：TiDB 2,966.6／YBDB 3,379.9／CRDB 5,704.9 | [XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md) |
| backup / migration / chaos | ⚪ 未開始（同 P-A spec） | — | — | — |

**P-B 三種 workload（A-S/A-A-RO/A-A）W=128 執行矩陣已跑過一次**
（各 profile N=1），橫向比對彙總見
[XCROSS-PB-ALL-WORKLOADS-SUMMARY.md](./XCROSS-PB-ALL-WORKLOADS-SUMMARY.md)。
**P-A 與 P-B 跨 placement 階段性比較**（A-S、A-A-RO 兩個有雙邊數據的
profile 逐檔位對照；A-A 依 [Q19](./decisions-2026-06-08.md#q19-p-aa-a-終止排程不補跑2026-08-04-拍板)
終止排程、不補跑，非執行落後）見
[XCROSS-PA-VS-PB-FINAL-COMPARISON.md](./XCROSS-PA-VS-PB-FINAL-COMPARISON.md)
（**fact**：雙側負載的兩個批次皆觀察到 TiDB 高併發吞吐劣化與跨區鎖
路徑錯誤存在性證據，單邊批次（A-S）未見同款現象；**inference，尚待
控制實驗確認**：現象與跨區鎖競爭相容，但三個 profile 非單變量對照
（total offered concurrency 與 mix 皆不同），不可視為已排除其他
解釋。詳見彙總文件 §3 的 fact/inference 分節與最小控制實驗設計）。

**P-B×A-S 已於 2026-07-27~29 完成正式 W=128 執行**——過程中發現並修復一個
跨三家資料庫共通的設計缺口（單一 whole-table/whole-database placement
policy 只能表達優先順序、無法表達機率式跨區混合分佈），TiDB/YBDB/CRDB
各自以不同機制修復（雙 policy／雙 tablespace+enforcer／雙 lease_preferences
+`PARTITION BY RANGE`），詳見結案報告與 `SESSION-HISTORY.md` 同期節。
07-17 Q3 拍板的 S1（O1 gate 補強）/ S2（`gcp-replica-gate.sh` 內建
`PLACEMENT=P-B` 分支，30-70% leader/lease spread 判準）/ S3
（`phase4-ybdb-fix6n` P-B 分支，跳過 `set_preferred_zones`）基礎設施備便
已於本輪驗證為有效（僅代表 prepare-time 抽樣 gate 通過，見
`XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §5）。**P-B 三種 workload
（A-S/A-A-RO/A-A）W=128 執行矩陣至此已跑過一次**——TiDB 在雙側負載
的兩個批次（A-A-RO、A-A）皆於高併發檔位（th=64/128）觀察到吞吐劣化
（A-A-RO 為崩潰後未恢復、A-A 為持續劣化），YBDB/CRDB 兩家 mean tpmC
在三種 workload 下皆隨併發數成長。**現象是否為 TiDB percolator 式
兩階段悲觀鎖與 P-B 跨區混合 leader 交互作用所致，目前只是與觀察
相容的假說**——三個 profile 各僅 N=1、total offered concurrency 與
transaction mix 皆不同，尚未做控制實驗排除其他因素，不可寫成已確認
根因，詳見彙總文件 §3。

**2026-07-27 死碼清理**：稽核發現 `scripts/gate-placement-p-b.sh`（判準
≥1 each，與 `gcp-replica-gate.sh` 的 30-70% spread 不一致）從未被
`run-vm6-suite.sh`／`Makefile` 呼叫，屬孤兒腳本，已刪除；當時的
`tests/yuga/placement-p-b.sql` 舊版（per-table tablespace 設計，假設
GCP 有 `asia-east1-a`/`asia-east1-b` 兩個獨立 zone）同樣從未被
`prepare.sh` 呼叫，且與 `ansible/playbooks/yugabyte-vm6.yml` 實際把
所有 GCP tserver 攤平成單一 `zone=asia-east1` 的事實不符，已一併
刪除。

**現行實作（2026-07-27 同批稍後修正，取代上述已刪除的舊版）**：
`tests/yuga/placement-p-b.sql` **目前存在**，內容為修正後的雙
tablespace 設計（`ts_p_b_leader_idc`/`ts_p_b_leader_gcp`，zone 統一用
實際生效的 `asia-east1`），由 `run-vm6-suite.sh` 新增的 YBDB placement
watcher 在 prepare 建完 tpcc 表後執行 `SET TABLESPACE` + 主動
`leader_stepdown` enforcer。**YBDB P-B 目前有兩層機制共同生效**：
`Makefile phase4-ybdb-fix6n` 的 universe 層 `modify_placement_info`
（決定 RF=3 的基礎 2 idc+1 gcp 副本分佈）+ 上述雙 tablespace（決定
leader 跨區混合分佈），兩者分工不同、缺一不可，詳見 `topology/P-B.md`
與 `tests/yuga/placement-p-b.sql` 檔頭註解。

**追記（2026-07-27，規劃/執行落差說明）**：`decisions-2026-06-08.md`
Q2/Q4（2026-07-17 拍板）曾決議「P-A×A-A-RO／P-A×A-A 共 6 cells 明文砍除」，
規劃僅以 smoke 驗證 `summary-gcp-side.py` 計算邏輯、不進正式數據表。但
2026-07-18 起的實際執行（詳 `SESSION-HISTORY.md` 各節）走向了正式 W=128
全輪，並於 07-24 產出正式結案報告（`XCROSS-AARO-CLOSING-REPORT-DRAFT.md`），
數字已被引用採用。此為**執行事實覆蓋規劃決策**、決策文件本身當時未回補
修正——已於 `decisions-2026-06-08.md` 補記 Q18 追溯性決策項；本表以實際
執行結果為準，P-A×A-A（Q2/Q4 同批砍除的另一半）**未受影響**，且已於
Q19（2026-08-04）明確終止排程、不補跑（P-A leader 固定 IDC，A-A 情境下
GCP 端寫入僅疊加跨 WAN RTT、無 mixed-leader 變因可觀察，與近讀近寫
原則衝突，不具參考價值）。

**已知阻擋**（詳 [`SESSION-HISTORY.md`](./SESSION-HISTORY.md) 關鍵結論速查）：
- `results/x-cross/` 內 W=4 same-cluster determinism 資料**不可作正式跨家排名**（pipeline-log §1 已標註）；W=128 正式採用數字以上表連結的結案報告為準。
- probe driver + wall-clock wrapper script 已實裝（`scripts/probe-rto-driver/`, `scripts/wall-clock-wrapper.sh`），但尚未串入 Makefile runtime chain（RTO/RPO 實測前置；升級實跑須 PR + DBA review）。
  注意 `scripts/probe-rto-driver.sh`（bash，早期版本）與 `scripts/probe-rto-driver/`（Go，F8 新版，`time.Since()` monotonic + 額外輸出 `probe-stats.json` jitter 統計）**同名雙實作**——接線目標是 **Go 版**，bash 版為前期產物，尚未刪除。

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
