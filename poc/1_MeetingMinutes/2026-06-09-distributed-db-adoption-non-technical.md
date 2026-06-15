# 2026-06-09 分散式資料庫導入：非技術討論

> 純 Q / 選項結構；待決議題 + 已拍板紀錄分列。

---

## 待決議題

### Q1 — Vendor 政策

- **問題**：排除哪些（中資 / BSL / 規模 / 商業實體）？

### Q2 — 對外溝通 / 內部背書

- **問題**：是否邀請 vendor presentation / 第三方驗證（顧問 / Gartner）？

### Q3 — POC report 呈現形式

- **Context**：給誰看 + 深度
- **選項**：BOD summary (1-2 pg) / Executive deep dive (10 pg) / Technical detail (30+ pg)
- **預設答**：三層皆做（不同 audience）

### Q4 — PG 應用導入 TiDB 可行性

- **Context**：TiDB 是 MySQL 8.0 wire-compat；PG → TiDB 是 cross-engine 遷移（SQL 方言 + driver + ORM dialect 三重）
- **選項**：(a) PG-stack 為主 → 排除 TiDB / (b) MySQL-stack 為主 → TiDB 首選 / (c) 混合 → 拆 track
- **影響**：直接決定三家篩選；與 Q1 / Q5 連動

### Q5 — all-in TiDB 公司樂見否

- **Context**：PoC 中 TiDB tpmC 26,947（最強 vs CRDB 15k / YBDB 15.6k）；但 all-in = 中資 vendor lock-in
- **選項**：(a) all-in TiDB / (b) TiDB-primary + 1 backup vendor / (c) multi-vendor by use-case
- **影響**：vendor 策略；與 Q1 / Q4 強連動

---

## 已拍板紀錄（2026-06-09）

### D1 — 跨區 IDC↔GCP DR：**No, 但中長期必需**

- **拍板理由**：distributed DB 導入 focus 在 IDC，累積維運經驗 + 架構穩定性
- **phase-crossregion 處置**：framework 保留作能力儲備（5 GCP VM iac + tidb-vm6 ansible + placement SQL + dry-run gate + chrony gate）；**不 destroy** commit `0c17ae9`；業務面 ready 時隨時啟動

### D2 — TLS 補測：**降權，cavet-only**

- 不啟動 9h 補測；PoC report 寫 caveat-only：「production TLS 預估 −5 ~ −15%」

### D3 — PG → TiDB 可行性（對應 Q4）：**TiDB 著重**（MySQL 相容性為主）

- 公司現行業務 MySQL stack 為主，PG stack < 5%

### D4 — all-in TiDB（對應 Q5）：**Unknown / 資訊不足**

- DBA 持有資訊不足以上 CTO / IT 治理委員會
- 阻塞：缺 PingCAP 商業實體狀態 / 中資政策依據 / 5-yr TCO 對比 / reference call / dual-vendor 量化共 5 項背書（補完約 4-6 週後重議）

---

## 變更歷史

| 日期 | 變更 |
|---|---|
| 2026-06-09 | 初稿 + 14 Q&A 拍板（commit cdb13e3）|
| 2026-06-15 | §3.2 / §3.10 / Q12 三節縮減（commit 85825a0）|
| 2026-06-15 | 整體結構重組為 10 個 section（commit 324d4be）|
| 2026-06-15 | 改為純 Q / 選項結構；移除原 10 section 對齊表 / vendor 對照表 / Q5 材料清單 / Q3 衍生 10 項 / critical path 等延伸資料 |
