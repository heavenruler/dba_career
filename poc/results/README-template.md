# S-BASE 結果索引

> 本頁是結果索引，不單獨作最終結論。需要判斷數據可信度或機制原因時，請回到各資料庫 `pipeline-log.md`、來源目錄與調度分析（`dispatch-records/`）。

## 使用規則

- 資料庫名稱使用完整名稱：`TiDB`、`CockroachDB`、`YugabyteDB`。
- 隔離級使用完整名稱：`READ COMMITTED`、`REPEATABLE READ`、`SERIALIZABLE`、`最嚴格隔離級`。
- 不使用 `產物`；改用 `執行紀錄`、`結果目錄`、`流程紀錄`、`gate 記錄`。
- `來源目錄` 一律使用 Markdown link，指向實際結果目錄。
- README 只放索引與摘要；完整分析、機制推論與驗算細節放各資料庫 `pipeline-log.md` 或 `dispatch-records/<日期>-<scope>-analysis.md`。
- 不同方法產生的數據必須在 `數據品質註解` 標明，例如 v4.7 5-round mean 與單次 10min wrapper 不可直接混成同一口徑。
- 若總覽或已驗證結果需要說明數據差異，只在表格內放 `註記` 欄；表格外段落則在句尾放註解連結。
- 表格內的「標準四項」`註1`–`註4` 與「補充」`N1`–`N10` 分屬兩組編號，不互相替代。
- 註解連結統一寫成 `[註1](#note-1)`、`[N9](#note-N9)` 等格式；文末固定使用 `<a id="note-1"></a>` / `<a id="note-N9"></a>` anchor，避免 Markdown renderer 對中文 heading anchor 產生差異。
- `註1`–`註4` 與 `N1`–`N10` 為全文件共用，不針對單一表格重新編號。

## 如何閱讀

| 順序 | 閱讀區塊 | 目的 | 重點確認 |
|---:|---|---|---|
| 1 | [目前總覽](#目前總覽) | 快速掌握三家資料庫完成範圍 | 哪些案例已完成、待重跑、待執行 |
| 2 | [已驗證結果](#已驗證結果) | 取得目前可引用數字 | 來源目錄、TPCC_TS、`summary.json` / 原始輸出、完成標記 |
| 3 | [執行矩陣](#執行矩陣) | 避免誤讀測試進度 | 不把尚未回填的內容或待執行案例當正式結果 |
| 4 | [資料庫說明](#資料庫說明) | 建立各資料庫前置準備與知識儲備 | 架構、拓樸、吞吐、延遲、錯誤率、瓶頸與機制推論 |
| 5 | [表格註解](#表格註解標準四項) / [數據品質註解](#數據品質註解補充) | 先校準判讀口徑 | 隔離級、[分片 / 複本對吞吐與延遲的影響](#note-N10)、[獨立重跑次數 N 的嚴謹性差異](#note-N9) |
| 6 | [參考](#參考) | 追溯細節與設計口徑 | `pipeline-log.md`、調度分析、各資料庫研究紀錄、`PoC-DESIGN.md`、模板與協作規範 |

## 狀態標記

| 狀態 | 用途 |
|---|---|
| ✅ 完成 | 流程完整，數據可納入目前索引 |
| 🟡 完成，分析待修 | 執行紀錄完整，但分析口徑、欄位或歸因仍需修正 |
| 🟡 完成（pre-v4.7） | 舊流程或單次 wrapper 結果，可參考但不作為 v4.7 baseline |
| 🔄 待重跑 | 舊數據已排除，需用目前標準流程重跑 |
| ⏳ 待執行 | 尚未執行 |
| ➖ 不執行 | 在本 PoC 範圍內明確不跑（例如 vm-3node 以 RC 為主，RR / 最嚴格不執行）|

## 目前總覽

| 資料庫 | 已完成且可用的結果 | 目前最高 tpmC | 狀態 | 追溯入口 |
|---|---|---:|---|---|
| TiDB | `<案例與隔離級摘要>` | `<tpmC 或 —>` | `<狀態摘要>` | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | `<案例與隔離級摘要>` | `<tpmC 或 —>` | `<狀態摘要>` | [流程紀錄](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | `<案例與隔離級摘要>` | `<tpmC 或 —>` | `<狀態摘要>` | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md) |

> `<跨資料庫摘要或 caveat，例如同硬體規格對照、同名 isolation 機制差異參考 [註2](#note-2)。>`

## 已驗證結果

> `error rate` 代表「失敗交易數 / 全部交易數」。全部交易數包含成功與失敗，並把 5 種 TPC-C transaction type 加總；由 [summary parser](../tests/common/summary-from-stdout.py) 解析 stdout `[Summary]` 後寫入 `summary.json`。

| 資料庫 | 案例 | 隔離級 | 來源目錄 | 併發 | tpmC | p99 (ms) | error rate | 判讀 |
|---|---|---|---|---:|---:|---:|---:|---|
| TiDB | `<案例>` | `<隔離級>` | [`<TPCC_TS>`](./tidb-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<errors / total 或 %>` | `<一句判讀；可引用 [註2](#note-2) [註4](#note-4)>` |
| CockroachDB | `<案例>` | `<隔離級>` | [`<TPCC_TS>`](./crdb-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<errors / total 或 %>` | `<一句判讀>` |
| YugabyteDB | `<案例>` | `<隔離級>` | [`<TPCC_TS>`](./yuga-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<errors / total 或 %>` | `<一句判讀>` |

### 三節點補充結果

> 本段列出已完成但仍需 caveat 的三節點結果（例如 N=1、DB-host metrics 缺失）；不併入上方主表，避免與單節點三 isolation baseline 混讀。N=1 / N=3 定義見 [N9](#note-N9)；shard / replica 對吞吐與延遲的影響見 [N10](#note-N10)。

| 資料庫 | 案例 | 隔離級 | 來源目錄 | 併發 | tpmC | p99 (ms) | error rate | 判讀 |
|---|---|---|---|---|---:|---:|---|---|
| `<DB>` | `<直連 - <shards>s<replicas>r 或 HAProxy - <shards>s<replicas>r>` | READ COMMITTED | [`<TPCC_TS>`](./<db>-tc1/S-BASE/<case>/<result-dir>/) | `<threads>` | `<tpmC>` | `<p99>` | `<errors / total 或 %>` | [流程紀錄](./<db>-tc1/S-BASE/pipeline-log.md#<anchor>)；[<分析報告>](./dispatch-records/<file>.md) |

## 執行矩陣

> 三節點（直連 + HAProxy）及 Kubernetes 以 `READ COMMITTED` 為主。`REPEATABLE READ` / 最嚴格隔離級在三節點不執行；vm-1node 三 isolation 已涵蓋跨家對標。

<table>
  <thead>
    <tr>
      <th>資料庫</th>
      <th>案例</th>
      <th>READ COMMITTED</th>
      <th>REPEATABLE READ</th>
      <th>最嚴格隔離級</th>
    </tr>
  </thead>
  <tbody>
    <tr><td rowspan="5">TiDB</td><td>單節點虛擬機</td><td>`<狀態>`</td><td>`<狀態>`</td><td>`<狀態>`</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>`<狀態>`</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>`<狀態>`</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>`<狀態>`</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>`<狀態>`</td></tr>
    <tr><td rowspan="5">CockroachDB</td><td>單節點虛擬機</td><td>`<狀態>`</td><td>`<狀態>`</td><td>`<狀態>`</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>`<狀態>`</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>`<狀態>`</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>`<狀態>`</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>`<狀態>`</td></tr>
    <tr><td rowspan="5">YugabyteDB</td><td>單節點虛擬機</td><td>`<狀態>`</td><td>`<狀態>`</td><td>`<狀態>`</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>`<狀態>`</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>`<狀態>`</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>`<狀態>`</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>`<狀態>`</td></tr>
  </tbody>
</table>

## 資料庫說明

### TiDB

- `<架構摘要：TiDB server / TiKV / PD / TiFlash 分層；scale-out 路徑。>`
- `<目前完成範圍與最高結果。>`
- `<主要瓶頸或重要 caveat。>`
- `<下一步。>`

### CockroachDB

- `<架構摘要：對稱式 SQL/Distribution/Replication/Storage；HAProxy 連線分散。>`
- `<目前完成範圍與最高結果。>`
- `<主要瓶頸或重要 caveat。>`
- `<下一步。>`

### YugabyteDB

- `<架構摘要：YSQL / DocDB / yb-tserver 一體；YB triple gate。>`
- `<目前完成範圍與最高結果。>`
- `<主要瓶頸或重要 caveat。>`
- `<下一步。>`

### 歷史檔案

- `<列出 deprecated 或 pre-v4.7 資料來源，並說明是否納入 baseline。>`

## 表格註解（標準四項）

> 本段定義 README 內數字與判讀用語的共通口徑；正文出現 `[註1]`–`[註4]` 連回本段。下方 `N1`–`N10` 為**額外方法論補充**。

| 編號 | 說明 |
|---|---|
| <a id="note-1"></a>註1 | **差異計算口徑**：所有 Δ tpmC / Δ p99 / `相對 -XX%` 均為 `(本組 - 對照組) / 對照組 × 100%`；error rate 為「失敗交易數 / 全部交易數 × 100%」，全部交易數 = 成功交易數 + 失敗交易數（5 種 TPC-C transaction type 全部加總）。 |
| <a id="note-2"></a>註2 | **跨家比較限制**：同名 isolation 在三家底層機制不同（TiDB RR=pessimistic SI / CockroachDB RR=preview SI optimistic / YugabyteDB RR=snapshot iso optimistic），不可視為單一變數差異；TiDB strict 在工具鏈上 alias 到 RR，不可直比 CockroachDB / YugabyteDB 原生 SSI。 |
| <a id="note-3"></a>註3 | **資料品質口徑**：本表所有 v4.7 結果均為 5-round mean（drop round 1 取 round 2-5 中位數的口徑詳見 PoC-DESIGN §8.3），由 [`tests/common/summary-from-stdout.py`](../tests/common/summary-from-stdout.py) 解析 stdout 後落地至各 suite `summary.json`；pre-v4.7 single-run 結果已封存於 `<db>-tc1-old/` 不納入本表。 |
| <a id="note-4"></a>註4 | **機制歸因限制**：所有「飽和成因」/「strict 反 pattern」/「retry storm」結論主要以 OS 指標（mpstat/iostat）+ artifact 錯誤訊息推論而來；DB-internal 路徑（CockroachDB store metrics、YugabyteDB DocDB tablet metrics、TiDB TiKV wait events）未直接量測，待 trace / statement diagnostics 補強。 |

## 數據品質註解（補充）

| 編號 | 說明 |
|---|---|
| N1 | 本測試是 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C，不能與官方 TPC-C 排名直接比較。 |
| N2 | go-tpc 本輪沒有 think time / keying time，執行緒完成一筆交易後會立即送下一筆，因此 efficiency 超過 100% 屬正常。 |
| N3 | isolation 必須由 connection string 與 gate 記錄共同確認，避免 driver 或資料庫預設值造成測試口徑偏移（CockroachDB 採 isolation 雙閘 = `isolation-db.txt` + `isolation-driver-verify.txt`；YugabyteDB 採 **triple gate**：① `--ysql_default_transaction_isolation` ② `--yb_enable_read_committed_isolation` ③ active gate `SHOW TRANSACTION ISOLATION LEVEL` + `SELECT yb_get_effective_transaction_isolation_level()`；舊 `SHOW yb_effective_transaction_isolation_level` 已 [deprecated](https://yugabytedb.tips/view-yb-run-time-parameters-values-and-descriptions/)）。 |
| N4 | v4.7 標準格式：20 分鐘 warmup、每個併發水位 5 round × 5 分鐘、4 thread groups（16/32/64/128）、DB-host 雙邊 OS 監控（mpstat/iostat/vmstat/sar）。 |
| N5 | suite marker `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` + `.db-config.done` 代表該案例流程鏈完整。 |
| N6 | tpmC 與 latency p50/p95/p99 全為 5-round mean；數據來源為 `runs/threads-*/round-*/go-tpc-stdout.txt` + [`tests/common/summary-from-stdout.py`](../tests/common/summary-from-stdout.py) 解析後落地的 `summary.json`。 |
| N7 | `<已清空或待重跑的資料說明。>` |
| N8 | `<外部文件、官方文件或推論限制。>` |
| <a id="note-N9"></a>N9 | **`N` = 獨立重跑次數**，不是 round 數。`N=1` 代表只做過 1 次完整流程（重建環境 → 部署 → prepare → run → collect），雖然裡面有 4 個併發水位 × 5 round，但只能降低單次執行內的隨機波動，無法證明不同時間、不同重建環境下仍穩定。`N=3` 代表完整流程獨立重跑 3 次，可觀察三次之間是否一致，嚴謹性明顯高於 N=1；若三次結果接近，才比較適合作為對外結論。本文凡標 `N=1` 或 `N=3 待確認` 的結果，都只能視為方向性觀察，不視為最終定論。 |
| <a id="note-N10"></a>N10 | **分片（shard）/ 複本（replica）是三節點結果的核心變數**。分片數決定資料被切成幾份，會影響資料分散、tablet / range 協調與跨節點查找成本；複本數決定每筆資料同步保存幾份，會影響寫入時的同步複寫、quorum commit 與延遲。若分片數或複本數沒有固定，就無法分辨效能差異到底來自「資料切分」還是「複寫成本」，也不能把不同拓撲的 tpmC / p99 視為同口徑比較。 |

## 參考

- TiDB 流程紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB 流程紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- YugabyteDB 流程紀錄：[yuga-tc1/S-BASE/pipeline-log.md](./yuga-tc1/S-BASE/pipeline-log.md)
- PoC 設計：[PoC-DESIGN.md](./PoC-DESIGN.md)
- 模板與協作規範：[README-template.md](./README-template.md) / [pipeline-log-template.md](./pipeline-log-template.md) / [AI-COLLABORATION.md](./AI-COLLABORATION.md)
- 審計 prompt：[audit-watch-prompt.md](./audit-watch-prompt.md)
- 調度紀錄與分析：[dispatch-records/](./dispatch-records/)
- 歷史 README 備份：[archive/README_old.md](./archive/README_old.md)
