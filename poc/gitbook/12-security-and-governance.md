# 12. 安全與治理

> 最後驗證：2026-07-11｜本章為 vendor-neutral 控制基線；產品設定與稽核證據須由實際平台補齊。

## 上線安全硬閘

任一閘未通過即停止 promotion、cutover 或 DR 實跑；不得以例外口頭核准繞過。

| Gate | 通過證據 | 失敗處置 |
|---|---|---|
| 身分與權限 | SSO/IdP 對接、最小權限 RBAC、break-glass 可稽核 | 停止上線 |
| 網路 | 私網路徑、僅核准來源與埠、管理面隔離 | 停止上線 |
| 傳輸與靜態資料 | TLS、憑證輪替、加密金鑰 ownership/rotation 證據 | 停止上線 |
| 機密 | Secret manager 引用；repo、文件、log 無明文 | 移除、輪替、資安事件處理 |
| 稽核 | 管理操作、權限變更、資料存取審計可查且有保存期 | 停止上線 |
| 備份 | 加密、獨立存取、復原演練證據 | 不接受 RPO 宣告 |
| 弱點與供應鏈 | 版本清冊、弱點處理時限、映像/套件來源 | 停止 promotion |
| 個資 | 資料分類、遮罩、非生產去識別化 | 停止資料複製 |

## 治理原則

1. 資料 owner 定義分類、保留與刪除；平台 owner 不代替資料 owner 決定用途。
2. 生產存取採人員身分、時效授權、雙人覆核；禁止共享帳號。
3. SQL、設定、IaC 與 runbook 皆經 PR/變更單；緊急變更於事後補審計。
4. 本文件與交付物不可記載帳密、token、私鑰、內網位址或客戶/候選人資料。

## 最小稽核包

| 證據 | 保存 owner | 週期 | 標籤 |
|---|---|---|---|
| 存取與權限審查 | 資安 + 平台 | 季 | [待驗證] |
| 管理/資料稽核 log | 平台 | 依資料分級 TBD | [待驗證] |
| 憑證與金鑰輪替紀錄 | 資安 | 依政策 TBD | [待驗證] |
| 備份 restore 演練 | DBA | 至少每季，實際頻率 TBD | [待驗證] |

## 證據與限制

- [決策] 跨區既有規則禁止把密碼、token、私鑰寫入訊息、log 或文件；本章沿用此限制。[跨區 README](../phase-crossregion/README.md)
- [決策] 既有 PoC baseline 明示使用非生產的 trust/disabled auth 作 benchmark control，絕不可沿用到生產。[PoC 設計](../results/PoC-DESIGN.md)
- [待驗證] RBAC、審計保存期、金鑰系統、個資分類與法遵責任尚未由資安確認。

## 決策與待決

| 決策 | 狀態 | Owner |
|---|---|---|
| 定義 production security baseline 與例外流程 | 待核定 | 資安 |
| 建立資料分類、遮罩與非生產資料政策 | 待核定 | 資安、資料 owner |
| 將 security gates 納入 release/promotion pipeline | 待實作 | 平台、DBA |
