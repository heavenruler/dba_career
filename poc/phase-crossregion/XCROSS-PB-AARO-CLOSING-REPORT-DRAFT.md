# X-CROSS P-B×A-A-RO 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 P-B Placement 正式測試

> 目的：驗證 TiDB/YBDB/CRDB 三家 DB 在 6-node cross-region 拓樸下、**P-B
> placement**（散置 RF=3 全 voter、leader 跨區混合分佈 30-70%）於
> A-A-RO（IDC 標準讀寫 mix、GCP 同時跑唯讀 mix）profile 的正式 W=128
> 效能基準。TS=`20260730T094406+0800`，執行順序 TiDB→YBDB→CRDB，三家皆
> PASS 並已歸檔，VM 已 destroy。

## 1. 執行摘要

| DB | IDC tpmC@128 | GCP read_tpmTotal@128 | Placement gate | Artifact |
|---|---:|---:|---|---|
| **TiDB** | 5,699.7（⚠ 見 §3 異常） | 23,120.0 | idc=10/19（52%）PASS | [`tidb-vm-6node-P-B-aaro-rc-20260730T094406+0800`](../results/x-cross/smoke/early-runs/20260730T094406+0800/tidb-vm-6node-P-B-aaro-rc-20260730T094406+0800/) |
| **YBDB** | 11,989.8 | 42,116.4 | idc=2/3（66%）PASS | [`ybdb-vm-6node-P-B-aaro-rc-20260730T094406+0800`](../results/x-cross/smoke/early-runs/20260730T094406+0800/ybdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/) |
| **CRDB** | 13,777.1 | 38,194.9 | idc=7/12（58%）PASS | [`crdb-vm-6node-P-B-aaro-rc-20260730T094406+0800`](../results/x-cross/smoke/early-runs/20260730T094406+0800/crdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/) |

三家 IDC 側全程 0 error（TiDB th=128 例外，錯誤率 0.004%，見 §3）。P-B
placement gate（`prepare.sh` §6.6 抽樣 warehouse/district/customer 3 表）
三家皆落在 30-70% 窗口內通過。**TiDB 在 th=128（最高併發檔位）出現嚴重
吞吐崩潰與延遲暴衝，YBDB/CRDB 未見同款現象**——判定為 TiDB 特有的
跨區鎖競爭問題，非流程或口徑錯誤，詳見 §3。

## 2. 測試目的與範圍

- 驗證 P-B×A-A-RO（IDC 標準 TPCC 讀寫 + GCP 同時跑唯讀 mix ORDER_STATUS/
  STOCK_LEVEL）在正式 W=128 規模下，P-B 的跨區混合 leader 分佈
  是否仍能同時支撐 IDC 寫入與 GCP 就近讀兩種負載。
- Profile：A-A-RO，IDC warehouses=128 標準 mix；GCP 同一批資料唯讀 mix
  （`--weight 0,0,50,0,50`，即 ORDER_STATUS/STOCK_LEVEL 各半）。執行緒
  檔位 16/32/64/128，各檔位 5 輪。

## 3. TiDB th=128 吞吐崩潰異常（本輪最重要發現）

### 現象

| 執行緒 | tpmC | NEW_ORDER p50/p95/p99 (ms) | tpmC_range_mean_pct | 錯誤率 |
|---:|---:|---|---:|---:|
| 16 | 6,037.6 | 98.2 / 180.3 / 280.2 | 24.1% | 0% |
| 32 | 9,379.1 | 127.5 / 204.7 / 484.9 | 13.3% | 0% |
| 64 | 12,205.0 | 181.2 / 432.9 / 825.4 | 40.6% | 0% |
| **128** | **5,699.7** | **2,182.7 / 7,429.0 / 9,234.2** | **245.5%** | **0.004%** |

th=128 的 5 輪 tpmC 逐輪為 `[9003.0, 14948.5, 2113.0, 953.7, 1480.2]`——
前兩輪正常（甚至是全程最高值），第 3-5 輪崩潰到 ~1,000-2,100，NEW_ORDER
延遲 p99 衝到 9.2 秒（正常檔位僅數百 ms）。YBDB／CRDB 同檔位五輪皆穩定
（range% 分別 16.4%／13.1%），僅 TiDB 出現此現象。

### 根因調查

1. **非資源瓶頸**：崩潰輪次（round-3）與正常輪次（round-1）的 IDC
   dbhost CPU/記憶體對比——round-3 平均 CPU idle 83.5%（round-1 僅
   58.3%），記憶體皆維持 150MB-1.2GB free、無 swap。**崩潰當下節點反而
   更閒**，排除本地 CPU/記憶體資源耗盡。
2. **實際錯誤訊息**：round-3 的 `go-tpc-stdout.txt` 大量出現
   ```
   execute run failed, err Error 8022 (HY000): Error: KV error safe to
   retry Error(Txn(Error(Mvcc(Error(TxnLockNotFound { ... })))))
   [try again later]
   ```
   這是 TiDB/TiKV 悲觀鎖交易在**鎖解析競賽（lock resolution race）**下的
   標準重試訊號——當 secondary lock 嘗試解析 primary lock 時，若 primary
   已因 TTL 逾時被其他協程清除，會回報 `TxnLockNotFound` 並要求 client
   重試。此類錯誤在**高併發 + 高跨節點延遲**下發生率會顯著上升。
3. **與 P-B 設計的關聯**：P-B 下 TiDB 9 張表拆兩組相反方向
   `PRIMARY_REGION` policy（idc 優先 5 表／gcp 優先 4 表，見
   `tests/tidb/placement-p-b.sql`）——IDC 端寫入落在 gcp 優先組的表
   （約全體一半的 region）時，寫入路徑本身就要跨 WAN 到 gcp 端 leader。
   在 t128 最高併發下，跨 WAN 的悲觀鎖交易堆疊加上 TTL 到期，觸發
   `TxnLockNotFound` 重試風暴，導致部分交易延遲暴增、有效吞吐崩潰。
4. **YBDB/CRDB 為何未見同款現象**：兩者的併發控制機制不同——CRDB 用
   per-range lease（`lease_preferences`）、YBDB 用 tablet leader，皆非
   TiDB 這種 percolator 式兩階段悲觀鎖 + 顯式鎖表；跨區延遲對它們的
   影響主要反映在單筆延遲上升，不會像 TiDB 這樣觸發鎖解析重試風暴。

### 判定

此為 **TiDB 特有的、P-B 跨區混合 leader 與高併發悲觀鎖交互作用**下的
真實限制，非測試流程或口徑錯誤（`check-aaro-artifacts.py` 正確驗證
0.004% 錯誤率、gcp_side 欄位齊全，PASS 判定成立）。這是本輪最有價值的
發現之一——**P-B 對 TiDB 在最高併發檔位存在實際風險，正式評估報告需
明確標注此限制**，建議後續：
- 針對 TiDB 單獨在 t128 檔位重跑，驗證是否可重現（判斷是否為必然現象
  或機率性）。
- 若確認必然發生，需評估是否調整 TiDB 的悲觀鎖重試策略
  （`tidb_lock_ttl` 等）或降低 P-B 下 gcp 優先組表的比例。

## 4. IDC 側完整結果

### TiDB

| 執行緒 | tpmC | tpmTotal | 效率% | 錯誤率 |
|---:|---:|---:|---:|---:|
| 16 | 6,037.6 | 13,413.0 | 366.8 | 0% |
| 32 | 9,379.1 | 20,798.3 | 569.8 | 0% |
| 64 | 12,205.0 | 27,119.7 | 741.4 | 0% |
| 128 | 5,699.7 | 12,646.7 | 346.2 | 0.004% |

### YBDB

| 執行緒 | tpmC | tpmTotal | 效率% | 錯誤率 |
|---:|---:|---:|---:|---:|
| 16 | 2,325.7 | 5,176.8 | 141.3 | 0% |
| 32 | 3,638.5 | 8,099.6 | 221.1 | 0% |
| 64 | 9,785.0 | 21,740.7 | 594.4 | 0% |
| 128 | 11,989.8 | 26,710.4 | 728.4 | 0% |

### CRDB

| 執行緒 | tpmC | tpmTotal | 效率% | 錯誤率 |
|---:|---:|---:|---:|---:|
| 16 | 3,898.8 | 8,673.0 | 236.9 | 0% |
| 32 | 5,986.1 | 13,336.7 | 363.6 | 0% |
| 64 | 11,294.9 | 25,116.0 | 686.2 | 0% |
| 128 | 13,777.1 | 30,640.9 | 837.0 | 0% |

## 5. GCP 側完整結果（唯讀 mix，`read_tpmTotal` 為主指標，非 tpmC）

| 執行緒 | TiDB read_tpmTotal | YBDB read_tpmTotal | CRDB read_tpmTotal |
|---:|---:|---:|---:|
| 16 | 8,369.5 | 31,239.9 | 25,794.1 |
| 32 | 14,312.7 | 35,182.5 | 41,108.0 |
| 64 | 13,632.8 | 40,402.4 | 39,330.5 |
| 128 | 23,120.0 | 42,116.4 | 38,194.9 |

TiDB GCP 側 th=128 的 ORDER_STATUS/STOCK_LEVEL p99 分別為 2,113.9ms／
5,288.2ms，明顯高於 YBDB（520.1／442.9ms）與 CRDB（469.8／325.5ms）——
與 §3 的 IDC 側崩潰同時發生，判斷是同一輪跨區鎖競爭/重試風暴造成的
連帶延遲，非 GCP 側就近讀本身失效。

## 6. Placement Gate 驗證

`prepare.sh` §6.6 抽樣（僅 warehouse/district/customer 3 表）：

- TiDB：idc=10/19（52%）PASS
- YBDB：idc=2/3（66%）PASS
- CRDB：idc=7/12（58%）PASS

三家皆延續 P-B×A-S 已驗證的雙 policy／雙 tablespace+enforcer／雙
lease_preferences+partition 修復設計，無需針對 A-A-RO 額外調整。

## 7. 已知限制

- **TiDB th=128 吞吐崩潰**（§3）為本輪最重要待跟催項目，建議排入下一輪
  TiDB 專項重跑驗證可重現性。
- 本輪為 P-B×A-A-RO 單一 workload；P-B×A-A（兩端皆寫，W 全重疊 max
  contention）為下一步，執行前復盤已發現並修復 `run-vm6-aa.sh` 的 GCP
  側 conn-params 對 A-A 場景會誤加 read-only 設定（見
  `SESSION-HISTORY.md` 2026-07-31 節），修復後尚待正式執行驗證。
- 同批 fetch 依既有慣例附帶撈回歷史 run 完整副本（非本次目標，已比照
  W=128 P-B×A-S 慣例處理，暫不刪除）。

## 8. Artifact 路徑

```
results/x-cross/smoke/early-runs/20260730T094406+0800/tidb-vm-6node-P-B-aaro-rc-20260730T094406+0800/
results/x-cross/smoke/early-runs/20260730T094406+0800/ybdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/
results/x-cross/smoke/early-runs/20260730T094406+0800/crdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/
```

各 DB suite 目錄下 `summary.json` 為機器可讀彙整來源（含
`gcp_side`、`region_routing_evidence.placement_gate`）；三個 DB suite
原始 artifact（各 ~40M）依既有慣例 gitignore。VM 已於採證後
`terraform destroy`，兩側 state 歸零。

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-30/31 節。
