# S-BASE 結果索引

## 如何閱讀

本頁是結果索引，不單獨作最終結論。需要判斷數據可信度或機制原因時，請回到各資料庫 `pipeline-log.md`、來源目錄與調度分析。

| 順序 | 閱讀區塊 | 目的 | 重點確認 |
|---:|---|---|---|
| 1 | 目前總覽 | 快速掌握三家資料庫完成範圍 | 哪些案例已完成、待重跑、待執行 |
| 2 | 已驗證結果 | 取得目前可引用數字 | 來源目錄、TPCC_TS、`summary.json` / 原始輸出、完成標記 |
| 3 | 執行矩陣 | 避免誤讀測試進度 | 不把尚未回填的內容或待執行案例當正式結果 |
| 4 | 資料庫說明 | 建立各資料庫前置準備與知識儲備 | 架構、拓樸、吞吐、延遲、錯誤率、瓶頸與機制推論 |
| 5 | 表格註解與數據品質註解 | 先校準判讀口徑 | 隔離級、[分片 / 複本對吞吐與延遲的影響](#note-N10)、[獨立重跑次數 N 的嚴謹性差異](#note-N9) |
| 6 | 參考 | 追溯細節與設計口徑 | `pipeline-log.md`、調度分析、各資料庫研究紀錄、`PoC-DESIGN.md`、模板與協作規範 |

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

| 資料庫 | 案例 | READ COMMITTED | REPEATABLE READ | 最嚴格隔離級 |
|---|---|---|---|---|
| TiDB | 單節點虛擬機 | ✅ 完成 | ✅ 完成 | ✅ 以 REPEATABLE READ 代表 |
| TiDB | 三節點虛擬機，直連 | 🔄 待重跑 | ➖ 不執行（RC 為主）| ➖ 不執行（RC 為主）|
| TiDB | 三節點虛擬機，HAProxy | 🔄 待重跑 | ➖ 不執行（RC 為主）| ➖ 不執行（RC 為主）|
| TiDB | Kubernetes，無資源限制 | 🔄 待重跑 | ➖ 不執行（RC 為主） | ➖ 不執行（RC 為主） |
| TiDB | Kubernetes，有資源限制 | 🔄 待重跑 | ➖ 不執行（RC 為主） | ➖ 不執行（RC 為主） |
| CockroachDB | 單節點虛擬機 | ✅ 完成 | ✅ 完成 | ✅ 完成（SERIALIZABLE）|
| CockroachDB | 三節點虛擬機，直連 | 🔄 待重跑 | ➖ 不執行（RC 為主）| ➖ 不執行（RC 為主）|
| CockroachDB | 三節點虛擬機，HAProxy | 🔄 待重跑 | ➖ 不執行（RC 為主）| ➖ 不執行（RC 為主）|
| CockroachDB | Kubernetes，無資源限制 | 🔄 待重跑 | ➖ 不執行（RC 為主） | ➖ 不執行（RC 為主） |
| CockroachDB | Kubernetes，有資源限制 | 🔄 待重跑 | ➖ 不執行（RC 為主） | ➖ 不執行（RC 為主） |
| YugabyteDB | 單節點虛擬機 | ✅ 完成 | ✅ 完成 | ✅ 完成（SERIALIZABLE）|
| YugabyteDB | 三節點虛擬機，直連 | ✅ 完成（4 子拓撲）| ➖ 不執行（RC 為主）| ➖ 不執行（RC 為主）|
| YugabyteDB | 三節點虛擬機，HAProxy | ✅ 完成（3s3r）| ➖ 不執行（RC 為主）| ➖ 不執行（RC 為主）|
| YugabyteDB | Kubernetes，無資源限制 | 🔄 待重跑 | ➖ 不執行（RC 為主） | ➖ 不執行（RC 為主） |
| YugabyteDB | Kubernetes，有資源限制 | 🔄 待重跑 | ➖ 不執行（RC 為主） | ➖ 不執行（RC 為主） |

## 資料庫說明

### TiDB

- 單節點 RC 與 RR 已完成。pessimistic 模式下 RR 比 RC 快 +6.2% tpmC（t128: 13,874 vs 13,064）、p99 低（503 vs 597ms），整輪全 20 round 零 NEW_ORDER_ERR。
- CPU-bound：%iowait < 5%、sda %util ≤ 51%、t128 %user mean 約 95.5%（瞬間接近 100%）。
- TiDB 不支援原生 SERIALIZABLE，strict 在工具鏈上等價於 RR；跨家 strict 對標時須注意此點，不能直比 CockroachDB / YugabyteDB 的 SSI。
- 三節點與 Kubernetes 舊數據已清空，等待 PoC v4.7 重跑。

### CockroachDB

- 單節點三 isolation（RC / RR / SERIALIZABLE）全完整。**SERIALIZABLE 反而是最快**（t32+ 比 RC 高 +10~19% tpmC、p99 低一個量級）：RC 自 t16 起被 fsync IO 卡死（%idle 5% / %iowait 18%），strict 走 read-refresh 路徑 IO 更省、有 CPU headroom。
- preview RR 是最慢選項（t128: 3,788 tpmC，比 RC -57% / 比 TiDB RR -72.7%）；雖然 RR 在 CockroachDB 與 TiDB 內部都 = SI，但 CockroachDB 採 first-committer-wins + client retry，無等效於 TiDB `tidb_txn_mode=pessimistic` 的全域開關。
- starting-gun storm：RR/strict 兩者在每 round 起始爆 retry（per-txn snapshot ts 同步衝突）；RC 因 per-statement snapshot 完全免疫。
- 詳細機制與比較見 [crdb-tc1 流程紀錄 TL;DR](./crdb-tc1/S-BASE/pipeline-log.md#tldr--vm-1node-三-isolation-矩陣完成2026-05-19)。

### YugabyteDB

- 2025.2.2 LTS + 有效 Read Committed（`yb_enable_read_committed_isolation=true` tserver gflag + session iso 雙閘）後 TPC-C 才有可比結果；三 iso 全部以 `SHOW transaction_isolation` + `SHOW yb_effective_transaction_isolation_level` 雙閘驗證生效，無 silent fallback。
- **vm-1node-rc**：peak **11,436 tpmC @ t32**（5-round mean），零 NEW_ORDER_ERR / 20 round；CPU-bound 含異常高 %sys (19%) — YSQL postgres ↔ DocDB tserver 跨進程 RPC 拉走 1/5 CPU；對比 TiDB %sys 9% / CockroachDB %sys 5.5%。
- **vm-1node-rr**：peak **1,879 tpmC @ t32**，比 rc **-84%**；YugabyteDB rr = snapshot isolation 撞 SI hot row → 每 round **線性 N − 1 errors**（與 CockroachDB rr 完全相同 pattern）；DB-host %idle 66-67% 全程，瓶頸在 transaction coordination layer。
- **vm-1node-strict**：peak **1,130 tpmC @ t32**，比 rc **-90%**、比 rr **再砍 -40%**；errors ≈ N-1 但比 rr 略少 ~5%（SSI early-abort 救回部分衝突）；DB %idle 70% 為三 iso 最高、disk %util 70% 為三 iso 最高（SSI version metadata + read-refresh 小 IO 放大）。
- **三 iso 排序：rc ＞＞ rr ＞ strict** — 與 CockroachDB「strict ＞ rc ＞ rr」**完全相反**；機制：CockroachDB rc 為 IO-bound 故 SSI 走 CPU 路徑可避瓶頸；YugabyteDB rc 已 CPU-bound 無 headroom 可榨。
- 詳見 [yuga-tc1 pipeline-log TL;DR](./yuga-tc1/S-BASE/pipeline-log.md#tldr--vm-1node-三-isolation-矩陣完成2026-05-20--21)。
- **vm-3node-direct (RC)**：4 子拓撲 × RC 2026-05-24 / 25 完成（5-round mean）。代表點：1s1r 13,702 (t=32) ＞ 3s1r 11,967 (t=32) ＞ 1s3r 10,228 (t=128) ＞ 3s3r 8,729 (t=128)。**RF=3 一律 ~25% 寫吞吐損耗、shard=3 加 ~13% 協調成本，疊加 1s1r→3s3r 為 −36%**；3s3r 在 4 vCPU 上 tablet 協調瓶頸（CPU 24-42% idle 但 throughput drop）。詳見 [vm-3node TL;DR](./yuga-tc1/S-BASE/pipeline-log.md#tldr--vm-3node-4-cells2026-05-25) 與 [跨 cell 分析](./dispatch-records/2026-05-25-vm-3node-ybdb-all4-rc-analysis.md)。
- **vm-3node-haproxy (RC, 3s3r only, N=1 [N9](#note-N9))**：2026-05-25 完成。HAProxy roundrobin 把 client 連線分散到 .32/.33/.34 三 tservers，best mean **15,632 tpmC @ t=128**（**+79% vs direct 3s3r 8,729 tpmC**、NO_p99 −37% / 1,114→705ms、stddev 縮 6×）。**反超 1s1r single-shard baseline +14%**，推翻 PoC-DESIGN §6.4「YugabyteDB HAProxy delta 最小（tserver 一體）」假設。機制推論：direct 模式 client 全進入 .32 single YSQL postgres entry point 形成 serial backpressure；haproxy 把 128 connection 攤平到 3 tservers，coordination layer 平行化。詳見 [haproxy-vs-direct 分析](./dispatch-records/2026-05-26-vm-3node-haproxy-vs-direct-3s3r-ybdb-analysis.md)。
- vm-1node pre-v4.7 single-run / 早期 vm-3node-HAProxy / Kubernetes（unlimit & limit）等歷史結果已備份於 [`yuga-tc1-old/`](./yuga-tc1-old/)；v4.7 vm-3node-haproxy 其他 sub-topology (1s1r/1s3r/3s1r) 與 Kubernetes 重跑尚未排程。

### 歷史檔案

- `cockroach-tc1/` 為 PoC v4.7 前的 CockroachDB 舊資料（單次 10min、手動部署、無雙邊監控）。已加 deprecated banner，**不納入 PoC v4.7 baseline 與跨家對比**。

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
| N3 | isolation 必須由 connection string 與 gate 記錄共同確認，避免 driver 或資料庫預設值造成測試口徑偏移（CockroachDB 採 isolation 雙閘 = `isolation-db.txt` + `isolation-driver-verify.txt`；YugabyteDB 加 `SHOW yb_effective_transaction_isolation_level` 三層驗證）。 |
| N4 | v4.7 標準格式：20 分鐘 warmup、每個併發水位 5 round × 5 分鐘、4 thread groups（16/32/64/128）、DB-host 雙邊 OS 監控（mpstat/iostat/vmstat/sar）。TiDB / CockroachDB / YugabyteDB vm-1node 三家全 iso 已採此格式；YugabyteDB vm-3node direct RC 4 cells 已採此格式；YugabyteDB HAProxy 3s3r RC 已完成但 DB-host metrics missing；Kubernetes 重跑尚未排程；YugabyteDB pre-v4.7 single-run 已備份於 yuga-tc1-old/。 |
| N5 | suite marker `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` + `.db-config.done` 代表該案例流程鏈完整。 |
| N6 | CockroachDB / TiDB / YugabyteDB 三家 vm-1node 全 iso 的 tpmC 與 latency p50/p95/p99 已全為 5-round mean，口徑一致；數據來源為 `runs/threads-*/round-*/go-tpc-stdout.txt` + `[tests/common/summary-from-stdout.py](../tests/common/summary-from-stdout.py)` 解析後落地的 `summary.json`。 |
| N7 | TiDB 三節點與 Kubernetes 數據已刻意清空，等待 PoC v4.7 重跑後再回填。 |
| N8 | CockroachDB 機制描述以 artifact 數據與[官方 v26.2 docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) 為主；server-internal retry 等未直接量測項以「推測」呈現，待 trace / statement diagnostics 補強。 |
| <a id="note-N9"></a>N9 | **`N` = 獨立重跑次數**，不是 round 數。`N=1` 代表只做過 1 次完整流程（重建環境 → 部署 → prepare → run → collect），雖然裡面有 4 個併發水位 × 5 round，但只能降低單次執行內的隨機波動，無法證明不同時間、不同重建環境下仍穩定。`N=3` 代表完整流程獨立重跑 3 次，可觀察三次之間是否一致，嚴謹性明顯高於 N=1；若三次結果接近，才比較適合作為對外結論。本文凡標 `N=1` 或 `N=3 待確認` 的結果，都只能視為方向性觀察，不視為最終定論。 |
| <a id="note-N10"></a>N10 | **分片（shard）/ 複本（replica）是三節點結果的核心變數**。分片數決定資料被切成幾份，會影響資料分散、tablet / range 協調與跨節點查找成本；複本數決定每筆資料同步保存幾份，會影響寫入時的同步複寫、quorum commit 與延遲。若分片數或複本數沒有固定，就無法分辨效能差異到底來自「資料切分」還是「複寫成本」，也不能把不同拓撲的 tpmC / p99 視為同口徑比較。 |

## 參考

- TiDB 流程紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB 流程紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- YugabyteDB 流程紀錄：[yuga-tc1/S-BASE/pipeline-log.md](./yuga-tc1/S-BASE/pipeline-log.md)
- CockroachDB 歷史資料（已 deprecated）：[cockroach-tc1/S-BASE/pipeline-log.md](./cockroach-tc1/S-BASE/pipeline-log.md)
- Summary parser（從 stdout 補產 summary.json）：[tests/common/summary-from-stdout.py](../tests/common/summary-from-stdout.py)
- Codex 文件審計 prompt：[audit-prompt.md](./audit-prompt.md)
- 歷史 README 備份：[README_old.md](./README_old.md)
