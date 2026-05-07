# [分散式資料庫架構 PoC](https://104corp.atlassian.net/browse/ITDBA-3596)

```
opencode -s ses_28f349b65ffesqMOs3ScraWUt4
claude --resume 39164c14-87bc-4b78-a426-385135878d3f
```

## PoC 目標

本 PoC 用於驗證分散式資料庫架構是否可滿足 104Corp 既有業務系統需求。

Goal: 分散式資料庫部署不應因任何因素（例如停機維護）導致服務中止或暫停。

- 可用性：單點故障時可持續提供服務
- 擴充性：可支援資料量與流量成長
- 一致性：確認交易、複寫與故障切換行為
- 維運性：備援、監控、告警、備份與還原流程可操作
- 成本可行性：評估導入與營運成本是否合理

## 文件索引

| 用途 | 檔案 |
| --- | --- |
| 選型比較（9 維度 survey 表） | [`docs/survey.md`](./docs/survey.md) |
| Test case 定義、metrics、驗收重點 | [`docs/test-design.md`](./docs/test-design.md) |
| 部署流程、IaC 需求、執行 runbook | [`docs/execution-runbook.md`](./docs/execution-runbook.md) |
| TiDB 架構圖（Mermaid） | [`docs/architecture/tidb.md`](./docs/architecture/tidb.md) |
| YugabyteDB 架構圖（Mermaid） | [`docs/architecture/yugabytedb.md`](./docs/architecture/yugabytedb.md) |

## Requirements for Consultant

- [TiDB](https://hackmd.io/@a0SKFQ6dSo6shLxkFRvsBw/SycRGvKAWe)
- [YugabyteDB](https://hackmd.io/@a0SKFQ6dSo6shLxkFRvsBw/SkhH4vt0Zx)

## 目前狀態

規劃與文件階段：test case 設計完成，IaC 尚未實作。

下一步：補齊 vSphere / GCP 環境資訊後，開始建立 `infra/` Terraform 與 Ansible 骨架。
