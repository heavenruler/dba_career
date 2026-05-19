# S-BASE 結果索引

> 原始 README 已備份至 [`README_old.md`](./README_old.md)。本頁作為結果索引，只放目前可用數據、執行狀態與追溯入口；細節分析請看各資料庫的流程紀錄。

## 目前總覽

| 資料庫 | 已完成且可用的結果 | 目前最高 tpmC | 狀態 | 追溯入口 |
|---|---|---:|---|---|
| TiDB | 單節點虛擬機，READ COMMITTED / REPEATABLE READ | **13,874** | 單節點完成；三節點與 Kubernetes 待重跑 | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | 單節點虛擬機，READ COMMITTED | **9,134** | 執行紀錄完整；分析口徑待修正 | [流程紀錄](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | — | — | 待用 PoC v4.7 流程重建 | — |

## 已驗證結果

| 資料庫 | 案例 | 隔離級 | 拓撲 | 併發數 | tpmC | 第 99 百分位延遲 | 判讀 |
|---|---|---|---|---:|---:|---:|---|
| TiDB | 單節點虛擬機 | REPEATABLE READ | 單節點 / 複本數 1 | 128 | **13,874** | 503ms | TiDB 目前最高 tpmC |
| CockroachDB | 單節點虛擬機 | READ COMMITTED | 單節點 / 複本數 1 | 64 | **9,134** | 待重算 | 執行紀錄已完成；延遲欄位待修正後定稿 |

## 執行矩陣

| 資料庫 | 案例 | READ COMMITTED | REPEATABLE READ | 最嚴格隔離級 | 說明 |
|---|---|---|---|---|---|
| TiDB | 單節點虛擬機 | ✅ 完成 | ✅ 完成 | ✅ 以 REPEATABLE READ 代表 | 原生最嚴格隔離級等同 REPEATABLE READ |
| TiDB | 三節點虛擬機，直連 | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| TiDB | 三節點虛擬機，HAProxy | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| TiDB | Kubernetes，無資源限制 | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| TiDB | Kubernetes，有資源限制 | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| CockroachDB | 單節點虛擬機 | 🟡 完成，分析待修 | ⏳ 待執行 | ⏳ 待執行 | READ COMMITTED 執行紀錄完整，延遲與瓶頸分析需修正 |
| CockroachDB | 三節點虛擬機，直連 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| CockroachDB | 三節點虛擬機，HAProxy | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| CockroachDB | Kubernetes，無資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| CockroachDB | Kubernetes，有資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | 單節點虛擬機 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | 三節點虛擬機，直連 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | 三節點虛擬機，HAProxy | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | Kubernetes，無資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | Kubernetes，有資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |

## 資料庫說明

### TiDB

- 單節點結果已完成 READ COMMITTED 與 REPEATABLE READ。
- 在 TiDB v8.5.2 pessimistic mode 與本工作負載下，REPEATABLE READ 的吞吐與第 99 百分位延遲都優於 READ COMMITTED。
- 128 併發是最高 tpmC，但 64 併發是較合理的觀察點；128 併發的延遲放大明顯。
- 三節點與 Kubernetes 舊數據已清空，避免與 PoC v4.7 方法混用。

### CockroachDB

- 單節點 READ COMMITTED 執行紀錄已完成，包含 gate、prepare、run、collect 與 suite marker。
- isolation gate 確認 session isolation 為 `read committed`。
- 目前只採用已核對的 tpmC；延遲與瓶頸分析待流程紀錄修正後再作正式結論。

### YugabyteDB

- 目前結果尚未用 PoC v4.7 流程重建。
- 後續需先確認 READ COMMITTED 是否真正生效，再納入橫向比較。

## 數據品質註解

| 編號 | 說明 |
|---|---|
| N1 | 本測試是 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C，不能與官方 TPC-C 排名直接比較。 |
| N2 | go-tpc 本輪沒有 think time / keying time，執行緒完成一筆交易後會立即送下一筆，因此 efficiency 超過 100% 屬正常。 |
| N3 | isolation 必須由 connection string 與 gate 記錄共同確認，避免 driver 或資料庫預設值造成測試口徑偏移。 |
| N4 | 單節點 PoC v4.7 使用 20 分鐘 warmup、每個併發水位 5 round，每 round 5 分鐘；正式解讀需看多輪穩定性。 |
| N5 | `.gate.done`、`.prepare.done`、`.gate-isolation.done`、`.run.done`、`.collect.done`、`.suite.done` 代表該案例流程鏈完整。 |
| N6 | CockroachDB 目前的 tpmC 可用；流程紀錄內延遲欄位與部分瓶頸歸因仍需修正後才可對外定稿。 |
| N7 | TiDB 三節點與 Kubernetes 數據已刻意清空，等待 PoC v4.7 重跑後再回填。 |

## 參考

- TiDB 流程紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB 流程紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- 歷史 README 備份：[README_old.md](./README_old.md)
