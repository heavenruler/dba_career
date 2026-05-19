# TPC-C Benchmark Results — S-BASE

> 原始 README 已備份至 [`README_old.md`](./README_old.md)。本檔目前先聚焦 PoC v4.7 已完成的 TiDB 與 CockroachDB vm-1node RC 進度；YugabyteDB 區段已清空，待後續用同一套 v4.7 流程重建。

## 本報告摘要

本輪摘要依 TiDB / CockroachDB 各自的 PoC v4.7 pipeline log 更新。PoC v4.7 已將 vm-1node 測試改為 detached suite、多輪平均、isolation gate、client + DB-host OS 監控；舊流程結果僅作歷史參考，不直接混入新 baseline。

| DB | vm-1node RC peak | vm-1node RR peak | vm-3node peak | k8s-unlimit peak | k8s-limit peak | 狀態 | pipeline log |
|---|---:|---:|---:|---:|---:|---|---|
| TiDB | 13,064 tpmC | **13,874 tpmC** | — | — | — | vm-1node RC/RR 已更新；vm-3node / k8s 待 v4.7 重跑後回填 | [tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | 9,134 tpmC | — | — | — | — | vm-1node RC artifacts 已完成；analytics 待修正後定稿 | [crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md) |
| YugabyteDB | — | — | — | — | — | 已清空，待重建 | — |

## 測試環境總覽

- **測試工具**：[go-tpc](https://github.com/pingcap/go-tpc)
- **工作負載**：TPC-C-derived OLTP stress benchmark，128 warehouses
- **併發水位**：16 / 32 / 64 / 128 threads
- **vm-1node v4.7 方法**：20 min warmup @ 64 threads；每個 thread 水位 5 round × 5 min；記錄 round-to-round variance
- **監控**：client (`.31`) 與 DB-host (`.32`) 同時採集 `mpstat` / `iostat` / `vmstat` / `sar`
- **注意**：本 PoC 無 think time / keying time，`efficiency > 100%` 屬正常；不可與 audited TPC-C 官方數字直接比較。

## TiDB (tidb-tc1)

### vm-1node RC / RR 最新 baseline

| variant | isolation | 拓撲 | RF | 入口 | 16t | 32t | 64t | 128t | peak | sweet spot |
|---|---|---|---:|---|---:|---:|---:|---:|---:|---|
| vm-1node-rc | READ COMMITTED | VM×1 | 1 | 直連 :4000 | 10,074 | 11,728 | 12,744 | **13,064** | **13,064** | 64t：12,744 tpmC / p99 305ms |
| vm-1node-rr | REPEATABLE READ | VM×1 | 1 | 直連 :4000 | 11,196 | 12,831 | 13,743 | **13,874** | **13,874** | 64t：13,743 tpmC / p99 246ms |
| vm-1node-strict | TiDB native strictest = RR | VM×1 | 1 | 直連 :4000 | — | — | — | — | — | 略過；以 RR 代表 |

### RC vs RR 觀察

| threads | RC tpmC | RR tpmC | RR delta | RC p99 | RR p99 | p99 delta |
|---:|---:|---:|---:|---:|---:|---:|
| 16 | 10,074 | 11,196 | +11.1% | 94ms | 80ms | -14.9% |
| 32 | 11,728 | 12,831 | +9.4% | 163ms | 134ms | -17.8% |
| 64 | 12,744 | 13,743 | +7.8% | 305ms | 246ms | -19.3% |
| 128 | 13,064 | 13,874 | +6.2% | 597ms | 503ms | -15.7% |

RR 在 TiDB v8.5.2 pessimistic + go-tpc multi-statement workload 下全面優於 RC：tpmC 提升 6-11%，p99 latency 降低 15-19%。此結論只適用於 TiDB pessimistic 與本 PoC workload；不可外推到 CRDB / YBDB。

### DB-host 飽和結論

| variant | sweet spot | peak | CPU / IO 判讀 |
|---|---|---:|---|
| vm-1node-rc | 64t | 13,064 @ 128t | 128t 只比 64t 多 2.5% tpmC，但 p99 近 2 倍；4 vCPU 是硬天花板，iowait < 5%，disk util <= 51%。 |
| vm-1node-rr | 64t | 13,874 @ 128t | 128t 只比 64t 多約 1% tpmC，但 p99 翻倍；%idle 最低 0.25%，已接近 CPU 撞牆。 |

### K8s 對照（待 v4.7 重跑後回填）

| variant | 拓撲 | RF | 入口 | resource limit | 16t | 32t | 64t | 128t | peak |
|---|---|---:|---|---|---:|---:|---:|---:|---:|
| k8s-3node-unlimit | K8s×3 | 3 | NodePort :30004 | 無 | — | — | — | — | — |
| k8s-3node-limit | K8s×3 | 3 | NodePort :30004 | TiKV 2c/8GiB | — | — | — | — | — |

K8s 數據先清空，待依 PoC v4.7 流程重跑完成後回填；舊版 2026-05-10 結果保留在 [`README_old.md`](./README_old.md) 與 TiDB pipeline 歷史段落中。

### VM 3-node 對照（待 v4.7 重跑後回填）

| variant | peak tpmC | 解讀 |
|---|---:|---|
| vm-3node-direct | — | 待重跑 |
| vm-3node (HAProxy) | — | 待重跑 |

scale-out ratio 不應預設為線性；後續 vm-3node v4.7 需用同樣 DB-host 監控驗證 CPU / IO / Raft / network 是否成為新瓶頸。

## CockroachDB (cockroach-tc1)

### vm-1node RC 目前進度

CockroachDB 已完成 PoC v4.7 `vm-1node-rc` 執行，artifact 目錄為 `crdb-tc1/S-BASE/vm-1node-rc/crdb-vm-1node-rc-20260519T085346+0800/`。

| variant | isolation | 拓撲 | RF | 入口 | 16t | 32t | 64t | 128t | peak | 狀態 |
|---|---|---|---:|---|---:|---:|---:|---:|---:|---|
| vm-1node-rc | READ COMMITTED | VM×1 | 1 | 直連 :26257 | 9,034 | 9,020 | **9,134** | 8,813 | **9,134** | artifacts 完整；analytics 待修 |

執行鏈已完成：`.gate.done`、`.prepare.done`、`.gate-isolation.done`、`.run.done`、`.collect.done`、`.suite.done` 皆存在；20 個 round log 與 80 個 DB-host OS 監控檔齊全。isolation gate 驗證為 `read committed`。

目前需修正後再定稿的 analytics 口徑：
- `NO p50 / p95 / p99` 欄位與原始 go-tpc summary 不一致，需重算後更新。
- `Raft log fsync` 歸因目前由 OS iowait 推論，應改成保守描述或補 CRDB metrics/log 證據。
- 與 TiDB 的 `+33% / +55%` 表述需明確分母，避免把 CRDB 相對 TiDB與 TiDB 相對 CRDB混用。

在 analytics 修正前，本 README 僅採用已核對的 tpmC / artifact 進度，不採用 latency 與瓶頸結論作正式對外摘要。

## YugabyteDB (yuga-tc1)

> 本區段已清空。待 YugabyteDB 用 PoC v4.7 流程重新產生 gate / prepare / run / collect artifacts 後再回填。

## 對標維度

| 維度 | TiDB 目前狀態 | CRDB / YBDB 狀態 |
|---|---|---|
| 單機 VM baseline | vm-1node-rc / vm-1node-rr 已更新到 v4.7 | CRDB vm-1node-rc artifacts 完成、analytics 待修；YBDB 待重建 |
| 隔離級成本 | RC vs RR 已完成；TiDB strict 以 RR 代表 | CRDB rr/strict 待跑；YBDB 待重建 |
| 多節點 VM | vm-3node 數據已清空，待 v4.7 重跑後回填 | 待重建 |
| K8s 無限制 | k8s-unlimit 數據已清空，待 v4.7 重跑後回填 | 待重建 |
| K8s 資源限制 | k8s-limit 數據已清空，待 v4.7 重跑後回填 | 待重建 |

## 參考

- TiDB 最新測試紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- CockroachDB v4.7 測試紀錄：[crdb-tc1/S-BASE/pipeline-log.md](./crdb-tc1/S-BASE/pipeline-log.md)
- README 備份：[README_old.md](./README_old.md)
