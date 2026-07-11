# 14. 遷移與回滾

> 最後驗證：2026-07-11｜backup 與 migration 為 spec-only；不得描述為已完成的零停機能力。

## 遷移原則

採「可重跑、可驗證、可回退」的 wave 方式；單一服務先完成 rehearsal 與資料校驗，才可推進下一 wave。禁止把 PoC 壓測結果當成資料遷移驗收。

```mermaid
flowchart LR
  A[盤點與相容性] --> B[全量載入]
  B --> C[CDC/增量同步]
  C --> D[對帳與壓測]
  D --> E[Canary cutover]
  E --> F[觀察窗口]
  F --> G[擴大或回滾]
```

## 每波 checklist

| 階段 | 必備輸出 | Go/No-go |
|---|---|---|
| 評估 | schema/SQL/driver 相容性、資料分類、依賴清冊 | 未列出不支援語意即 No-go |
| 同步 | 全量基線、CDC lag、cutover point | lag 與錯誤門檻 TBD，未定義即 No-go |
| 驗證 | row count、checksum/抽樣、關鍵交易、權限 | 任一關鍵不一致即 No-go |
| 切換 | DNS/連線池/feature flag 回切步驟 | 無可測回切即 No-go |
| 觀察 | 業務 KPI、錯誤、p99、資料對帳 | 未達服務契約即回滾 |

## 回滾策略

| 狀況 | 回滾動作 | 必留證據 |
|---|---|---|
| cutover 前同步失敗 | 停止 wave，修正後從可識別 checkpoint 重跑 | lag/error、checkpoint、變更單 |
| canary 行為不符 | 流量切回來源系統，停止寫入擴大 | 時間線、比較指標、交易對帳 |
| 資料不一致 | 隔離目標寫入，啟動資料修復與 RCA | 差異範圍、修復紀錄、核准 |
| 區域 placement 遷移異常 | 重新套用已核准原 placement，待收斂再判定 | 前後 placement、健康、收斂時間 |

來源系統保留期限、雙寫/CDC 的衝突權威與最終回退截止點均為 TBD；未定義前不可開始 production cutover。[待驗證]

## 證據與限制

- [待驗證] 現有 migration profile 定義 placement 移動、timeline、資料列數驗證與緊急 abort，但未有實跑結果。[migration profile](../phase-crossregion/workload-profiles/migration.md)
- [待驗證] backup profile 列出 backup/restore 觀測項目，亦未有實跑結果。[backup profile](../phase-crossregion/workload-profiles/backup.md)
- [決策] 原 PoC 不涵蓋生產級容量、完整成本與正式 SLA 承諾。[test design](../0_projectFor104/docs/test-design.md)

## 決策與待決

| 決策 | 狀態 | Owner |
|---|---|---|
| 首波服務、資料範圍與來源系統保留期限 | 待核定 | 應用 owner、資料 owner |
| CDC/雙寫權威、衝突與補償規則 | 待核定 | 架構、應用 owner |
| 回滾截止點與資料修復授權 | 待核定 | 業務 owner、DBA |
