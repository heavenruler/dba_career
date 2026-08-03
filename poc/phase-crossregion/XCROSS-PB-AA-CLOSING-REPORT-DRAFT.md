# X-CROSS P-B×A-A 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 P-B Placement Phase-Adopted 探索性測試

> **Scope**：`X-CROSS`，`baseline_family=crossregion`，
> `baseline_eligible=false`，本 profile `N=1`。本報告是**本 phase 的
> 採用批次**，不是可直接對外排名的 S-BASE/S-K8S 正式 baseline，見
> `phase-crossregion/README.md`。
>
> 目的：驗證 TiDB/YBDB/CRDB 三家 DB 在 6-node cross-region 拓樸下、**P-B
> placement**（散置 RF=3 全 voter、leader 跨區混合分佈 30-70%）於
> A-A（IDC 與 GCP 兩端同時跑標準讀寫 mix、W 全範圍重疊，per
> `workload-profiles/A-A.md` Q5 拍板的 max contention 設計）profile 的
> W=128 phase-adopted 執行結果。TS=`20260731T204801+0800`，執行順序
> TiDB→YBDB→CRDB，三家皆 PASS 並已歸檔，VM 已 destroy。

## 1. 執行摘要

| DB | IDC tpmC@128 | GCP tpmC@128 | IDC all_txn 錯誤率 | GCP all_txn 錯誤率 | Placement gate |
|---|---:|---:|---:|---:|---|
| **TiDB** | 4,413.9（⚠ 見 §3 高併發劣化） | 2,966.6 | 0/1,455,353=0% | 885/561,823≈0.157275% | idc=10/19（52%）PASS |
| **YBDB** | 11,605.5 | 3,379.9 | 0/1,396,294=0% | 799/595,090≈0.134085% | idc=2/3（66%）PASS |
| **CRDB** | 9,880.6 | 5,704.9 | 0/1,410,538=0% | 1,146/1,029,056≈0.111240% | idc=7/12（58%）PASS |

**錯誤率修正（2026-08-03 Round 2）**：先前版本（含 Round 1 修正）寫
「三家全程 0 error」不成立，只檢查了 IDC 側；Round 1 已補上 GCP 側，
但**未明示 IDC 側 0% 是否為 all_txn 口徑**——本 profile 的 IDC 側
`all_txn.error_count` 三家確實皆為 0（與 NEW_ORDER-only 結果一致，
因分子本身是 0），已在上表明示分母為 all_txn 加總（1,455,353／
1,396,294／1,410,538）以利追溯，不再用模糊的 `count/total`。**GCP
側錯誤率三家皆非零**（885/561,823、799/595,090、1,146/1,029,056，
五種 transaction 加總，口徑見 `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md`
§2），最常見的是 `context deadline exceeded`（round 收尾取消，抽查
非精確計數），CRDB 另有 2 個 distinct `TransactionRetryError` 序列化
重試失敗事件（raw log 各印兩次、非 4 筆獨立事件）。P-B placement
gate 三家皆落在 30-70% 窗口內通過（僅代表 prepare-time 的實際有限
樣本通過，非全 9 表全程 ground truth，見 §6）。**TiDB 在高併發
（th=64/128）出現明顯吞吐劣化**（tpmC 隨執行緒數增加反而下降），
YBDB／CRDB mean 曲線隨併發數增加而成長——現象觀察詳見 §3，因果尚待
驗證。

**採用 suite source**：[TiDB summary.json](../results/x-cross/smoke/early-runs/20260731T204801+0800/tidb-vm-6node-P-B-aa-rc-20260731T204801+0800/summary.json) ／
[YBDB summary.json](../results/x-cross/smoke/early-runs/20260731T204801+0800/ybdb-vm-6node-P-B-aa-rc-20260731T204801+0800/summary.json) ／
[CRDB summary.json](../results/x-cross/smoke/early-runs/20260731T204801+0800/crdb-vm-6node-P-B-aa-rc-20260731T204801+0800/summary.json)。

## 2. 測試目的與範圍

- 驗證 P-B×A-A（IDC 與 GCP 同時跑標準 TPCC 讀寫、W=1-128 全範圍重疊，
  刻意製造最大跨區 key 衝突）在正式 W=128 規模下，P-B 跨區混合 leader
  分佈是否仍能運作，並觀察跨區寫入衝突對各家 DB 的實際影響。
- Profile：A-A，IDC 與 GCP 兩端皆 warehouses=128 標準 mix，同一批
  warehouse 範圍兩端同時打（per Q5，非 P-B×A-S/A-A-RO 那種切分或
  唯讀設計）。執行緒檔位 16/32/64/128，各檔位 5 輪。

## 3. TiDB 高併發吞吐劣化（本輪最重要發現）

### 現象

| 執行緒 | IDC tpmC | NEW_ORDER p50/p95/p99 (ms) | tpmC_range_mean_pct |
|---:|---:|---|---:|
| 16 | 6,141.3 | 92.3 / 174.5 / 313.7 | 14.0% |
| 32 | 8,868.2 | 125.0 / 335.5 / 516.7 | 38.5% |
| **64** | **6,717.9** | 402.7 / 1,362.3 / 2,006.6 | 107.7% |
| **128** | **4,413.9** | 1,436.2 / 3,355.5 / 5,019.7 | 103.5% |

tpmC 在 th=32 見頂（8,868.2）後於 th=64/128 反而下滑，NEW_ORDER p99
從 th=16 的 313.7ms 一路衝到 th=128 的 5,019.7ms（16 倍），
`tpmC_range_mean_pct` 在 th=64/128 皆超過 100%（5 輪間變異度極大）。

**修正（2026-08-03）**：先前版本寫「本輪 TiDB 錯誤率仍是 0%（未見
`TxnLockNotFound` 之類的重試風暴訊號）」與 raw artifact 矛盾——
[`runs/threads-128/round-2/go-tpc-stdout-gcp.txt`](../results/x-cross/smoke/early-runs/20260731T204801+0800/tidb-vm-6node-P-B-aa-rc-20260731T204801+0800/runs/threads-128/round-2/go-tpc-stdout-gcp.txt)
第 26-27 行確實包含
`PessimisticLockNotFound { ..., reason: LockTsMismatch }`，是與
A-A-RO 那次 `TxnLockNotFound` 同性質的鎖解析錯誤訊號。此為**單一輪次
的單一命中**（僅此檔案出現，其餘輪次/檔位未見同款訊息），可作為
「跨區鎖競爭確實會發生」的存在性證據，**但不能據此宣稱已證明其造成
整體吞吐劣化**，也不能倒推「A-A 比 A-A-RO 更容易觸發」——兩個 profile
各只有 N=1，總 offered concurrency 與 workload mix 皆不同，尚未做過
控制對照，無法排序何者「更容易觸發」。與 A-A-RO 的差異僅能客觀描述
為：A-A-RO 該檔位是「崩潰後未在 5 輪內恢復」，A-A 是「持續性緩慢
劣化」，兩者現象型態不同，但何者反映更嚴重的根因尚待驗證。

### YBDB／CRDB 對照

| 執行緒 | YBDB IDC tpmC | CRDB IDC tpmC |
|---:|---:|---:|
| 16 | 2,287.8 | 3,966.7 |
| 32 | 2,150.7（小幅回落） | 4,897.3 |
| 64 | 9,135.8 | 6,593.8 |
| 128 | 11,605.5 | 9,880.6 |

兩家 mean tpmC 皆隨執行緒數增加而成長（YBDB th=32 有小幅回落後在
th=64/128 回升；CRDB 單調遞增），未見 TiDB 這種持續性劣化。
`tpmC_range_mean_pct` 在 th=32/64 仍偏高（YBDB 66.0%／46.0%，見
`XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §4），mean 曲線可擴展不代表
round-level 已證明穩定。

### 判定（fact + inference，2026-08-03 依 raw artifact 覆核後降級為假說）

**Fact**：兩個雙側負載批次（A-A-RO、A-A）都觀察到 TiDB 在高併發檔位
的吞吐劣化與高輪間變異，且 raw log 皆有跨區鎖路徑錯誤的存在性證據
（`TxnLockNotFound`／`PessimisticLockNotFound`）。**Inference**：現象
與「P-B 跨區混合 leader 下的悲觀鎖競爭」相容，但兩個 profile 各僅
N=1、總 offered concurrency 與 mix 不同，尚未排除總執行緒數、批次
雜訊等混淆因素，**不可寫成已確認根因，也不可排序哪個 profile
「更容易觸發」**。建議正式評估報告依
`XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §3.3 的控制實驗設計驗證因果後，
再列為 TiDB 專項調校（悲觀鎖 TTL 相關設定、重試策略）的優先項。
  **修正**：先前版本寫 `tidb_lock_ttl` 為已知調校參數，經查證非真實
  TiDB 系統變數，實際是設定檔 `performance.max-txn-ttl`（見
  `XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md` §3 根因調查第 2 點），
  調校前應以官方文件與 `SHOW VARIABLES`/設定檔核對本版本是否適用。

## 4. IDC 側完整結果

### TiDB

| 執行緒 | tpmC | tpmTotal | 效率% | 錯誤率 |
|---:|---:|---:|---:|---:|
| 16 | 6,141.3 | 13,685.7 | 373.1 | 0% |
| 32 | 8,868.2 | 19,704.1 | 538.7 | 0% |
| 64 | 6,717.9 | 14,949.0 | 408.1 | 0% |
| 128 | 4,413.9 | 9,789.6 | 268.1 | 0% |

### YBDB

| 執行緒 | tpmC | tpmTotal | 效率% | 錯誤率 |
|---:|---:|---:|---:|---:|
| 16 | 2,287.8 | 5,086.0 | 139.0 | 0% |
| 32 | 2,150.7 | 4,807.8 | 130.7 | 0% |
| 64 | 9,135.8 | 20,306.6 | 555.0 | 0% |
| 128 | 11,605.5 | 25,726.3 | 705.0 | 0% |

### CRDB

| 執行緒 | tpmC | tpmTotal | 效率% | 錯誤率 |
|---:|---:|---:|---:|---:|
| 16 | 3,966.7 | 8,819.1 | 241.0 | 0% |
| 32 | 4,897.3 | 10,859.2 | 297.5 | 0% |
| 64 | 6,593.8 | 14,679.5 | 400.6 | 0% |
| 128 | 9,880.6 | 21,931.0 | 600.2 | 0% |

## 5. GCP 側完整結果（A-A 下兩端皆標準 mix，`tpmC` 為真實值非 null）

| 執行緒 | TiDB tpmC | YBDB tpmC | CRDB tpmC |
|---:|---:|---:|---:|
| 16 | 1,600.2 | 1,853.6 | 2,333.9 |
| 32 | 2,619.3 | 2,806.8 | 4,845.1 |
| 64 | 2,978.3 | 2,806.2 | 5,677.3 |
| 128 | 2,966.6 | 3,379.9 | 5,704.9 |

GCP 側 TiDB 同樣在 th=64→128 出現吞吐停滯（2,978.3→2,966.6，幾乎打平）
且 NEW_ORDER p99 從 th=16 的 677.8ms 衝到 th=128 的 5,717.6ms，與 IDC
側劣化同步發生，現象上與「雙端互相阻塞」相容，但如 §3 所述尚未經
控制實驗確認因果。

**GCP 側全檔位錯誤率**（口徑見 §1／`XCROSS-PB-ALL-WORKLOADS-SUMMARY.md`
§2）：TiDB≈0.158%、YBDB≈0.134%、CRDB≈0.111%，皆非 0，主要由
`context deadline exceeded`／`query execution canceled`（round 收尾
取消）構成；CRDB 另有 2 筆 `TransactionRetryError`（read-committed
retry limit exceeded）序列化重試失敗，數量極少但屬交易層錯誤，非
收尾類。

## 6. Placement Gate 驗證

`prepare.sh` §6.6 抽樣（僅 warehouse/district/customer 3 表）：

- TiDB：idc=10/19（52%）PASS
- YBDB：idc=2/3（66%）PASS
- CRDB：idc=7/12（58%）PASS

與 P-B×A-S、P-B×A-A-RO 兩輪數字一致，顯示同一套 P-B 修復設計（雙
policy／雙 tablespace+enforcer／雙 lease_preferences+partition）在
三個 profile 的 **prepare-time 抽樣**下皆通過 gate。此僅證明 prepare
完成當下抽樣通過 30-70% 窗口，不代表 workload 執行期間或全 9 表分佈
情形（唯一的 post-run 全表證據是 P-B×A-S 的 CRDB 一項，不外推至
本輪，見 `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md` §5）。

## 7. 已知限制

- **TiDB 高併發劣化**（§3）為本輪最重要待跟催項目，現象與 A-A-RO 輪
  的 th=128 崩潰相容於同一假說（跨區鎖競爭），但兩者根因是否相同
  尚未經控制實驗確認，建議排入 §3 所述控制實驗，再排 TiDB 專項調校
  （悲觀鎖重試策略、`performance.max-txn-ttl`——非 `tidb_lock_ttl`，
  詳見 §3 修正）。
- 本次 W=128 P-B×A-A 執行前歷經多次波折：首發撞上 WAN 專線壅塞
  （iperf3 量到 178Mbps vs 基準 ~300Mbps）中止重來；YBDB deploy 撞上
  VM 預設 `/usr/bin/python3` 指向 3.6（`yugabyted` 需要 3.7+ 的
  `dataclasses`），已透過 `alternatives --set python3 python3.12`
  修復；過程中多次 SSH/VPN 間歇性中斷，皆判斷為連線層問題、driver
  本身未受影響。完整過程見 `SESSION-HISTORY.md` 2026-07-31/08-01 節。
- 三家 W=128 P-B 三種 workload（A-S、A-A-RO、A-A）**執行矩陣已跑過
  一次**（各 N=1）；重現性與因果仍待 §3 所述控制實驗，橫向彙總與
  caveat 見 `XCROSS-PB-ALL-WORKLOADS-SUMMARY.md`。

## 8. Artifact 路徑

```
results/x-cross/smoke/early-runs/20260731T204801+0800/tidb-vm-6node-P-B-aa-rc-20260731T204801+0800/
results/x-cross/smoke/early-runs/20260731T204801+0800/ybdb-vm-6node-P-B-aa-rc-20260731T204801+0800/
results/x-cross/smoke/early-runs/20260731T204801+0800/crdb-vm-6node-P-B-aa-rc-20260731T204801+0800/
```

各 DB suite 目錄下 `summary.json` 為機器可讀彙整來源（含 `gcp_side`
真實 tpmC 值、`region_routing_evidence.placement_gate`）；三個 DB suite
原始 artifact 依既有慣例 gitignore。VM 已於採證後 `terraform destroy`，
兩側 state 歸零。

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-31/08-01 節。
