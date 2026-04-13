# PoC 文件導引

## 1. 閱讀順序

建議依以下順序閱讀：

1. [`README.md`](./README.md)
2. [`POC_TEST_DESIGN.md`](./POC_TEST_DESIGN.md)
3. [`POC_EXECUTION_RUNBOOK.md`](./POC_EXECUTION_RUNBOOK.md)
4. [`TIDB_IDC_GCP_ARCHITECTURE_DRAFT.md`](./TIDB_IDC_GCP_ARCHITECTURE_DRAFT.md)
5. [`YUGABYTEDB_IDC_GCP_ARCHITECTURE_DRAFT.md`](./YUGABYTEDB_IDC_GCP_ARCHITECTURE_DRAFT.md)

## 2. 各檔案用途

### `README.md`

- PoC 主文件
- 定義目標、文件結構、survey 評估面向
- 提供整體入口與架構設計章節索引

### `POC_TEST_DESIGN.md`

- PoC test case 定義文件
- 說明 common test cases 與 TiDB / YugabyteDB 專屬 test cases
- 定義 metrics、驗收觀點、後續待補項目

### `POC_EXECUTION_RUNBOOK.md`

- PoC 實作落地文件
- 說明環境前提、IaC 需求、部署工作分解、架構圖輸入資訊
- 適合當建置與執行 runbook 使用

### `TIDB_IDC_GCP_ARCHITECTURE_DRAFT.md`

- TiDB 在 `IDC-GCP / 5VM` 條件下的 Mermaid 架構草稿
- 包含 logical architecture 與 physical deployment
- 可作為 draw.io / Mermaid 繪圖基礎

### `YUGABYTEDB_IDC_GCP_ARCHITECTURE_DRAFT.md`

- YugabyteDB 在 `IDC-GCP / 5VM` 條件下的 Mermaid 架構草稿
- 包含 logical architecture 與 physical deployment
- 可作為 draw.io / Mermaid 繪圖基礎

## 3. 依工作目的找文件

### 要看 PoC 範圍與選型邏輯

- 先看 [`README.md`](./README.md)

### 要看 test case 與驗收重點

- 先看 [`POC_TEST_DESIGN.md`](./POC_TEST_DESIGN.md)

### 要看實際怎麼部署、怎麼執行

- 先看 [`POC_EXECUTION_RUNBOOK.md`](./POC_EXECUTION_RUNBOOK.md)

### 要補架構圖

- TiDB：[`TIDB_IDC_GCP_ARCHITECTURE_DRAFT.md`](./TIDB_IDC_GCP_ARCHITECTURE_DRAFT.md)
- YugabyteDB：[`YUGABYTEDB_IDC_GCP_ARCHITECTURE_DRAFT.md`](./YUGABYTEDB_IDC_GCP_ARCHITECTURE_DRAFT.md)

## 4. 建議維護原則

- `README.md` 只放總覽與索引，不塞過多細節
- `POC_TEST_DESIGN.md` 只放 test cases、metrics、驗收重點
- `POC_EXECUTION_RUNBOOK.md` 只放落地執行項目與環境資訊
- 架構圖草稿獨立維護，避免主文件過度膨脹

## 5. 後續可再新增的檔案

- `RESULTS_SUMMARY.md`
- `OPEN_ITEMS.md`
- `PORT_MATRIX.md`
- `IP_PLAN.md`
- `ANSIBLE_VARIABLES.md`
