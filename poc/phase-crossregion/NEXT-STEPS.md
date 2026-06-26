# phase-crossregion — Next Steps (post 2026-06-26 doc + retrofit)

> Status: 本 session 完成 doc + 既有紀錄彙整；實作（W=128 跨區 benchmark、P-B 跑線、chaos/F1 實跑）由 operator 後續觸發。
>
> 對應 [`plan` 路徑 1+2+3](../1_MeetingMinutes/0626-slide-v6.pptx)（slide 11 後續推進段對應）。

---

## 1. 本 session 已落地（純 doc / 純彙整）

| 項目 | 路徑 | 產物 |
|---|---|---|
| RTO/RPO 方法論 spec | Path 3 doc 化 | `failover/RTO-RPO-methodology.md` |
| summary.json retrofit（W=4 determinism）| Path 1.3 | `results/x-cross/determinism/{run1,run2}/<3-DB-suite>/summary.json` |
| `summary-from-stdout.py` patch | Path 1.3 工具 | 新增 `--warehouses N` / `--skip-rounds K`；regex 支援 `-run<N>-` suffix |
| pipeline-log §0 + §7 更新 | Path 1.3 收尾 | `results/x-cross/pipeline-log.md` |
| P-B placement actual gate | Path 2.2 | `phase-crossregion/scripts/gate-placement-p-b.sh`（read-only spec script）|

P-A / P-B placement SQL **早已存在**（`tests/{tidb,cockroach,yuga}/placement-p-{a,b}.sql`），本 session 確認三家完整，未新增。

---

## 2. 待 operator 觸發（不在本 session 範圍）

### 2.1 路徑 1 — W=128 正式跨區 baseline

| step | 內容 | 觸發前先準備 |
|---|---|---|
| **1.1** | WAN baseline 量測（B4 hard gate） | `phase-crossregion/scripts/wan-probe.sh` 已存在；需 operator 在 business hour + off-peak 兩時段呼叫，產 `iperf3 / ping / MTU / loss` 紀錄 |
| **1.2** | 三家 W=128 × N=5 × same-cluster suite | **目前 Makefile 沒有 W=128 X-CROSS suite target**；需 operator 新增（或沿用 `phase6/7/8-*-smoke` 但 override W 參數）。建議新 target：`phase-crossregion-w128-suite`，掛 freeze → warmup 20min → 5 round × 5min → collect |
| **1.3** | 跑完 retrofit | 已可重用 `tests/common/summary-from-stdout.py --warehouses 128` |
| **1.4** | pipeline-log §2 W=128 數據回填 | 由 operator 跑 step 1.3 後填表 |
| **1.5** | slide v6 W=128 數據回填 | slide 6 / slide 9 三家欄位 |

**操作前 hard gate**：
- `gate-chrony-cross-region.sh` PASS（cross-region NTP 同步）
- WAN baseline RTT p50 < 50ms（per `wan/baseline-measurement.md`）
- TiDB/CRDB/YBDB 各 freeze scheduler/balancer（per `freeze/` 目錄）

### 2.2 路徑 2 — P-B placement 對比

| step | 內容 | 備註 |
|---|---|---|
| **2.1** | 三家 apply `placement-p-b.sql` | ansible playbook 觸發；apply 順序 per topology/P-B.md |
| **2.2** | `gate-placement-p-b.sh --db <db>` 確認 leader 跨區散 | 本 session 新增；fail-closed if 退化為 P-A 行為 |
| **2.3** | 三家 P-B × W=128 × N=5 suite | 同 step 1.2 觸發框架；只是 PLACEMENT=P-B |
| **2.4** | P-A vs P-B 對比表 | tpmC drop %、p99、commit RTT 三欄；填回 pipeline-log §3（新節）|

### 2.3 路徑 3 — chaos / F1 lab mode

| step | 內容 | 阻擋條件 |
|---|---|---|
| **3.1** | F1 IDC leader → GCP follower planned failover | 升級條件見 `RTO-RPO-methodology.md` §9（DBA review + probe driver + dry-run schema sanity 等 7 項） |
| **3.2** | C1 GCP partition lab | 同 §9 |
| **3.3** | C4 IDC leader die lab | 同 §9 |
| **3.4** | C7 placement gate fail-closed | 同 §9 |

⚠ CLAUDE.md 規定 chaos/F1 **planner-only；嚴禁 --execute flag**。實跑啟用必須單獨開 PR + DBA review label。

---

## 3. 已知阻擋 / 風險

- **`results/x-cross/` 目前資料皆 W=4** — slide v6 不能引用作為正式跨家排名數據（pipeline-log §1 已標註）
- **probe driver 尚未實裝**（RTO-RPO-methodology §3.2、§9 step 2）— go-tpc stdout 1s tick 顆粒度不足以量 RTO < 1s
- **wall-clock wrapper 尚未實裝**（§7.3）— `t_incident` / `t_first_ok` 兩時間戳目前無工具產生
- **TiDB / CRDB / YBDB 版本對應的 admin CLI 路徑** 需 DBA 重新確認（per F1.md §47-52）；本 session 用的指令為 spec 性質

---

## 4. 建議下一個 session 重點

1. **W=128 X-CROSS suite Makefile target 新增**（路徑 1.2 阻擋項）
2. **probe driver 三家最小 SQL probe 實裝**（RTO/RPO 量測前置）
3. **0626-slide-v6 後續推進段（slide 11）以本 NEXT-STEPS 為基底重寫**

---

## 5. 變更歷史

| 日期 | 內容 |
|---|---|
| 2026-06-26 | 初版 — RTO/RPO 方法論 + summary.json retrofit + P-B gate 落地後彙整 |
