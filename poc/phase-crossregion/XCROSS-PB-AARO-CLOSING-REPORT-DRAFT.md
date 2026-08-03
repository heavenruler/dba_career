# X-CROSS P-B×A-A-RO 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 P-B Placement Phase-Adopted 探索性測試

> **Scope**：`X-CROSS`，`baseline_family=crossregion`，
> `baseline_eligible=false`，本 profile `N=1`。本報告是**本 phase 的
> 採用批次**，不是可直接對外排名的 S-BASE/S-K8S 正式 baseline，見
> `phase-crossregion/README.md`。
>
> 目的：驗證 TiDB/YBDB/CRDB 三家 DB 在 6-node cross-region 拓樸下、**P-B
> placement**（散置 RF=3 全 voter、leader 跨區混合分佈 30-70%）於
> A-A-RO（IDC 標準讀寫 mix、GCP 同時跑唯讀 mix）profile 的 W=128
> phase-adopted 執行結果。TS=`20260730T094406+0800`，執行順序
> TiDB→YBDB→CRDB，三家皆 PASS 並已歸檔，VM 已 destroy。

## 1. 執行摘要

| DB | IDC tpmC@128 | GCP read_tpmTotal@128 | Placement gate | Artifact |
|---|---:|---:|---|---|
| **TiDB** | 5,699.7（⚠ 見 §3 異常） | 23,120.0 | idc=10/19（52%）PASS | [`tidb-vm-6node-P-B-aaro-rc-20260730T094406+0800`](../results/x-cross/smoke/early-runs/20260730T094406+0800/tidb-vm-6node-P-B-aaro-rc-20260730T094406+0800/) |
| **YBDB** | 11,989.8 | 42,116.4 | idc=2/3（66%）PASS | [`ybdb-vm-6node-P-B-aaro-rc-20260730T094406+0800`](../results/x-cross/smoke/early-runs/20260730T094406+0800/ybdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/) |
| **CRDB** | 13,777.1 | 38,194.9 | idc=7/12（58%）PASS | [`crdb-vm-6node-P-B-aaro-rc-20260730T094406+0800`](../results/x-cross/smoke/early-runs/20260730T094406+0800/crdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/) |

**錯誤率修正（2026-08-03 Round 2）**：Round 1 修正版仍誤用
`NEW_ORDER.error_count`/`NEW_ORDER.total_count` 冒充「all transaction
加總」——正確口徑須是 `all_txn`（NEW_ORDER+PAYMENT+DELIVERY+
ORDER_STATUS+STOCK_LEVEL，依 `tests/common/summary-from-stdout.py:128-131`）。
**IDC 側全檔位（16/32/64/128）all_txn 加總**：TiDB
12 errors / 1,850,283 successes ≈ 0.000649%（先前誤寫為
「8/833,276≈0.00096%」，即 NEW_ORDER-only）、YBDB 0/1,538,004=0%、
CRDB 0/1,946,407=0%。**GCP 側**（唯讀 mix，ORDER_STATUS+STOCK_LEVEL
加總，口徑本身未受本次修正影響）：TiDB 1,190 / 1,481,960 ≈
0.080235%、YBDB 1,185 / 3,671,772 ≈ 0.032263%、CRDB
1,150 / 3,606,553 ≈ 0.031876%——抽查 raw `go-tpc-stdout-gcp.txt`
發現最常見的是 `context deadline exceeded`（每輪計時結束時的 worker
收尾取消訊號），但目前無可重現的去重計數腳本，不能寫成精確比例
（口徑與抽樣證據見 `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §2）。若保留
th=128 單檔位錯誤率，須明示為 `all_txn.error_rate_pct`（TiDB 該檔位
`summary.json` 內建值為 `0.004%`，與上述「全檔位加總 0.000649%」是
不同分母的兩個數字）。P-B placement gate（`prepare.sh` §6.6 抽樣
warehouse/district/customer 3 表）三家皆落在 30-70% 窗口內通過，
**僅代表 prepare-time 的實際有限樣本通過，不代表全 9 表、全 workload
時段皆為此比例**。**TiDB 在 th=128（最高併發檔位）出現嚴重吞吐劣化
與延遲暴衝，YBDB/CRDB 同檔位未見同款現象**——現象與跨區鎖競爭相容，
但目前只有 N=1、非單變量對照，僅能列為待驗證假說，非已確認根因，
詳見 §3。

**採用 suite source**：[TiDB summary.json](../results/x-cross/smoke/early-runs/20260730T094406+0800/tidb-vm-6node-P-B-aaro-rc-20260730T094406+0800/summary.json) ／
[YBDB summary.json](../results/x-cross/smoke/early-runs/20260730T094406+0800/ybdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/summary.json) ／
[CRDB summary.json](../results/x-cross/smoke/early-runs/20260730T094406+0800/crdb-vm-6node-P-B-aaro-rc-20260730T094406+0800/summary.json)。

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
延遲 p99 衝到 9.2 秒（正常檔位僅數百 ms）。YBDB／CRDB 同檔位 th=128
的 range/mean（分別 16.4%／13.1%）遠低於 TiDB 本檔位的 245.5%，僅
TiDB 出現此崩潰現象；range/mean 未定義「穩定」的門檻，故此處僅比較
相對量級，不逕稱 YBDB/CRDB「穩定」。

### 根因調查

1. **該採樣 host/window 未見 CPU/記憶體飽和（範圍有限，非全面排除
   資源瓶頸）**：崩潰輪次（round-3）與正常輪次（round-1）的 **IDC
   dbhost** CPU/記憶體對比——round-3 平均 CPU idle 83.5%（round-1 僅
   58.3%），記憶體皆維持 150MB-1.2GB free、無 swap。**這只排除了本次
   採樣到的 IDC dbhost 在該時間窗的 CPU/記憶體飽和**；GCP 節點、所有
   TiKV 節點（含未採樣者）、磁碟 I/O、WAN 頻寬/延遲、TiKV 內部
   queue/lock wait 佇列皆**未**採集對應指標，不能寫成「排除資源
   瓶頸」這種全稱結論。
2. **實際錯誤訊息（已去重計數）**：round-3 的 `go-tpc-stdout.txt` 命中
   `TxnLockNotFound` 文字 pattern 12 次、round-4 命中 4 次；但 go-tpc
   對同一錯誤事件會列印兩次（一次帶時間戳、一次不帶，start_ts/key
   相同），**去重後為 round-3 6 起、round-4 2 起，共 8 個 distinct
   events**（與 `summary.json` th=128 的 `NEW_ORDER.error_count=8`
   吻合）：
   ```
   execute run failed, err Error 8022 (HY000): Error: KV error safe to
   retry Error(Txn(Error(Mvcc(Error(TxnLockNotFound { ... })))))
   [try again later]
   ```
   這是 TiDB/TiKV 悲觀鎖交易在**鎖解析（lock resolution）**路徑上的
   失敗訊號，raw log 直接證明的是「lock-path failure 確實發生」；
   PingCAP 官方文件（[Troubleshoot Lock
   Conflicts](https://docs.pingcap.com/tidb/stable/troubleshoot-lock-conflicts/)）
   說明 `TxnLockNotFound` 語意上對應「交易 commit 耗時超過鎖 TTL、
   commit 時 primary lock 已被其他交易回滾/清除」，但**本輪未採集
   TiKV log/metric/trace 或針對這 8 起具體事件逐一比對觸發時序**，
   故「這 8 起具體發生是因為 TTL 到期被清除」仍是**與官方文件語意
   相容的候選機制**，不是本批次已證實的具體因果鏈。
3. **與 P-B 設計的可能關聯（inference，非已確認）**：P-B 下 TiDB 9 張
   表拆兩組相反方向 `PRIMARY_REGION` policy（idc 優先 5 表／gcp 優先
   4 表，見 `tests/tidb/placement-p-b.sql`）——IDC 端寫入落在 gcp
   優先組的表時，寫入路徑本身就要跨 WAN 到 gcp 端 leader。**現象**與
   「跨 WAN 悲觀鎖交易延長 commit 時間、增加撞上鎖 TTL 窗口的機率，
   進而觸發 `TxnLockNotFound`」這個候選機制相容，但**本輪只有 1 個
   採用批次（N=1），且 th=128 這個檔位同時是「總 offered concurrency
   最高」與「跨區鎖競賽理論上最容易發生」的交會點，兩者尚未被個別
   控制分離**——不能排除單純總併發量（IDC 128 執行緒本身）或批次
   特有的資料/環境狀態也是促成因素之一。8 起事件本身也**不足以**
   稱為「重試風暴」，僅為中性描述的「lock resolution 失敗事件」。
4. **YBDB/CRDB 同檔位未見同款現象**：兩者的併發控制機制與 TiDB 不同
   （CRDB 用 per-range lease、YBDB 用 tablet leader，皆非 TiDB 這種
   percolator 式兩階段悲觀鎖），此差異與觀察到的現象相容，但同樣未
   排除其他混淆因素。

### 判定（fact + inference，2026-08-03 依 raw artifact 覆核後降級為假說）

TiDB 在 th=128 出現的吞吐劣化與 `TxnLockNotFound` 重試訊號是**已觀察
到的事實**（`check-aaro-artifacts.py` 驗證通過、gcp_side 欄位齊全，
PASS 判定本身成立，非流程或口徑錯誤）。但「P-B 跨區混合 leader 與
高併發悲觀鎖交互作用」目前**只是與現象相容的假說**，尚未透過控制
實驗排除總執行緒數、workload mix、批次雜訊等混淆變數，**不可寫成
已確認根因**。建議後續（依優先序）：
- 依 `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §3.3 的最小控制實驗設計
  （IDC-only 256 vs dual-side 128+128；固定總 threads 對照；GCP
  on/off 開關；N≥3 重跑並採集 TiKV/PD/WAN/資源指標），確認因果後
  才能寫入正式結論。
- 若後續確認是跨區鎖競爭所致，再評估是否調整 TiDB 悲觀鎖 TTL 相關
  設定或降低 P-B 下 gcp 優先組表的比例。**修正**：先前版本寫
  `tidb_lock_ttl` 為已知調校參數，經查證非真實 TiDB 系統變數——依
  PingCAP 官方文件，悲觀鎖 TTL 上限實際由 TiDB 設定檔的
  `performance.max-txn-ttl` 控制（非 `SHOW VARIABLES` 可見的 session/
  global 變數），鎖等待逾時另由 `innodb_lock_wait_timeout` 控制；
  調校前應以官方文件與實際 `SHOW VARIABLES`/設定檔核對本版本
  （TiDB v8.5.2）是否適用、是否對本錯誤有效，不可逕列為已知手段。

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
與 §3 的 IDC 側劣化同時發生，現象上相容於「同一輪跨區鎖競爭/重試造成
連帶延遲」，但如 §3 所述，此因果關係尚未經控制實驗確認。

**GCP 側全檔位錯誤率**（口徑見摘要 §1／`XCROSS-PB-ALL-WORKLOADS-SUMMARY.md`
§2）：TiDB≈0.0803%、YBDB≈0.03227%、CRDB≈0.03189%，皆非 0。三家皆以
`context deadline exceeded`（round 收尾取消）為主要組成，非 GCP 側
就近讀查詢本身邏輯失效。

## 6. Placement Gate 驗證

`prepare.sh` §6.6 抽樣（僅 warehouse/district/customer 3 表）：

- TiDB：idc=10/19（52%）PASS
- YBDB：idc=2/3（66%）PASS
- CRDB：idc=7/12（58%）PASS

三家皆延續 P-B×A-S 已驗證的雙 policy／雙 tablespace+enforcer／雙
lease_preferences+partition 修復設計，無需針對 A-A-RO 額外調整。**此
gate 僅證明 prepare-time 3 表抽樣通過，不代表 workload 執行期間或全
9 表的分佈情形**（唯一的 post-run 全表證據是 P-B×A-S 的 CRDB 一項，
不外推至本輪，見 `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §5）。

## 7. 已知限制

- **TiDB th=128 吞吐劣化**（§3）目前只是與跨區鎖競爭相容的假說，
  為本輪最重要待跟催項目，建議依 §3「判定」段的控制實驗設計排入
  下一輪驗證。
- 本報告涵蓋 P-B×A-A-RO 單一 workload；P-B×A-A（兩端皆寫，W 全重疊
  max contention）已於 2026-07-31/08-01 完成正式執行（執行前復盤發現
  並修復 `run-vm6-aa.sh` 的 GCP 側 conn-params 對 A-A 場景會誤加
  read-only 設定，見 `SESSION-HISTORY.md` 2026-07-31 節），數字見
  `XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`。
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
