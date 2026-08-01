# X-CROSS P-B×A-A 結案報告（雛形）— IDC↔GCP Cross-Region 3-DB W=128 P-B Placement 正式測試

> 目的：驗證 TiDB/YBDB/CRDB 三家 DB 在 6-node cross-region 拓樸下、**P-B
> placement**（散置 RF=3 全 voter、leader 跨區混合分佈 30-70%）於
> A-A（IDC 與 GCP 兩端同時跑標準讀寫 mix、W 全範圍重疊，per
> `workload-profiles/A-A.md` Q5 拍板的 max contention 設計）profile 的
> 正式 W=128 效能基準。TS=`20260731T204801+0800`，執行順序
> TiDB→YBDB→CRDB，三家皆 PASS 並已歸檔，VM 已 destroy。

## 1. 執行摘要

| DB | IDC tpmC@128 | GCP tpmC@128 | 錯誤率 | Placement gate |
|---|---:|---:|---:|---|
| **TiDB** | 4,413.9（⚠ 見 §3 高併發劣化） | 2,966.6 | 0% | idc=10/19（52%）PASS |
| **YBDB** | 11,605.5 | 3,379.9 | 0% | idc=2/3（66%）PASS |
| **CRDB** | 9,880.6 | 5,704.9 | 0% | idc=7/12（58%）PASS |

三家全程 **0 error**（16/32/64/128 四檔位、每檔 5 輪皆無交易錯誤）。P-B
placement gate 三家皆落在 30-70% 窗口內通過。**TiDB 在高併發（th=64/128）
出現明顯吞吐劣化**（tpmC 隨執行緒數增加反而下降），YBDB／CRDB 皆正常
擴展（tpmC 隨併發數增加）——本輪最重要發現，詳見 §3。

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

**與 P-B×A-A-RO 的 th=128 崩潰相比**：本輪 TiDB 錯誤率仍是 0%（未見
`TxnLockNotFound` 之類的重試風暴訊號），是「持續劣化」而非「崩潰後
恢復」的形態——判斷是同一根因（P-B 跨區混合 leader + TiDB percolator
兩階段悲觀鎖）在 **A-A 場景下更容易長期發生**，因為 A-A 的 IDC/GCP
兩端寫入同一組 warehouse 範圍（Q5 max contention 設計），跨區鎖競爭
的觸發頻率天生比 A-A-RO（GCP 端唯讀，不寫）高得多。

### YBDB／CRDB 對照

| 執行緒 | YBDB IDC tpmC | CRDB IDC tpmC |
|---:|---:|---:|
| 16 | 2,287.8 | 3,966.7 |
| 32 | 2,150.7（小幅回落） | 4,897.3 |
| 64 | 9,135.8 | 6,593.8 |
| 128 | 11,605.5 | 9,880.6 |

兩家皆隨執行緒數增加而**正常擴展**（YBDB 僅 th=32 有小幅回落，之後
強勢回升；CRDB 全程單調遞增），未見 TiDB 這種持續性劣化。與
`XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md` §3 的判斷一致：**TiDB
percolator 式兩階段悲觀鎖在 P-B 跨區混合 leader 下對高併發特別敏感，
YBDB（tablet leader）／CRDB（per-range lease）的併發控制機制較不受
影響**。

### 判定

**P-B 對 TiDB 在高併發檔位存在真實的效能限制，且 A-A（雙寫滿載）比
A-A-RO（單邊唯讀）更容易觸發**——這是兩輪 W=128 正式測試一致收斂的
結論，建議正式評估報告明確標注此限制，並列為後續 TiDB 專項調校
（`tidb_lock_ttl`、悲觀鎖重試策略）的優先項。

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
側劣化同步發生，佐證 §3 的跨區鎖競爭判定（雙端互相阻塞，非單側問題）。

## 6. Placement Gate 驗證

`prepare.sh` §6.6 抽樣（僅 warehouse/district/customer 3 表）：

- TiDB：idc=10/19（52%）PASS
- YBDB：idc=2/3（66%）PASS
- CRDB：idc=7/12（58%）PASS

與 P-B×A-S、P-B×A-A-RO 兩輪數字一致，確認 P-B 修復設計（雙 policy／雙
tablespace+enforcer／雙 lease_preferences+partition）在 A-A profile 下
同樣有效，不受 workload 類型影響。

## 7. 已知限制

- **TiDB 高併發劣化**（§3）為本輪最重要待跟催項目，與 A-A-RO 輪的
  th=128 崩潰同根因，建議排入 TiDB 專項調校（悲觀鎖重試策略、
  `tidb_lock_ttl`）。
- 本次 W=128 P-B×A-A 執行前歷經多次波折：首發撞上 WAN 專線壅塞
  （iperf3 量到 178Mbps vs 基準 ~300Mbps）中止重來；YBDB deploy 撞上
  VM 預設 `/usr/bin/python3` 指向 3.6（`yugabyted` 需要 3.7+ 的
  `dataclasses`），已透過 `alternatives --set python3 python3.12`
  修復；過程中多次 SSH/VPN 間歇性中斷，皆判斷為連線層問題、driver
  本身未受影響。完整過程見 `SESSION-HISTORY.md` 2026-07-31/08-01 節。
- 三家 W=128 P-B 三種 workload（A-S、A-A-RO、A-A）至此全數完成，P-B
  placement 對三家資料庫的行為特徵已有完整交叉驗證基礎。

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
