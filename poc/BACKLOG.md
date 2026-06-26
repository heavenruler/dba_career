# PoC Backlog（future-scope / 未排入當前 session）

> 收集本 PoC 範圍外 / 未排定 session 的後續工項。當前 session 內 to-do 寫進 `phase-crossregion/NEXT-STEPS.md`；spec / SSOT 留 `results/PHASES.md` / `results/PoC-DESIGN.md`。本檔不放 spec 細節，只條列**項目 + 拍板來源**。

---

## 1. MySQL 對標測試

**拍板**：2026-06-26（goal session）
**動機**：補一條 baseline 對照線，讓「分散式 SQL vs 傳統 RDBMS」差距可量化；同時為現有產品線容量規劃提供 tpmC 基準。

| # | 項目 | scope 對齊 | 依賴 |
|---|---|---|---|
| 1.1 | **S-BASE 情境 MySQL 對標** | 對齊 `results/s-base/` 三家 (TiDB/CRDB/YBDB) W=128 × 5 round；同 hardware tier | 不依賴跨區；可獨立排程 |
| 1.2 | **X-CROSS (A-S) 情境 MySQL 對標** | 對齊 `phase-crossregion/workload-profiles/A-S.md`（active-standby）；同 W=128 × 5 round | MySQL replication 跨區 topology 確認（同/不同 region；async/semi-sync 口徑）|
| 1.3 | **科學計算 — 現有產品線 tpmC 需求量化** | 各既有產品線（依 stakeholder 提供）抓 peak QPS / TPS / DAU，反算所需 tpmC | 需 stakeholder 提供 metric 來源（Grafana / DB 監控） |

**前置決策（拍板前不啟動）**：
- MySQL 版本：8.x community / Percona / MariaDB？
- topology：single-node baseline / async replica / group replication / InnoDB Cluster？
- 一致性口徑：對應 RC / RR / strict 之 MySQL 哪個 isolation level（READ COMMITTED / REPEATABLE READ）？
- 觀測欄位：是否沿用 `summary-from-stdout.py` 解析？（go-tpc MySQL driver stdout 格式需驗證）

**產出對齊既有 schema**：
- `summary.json` 寫入 `phase` / `result_scope` / `baseline_family`（baseline_family 可能新增 `traditional-rdbms`）
- pipeline-log 沿用 `pipeline-log-template.md`

---

## 變更歷史

| 日期 | 變更 |
|---|---|
| 2026-06-26 | 初版：MySQL 對標 3 項排入 |
