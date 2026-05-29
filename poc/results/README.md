# S-BASE 結果索引

## 如何閱讀

本頁是結果索引，不單獨作最終結論。需要判斷數據可信度或機制原因時，請回到各資料庫 `pipeline-log.md`、來源目錄與調度分析。

| 順序 | 閱讀區塊 | 目的 | 重點確認 |
|---:|---|---|---|
| 1 | [目前總覽](#目前總覽) | 快速掌握三家資料庫完成範圍 | 哪些案例已完成、待重跑、待執行 |
| 2 | [已驗證結果](#已驗證結果) | 取得目前可引用數字 | 來源目錄、TPCC_TS、`summary.json` / 原始輸出、完成標記 |
| 3 | [執行矩陣](#執行矩陣) | 避免誤讀測試進度 | 不把尚未回填的內容或待執行案例當正式結果 |
| 4 | [資料庫說明](#資料庫說明) | 建立各資料庫前置準備與知識儲備 | 架構、拓樸、吞吐、延遲、錯誤率、瓶頸與機制推論 |
| 5 | [專案進度](#專案進度) | 從專案管理視角查看範圍、時程、風險與驗收 | 週次時程表、產出項目、風險管制欄位 |
| 6 | [表格註解](#表格註解標準四項) / [數據品質註解](#數據品質註解補充) | 先校準判讀口徑 | 隔離級、[分片 / 複本對吞吐與延遲的影響](#note-N10)、[獨立重跑次數 N 的嚴謹性差異](#note-N9) |
| 7 | [參考](#參考) | 追溯細節與設計口徑 | `pipeline-log.md`、調度分析、各資料庫研究紀錄、`PoC-DESIGN.md`、模板與協作規範 |

## 目前總覽

| 資料庫 | 已完成且可用的結果 | 目前最高 tpmC | 狀態 | 追溯入口 |
|---|---|---:|---|---|
| TiDB | - 單節點虛擬機，三 isolation | **13,874**<br>單節點 RR，t=128 | - ✅ 單節點三 isolation 完成<br>- 🔄 三節點（多分片 / 副本 / HAProxy）待重跑<br>- 🔄 Kubernetes 待重跑 | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | - 單節點虛擬機，三 isolation | **10,830**<br>單節點 SERIALIZABLE，t=64 | - ✅ 單節點三 isolation 完成<br>- 🔄 三節點（多分片 / 副本 / HAProxy）待重跑<br>- 🔄 Kubernetes 待重跑 | [流程紀錄](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | - 單節點虛擬機，三 isolation<br>- 三節點虛擬機，direct RC<br>- 三節點虛擬機，HAProxy 3s3r RC | **15,632**<br>三節點 HAProxy 3s3r RC，t=128 | - ✅ 單節點三 isolation 完成<br>- ✅ 三節點（多分片 / 副本 / HAProxy）完成<br>- 🔄 Kubernetes 待重跑 | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md) |

- 同硬體規格對照：4 vCPU / 16 GiB / single XFS，5-round mean，9 組（資料庫 × isolation）[註3](#note-3)。
- 同名 isolation 在三家底層機制不同，請先參考 [註2](#note-2)。

## 已驗證結果

> `error rate` 代表「失敗交易數 / 全部交易數」。全部交易數包含成功與失敗，並把 5 種 TPC-C transaction type 加總；由 [summary parser](../tests/common/summary-from-stdout.py) 解析 stdout `[Summary]` 後寫入 `summary.json`。

| 資料庫 | 案例 | 隔離級 | 來源目錄 | 併發 | tpmC | p99 (ms) | error rate | 判讀 |
|---|---|---|---|---:|---:|---:|---:|---|
| TiDB | 單節點虛擬機 | READ COMMITTED | [20260518T202009](./tidb-tc1/S-BASE/vm-1node-rc/tidb-vm-1node-rc-20260518T202009+0800/) | 128 | 13,064 | 597 | 0.000% | RC baseline；CPU-bound（%user 80.8%、%iowait 3.1%）[註4](#note-4) |
| TiDB | 單節點虛擬機 | REPEATABLE READ | [20260519T001949](./tidb-tc1/S-BASE/vm-1node-rr/tidb-vm-1node-rr-20260519T001949+0800/) | 128 | **13,874** | 503 | 0.000% | **TiDB 最高 tpmC**；pessimistic 模式零 error（跨家 RR 同名不同實 [註2](#note-2)）|
| CockroachDB | 單節點虛擬機 | READ COMMITTED | [20260519T085346](./crdb-tc1/S-BASE/vm-1node-rc/crdb-vm-1node-rc-20260519T085346+0800/) | 64 | 9,134 | 440 | 0.000% | RC 在 t16 起即被 fsync IO 卡死（%iowait 18%）[註4](#note-4) |
| CockroachDB | 單節點虛擬機 | REPEATABLE READ | [20260519T124506](./crdb-tc1/S-BASE/vm-1node-rr/crdb-vm-1node-rr-20260519T124506+0800/) | 128 | 3,788 | 604 | 0.300% | preview RR；retry storm（DB %idle 46%、127 err/round）[註2](#note-2) [註4](#note-4) |
| CockroachDB | 單節點虛擬機 | SERIALIZABLE | [20260519T164057](./crdb-tc1/S-BASE/vm-1node-strict/crdb-vm-1node-strict-20260519T164057+0800/) | 64 | **10,830** | 227 | 0.051% | **CockroachDB 最高 tpmC**；t32+ 超越 RC（反直覺，預設最快）[註4](#note-4)；t128 mean 仍 10,456 / p99 487ms，高併發保持領先 |
| YugabyteDB | 單節點虛擬機 | READ COMMITTED | [20260520T134929](./yuga-tc1/S-BASE/vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/) | 32 | **11,436** | 216 | 0.000% | **YugabyteDB v4.7 baseline**；5-round mean，零 error；t32 為 peak（t128 -4.8% 過飽和）|
| YugabyteDB | 單節點虛擬機 | REPEATABLE READ | [20260520T215216](./yuga-tc1/S-BASE/vm-1node-rr/ybdb-vm-1node-rr-20260520T215216+0800/) | 32 | 1,879 | 174 | 0.149% | snapshot iso（非 PG 標準 RR）[註2](#note-2)；hot row retry storm，每 round = thread − 1 errors；DB %idle 67% — coordination bound 非 CPU/IO [註4](#note-4) |
| YugabyteDB | 單節點虛擬機 | SERIALIZABLE | [20260521T091048](./yuga-tc1/S-BASE/vm-1node-strict/ybdb-vm-1node-strict-20260521T091048+0800/) | 32 | 1,130 | 54 | 0.248% | SSI；YugabyteDB rc 為 CPU-bound 所以 SSI 反而比 rc / rr 都慢（與 CockroachDB SSI ＞ rc 相反）[註2](#note-2) [註4](#note-4)；p99 全 iso 最低但因 throughput -90% queue 短的副作用；DB %idle 70% |

### 三節點補充結果

> 本段列出已完成但仍需 caveat 的三節點結果；不併入上方主表，避免與單節點三 isolation baseline 混讀。

| 資料庫 | 案例 | 隔離級 | 來源目錄 | 併發 | tpmC | p99 (ms) | error rate | 判讀 |
|---|---|---|---|---|---:|---:|---|---|
| YugabyteDB | 直連 - 3s3r | READ COMMITTED | [20260525T031918](./yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/) | t=128 | 8,729 | 1,114 | 0.000% | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md#vm-3node-系列4-sub-topology--rcpoc-design-632)；[跨 cell 分析](./dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md) |
| YugabyteDB | HAProxy - 3s3r | READ COMMITTED | [20260525T193740](./yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/) | t=128 | **15,632** | 705 | 0.000% | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md#vm-3node-haproxy-3s3r-rc3-shards--rf3--haproxy)；[HAProxy 分析](./dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md) |

## 執行矩陣

> 三節點（直連 + HAProxy）及 Kubernetes 以 `READ COMMITTED` 為主。參考 vm-1node 三 isolation 對標說明。

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
    <tr><td rowspan="5">TiDB</td><td>單節點虛擬機</td><td>✅ 完成</td><td>✅ 完成</td><td>✅ 以 REPEATABLE READ 代表</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>🔄 待重跑</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td rowspan="5">CockroachDB</td><td>單節點虛擬機</td><td>✅ 完成</td><td>✅ 完成</td><td>✅ 完成（SERIALIZABLE）</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>🔄 待重跑</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td rowspan="5">YugabyteDB</td><td>單節點虛擬機</td><td>✅ 完成</td><td>✅ 完成</td><td>✅ 完成（SERIALIZABLE）</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>✅ 完成（4 子拓撲）</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>✅ 完成（3s3r）</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>🔄 待重跑</td></tr>
  </tbody>
</table>

## 資料庫說明

### TiDB

[![TiDB Architecture](https://docs-download.pingcap.com/media/images/docs/tidb-architecture-v6.png)](https://docs.pingcap.com/tidb/stable/tidb-architecture/)

來源：[TiDB Architecture — PingCAP Docs](https://docs.pingcap.com/tidb/stable/tidb-architecture/)

- **TiDB server**：SQL 接收層，負責解析 SQL、產生執行計畫、處理 transaction coordination；本身不保存主要資料。
- **TiKV**：分散式 row store，保存 OLTP 資料；資料以 Region 切分並透過 Raft 複寫，影響寫入延遲與多副本成本。
- **PD (Placement Driver)**：叢集 metadata 與排程控制中心，負責 timestamp oracle、Region placement 與負載調度。
- **TiFlash**：columnar replica，主要用於 HTAP / analytical query；本輪 TPC-C-derived OLTP 測試不以 TiFlash 為主要路徑。
- **架構重點**：SQL 層與儲存層分離；增加 TiDB server 可擴充 SQL 接收與執行能力，增加 TiKV 則擴充資料儲存與 Raft 複寫能力。

### CockroachDB

[![CockroachDB Architecture](https://github.com/cockroachdb/cockroach/raw/master/docs/media/architecture.png)](https://github.com/cockroachdb/cockroach/blob/master/docs/design.md)

來源：[cockroachdb/cockroach — docs/design.md](https://github.com/cockroachdb/cockroach/blob/master/docs/design.md)。CockroachDB 官方 docs 站 Architecture Overview 頁為純文字、無單一整體架構圖；此圖取自 CockroachDB GitHub 原始碼倉庫 `docs/media/architecture.png`，雖為早期設計文件版本，但仍是原廠維護中的官方資料。

- **SQL layer**：每個 CockroachDB 節點都能接 SQL request、產生 query plan、處理 transaction coordination。
- **Transactional KV / Distribution**：SQL 會轉成 key-value operation，由 distribution layer 找到資料所在 range 並路由到正確節點。
- **Replication / Raft**：資料以 range 為單位複寫，透過 Raft 維持一致性；replica 數會直接影響寫入 quorum 與 commit latency。
- **Storage**：每個節點都同時保存資料並處理查詢，沒有獨立 SQL node / storage node 分層。
- **架構重點**：對稱式架構；任一節點都同時具備 SQL、transaction、distribution、replication 與 storage 能力，HAProxy 可把連線分散到多個完整節點。

### YugabyteDB

[![YugabyteDB Architecture](https://docs.yugabyte.com/images/architecture/layered-architecture.png)](https://docs.yugabyte.com/stable/architecture/)

來源：[Architecture — YugabyteDB Docs](https://docs.yugabyte.com/stable/architecture/)

- **YSQL**：PostgreSQL-compatible SQL API，負責接收 SQL、處理 query planning 與 transaction request。
- **YCQL**：Cassandra-compatible API，本輪 TPC-C-derived OLTP 測試不走此路徑。
- **DocDB**：YugabyteDB 的 distributed document store，負責資料儲存、MVCC、tablet 管理與 Raft 複寫。
- **YB-TServer**：資料服務節點，承載 YSQL/YCQL request path 與 DocDB tablet；SQL 與儲存同在 tserver 內，和 TiDB 的 SQL / storage 分離不同。
- **YB-Master**：叢集 metadata 管理元件，負責 tablet placement、schema metadata 與 cluster coordination。
- **架構重點**：tserver 一體式架構；加節點時 SQL 接收能力與資料 tablet capacity 一起增加，實際效能同時受 tablet 分布、複本數與 transaction coordination 影響。

## 表格註解（標準四項）

> 本段定義 README 內數字與判讀用語的共通口徑；正文若出現 [註2] / [註3] / [註4] 會連回本段，註1 作為全文件計算口徑。下方 N1-N10 為**額外方法論補充**。

| 編號 | 說明 |
|---|---|
| <a id="note-1"></a>註1 | **差異計算口徑**：所有 Δ tpmC / Δ p99 / `相對 -XX%` 均為 `(本組 - 對照組) / 對照組 × 100%`；error rate 為「失敗交易數 / 全部交易數 × 100%」，全部交易數 = 成功交易數 + 失敗交易數（5 種 TPC-C transaction type 全部加總）。 |
| <a id="note-2"></a>註2 | **跨家比較限制**：同名 isolation 在三家底層機制不同（TiDB RR=pessimistic SI / CockroachDB RR=preview SI optimistic / YugabyteDB RR=snapshot iso optimistic），不可視為單一變數差異；TiDB strict 在工具鏈上 alias 到 RR，不可直比 CockroachDB / YugabyteDB 原生 SSI。 |
| <a id="note-3"></a>註3 | **資料品質口徑**：本表所有 v4.7 結果均為 5-round mean（drop round 1 取 round 2-5 中位數的口徑詳見 PoC-DESIGN §8.3），由 [`tests/common/summary-from-stdout.py`](../tests/common/summary-from-stdout.py) 解析 stdout 後落地至各 suite `summary.json`；pre-v4.7 single-run 結果已封存於 `yuga-tc1-old/` 不納入本表。 |
| <a id="note-4"></a>註4 | **機制歸因限制**：所有「飽和成因」/「strict 反 pattern」/「retry storm」結論主要以 OS 指標（mpstat/iostat）+ artifact 錯誤訊息推論而來；DB-internal 路徑（CockroachDB store metrics、YugabyteDB DocDB tablet metrics、TiDB TiKV wait events）未直接量測，待 trace / statement diagnostics 補強。 |

## 數據品質註解（補充）

| 編號 | 說明 |
|---|---|
| N1 | 本測試是 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C，不能與官方 TPC-C 排名直接比較。 |
| N2 | go-tpc 本輪沒有 think time / keying time，執行緒完成一筆交易後會立即送下一筆，因此 efficiency 超過 100% 屬正常。 |
| N3 | isolation 必須由 connection string 與 gate 記錄共同確認，避免 driver 或資料庫預設值造成測試口徑偏移（CockroachDB 採 isolation 雙閘 = `isolation-db.txt` + `isolation-driver-verify.txt`；YugabyteDB 採 **triple gate**：① `--ysql_default_transaction_isolation` ② `--yb_enable_read_committed_isolation` ③ active gate `SHOW TRANSACTION ISOLATION LEVEL` + `SELECT yb_get_effective_transaction_isolation_level()`；舊 `SHOW yb_effective_transaction_isolation_level` 已 [deprecated](https://yugabytedb.tips/view-yb-run-time-parameters-values-and-descriptions/)）。 |
| N4 | v4.7 標準格式：20 分鐘 warmup、每個併發水位 5 round × 5 分鐘、4 thread groups（16/32/64/128）、DB-host 雙邊 OS 監控（mpstat/iostat/vmstat/sar）。TiDB / CockroachDB / YugabyteDB vm-1node 三家全 iso 已採此格式；YugabyteDB vm-3node direct RC 4 cells 已採此格式；YugabyteDB HAProxy 3s3r RC 已完成但 DB-host metrics missing；Kubernetes 重跑尚未排程；YugabyteDB pre-v4.7 single-run 已備份於 yuga-tc1-old/。 |
| N5 | suite marker `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` + `.db-config.done` 代表該案例流程鏈完整。 |
| N6 | CockroachDB / TiDB / YugabyteDB 三家 vm-1node 全 iso 的 tpmC 與 latency p50/p95/p99 已全為 5-round mean，口徑一致；數據來源為 `runs/threads-*/round-*/go-tpc-stdout.txt` + `[tests/common/summary-from-stdout.py](../tests/common/summary-from-stdout.py)` 解析後落地的 `summary.json`。 |
| N7 | TiDB 三節點與 Kubernetes 數據已刻意清空，等待 PoC v4.7 重跑後再回填。 |
| N8 | CockroachDB 機制描述以 artifact 數據與[官方 v26.2 docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) 為主；server-internal retry 等未直接量測項以「推測」呈現，待 trace / statement diagnostics 補強。 |
| <a id="note-N9"></a>N9 | **`N` = 獨立重跑次數**，不是 round 數。`N=1` 代表只做過 1 次完整流程（重建環境 → 部署 → prepare → run → collect），雖然裡面有 4 個併發水位 × 5 round，但只能降低單次執行內的隨機波動，無法證明不同時間、不同重建環境下仍穩定。`N=3` 代表完整流程獨立重跑 3 次，可觀察三次之間是否一致，嚴謹性明顯高於 N=1；若三次結果接近，才比較適合作為對外結論。本文凡標 `N=1` 或 `N=3 待確認` 的結果，都只能視為方向性觀察，不視為最終定論。 |
| <a id="note-N10"></a>N10 | **分片（shard）/ 複本（replica）是三節點結果的核心變數**。分片數決定資料被切成幾份，會影響資料分散、tablet / range 協調與跨節點查找成本；複本數決定每筆資料同步保存幾份，會影響寫入時的同步複寫、quorum commit 與延遲。若分片數或複本數沒有固定，就無法分辨效能差異到底來自「資料切分」還是「複寫成本」，也不能把不同拓撲的 tpmC / p99 視為同口徑比較。 |

## 專案進度

> 如果把 `poc` 當成一個需要控管範圍、時程、風險與驗收門檻的專案，README 這份索引會額外產生下列治理資訊；這些內容不替代各資料庫 `pipeline-log.md`，只用來看專案進度與風險狀態。

| 類別 | 會產生的資訊 | 主要用途 |
|---|---|---|
| 範圍 | 已完成 / 待重跑 / 待執行案例、vm-1node / vm-3node / Kubernetes / HAProxy 的覆蓋範圍 | 確認 PoC 邊界是否收斂，避免把待執行案例當成正式完成 |
| 時程 | 里程碑、目前卡點、重跑順序、下一個可驗收節點 | 判斷專案是否延誤，以及是否需要調整執行順序 |
| 成本 | 受影響的機器、執行批次數、重跑次數、人工介入次數 | 估算實際投入，避免只看最終數字而忽略執行成本 |
| 風險 | 參數偏移、shard / replica 不一致、summary 來源缺失、DB-host metrics 缺口、流程中斷 | 形成風險清單與管制點，決定哪些 case 可以進主表、哪些只能作 caveat |
| 驗收 | `.gate.done` / `.prepare.done` / `.run.done` / `.collect.done` / `summary.json` / 來源目錄 / TPCC_TS | 檢查每組數據是否具備可追溯性，以及是否能進入對外引用 |
| 變更 | 調度分析、pipeline-log 修訂、模板調整、deprecated 資料封存 | 保留版本差異，讓結果與規格變更可回頭追蹤 |

### 風險管制欄位

- `scope drift`：案例範圍是否超出原本定義，或把待執行案例提前當成完成。
- `data completeness`：`summary.json`、原始輸出、完成標記、來源目錄是否齊全。
- `topology drift`：shard / replica / HAProxy / Kubernetes 拓樸是否與設計口徑一致。
- `isolation drift`：connection string、session setting、effective isolation 是否一致。
- `operational drift`：執行是否被中斷、重跑是否有遺留資料、結果是否混入 retry artifact。
- `analysis drift`：分析是否使用了未驗證推論，或把 caveat 省略成結論。

### PMP 會看的摘要

- 進度：哪些 case 完成，哪些待重跑，哪些只到設計或 pre-check。
- 風險：哪一類缺口會影響數據可用性，哪一類只是時間延後。
- 驗收：哪些結果已可引用，哪些仍需補 marker / summary / metrics。
- 變更：文件或模板有沒有改口徑，是否影響既有結果解讀。

## 專案時程表

> 週次基準：以本頁第一個 commit（`2026-05-06`）作為 Week 1 起點。

| 週次 | 日期區間 | 主要工作 | 產出項目 | 風險管制重點 |
|---|---|---|---|---|
| 專案第 1 週 | 2026-05-06 ~ 2026-05-12 | 建立結果索引、統一命名與資料口徑、整理既有 v4.7 baseline 框架 | - | 先確認範圍是否可控，避免舊資料與新框架混用 |
| 專案第 2 週 | 2026-05-13 ~ 2026-05-19 | 完成 vm-1node 三家三 isolation baseline、整理 README 主表與註解口徑 | PoC 對照驗證報告（初版） | 檢查 isolation、summary、source dir、error rate 口徑是否一致 |
| 專案第 3 週 | 2026-05-20 ~ 2026-05-26 | 推進 vm-3node direct / HAProxy、補齊 shard / replica / triple gate 說明、整理 dispatch analysis | PoC 對照驗證報告（補強三節點） | 管制拓樸漂移、shard / replica 漂移、DB-host metrics 缺口 |
| 專案第 4 週 | 2026-05-27 ~ 2026-06-02 | 收斂三節點與 Kubernetes 的待重跑項、整理可移交版本、補強 caveat 與風險結論 | 可落地執行計畫 | 確認哪些結果可對外引用，哪些只能作探索性觀察 |
| 專案第 5 週 | 2026-06-03 ~ 2026-06-09 | 彙整建置 / 維運 / 擴展成本，整理最低成本啟動路徑與前置條件 | 預算評估報告（初版） | 控管成本假設是否有對應數據支撐 |
| 專案第 6 週 | 2026-06-10 ~ 2026-06-16 | 完成三份報告的整合版、補足缺口與簽核材料 | PoC 對照驗證報告、可落地執行計畫、預算評估報告（整合版） | 最終檢查可追溯性、版本一致性與風險閉環 |

### 產出項目定義

- `PoC 對照驗證報告`：包含導入已知或可能發生風險、一致性 / 延遲 / 可用性測試結果，並以 104 產品資料庫應用場景適性為評估基準。
- `可落地執行計畫`：涵蓋架構設計、部署流程、資料遷移策略、HA / DR 策略（含 A/A、A/A(Read Only)、A/S 模式），以及備份架構與方式。
- `預算評估報告`：涵蓋建置、維運與擴展成本分析，提出後續專案啟動之最低成本策略與依據。

## 參考

- TiDB 流程紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB 流程紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- YugabyteDB 流程紀錄：[yuga-tc1/S-BASE/pipeline-log.md](./yuga-tc1/S-BASE/pipeline-log.md)
- CockroachDB 歷史資料（已 deprecated）：[cockroach-tc1/S-BASE/pipeline-log.md](./cockroach-tc1/S-BASE/pipeline-log.md)
- Codex 文件審計 prompt：[audit-watch-prompt.md](./audit-watch-prompt.md)
- 歷史 README 備份（已 deprecated）：[README_old.md](./README_old.md)
