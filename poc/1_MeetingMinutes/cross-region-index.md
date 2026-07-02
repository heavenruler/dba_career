# 跨區 PoC（IDC ↔ GCP / Track E）會議歷程索引

本檔是 `1_MeetingMinutes/` 中**跨區 PoC 討論脈絡的唯一入口**，依時序列出各會議文件的角色。
技術 canonical 一律以 [`../phase-crossregion/README.md`](../phase-crossregion/README.md) 為準，採信數據以
[`../results/x-cross/pipeline-log.md`](../results/x-cross/pipeline-log.md) 為準——本索引不複製技術細節。

## 時序脈絡

| 時間 | 文件 | 角色（此檔在跨區脈絡的定位） |
|---|---|---|
| 03–04 | [`0407.md`](./0407.md) · [`0400-to-J-slides.md`](./0400-to-J-slides.md) | 場域選定：以 SD IDC↔GCP 模擬 IDC↔EDC；對外敘事 |
| 06-02 | [`0602-decisions-track-E.md`](./0602-decisions-track-E.md) | **Track E B/C 決策 SSOT**（single 6-node、P-A/P-B、先 TiDB、N=1、W=128、chaos lab 模式）|
| 06-02 | [`0602.md`](./0602.md) §10 | Track E **原始詳細設計記錄**（拓撲/Test/chaos 注入/排程）— 現行 spec 已移至 phase-crossregion/ |
| 06-09 | [`2026-06-09-distributed-db-adoption-non-technical.md`](./2026-06-09-distributed-db-adoption-non-technical.md) | **D1 方向拍板**：跨區 DR「現行 No、中長期必需」；phase-crossregion 框架保留為能力儲備 |
| 06-11 | [`0611-TiDBx104-summary.md`](./0611-TiDBx104-summary.md) | PingCAP 原廠事實基線（多中心延遲/failover 建議）|
| 06-16 | [`0616.md`](./0616.md) | 進度盤點 + IDC IaC bug 發現 |
| 06-18 | [`2026-06-18-fw-request-net.md`](./2026-06-18-fw-request-net.md) | **FW 開通申請**：IDC↔GCP 控制平面阻擋根因實測 + 申請範圍 |
| 06-22 | [`2026-06-22-milestone.md`](./2026-06-22-milestone.md) | **全專案里程碑時間線**（跨區集中 M11–M13）|
| 06-30 | [`0630.md`](./0630.md) | TiDB 資源隔離 + 跨專線就近存取研究 |
| （簡報）| [`0616-slide-draft.md`](./0616-slide-draft.md) | 對外簡報草稿（事實基礎自 milestone + SESSION-HISTORY 衍生）|

## 決策 vs 技術 canonical 分工

- **決策脈絡**：本索引 + `0602-decisions-track-E.md`（Track E）+ `2026-06-09-...non-technical.md`（D1 方向）
- **本階段 Q1–Q14 拍板**：[`../phase-crossregion/decisions-2026-06-08.md`](../phase-crossregion/decisions-2026-06-08.md)
- **技術 spec / 執行 / 狀態**：[`../phase-crossregion/README.md`](../phase-crossregion/README.md)（閱讀脈絡樞紐）
- **執行歷史 / 踩坑**：[`../phase-crossregion/SESSION-HISTORY.md`](../phase-crossregion/SESSION-HISTORY.md)
- **採信數據**：[`../results/x-cross/pipeline-log.md`](../results/x-cross/pipeline-log.md)（現有多為 W=4 smoke，不可作正式跨家排名）
