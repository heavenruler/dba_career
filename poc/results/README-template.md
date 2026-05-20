# S-BASE 結果索引

> 本頁作為結果索引，只放目前可用數據、執行狀態與追溯入口；細節分析請看各資料庫的流程紀錄。

## 使用規則

- 資料庫名稱使用完整名稱：`TiDB`、`CockroachDB`、`YugabyteDB`。
- 隔離級使用完整名稱：`READ COMMITTED`、`REPEATABLE READ`、`SERIALIZABLE`、`最嚴格隔離級`。
- 不使用 `產物`；改用 `執行紀錄`、`結果目錄`、`流程紀錄`、`gate 記錄`。
- `來源目錄` 一律使用 Markdown link，指向實際結果目錄。
- README 只放索引與摘要；完整分析、機制推論與驗算細節放各資料庫 `pipeline-log.md`。
- 不同方法產生的數據必須在 `數據品質註解` 標明，例如 v4.7 5-round mean 與單次 10min wrapper 不可直接混成同一口徑。
- 若總覽或已驗證結果需要說明數據差異，只在表格內放 `註記` 欄；表格外段落則在句尾放註解連結。
- 註解連結統一寫成 `[註1](#note-1)`、`[註2](#note-2)`、`[註3](#note-3)`、`[註4](#note-4)`。
- `註1` 到 `註4` 為全文件共用，不針對單一表格重新編號。
- 文末固定使用 `<a id="note-1"></a>` anchor，避免 Markdown renderer 對中文 heading anchor 產生差異。

## 狀態標記

| 狀態 | 用途 |
|---|---|
| ✅ 完成 | 流程完整，數據可納入目前索引 |
| 🟡 完成，分析待修 | 執行紀錄完整，但分析口徑、欄位或歸因仍需修正 |
| 🟡 完成（pre-v4.7） | 舊流程或單次 wrapper 結果，可參考但不作為 v4.7 baseline |
| 🔄 待重跑 | 舊數據已排除，需用目前標準流程重跑 |
| ⏳ 待執行 | 尚未執行 |

## 目前總覽

| 資料庫 | 已完成且可用的結果 | 目前最高 tpmC | 狀態 | 註記 | 追溯入口 |
|---|---|---:|---|---|---|
| TiDB | `<案例與隔離級摘要>` | `<tpmC 或 —>` | `<狀態摘要>` | `<[註1](#note-1) 或 —>` | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | `<案例與隔離級摘要>` | `<tpmC 或 —>` | `<狀態摘要>` | `<[註2](#note-2) 或 —>` | [流程紀錄](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | `<案例與隔離級摘要>` | `<tpmC 或 —>` | `<狀態摘要>` | `<[註3](#note-3) 或 —>` | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md) |

> `<跨資料庫摘要或 caveat，例如不同 run 方法不可直接比較。>`

## 已驗證結果

| 資料庫 | 案例 | 隔離級 | 來源目錄 | 併發 | tpmC | p99 (ms) | 註記 | 判讀 |
|---|---|---|---|---:|---:|---:|---|---|
| TiDB | `<案例>` | `<隔離級>` | [`<結果目錄>`](./tidb-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<[註1](#note-1) 或 —>` | `<一句判讀>` |
| CockroachDB | `<案例>` | `<隔離級>` | [`<結果目錄>`](./crdb-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<[註2](#note-2) 或 —>` | `<一句判讀>` |
| YugabyteDB | `<案例>` | `<隔離級>` | [`<結果目錄>`](./yuga-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<[註3](#note-3) 或 —>` | `<一句判讀>` |

## 執行矩陣

| 資料庫 | 案例 | READ COMMITTED | REPEATABLE READ | 最嚴格隔離級 | 說明 |
|---|---|---|---|---|---|
| TiDB | 單節點虛擬機 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| TiDB | 三節點虛擬機，直連 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| TiDB | 三節點虛擬機，HAProxy | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| TiDB | Kubernetes，無資源限制 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| TiDB | Kubernetes，有資源限制 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| CockroachDB | 單節點虛擬機 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| CockroachDB | 三節點虛擬機，直連 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| CockroachDB | 三節點虛擬機，HAProxy | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| CockroachDB | Kubernetes，無資源限制 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| CockroachDB | Kubernetes，有資源限制 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| YugabyteDB | 單節點虛擬機 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| YugabyteDB | 三節點虛擬機，直連 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| YugabyteDB | 三節點虛擬機，HAProxy | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| YugabyteDB | Kubernetes，無資源限制 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |
| YugabyteDB | Kubernetes，有資源限制 | `<狀態>` | `<狀態>` | `<狀態>` | `<說明>` |

## 資料庫說明

### TiDB

- `<TiDB 目前完成範圍與最高結果。>`
- `<主要瓶頸或重要 caveat。>`
- `<下一步。>`

### CockroachDB

- `<CockroachDB 目前完成範圍與最高結果。>`
- `<主要瓶頸或重要 caveat。>`
- `<下一步。>`

### YugabyteDB

- `<YugabyteDB 目前完成範圍與最高結果。>`
- `<主要瓶頸或重要 caveat。>`
- `<下一步。>`

### 歷史檔案

- `<列出 deprecated 或 pre-v4.7 資料來源，並說明是否納入 baseline。>`

## 數據品質註解

| 編號 | 說明 |
|---|---|
| N1 | 本測試是 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C，不能與官方 TPC-C 排名直接比較。 |
| N2 | go-tpc 若沒有 think time / keying time，執行緒完成一筆交易後會立即送下一筆，因此 efficiency 超過 100% 屬正常。 |
| N3 | isolation 必須由 connection string 與 gate 記錄共同確認，避免 driver 或資料庫預設值造成測試口徑偏移。 |
| N4 | `<正式流程定義，例如 warmup、round 數、併發水位、監控範圍。>` |
| N5 | suite marker `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` 代表該案例流程鏈完整。 |
| N6 | `<數據口徑 caveat，例如 5-round mean、單次 10min run、欄位待修。>` |
| N7 | `<已清空或待重跑的資料說明。>` |
| N8 | `<外部文件、官方文件或推論限制。>` |

## 差異分析註解

| 註記 | 說明 |
|---|---|
| <a id="note-1"></a>註1 | `<差異計算口徑，例如 Δ tpmC = (本組 - 對照組) / 對照組。>` |
| <a id="note-2"></a>註2 | `<比較限制，例如不同資料庫、不同 isolation、不同 retry 行為時不可直接視為單一因素差異。>` |
| <a id="note-3"></a>註3 | `<資料品質限制，例如 v4.7 5-round mean 與單次 10min wrapper 不同口徑。>` |
| <a id="note-4"></a>註4 | `<機制歸因限制，例如 OS 指標支持但缺少 DB metrics / trace 直接佐證。>` |

## 參考

- TiDB 流程紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB 流程紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- YugabyteDB 流程紀錄：[yuga-tc1/S-BASE/pipeline-log.md](./yuga-tc1/S-BASE/pipeline-log.md)
- 歷史 README 備份：[README_old.md](./README_old.md)
