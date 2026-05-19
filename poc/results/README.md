# TPC-C Benchmark Results — S-BASE

> 原始 README 已備份至 [`README_old.md`](./README_old.md)。本檔目前先聚焦 TiDB 最新 PoC v4.7 結果；CockroachDB / YugabyteDB 區段已清空，待後續用同一套 v4.7 流程重建。

## 本報告摘要

本輪 TiDB 摘要依 [`tidb-tc1/S-BASE/pipeline-log.md`](./tidb-tc1/S-BASE/pipeline-log.md) 更新。PoC v4.7 已將 vm-1node RC / RR 改為 detached suite、多輪平均、isolation gate、client + DB-host OS 監控；舊 VM / HAProxy 歷史段落已移到 TiDB pipeline log 的 old 檔中保留。

| DB | vm-1node RC peak | vm-1node RR peak | vm-3node peak | k8s-unlimit peak | k8s-limit peak | 狀態 | pipeline log |
|---|---:|---:|---:|---:|---:|---|---|
| TiDB | 13,064 tpmC | **13,874 tpmC** | 22,841 tpmC | 18,918.8 tpmC | 11,080.7 tpmC | 已更新 | [tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md) |
| CockroachDB | — | — | — | — | — | 已清空，待重建 | — |
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

### K8s 對照（保留既有 2026-05-10 結果）

| variant | 拓撲 | RF | 入口 | resource limit | 16t | 32t | 64t | 128t | peak |
|---|---|---:|---|---|---:|---:|---:|---:|---:|
| k8s-3node-unlimit | K8s×3 | 3 | NodePort :30004 | 無 | 13,160.9 | 16,304.1 | **18,918.8** | 18,871.3 | **18,918.8** |
| k8s-3node-limit | K8s×3 | 3 | NodePort :30004 | TiKV 2c/8GiB | 10,470.5 | **11,080.7** | 10,895.5 | 10,519.7 | **11,080.7** |

K8s unlimit peak 較 VM 3-node HAProxy peak 22,841 約低 17%。K8s limit 在 TiKV 2 CPU cap 下 peak 下降約 41%，且 32t 即達飽和。

### 歷史 VM 3-node 對照（僅作 scale-out 參考）

| variant | peak tpmC | 解讀 |
|---|---:|---|
| vm-3node-direct | 14,779 | 單一 SQL gateway，scale-out 效益有限 |
| vm-3node (HAProxy) | 22,841 | SQL 節點分散後表現最佳；對 vm-1node v4.7 RC peak 約 1.75x |

scale-out ratio 不應預設為線性；後續 vm-3node v4.7 需用同樣 DB-host 監控驗證 CPU / IO / Raft / network 是否成為新瓶頸。

## CockroachDB (cockroach-tc1)

> 本區段已清空。待 CockroachDB 用 PoC v4.7 流程重新產生 gate / prepare / run / collect artifacts 後再回填。

## YugabyteDB (yuga-tc1)

> 本區段已清空。待 YugabyteDB 用 PoC v4.7 流程重新產生 gate / prepare / run / collect artifacts 後再回填。

## 對標維度

| 維度 | TiDB 目前狀態 | CRDB / YBDB 狀態 |
|---|---|---|
| 單機 VM baseline | vm-1node-rc / vm-1node-rr 已更新到 v4.7 | 待重建 |
| 隔離級成本 | RC vs RR 已完成；TiDB strict 以 RR 代表 | 待重建 |
| 多節點 VM | 僅保留舊 vm-3node 參考數字 | 待重建 |
| K8s 無限制 | 保留 2026-05-10 結果 | 待重建 |
| K8s 資源限制 | 保留 2026-05-10 結果 | 待重建 |

## 參考

- TiDB 最新測試紀錄：[tidb-tc1/S-BASE/pipeline-log.md](./tidb-tc1/S-BASE/pipeline-log.md)
- README 備份：[README_old.md](./README_old.md)
