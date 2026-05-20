# S-BASE 結果索引

> 原始 README 已備份至 [`README_old.md`](./README_old.md)。本頁作為結果索引，只放目前可用數據、執行狀態與追溯入口；細節分析請看各資料庫的流程紀錄。

## 目前總覽

| 資料庫 | 已完成且可用的結果 | 目前最高 tpmC | 狀態 | 追溯入口 |
|---|---|---:|---|---|
| TiDB | 單節點虛擬機，READ COMMITTED / REPEATABLE READ | **13,874** | 單節點完成；三節點與 Kubernetes 待重跑 | [流程紀錄](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | 單節點虛擬機，READ COMMITTED / REPEATABLE READ / SERIALIZABLE | **10,830** | 單節點三 isolation 完成；三節點與 Kubernetes 待執行 | [流程紀錄](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | 單節點虛擬機，READ COMMITTED | **11,436** | vm-1node-rc v4.7 完成（5-round mean，零 error）；rr / strict / vm-3node / Kubernetes 待測；pre-v4.7 single-run 與 K8s 歷史已備份於 [yuga-tc1-old/](./yuga-tc1-old/) | [流程紀錄](./yuga-tc1/S-BASE/pipeline-log.md) |

> 同硬體 vm-1node 對照（4 vCPU / 15 GiB / single XFS, 5-round mean）：TiDB rr t128 13,874 ＞ TiDB rc t128 13,064 ＞ YugabyteDB rc t32 11,436（v4.7）＞ CockroachDB strict t64 10,830 ＞ CRDB rc t64 9,134。三家皆 5-round mean、口徑一致。

## 已驗證結果

| 資料庫 | 案例 | 隔離級 | 來源目錄 | 併發 | tpmC | p99 (ms) | 判讀 |
|---|---|---|---|---:|---:|---:|---|
| TiDB | 單節點虛擬機 | READ COMMITTED | [tidb-vm-1node-rc-20260518T202009+0800](./tidb-tc1/S-BASE/vm-1node-rc/tidb-vm-1node-rc-20260518T202009+0800/) | 128 | 13,064 | 597 | RC baseline；CPU-bound（%user 80.8%、%iowait 3.1%）|
| TiDB | 單節點虛擬機 | REPEATABLE READ | [tidb-vm-1node-rr-20260519T001949+0800](./tidb-tc1/S-BASE/vm-1node-rr/tidb-vm-1node-rr-20260519T001949+0800/) | 128 | **13,874** | 503 | **TiDB 最高 tpmC**；pessimistic 模式零 error |
| CockroachDB | 單節點虛擬機 | READ COMMITTED | [crdb-vm-1node-rc-20260519T085346+0800](./crdb-tc1/S-BASE/vm-1node-rc/crdb-vm-1node-rc-20260519T085346+0800/) | 64 | 9,134 | 440 | RC 在 t16 起即被 fsync IO 卡死（%iowait 18%）|
| CockroachDB | 單節點虛擬機 | REPEATABLE READ | [crdb-vm-1node-rr-20260519T124506+0800](./crdb-tc1/S-BASE/vm-1node-rr/crdb-vm-1node-rr-20260519T124506+0800/) | 128 | 3,788 | 604 | preview RR；retry storm（DB %idle 46%、127 err/round）|
| CockroachDB | 單節點虛擬機 | SERIALIZABLE | [crdb-vm-1node-strict-20260519T164057+0800](./crdb-tc1/S-BASE/vm-1node-strict/crdb-vm-1node-strict-20260519T164057+0800/) | 64 | **10,830** | 227 | **CRDB 最高 tpmC**；t32+ 超越 RC（反直覺，預設最快）；t128 mean 仍 10,456 / p99 487ms，高併發保持領先 |
| YugabyteDB | 單節點虛擬機 | READ COMMITTED | [ybdb-vm-1node-rc-20260520T134929+0800](./yuga-tc1/S-BASE/vm-1node-rc/ybdb-vm-1node-rc-20260520T134929+0800/) | 32 | **11,436** | 216 | **YBDB v4.7 baseline**；5-round mean，零 error；t32 為 peak（t128 -4.8% 過飽和）|

## 執行矩陣

| 資料庫 | 案例 | READ COMMITTED | REPEATABLE READ | 最嚴格隔離級 | 說明 |
|---|---|---|---|---|---|
| TiDB | 單節點虛擬機 | ✅ 完成 | ✅ 完成 | ✅ 以 REPEATABLE READ 代表 | TiDB 不支援原生 SERIALIZABLE，strict 等價於 RR |
| TiDB | 三節點虛擬機，直連 | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| TiDB | 三節點虛擬機，HAProxy | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| TiDB | Kubernetes，無資源限制 | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| TiDB | Kubernetes，有資源限制 | 🔄 待重跑 | 🔄 待重跑 | 🔄 待重跑 | 舊數據已清空，等待 PoC v4.7 重跑 |
| CockroachDB | 單節點虛擬機 | ✅ 完成 | ✅ 完成 | ✅ 完成 (SERIALIZABLE) | 三 isolation 全完整；strict t64 為 vm-1node 峰值 |
| CockroachDB | 三節點虛擬機，直連 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| CockroachDB | 三節點虛擬機，HAProxy | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| CockroachDB | Kubernetes，無資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| CockroachDB | Kubernetes，有資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | 單節點虛擬機 | ✅ 完成 | ⏳ 待執行 | ⏳ 待執行 | vm-1node-rc 5-round mean peak 11,436 tpmC @ t32，零 error；rr / strict 待測 |
| YugabyteDB | 三節點虛擬機，直連 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | 三節點虛擬機，HAProxy | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程 |
| YugabyteDB | Kubernetes，無資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程；pre-v4.7 單次 10min wrapper 僅作歷史參考 |
| YugabyteDB | Kubernetes，有資源限制 | ⏳ 待執行 | ⏳ 待執行 | ⏳ 待執行 | 等待同一套 PoC v4.7 流程；pre-v4.7 單次 10min wrapper 僅作歷史參考 |

## 資料庫說明

### TiDB

- 單節點 RC 與 RR 已完成。pessimistic 模式下 RR 比 RC 快 +6.2% tpmC（t128: 13,874 vs 13,064）、p99 低（503 vs 597ms），整輪全 20 round 零 NEW_ORDER_ERR。
- CPU-bound：%iowait < 5%、sda %util ≤ 51%、t128 %user mean 約 95.5%（瞬間接近 100%）。
- TiDB 不支援原生 SERIALIZABLE，strict 在工具鏈上等價於 RR；跨家 strict 對標時須注意此點，不能直比 CRDB / YBDB 的 SSI。
- 三節點與 Kubernetes 舊數據已清空，等待 PoC v4.7 重跑。

### CockroachDB

- 單節點三 isolation（RC / RR / SERIALIZABLE）全完整。**SERIALIZABLE 反而是最快**（t32+ 比 RC 高 +10~19% tpmC、p99 低一個量級）：RC 自 t16 起被 fsync IO 卡死（%idle 5% / %iowait 18%），strict 走 read-refresh 路徑 IO 更省、有 CPU headroom。
- preview RR 是最慢選項（t128: 3,788 tpmC，比 RC -57% / 比 TiDB RR -72.7%）；雖然 RR 在 CRDB 與 TiDB 內部都 = SI，但 CRDB 採 first-committer-wins + client retry，無等效於 TiDB `tidb_txn_mode=pessimistic` 的全域開關。
- starting-gun storm：RR/strict 兩者在每 round 起始爆 retry（per-txn snapshot ts 同步衝突）；RC 因 per-statement snapshot 完全免疫。
- 詳細機制與比較見 [crdb-tc1 流程紀錄 TL;DR](./crdb-tc1/S-BASE/pipeline-log.md#tldr--vm-1node-三-isolation-矩陣完成2026-05-19)。

### YugabyteDB

- 2025.2.2 LTS + 有效 Read Committed（`yb_enable_read_committed_isolation=true` tserver gflag + session iso 雙閘）後 TPC-C 才有可比結果；本輪 v4.7 vm-1node-rc 同時驗 `SHOW transaction_isolation` + `SHOW yb_effective_transaction_isolation_level`，effective 與 session 都 `read committed`，無 silent fallback。
- vm-1node-rc v4.7 baseline：peak **11,436 tpmC @ t32**（5-round mean），零 NEW_ORDER_ERR / 20 round；t128 已過飽和（-4.8% tpmC、p99 翻倍至 1000ms）。
- 三家飽和成因不同：YBDB CPU-bound 含異常高 %sys (19%) — YSQL postgres ↔ DocDB tserver 跨進程 RPC 拉走 1/5 CPU；對比 TiDB %sys 9% / CRDB %sys 5.5%。詳見 [yuga-tc1 pipeline-log TL;DR](./yuga-tc1/S-BASE/pipeline-log.md#tldr--vm-1node-rc-完成2026-05-20)。
- vm-1node pre-v4.7 single-run / vm-3node-direct / vm-3node-HAProxy / K8s（unlimit & limit）等歷史結果已備份於 [`yuga-tc1-old/`](./yuga-tc1-old/)，narrative 在 [`yuga-tc1-old/S-BASE/pipeline-log_old.md`](./yuga-tc1-old/S-BASE/pipeline-log_old.md)；v4.7 rr / strict / vm-3node / Kubernetes 重跑尚未排程。

### 歷史檔案

- `cockroach-tc1/` 為 PoC v4.7 前的 CockroachDB 舊資料（單次 10min、手動部署、無雙邊監控）。已加 deprecated banner，**不納入 PoC v4.7 baseline 與跨家對比**。

## 數據品質註解

| 編號 | 說明 |
|---|---|
| N1 | 本測試是 TPC-C-derived stress benchmark using go-tpc，非 audited TPC-C，不能與官方 TPC-C 排名直接比較。 |
| N2 | go-tpc 本輪沒有 think time / keying time，執行緒完成一筆交易後會立即送下一筆，因此 efficiency 超過 100% 屬正常。 |
| N3 | isolation 必須由 connection string 與 gate 記錄共同確認，避免 driver 或資料庫預設值造成測試口徑偏移（CRDB 採 isolation 雙閘 = `isolation-db.txt` + `isolation-driver-verify.txt`）。 |
| N4 | v4.7 標準格式：20 分鐘 warmup、每個併發水位 5 round × 5 分鐘、4 thread groups（16/32/64/128）、DB-host 雙邊 OS 監控（mpstat/iostat/vmstat/sar）。TiDB / CRDB / YugabyteDB vm-1node-rc 已採此格式（YBDB 為 commit `afe047d` 後在 yuga-tc1/S-BASE/vm-1node-rc/）；YBDB rr / strict / vm-3node / Kubernetes 重跑尚未排程；YBDB pre-v4.7 single-run 已備份於 yuga-tc1-old/。 |
| N5 | suite marker `.gate.done` / `.prepare.done` / `.gate-isolation.done` / `.run.done` / `.collect.done` / `.suite.done` 代表該案例流程鏈完整。 |
| N6 | CRDB / TiDB / YugabyteDB vm-1node-rc 的 tpmC 與 latency p50/p95/p99 已全為 5-round mean（YBDB 為 commit `afe047d` 後資料；YBDB rr / strict 待測）。 |
| N7 | TiDB 三節點與 Kubernetes 數據已刻意清空，等待 PoC v4.7 重跑後再回填。 |
| N8 | CRDB 機制描述以 artifact 數據與[官方 v26.2 docs](https://www.cockroachlabs.com/docs/stable/architecture/transaction-layer) 為主；server-internal retry 等未直接量測項以「推測」呈現，待 trace / statement diagnostics 補強。 |

## 參考

- TiDB 流程紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB 流程紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- YugabyteDB 流程紀錄：[yuga-tc1/S-BASE/pipeline-log.md](./yuga-tc1/S-BASE/pipeline-log.md)
- CockroachDB 歷史資料（已 deprecated）：[cockroach-tc1/S-BASE/pipeline-log.md](./cockroach-tc1/S-BASE/pipeline-log.md)
- Codex 文件審計 prompt：[audit-prompt.md](./audit-prompt.md)
- 歷史 README 備份：[README_old.md](./README_old.md)
