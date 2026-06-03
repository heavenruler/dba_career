# 分散式 SQL Database PoC — 結果索引、修正歷程、候選配置

## 如何閱讀

本頁是專案入口，提供結果索引（A）、修正歷程（B）、候選配置（C）三類資訊。需要判斷數據可信度或機制原因時，請回到各資料庫 `pipeline-log.md`、`dispatch-records/` 與來源目錄。

| 順序 | 閱讀區塊 | 目的 | 重點確認 |
|---:|---|---|---|
| 1 | [目前總覽](#目前總覽) | 快速掌握三家資料庫完成範圍 | 哪些案例已完成、待重跑、待執行 |
| 2 | [已驗證結果](#已驗證結果) | 取得目前可引用數字 | 來源目錄、TPCC_TS、`summary.json` / 原始輸出、完成標記 |
| 3 | [執行矩陣](#執行矩陣) | 避免誤讀測試進度 | 不把尚未回填的內容或待執行案例當正式結果 |
| 4 | [資料庫說明](#資料庫說明) | 建立各資料庫前置準備與知識儲備 | 架構、拓樸、吞吐、延遲、錯誤率、瓶頸與機制推論 |
| 5 | [修正歷程](#修正歷程-fixes-catalog) | 理解測試踩坑與修補 | F-A→F-E 系列 / D9-D11 / Fix #9-#12 / YugabyteDB & TiKV race fixes |
| 6 | [候選配置與彙整分析](#候選配置與彙整分析-pending-n3-validation) | 推導三家可上線參考設定 | 全段 N=1，標 `pending N=3 validation`；跨區規劃見 §C.7 |
| 7 | [專案進度](#專案進度) | 從專案管理視角查看範圍、時程、風險與驗收 | 週次時程表、產出項目、風險管制欄位 |
| 8 | [操作指南](#操作指南) | Makefile / replay / batch / 跨區入口 | 重現與後續 N=3 補測 |
| 9 | [表格註解](#表格註解標準四項) / [數據品質註解](#數據品質註解補充) | 校準判讀口徑 | 隔離級、[分片 / 複本對吞吐與延遲的影響](#note-N10)、[獨立重跑次數 N 的嚴謹性差異](#note-N9) |
| 10 | [參考 / 文件索引](#參考--文件索引) | 追溯細節與設計口徑 | `pipeline-log.md`、`dispatch-records/`、`PoC-DESIGN.md`、會議備忘、模板與協作規範 |

## 目前總覽

| 資料庫 | 已完成且可用的結果 | 目前最高 tpmC | 狀態 | 追溯入口 |
|---|---|---:|---|---|
| TiDB | - 單節點虛擬機，三 isolation<br>- 三節點虛擬機，direct RC（含 PD `l4r4` 主用、`l0r0` caveat 對照）<br>- 三節點虛擬機，HAProxy 3s3r RC | **26,947**<br>三節點 HAProxy 3s3r RC (`l4r4`)，t=128 | - ✅ 單節點三 isolation 完成<br>- ✅ 三節點 5 cells (1s1r/1s3r/3s1r/3s3r/haproxy-3s3r) 完成<br>- 🔄 Kubernetes 待重跑 | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | - 單節點虛擬機，三 isolation<br>- 三節點虛擬機，direct RC<br>- 三節點虛擬機，HAProxy 3s3r RC | **14,348**<br>三節點 HAProxy 3s3r RC，t=128 round-5（樣本，5-round mean 待 `summary-from-stdout.py` 後補） | - ✅ 單節點三 isolation 完成<br>- ✅ 三節點 5 cells (1s1r/1s3r/3s1r/3s3r/haproxy-3s3r) 完成<br>- 🔄 Kubernetes 待重跑 | [流程紀錄](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | - 單節點虛擬機，三 isolation<br>- 三節點虛擬機，direct RC（4 cells）<br>- 三節點虛擬機，HAProxy 3s3r RC | **15,632**<br>三節點 HAProxy 3s3r RC，t=128 | - ✅ 單節點三 isolation 完成<br>- ✅ 三節點（多分片 / 副本 / HAProxy）完成<br>- 🔄 Kubernetes 待重跑 | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md) |

- 同硬體規格對照：4 vCPU / 16 GiB / single XFS，5-round mean，9 組（資料庫 × isolation）[註3](#note-3)。
- 同名 isolation 在三家底層機制不同，請先參考 [註2](#note-2)。
- 三節點所有結果 `N=1`，對外結論前需補 `N=3`，詳見 [N9](#note-N9) 與 [§C.6](#c6-n3-補測規劃)。

## 已驗證結果

> `error rate` 代表「失敗交易數 / 全部交易數」。全部交易數包含成功與失敗，並把 5 種 TPC-C transaction type 加總；由 [summary parser](../tests/common/summary-from-stdout.py) 解析 stdout `[Summary]` 後寫入 `summary.json`。

### vm-1node（三家對標）

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

### vm-3node（5 cells × 3 DB，全 `N=1`；[N9](#note-N9) caveat）

> TiDB 主表只列 PD `l4r4` 主用配置；`l0r0` 為退化 baseline（PD 不 rebalance leader / replica），caveat 與修正歷程詳見 [§B / Fix #11 / D10](#修正歷程-fixes-catalog)。CockroachDB 5-round mean 待跑完 `summary-from-stdout.py`（artifact 已 fetch 至 Mac）後補；目前展示末 round 抽樣或 dispatch record 數字。

| 資料庫 | 案例 | 隔離級 | 來源目錄 (canonical TS) | t | tpmC | p99 (ms) | error rate | 判讀 / dispatch |
|---|---|---|---|---:|---:|---:|---:|---|
| TiDB | 直連 — 1s1r | RC | [20260529T132940](./tidb-tc1/S-BASE/vm-3node-1s1r-rc/tidb-vm-3node-1s1r-rc-20260529T132940+0800/) | 128 | 19,654 | 456 | 0.000% | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| TiDB | 直連 — 1s3r（`l4r4`） | RC | [20260530T162428](./tidb-tc1/S-BASE/vm-3node-1s3r-rc-pd-sched-l4r4/tidb-vm-3node-1s3r-rc-20260530T162428+0800/) | 128 | 16,336 | 527 | 0.000% | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md#vm-3node-1s3r-rc)；[schedule-limit 0→4 分析](./dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md) |
| TiDB | 直連 — 3s1r | RC | [20260530T023238](./tidb-tc1/S-BASE/vm-3node-3s1r-rc/tidb-vm-3node-3s1r-rc-20260530T023238+0800/) | 128 | 14,130 | 423 | 0.000% | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| TiDB | 直連 — 3s3r（`l4r4`） | RC | [20260531T085812](./tidb-tc1/S-BASE/vm-3node-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-3s3r-rc-20260531T085812+0800/) | 128 | 15,082 | 591 | 0.000% | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md#vm-3node-3s3r-rc)；[schedule-limit 0→4 分析](./dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md) |
| TiDB | HAProxy — 3s3r（`l4r4`） | RC | [20260601T003316](./tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/) | 128 | **26,947** | 309 | 0.000% | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md#vm-3node-haproxy-3s3r-rc)；[HAProxy vs direct 分析](./dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md)；3 tidb_servers + round-robin，vs direct +78.7% |
| CockroachDB | 直連 — 1s1r | RC | [20260601T105859](./crdb-tc1/S-BASE/vm-3node-1s1r-rc/crdb-vm-3node-1s1r-rc-20260601T105859+0800/) | — | 待 summary | — | — | [5-cell suite dispatch](./dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md) |
| CockroachDB | 直連 — 1s3r | RC | [20260601T142702](./crdb-tc1/S-BASE/vm-3node-1s3r-rc/crdb-vm-3node-1s3r-rc-20260601T142702+0800/) | — | 待 summary | — | — | 同上 |
| CockroachDB | 直連 — 3s1r | RC | [20260601T221341](./crdb-tc1/S-BASE/vm-3node-3s1r-rc/crdb-vm-3node-3s1r-rc-20260601T221341+0800/) | — | 待 summary | — | — | 同上；resume PASS（pre-F-E TS `20260601T175625` 為失敗 trial，[F-E 修補詳見 §B](#修正歷程-fixes-catalog)） |
| CockroachDB | 直連 — 3s3r | RC | [20260602T014253](./crdb-tc1/S-BASE/vm-3node-3s3r-rc/crdb-vm-3node-3s3r-rc-20260602T014253+0800/) | — | 待 summary | — | — | 同上 |
| CockroachDB | HAProxy — 3s3r | RC | [20260602T051500](./crdb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/crdb-vm-3node-haproxy-3s3r-rc-20260602T051500+0800/) | 128 | 14,348（末 round 抽樣） | 772（末 round） | 0.000% | 同上；5-round mean 待 summary parser |
| YugabyteDB | 直連 — 1s1r | RC | [20260524T032814](./yuga-tc1/S-BASE/vm-3node-1s1r-rc/ybdb-vm-3node-1s1r-rc-20260524T032814+0800/) | 128 | 13,725 | 758 | 0.000% | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md)；[4 cells 跨 cell 分析](./dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md) |
| YugabyteDB | 直連 — 1s3r | RC | [20260524T074754](./yuga-tc1/S-BASE/vm-3node-1s3r-rc/ybdb-vm-3node-1s3r-rc-20260524T074754+0800/) | 128 | 10,228 | 1,034 | 0.000% | 同上 |
| YugabyteDB | 直連 — 3s1r | RC | [20260524T202219](./yuga-tc1/S-BASE/vm-3node-3s1r-rc/ybdb-vm-3node-3s1r-rc-20260524T202219+0800/) | 32 | 11,967 | 203 | 0.000% | 同上；3s1r 在 t=32 飽和 |
| YugabyteDB | 直連 — 3s3r | RC | [20260525T031918](./yuga-tc1/S-BASE/vm-3node-3s3r-rc/ybdb-vm-3node-3s3r-rc-20260525T031918+0800/) | 128 | 8,729 | 1,114 | 0.000% | 同上；3s3r tablet 協調瓶頸（mpstat CPU 24-42% idle、throughput 反而 drop）|
| YugabyteDB | HAProxy — 3s3r | RC | [20260525T193740](./yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/) | 128 | **15,632** | 705 | 0.000% | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md#vm-3node-haproxy-3s3r-rc3-shards--rf3--haproxy)；[HAProxy vs direct 分析](./dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)；vs direct +79.1% |

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
    <tr><td>三節點虛擬機，直連</td><td>✅ 完成（4 cells，`l4r4` 主用）</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>✅ 完成（3s3r，`l4r4`）</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td rowspan="5">CockroachDB</td><td>單節點虛擬機</td><td>✅ 完成</td><td>✅ 完成</td><td>✅ 完成（SERIALIZABLE）</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>✅ 完成（4 cells，<a href="./dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md">5-cell suite</a>）</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
    <tr><td>三節點虛擬機，HAProxy</td><td>✅ 完成（3s3r）</td></tr>
    <tr><td>Kubernetes，無資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td>Kubernetes，有資源限制</td><td>🔄 待重跑</td></tr>
    <tr><td rowspan="5">YugabyteDB</td><td>單節點虛擬機</td><td>✅ 完成</td><td>✅ 完成</td><td>✅ 完成（SERIALIZABLE）</td></tr>
    <tr><td>三節點虛擬機，直連</td><td>✅ 完成（4 cells）</td><td rowspan="4" colspan="2" align="center">➖ 不執行（RC 為主）</td></tr>
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

[![YugabyteDB Architecture](https://raw.githubusercontent.com/yugabyte/yugabyte-db/master/architecture/images/yb-architecture.jpg)](https://github.com/yugabyte/yugabyte-db#architecture)

來源：[yugabyte/yugabyte-db — Architecture](https://github.com/yugabyte/yugabyte-db#architecture)

- **YSQL**：PostgreSQL-compatible SQL API，負責接收 SQL、處理 query planning 與 transaction request。
- **YCQL**：Cassandra-compatible API，本輪 TPC-C-derived OLTP 測試不走此路徑。
- **DocDB**：YugabyteDB 的 distributed document store，負責資料儲存、MVCC、tablet 管理與 Raft 複寫。
- **YB-TServer**：資料服務節點，承載 YSQL/YCQL request path 與 DocDB tablet；SQL 與儲存同在 tserver 內，和 TiDB 的 SQL / storage 分離不同。
- **YB-Master**：叢集 metadata 管理元件，負責 tablet placement、schema metadata 與 cluster coordination。
- **架構重點**：tserver 一體式架構；加節點時 SQL 接收能力與資料 tablet capacity 一起增加，實際效能同時受 tablet 分布、複本數與 transaction coordination 影響。

## 修正歷程 (Fixes Catalog)

> 列出 PoC 過程中踩到的 bug / 設計缺陷與對應修補。所有 commit hash 對應 `git log` 可追溯；dispatch record 連結提供完整背景。

### F 系列（CockroachDB 5-cell suite 修補）

| ID | Commit | 症狀 | 根因 | 修補 | 影響範圍 |
|---|---|---|---|---|---|
| **F-A / F-B / F-C** | `15c3208` | CockroachDB 5-cell batch pre-flight 失敗 | dry-run RF gate / HAProxy backend health / inventory self-ssh 三項缺漏 | 加入 pre-flight check 三項 | 全 5-cell CockroachDB suite |
| **F-A-v2** | `eaa2420` | dry-run-confirm §1c 在 CockroachDB v26.2.0 失效（`crdb_internal.*` access restricted，SQLSTATE 42501）| v26.2.0 require `SET allow_unsafe_internals=true`；且 CockroachDB per-range zone 系統 range RF=5 永遠超過 EXPECTED_RF=1 | §1c 改 no-op 註解；§2 已涵蓋 dry-run RF target 驗證 | CockroachDB 5-cell dry-run validated |
| **F-B-v2** | `eaa2420` | HAProxy backend health check 在 .20 host 失敗 | health probe 超時設定 | 調整 timeout | CockroachDB haproxy-3s3r cell |
| **F-D** | `ebc481f` | `prepare.sh` shard-count gate 全 9 表 actual=0 | v26.2.0 `crdb_internal.ranges` 受限 → query 靜默 failure，gate fail-closed | 改用 `SHOW RANGES FROM TABLE`（v26.2.0 supported API） | CockroachDB shard-count gate |
| **F-E** | `0ac53da` | `prepare.sh` history SPLIT 失敗：`could not parse "00000086" as type int: invalid syntax (SQLSTATE 22P02)` | 字串字面量 `'00000086'` → CockroachDB `strconv.ParseInt(s, 0, 64)` 以 base=0 解析，前導零觸發八進位，digit 8 不合法 | 改用裸 int `(1280000), (2560000)` 鏡像 TiDB `_tidb_rowid` 切點 | CockroachDB 3s1r / 3s3r / haproxy-3s3r cell ([5-cell dispatch](./dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)) |

### D 系列（系統性設計缺陷）

| ID | Commit | 症狀 | 根因 | 修補 |
|---|---|---|---|---|
| **D9** | `2057ada` | batch 移到新 controller 後 30s 內 fail（`ansible.posix` collection 缺失），1 cell TPCC_TS 作廢 | 跨 controller collection 對齊缺乏 preflight 驗證 | `audit-watch-prompt` 加入 batch-readiness preflight 章節（syntax-check + collection list + ssh + disk） |
| **D10** | `97ce300` | TiDB vm-3node 3s3r leader 27 全部集中單一 store；PD `leader-schedule-limit=0` 沿用自 vm-1node | vm-3node playbook 寫死 `leader-schedule-limit=0` 未調整 | vm-3node 改回 `4`（PD 預設）；vm-1node 保留 0 |
| **D11** | (Fix #12 涵蓋) | shard-count gate 嚴格 `actual == EXPECTED_SHARDS` 在 RF=3 + auto-split 情境 fail-closed（order_line 3→4 region）| TiKV auto-split 把熱點 region 自動加切 | gate 改 `actual >= EXPECTED_SHARDS`（SPLIT 是保底，auto-split 加 region 應允許） |

### Fix # 系列（TiDB / YugabyteDB 個別修補）

| ID | Commit | 對應 |
|---|---|---|
| **Fix #9** | `9fb9e5f` | TiDB SPLIT TABLE syntax for CLUSTERED PK — 不能用 `INDEX PRIMARY` |
| **Fix #10** | `a35142d` | TiDB SPLIT BY syntax for small tables — `BETWEEN/REGIONS` warehouse 42 keys < 1000 觸發 ERROR 8212；改用顯式分裂點 `BY (43),(86)` |
| **Fix #11** | `d30bceb` + `07d9da9` | PD `replica-schedule-limit=0→4`（讓 RF=3 真實生效）+ ansible shell task 改 `/bin/bash`（process substitution）+ dry-run actual peer count gate |
| **Fix #12** | `24d0c05` | shard-count gate `>=`（同 D11） |
| YugabyteDB vm3 a | `d654824` | YugabyteDB vm3 serial worker join + stabilize + master_addrs gate |
| YugabyteDB vm3 b | `68189bc` | stabilize 移至 workers-only，在 `configure data_placement` 之後 |
| YugabyteDB vm3 c | `29b5fc5` | RF-aware cluster gate + drop ineffective stabilize-workers |
| TiKV race fix | `3dd4989` | TiKV race + ansible `gather_facts` + TiDB vm-3node 4 cells dry-run anchors |

### 觀測 / 工具

| ID | Commit | 用途 |
|---|---|---|
| status-vm1.sh phase sub-log | `db3936b` | 顯示正在執行的 phase 子日誌，dispatch 中觀察用 |

## 候選配置與彙整分析 (Pending N=3 Validation)

> **所有 §C 結論均基於 `N=1` 實測**，僅供候選配置與假設驗證方向；對外結論前必須 `N=3` 重做（見 [§C.6](#c6-n3-補測規劃)）。每節以 `[N=1 — pending N=3 validation]` 為前提。

### C.1 三家共同候選原則 [N=1 — pending N=3 validation]

- **shard 鎖定**：三家自然 shard 數皆不可控（TiDB `region-split-size=128GB`、CockroachDB `range_max_bytes=128GB`、YugabyteDB tserver gflag）；跨 cell 對照必須用 manual SPLIT 鎖定，否則跨 DB tpmC / p99 無可比性。
- **RF=3 寫成本（候選）**：YugabyteDB / CockroachDB 約 -25%（Raft 三副本固定成本）；TiDB 視 PD schedule-limit 設定而異（`l0r0` baseline 是退化拓樸不算）。
- **HAProxy 同向收益（候選）**：TiDB direct→haproxy `+78.7%`；YugabyteDB direct→haproxy `+79.1%`（兩家獨立量測）。共同根因 = 「單一 entry node 的 client/parser/coord 排隊」分散到 3 DB-server。
- **iso=rc 鎖鏈**：TiDB 必 `tidb_txn_mode='pessimistic'`；CockroachDB cluster setting `sql.txn.read_committed_isolation.enabled=true`；YugabyteDB triple gate（default flag + enable flag + active SQL gate）。
- **自然 shard 全部不可控**：default 路徑下 shard 數隨資料量 / 負載動態變，僅可作 exploratory，不能進主表。

### C.2 TiDB 候選配置 [N=1 — pending N=3 validation]

**Current leading hypothesis**：

```
vm-3node + 3 tidb_servers + HAProxy round-robin (mode tcp)
PD: replica-schedule-limit=4, leader-schedule-limit=4, region-schedule-limit=0  (l4r4)
TiKV: coprocessor.region-split-size=128GB  (freeze auto-split)
isolation: --conn-params 'transaction_isolation=READ-COMMITTED&tidb_txn_mode=pessimistic'
SPLIT: manual SPLIT TABLE ... BY (43),(86)  for 3-shard cells
```

**證據**：HAProxy 3s3r `l4r4` 量到 **26,947 tpmC** / p99 309 ms（[20260601T003316](./tidb-tc1/S-BASE/vm-3node-haproxy-3s3r-rc-pd-sched-l4r4/tidb-vm-3node-haproxy-3s3r-rc-20260601T003316+0800/)）；vs direct l4r4 `+78.7%`（[HAProxy 分析](./dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md)）。

**Caveat**：
- `l4r4` 是 **mixed state**（region 凍結 + leader/replica 允許搬移）；leader 分佈在 5h workload 後仍 7/14/8 超 ±20% 容差，PD `leader-schedule-limit=4` 是 rate-limit 而非 weight。
- `l0r0` 為 broken baseline（27/0/0 全 leader 集中單一 store，RF=3 退化為 RF=1），詳 [§B / D10 / Fix #11](#修正歷程-fixes-catalog) 與 [schedule-limit 0→4 分析](./dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md)。
- N=1，需 N=3 確認 mixed state 是否穩定。

### C.3 CockroachDB 候選配置 [N=1 — pending N=3 validation]

**Current leading hypothesis**：

```
vm-3node + 3 CockroachDB nodes + HAProxy round-robin (mode tcp)
cluster setting: kv.range_split.by_load_enabled=false
                 sql.txn.read_committed_isolation.enabled=true
zone config: ALTER RANGE default CONFIGURE ZONE USING num_replicas=N
SPLIT: manual ALTER TABLE ... SPLIT AT VALUES (43),(86)  for 3-shard cells
        history table: SPLIT AT VALUES (1280000),(2560000)  (bare int per F-E)
v26.2.0 注意：crdb_internal.* 多處 access restricted；用 SHOW RANGES / SHOW ZONE CONFIGURATION 等 supported API
```

**證據**：5-cell suite 全 PASS（[2026-06-02 dispatch record](./dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)）；HAProxy 3s3r 末 round 抽樣 14,348 tpmC / p99 772 ms；5-round mean 待 `summary-from-stdout.py` 後補。

**Caveat**：
- v26.2.0 `crdb_internal.*` access restricted（[§B / F-A-v2 / F-D](#修正歷程-fixes-catalog)）；其他散落呼叫尚未稽核。
- F-E 修補後 history SPLIT 邊界與 rowid 實際分布不重合，shard-count gate 仍通過。
- N=1，需 N=3。

### C.4 YugabyteDB 候選配置 [N=1 — pending N=3 validation]

**Current leading hypothesis**：

```
vm-3node + 3 tservers + HAProxy round-robin (mode tcp)
tserver gflags: ysql_num_shards_per_tserver=N
                enable_automatic_tablet_splitting=false
                yb_enable_read_committed_isolation=true
yugabyted: configure data_placement --rf=N
SPLIT: pre-create with SPLIT INTO N TABLETS  (post-prepare SPLIT 不採用)
triple gate: ysql_default_transaction_isolation + enable flag + SQL active check
            (SELECT yb_get_effective_transaction_isolation_level())
```

**證據**：HAProxy 3s3r `15,632 tpmC` / p99 705 ms（[20260525T193740](./yuga-tc1/S-BASE/vm-3node-haproxy-3s3r-rc/ybdb-vm-3node-haproxy-3s3r-rc-20260525T193740+0800/)）；vs direct `+79.1%`（[HAProxy 分析](./dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)）。Leader 分佈 9/9/9 per tserver 收斂（[2026-05-31 verification](./dispatch-records/2026-05-31-ybdb-leader-balance-verification.md)）。

**Caveat**：
- 3s3r direct 模式 5-round stddev 1,400–2,615（極不穩，t=16 min/max 4.9×）；HAProxy 模式降至 178–401（14.7× 改善）。3s3r direct 在 4 vCPU 撞 tablet 協調牆。
- N=1，需 N=3。

### C.5 HAProxy 拓樸（方向性建議；N=1 evidence: TiDB +78.7% / YugabyteDB +79.1%）

- **建議生產**：vm-3node 必上 HAProxy；single-entry 拓樸已飽和（client/parser/coord 在單 DB-server 排隊）。
- **模式**：`mode tcp` + `balance roundrobin`；3 個 DB-server 並行接收。
- **驗證 gate**：本輪 N=1 HAProxy stats socket 沒開啟、roundrobin 生效是以 tpmC delta 反推。後續應補 `show stat` dump。
- **Caveat**：未對 CockroachDB 直接量化（5-round mean 待出）；初步末 round 抽樣顯示同向收益但量級待補。

### C.6 N=3 補測規劃

- **路徑**：三家 `vm-3node-haproxy-3s3r-rc` 各補 N=3（最具代表性 cell），約 `9 hours`（3 cell × ~3 h × N=3 重做）。
- **目的**：把 §C.2/3/4/5 候選結論升級為對外可用 baseline。
- **gate**：N=3 各 run 之間 cluster 完全重建（包含 final purge / verify pristine）。
- **後續**：若 N=3 結果與 N=1 同方向（±5% within stddev），可移除 `pending N=3 validation` badge；否則需追加 N=5 或 root cause 分析。

### C.7 跨區規劃 (Track E)

> 跨 IDC ⇄ GCP 6-node single cluster PoC（iso=rc / haproxy / 3 shard × 3 replica）詳細設計與 chaos 場景見會議備忘。

- 完整規劃：[`1_MeetingMinutes/0602.md §10`](../1_MeetingMinutes/0602.md)
- 議題彙整與待定決策：[`1_MeetingMinutes/0602-agenda.md §3 §4`](../1_MeetingMinutes/0602-agenda.md)
- 三大測項：Test 1 IDC 獨立 TPCC / Test 2 兩區並發 / Test 3 chaos 7 場景（node down / haproxy down / WAN partition / latency / loss / slow disk / region majority loss）

## 專案進度

### 專案時程表

> 週次基準：以本頁第一個 commit（`2026-05-06`）作為 Week 1 起點；`🟢` 已完成　`🟡` 執行中　`⚪` 待執行

| 週次 | 日期區間 | 目前進度 | 主要工作 | 產出項目 |
|---|---|---|---|---|
| 專案第 1-2 週 | 2026-05-06 ~ 2026-05-19 | 🟢 | 建立結果索引、統一命名與資料口徑，並完成 vm-1node 三家三 isolation baseline 與 README 主表 / 註解口徑 | - |
| 專案第 3-4 週 | 2026-05-20 ~ 2026-06-02 | 🟢 | 推進 vm-3node direct / HAProxy，補齊 shard / replica / triple gate 說明，整理 dispatch analysis；CockroachDB 5-cell suite 完成；TiDB / YugabyteDB vm-3node 完成 | - |
| 專案第 5-6 週 | 2026-06-03 ~ 2026-06-16 | 🟡 | 跨專線（IDC↔GCP）分散式資料庫測試：A/A、A/A(Read Only)、A/S 設計，備份架構與資料遷移策略；同時彙整建置 / 維運 / 擴展成本與最低成本啟動路徑；N=3 補測規劃 | - |
| 專案第 7-8 週 | 2026-06-17 ~ 2026-06-30 | ⚪ | 完成三份報告整合版、補足缺口與實驗數據，並回收前一階段 caveat 與風險結論 | - |

### 產出項目定義

- `PoC 對照驗證報告`：包含導入已知或可能發生風險、一致性 / 延遲 / 可用性測試結果，並以 104 產品資料庫應用場景適性為評估基準。
- `可落地執行計畫`：涵蓋架構設計、部署流程、資料遷移策略、HA / DR 策略（含 A/A、A/A(Read Only)、A/S 模式），以及備份架構與方式。
- `預算評估報告`：涵蓋建置、維運與擴展成本分析，提出後續專案啟動之最低成本策略與依據。

## 操作指南

### Makefile target（vm-3node 主要流程）

```bash
cd /Users/wn.lin/vscode-git/dba_career/poc

# 1. Deploy (含 dry-run preflight)
make deploy-vm3-<db>-<sub>             # <db>=tidb|crdb|ybdb；<sub>=1s1r|1s3r|3s1r|3s3r
make deploy-vm3-<db>-haproxy-3s3r      # haproxy 變體獨立 target

# 2. Dry-run anchor（驗 RF / topology / iso）
make dryrun-vm3-<db>-<sub>-rc          # 不帶 TPCC_TS = 新 ts
make dryrun-vm3-<db>-<sub>-rc TPCC_TS=<ts>  # 帶 TPCC_TS = 重驗

# 3. 全套 suite (gate → prepare → run → collect)
make test-tpcc-vm3-<db>-<sub>-rc EXECUTE=1 TPCC_TS=<ts>

# 4. Fetch artifact 回 Mac (含 .31 source 清理)
make fetch-vm3-<db>-<sub>-rc TPCC_TS=<ts>

# 5. Status (in-progress phase sub-log)
make status-vm3-<db>-<sub>-rc TPCC_TS=<ts>
```

### Replay / 數據解析

```bash
# 抽某 cell 5-round tpmC
ssh root@172.24.40.31 'for r in 1 2 3 4 5; do
  grep "^tpmC:" /tmp/poc-tpcc/artifacts/<artifact-dir>/runs/threads-<N>/round-$r/go-tpc-stdout.txt
done'

# 跑 summary aggregation (產 summary.json)
python3 tests/common/summary-from-stdout.py <artifact-dir>

# DB-host CPU avg
grep '平均時間' <artifact-dir>/runs/threads-<N>/round-<R>/mpstat-db.txt
```

### Batch scripts（transient on `.31`，未入 repo）

- `/tmp/batch-crdb-5cell-suite.sh`（原 5-cell，含 1s1r→haproxy-3s3r）
- `/tmp/batch-crdb-3cell-resume.sh`（F-E 修補後從 3s1r 接續，已使用一次）
- `/tmp/batch-tidb-5cell-suite.sh`（已 ready，待 dispatch）

### 跨區 PoC 入口（Track E）

- 完整規劃：[`1_MeetingMinutes/0602.md §10`](../1_MeetingMinutes/0602.md)
- 會議討論議題：[`1_MeetingMinutes/0602-agenda.md`](../1_MeetingMinutes/0602-agenda.md)

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
| N6 | CockroachDB / TiDB / YugabyteDB 三家 vm-1node 全 iso 的 tpmC 與 latency p50/p95/p99 已全為 5-round mean，口徑一致；數據來源為 `runs/threads-*/round-*/go-tpc-stdout.txt` + [`tests/common/summary-from-stdout.py`](../tests/common/summary-from-stdout.py) 解析後落地的 `summary.json`。 |
| N7 | TiDB 三節點與 Kubernetes 數據已刻意清空，等待 PoC v4.7 重跑後再回填。 |
| N8 | CockroachDB 機制描述以 artifact 數據與[官方 v26.2 docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) 為主；server-internal retry 等未直接量測項以「推測」呈現，待 trace / statement diagnostics 補強。 |
| <a id="note-N9"></a>N9 | **`N` = 獨立重跑次數**，不是 round 數。`N=1` 代表只做過 1 次完整流程（重建環境 → 部署 → prepare → run → collect），雖然裡面有 4 個併發水位 × 5 round，但只能降低單次執行內的隨機波動，無法證明不同時間、不同重建環境下仍穩定。`N=3` 代表完整流程獨立重跑 3 次，可觀察三次之間是否一致，嚴謹性明顯高於 N=1；若三次結果接近，才比較適合作為對外結論。本文凡標 `N=1` 或 `N=3 待確認` 的結果，都只能視為方向性觀察，不視為最終定論。 |
| <a id="note-N10"></a>N10 | **分片（shard）/ 複本（replica）是三節點結果的核心變數**。分片數決定資料被切成幾份，會影響資料分散、tablet / range 協調與跨節點查找成本；複本數決定每筆資料同步保存幾份，會影響寫入時的同步複寫、quorum commit 與延遲。若分片數或複本數沒有固定，就無法分辨效能差異到底來自「資料切分」還是「複寫成本」，也不能把不同拓撲的 tpmC / p99 視為同口徑比較。 |

## 參考 / 文件索引

### Pipeline 流程紀錄

- TiDB：[`tidb-tc1/S-BASE/pipeline-log.md`](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB：[`crdb-tc1/S-BASE/pipeline-log.md`](./crdb-tc1/S-BASE/pipeline-log.md)
- YugabyteDB：[`yuga-tc1/S-BASE/pipeline-log.md`](./yuga-tc1/S-BASE/pipeline-log.md)
- CockroachDB 歷史資料（已 deprecated）：[`cockroach-tc1/S-BASE/pipeline-log.md`](./cockroach-tc1/S-BASE/pipeline-log.md)
- YugabyteDB pre-v4.7 archive：`yuga-tc1-old/S-BASE/pipeline-log.md`

### 設計與會議文件

- 設計規劃：[`PoC-DESIGN.md`](./PoC-DESIGN.md)
- 會議備忘（單區 + 跨區整合）：[`../1_MeetingMinutes/0602.md`](../1_MeetingMinutes/0602.md)
- 會議討論議題（email-ready）：[`../1_MeetingMinutes/0602-agenda.md`](../1_MeetingMinutes/0602-agenda.md)

### Dispatch records（執行經過與跨 cell 分析）

- 預檢：[`2026-05-22 vm-3node-rc-pre-check`](./dispatch-records/2026-05-22-vm-3node-rc-pre-check.md)
- YugabyteDB 1s1r 結果：[`2026-05-23 ybdb-1s1r-rc-result`](./dispatch-records/2026-05-23-vm-3node-ybdb-1s1r-rc-result.md)
- YugabyteDB HAProxy dispatch：[`2026-05-25 haproxy-3s3r-ybdb-dispatch`](./dispatch-records/2026-05-25-vm-3node-haproxy-3s3r-ybdb-dispatch.md)
- YugabyteDB 4 cells 分析：[`2026-05-25 ybdb-all4-rc-analysis`](./dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md)
- YugabyteDB HAProxy vs direct：[`2026-05-26 haproxy-vs-direct-3s3r-ybdb-analysis`](./dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)
- TiDB vm-3node batch logs：[`2026-05-29 tidb-vm3-batch-logs/`](./dispatch-records/2026-05-29-tidb-vm3-batch-logs/)
- TiDB schedule-limit 0→4：[`2026-05-31 tidb-schedule-limit-0-vs-4`](./dispatch-records/2026-05-31-tidb-schedule-limit-0-vs-4.md)
- YugabyteDB leader balance check：[`2026-05-31 ybdb-leader-balance-check/`](./dispatch-records/2026-05-31-ybdb-leader-balance-check/)
- YugabyteDB leader balance verification：[`2026-05-31 ybdb-leader-balance-verification`](./dispatch-records/2026-05-31-ybdb-leader-balance-verification.md)
- TiDB HAProxy vs direct：[`2026-06-01 tidb-haproxy-vs-direct-3s3r-l4r4`](./dispatch-records/2026-06-01-tidb-haproxy-vs-direct-3s3r-l4r4.md)
- CockroachDB 5-cell suite + F-E：[`2026-06-02 crdb-vm3-5cell-suite-dispatch`](./dispatch-records/2026-06-02-crdb-vm3-5cell-suite-dispatch.md)
- vm-3node remaining handover：[`HANDOVER-2026-05-24-vm3-poc-remaining`](./dispatch-records/HANDOVER-2026-05-24-vm3-poc-remaining.md)

### Agent 參考材料

- AI 協作規範：[`AI-COLLABORATION.md`](./AI-COLLABORATION.md)
- README 模板：[`README-template.md`](./README-template.md)
- Pipeline log 模板：[`pipeline-log-template.md`](./pipeline-log-template.md)
- Codex 審計 / 監督 prompt：[`audit-watch-prompt.md`](./audit-watch-prompt.md)

### 歷史備份

- 舊版 README：[`README_old.md`](./README_old.md)
