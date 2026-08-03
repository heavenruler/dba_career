# X-CROSS P-B Placement 三 Workload 綜合彙總 — TiDB/YBDB/CRDB W=128 執行矩陣

> **範疇聲明**：本文件屬 `phase-crossregion`（X-CROSS）exploratory
> 測試，`baseline_family=crossregion`、`baseline_eligible=false`（見
> `phase-crossregion/README.md`）。三個 profile **各只有 1 個採用批次
> （N=1）**，且彼此的 transaction mix 與「總 offered concurrency」不同
> （見 §3 M1），因此本文件呈現的是**架構層級觀察**，不是可直接互比
> 的效能排名，**不得納入 S-BASE / S-K8S 正式 baseline 排名**。跨
> profile 的 tpmC 只能作觀察性描述，不能當作 placement 單因子對照。

> 目的：橫向彙總 P-B placement（散置 RF=3 全 voter、leader 跨區混合
> 分佈 30-70%）在 A-S、A-A-RO、A-A 三種 workload 下的 W=128 執行矩陣
> 結果（每個 profile 目前各執行過一次），區分「artifact fact／觀察／
> 推論／尚待驗證」四種語氣，避免把觀察到的相關性誤寫為已證實的因果。
> 三個 profile 已於 2026-07-27~08-01 完成一次執行，個別完整數字見
> §7 對應結案報告連結，本文件不重複列出原始數據，僅做橫向比對。

## 1. 執行矩陣總覽（fact，來源 `summary.json`）

| Workload | TS | TiDB IDC tpmC@128 | YBDB IDC tpmC@128 | CRDB IDC tpmC@128 |
|---|---|---:|---:|---:|
| **A-S**（IDC 單邊發負載，GCP client 不發負載） | `20260727T223650+0800` | 15,107.4 | 2,485.6 | 11,640.0 |
| **A-A-RO**（IDC 讀寫，GCP 唯讀） | `20260730T094406+0800` | 5,699.7 | 11,989.8 | 13,777.1 |
| **A-A**（IDC/GCP 同時讀寫，W 全重疊） | `20260731T204801+0800` | 4,413.9 | 11,605.5 | 9,880.6 |

## 2. 錯誤率（fact，來源各 suite `summary.json` 全檔位加總；C1 修正）

**先前版本「三家錯誤率全 0%」不成立**——只統計了 IDC 側，未檢查
`gcp_side.thread_results.*.error_count`。以下為 IDC／GCP 兩側分開的
全檔位（16/32/64/128 五輪加總）錯誤率：

| Profile | DB | IDC error（count/total） | GCP error（count/total） |
|---|---|---:|---:|
| A-S | TiDB | 0/1,169,077 = 0% | n/a（GCP client 未發負載） |
| A-S | YBDB | 0/180,741 = 0% | n/a |
| A-S | CRDB | 0/888,719 = 0% | n/a |
| A-A-RO | TiDB | 8/833,276 ≈ 0.00096% | 1,190/1,481,960 ≈ 0.0803% |
| A-A-RO | YBDB | 0/690,879 = 0% | 1,185/3,671,772 ≈ 0.03227% |
| A-A-RO | CRDB | 0/874,860 = 0% | 1,150/3,606,553 ≈ 0.03189% |
| A-A | TiDB | 0/654,355 = 0% | 885/561,823 ≈ 0.15752% |
| A-A | YBDB | 0/628,431 = 0% | 799/595,090 ≈ 0.13427% |
| A-A | CRDB | 0/634,863 = 0% | 1,146/1,029,056 ≈ 0.11136% |

**GCP 側錯誤組成**（抽查各 profile 全部 `go-tpc-stdout-gcp.txt` 的
`failed` 訊息分類，非精確逐筆窮舉）：

- 主要（合計 >85%）由 `context deadline exceeded` / `query execution
  canceled`（CRDB 用語）構成——這是每輪（`RUN_SEC`）計時結束時 go-tpc
  對尚在執行中的 worker 發出取消訊號的收尾行為，非交易邏輯錯誤。
- 次要有一批 `sql: connection is already closed`／
  `pq: canceling statement due to user request`，屬連線層錯誤，
  尚未逐筆追查觸發原因（**pending validation**）。
- **CRDB A-A** 額外出現 2 筆 `TransactionRetryError`（`RETRY_ASYNC_WRITE_FAILURE`，
  read-committed retry limit exceeded）——這是交易層的序列化衝突重試
  失敗，數量極少（2/1,029,056），列為觀察，不影響整體判定。
- **TiDB A-A th=128 round-2** 額外出現交易鎖錯誤（見 §3 C2），與上述
  收尾類錯誤性質不同、單獨列出。

即使收尾類錯誤佔多數，**GCP 側錯誤率本身仍是非零**，不可寫成
「全程 0 error」；上表數字才是可追溯的口徑。

## 3. TiDB 高併發吞吐特徵（fact + inference，C2/C3/M1 修正）

### 3.1 Fact：兩個雙側負載批次皆觀察到 IDC tpmC 隨執行緒數增加而下滑，
且伴隨高輪間變異

| Workload | th=16 | th=32 | th=64 | th=128 |
|---|---:|---:|---:|---:|
| A-S（單邊） | 6,642.6 | 10,828.2 | 14,203.0 | **15,107.4**（全程最高） |
| A-A-RO（雙邊） | 6,037.6 | 9,379.1 | 12,205.0 | **5,699.7**（見頂後崩落） |
| A-A（雙邊） | 6,141.3 | **8,868.2**（見頂） | 6,717.9 | 4,413.9 |

- A-A-RO th=128 的 5 輪 tpmC 為 `9003.0, 14948.5, 2113.0, 953.7,
  1480.2`——**前兩輪較高（甚至是全程最高值），第 3-5 輪持續低迷、在
  這 5 輪內未見回升**。先前版本用「崩潰-恢復循環」描述不準確（暗示
  週期性恢復），已更正為上述精確敘述；tpmC 亦更正為實際三位數量級
  （953.7 等），不是「個位數」。
- A-A 未見同等崩落，但 tpmC 自 th=32 見頂後單調下滑，NEW_ORDER p99
  從 th=16 的 313.7ms 升到 th=128 的 5,019.7ms。
- **TiDB A-A th=128 round-2 的 GCP 端 raw stdout 確實包含交易鎖錯誤**：
  `results/x-cross/smoke/early-runs/20260731T204801+0800/tidb-vm-6node-P-B-aa-rc-20260731T204801+0800/runs/threads-128/round-2/go-tpc-stdout-gcp.txt`
  第 26-27 行為 `PessimisticLockNotFound { ..., reason: LockTsMismatch
  }`（先前版本誤寫為「未見同類訊號」）。此為**單一輪次、單一 DB 的
  命中**，可作為「跨區鎖競賽確實會發生」的存在性證據，**不能誇大為
  「已證明其造成全部吞吐劣化」**——只出現這一處，其餘輪次/檔位未見
  同款訊息。

### 3.2 Inference（尚未排除混淆因素）

現象與「跨區 lock resolution／TiKV 資源競爭」相容，但**目前三個
profile 不是單變量對照**，不能推得已排除其他解釋：

- A-S 的 `threads=128` 只有 IDC client 發負載，總 offered
  concurrency = 128。
- A-A-RO／A-A 的 `threads=128` 是 IDC 128 + GCP 128 **同時**發負載，
  總 offered concurrency = 256，且 transaction mix 不同（A-A-RO GCP
  純讀；A-A GCP 標準讀寫）。
- 每個 profile 目前僅 N=1，未做重複批次。

因此**不能**寫成：
- 「排除單純執行緒數過高」
- 「只要 GCP 有流量就一定觸發」
- 「已定位根因為 P-B mixed leader + Percolator 悲觀鎖競賽」
- 「A-A 比 A-A-RO 更容易觸發」

**可保留的說法**：雙側負載的兩個批次都觀察到 TiDB 高併發吞吐劣化與
高輪間變異，raw log 有跨區鎖路徑錯誤的存在性證據；此現象與跨區鎖
解析／TiKV 資源競爭相容，但總 offered concurrency、workload mix、
批次資料狀態、WAN 狀況與節點資源等因素尚未被個別控制，仍是**待驗證
的假說**，非已確認根因。

### 3.3 Pending validation：最小控制實驗建議

1. IDC-only 256 threads 對 dual-side 128+128（固定 mix，僅變動負載
   來源分佈）。
2. IDC-only 128 對 dual-side 64+64（固定總 threads=128，比對是否仍
   有劣化）。
3. 同一批次重建的 cluster、固定 workload mix、GCP client on/off 開關
   對照。
4. TiDB th=64/128 至少 N=3 重跑，同步採集 TiKV txn/lock-resolver
   metrics、PD leader 分佈、WAN 延遲/吞吐、各節點 CPU/I/O，才能區分
   鎖競爭 vs. 資源飽和 vs. 批次雜訊。

## 4. YBDB／CRDB：mean 曲線多數可擴展，但 repeatability 未建立（M2 修正）

**先前版本「YBDB/CRDB 三種 workload 下皆表現穩定」用語過強**，
`tpmC_range_mean_pct =（max-min）/mean`（**非變異係數 CV**，先前文字
混稱已更正）在多個檔位偏高：

| DB | Profile | 高 range/mean 檔位 |
|---|---|---|
| YBDB | A-S | t32=38.7%、t64=28.7%、t128=61.9% |
| YBDB | A-A-RO | t16=43.9%、t32=95.6% |
| YBDB | A-A | t16=61.4%、t32=52.4% |
| CRDB | A-S | t128=25.5% |
| CRDB | A-A-RO | t64=32.8% |
| CRDB | A-A | t32=66.0%、t64=46.0% |

- **修正**：先前版本稱「A-A-RO YBDB mean 有中段波動」與實際 mean
  曲線不符——A-A-RO 的 YBDB mean 為 `2,325.7 → 3,638.5 → 9,785.0 →
  11,989.8`，**單調遞增、無中段 dip**（range/mean 偏高是輪間變異，
  不代表 mean 曲線本身下滑，兩者為不同概念，已分開陳述）。A-S／A-A
  的 YBDB 才有 mean 曲線本身的中段小幅回落（A-S th32→64：
  1,901.8→1,558.8；A-A th16→32：2,287.8→2,150.7），且皆在 th=128
  恢復到全程最高。
- **CRDB** 三個 profile 下 mean 曲線可描述為單調成長（A-S 在
  th=128 已接近打平，+3.7%），但**這只代表 5 輪平均值的趨勢，不能
  據此宣稱「round-level 穩定」**——上表列出的高 range/mean 檔位本身
  就是「該檔位 5 輪間變異大」的直接證據，不可用「正常雜訊」一語帶過；
  目前無法排除是否為系統性現象，列為 pending。

## 5. Placement Gate：只證明 prepare-time 抽樣 PASS（M3 修正）

**先前版本「同一套修復設計...不受 client workload 影響、穩定有效」
的表述過度外推**，實際證據範圍：

| DB | A-S prepare gate | A-A-RO prepare gate | A-A prepare gate | Post-run 全表證據 |
|---|---|---|---|---|
| TiDB | idc=10/19（52%）PASS | idc=10/19（52%）PASS | idc=10/19（52%）PASS | missing / not collected |
| YBDB | idc=1/3（33%）PASS | idc=2/3（66%）PASS | idc=2/3（66%）PASS | missing / not collected |
| CRDB | idc=7/12（58%）PASS | idc=7/12（58%）PASS | idc=7/12（58%）PASS | **僅 A-S 有**：post-run 全 9 表 lease holder 統計 idc=24/gcp=24=50%（`leader-snapshot/crdb-lease-holders.txt`） |

- 上表所有 gate 皆為 `prepare.sh` §6.6 **prepare-time、3 表抽樣**（或
  YBDB 更小的固定樣本）的結果，只能證明「prepare 完成當下抽樣通過
  30-70% 窗口」，**不能證明**：workload 執行期間 leader/lease 分佈
  不會變化、三種 workload 執行後分佈完全一致、或全 9 張表皆符合相同
  比例。
- 唯一的 **post-run、全表**證據只有 A-S 的 CRDB 一項（見上表），
  **不外推至 TiDB／YBDB 或 A-A-RO／A-A**。
- YBDB 的 33%（A-S）與 66%（A-A-RO/A-A）差異：分母僅 3（小樣本
  離散結果，1 個樣本翻轉即造成 33 個百分點差距），兩者都通過
  30-70% gate，但**不代表母體分布相同**，不宜稱為「抽樣雜訊」
  （雜訊隱含隨機且不影響結論，這裡只能說「小分母下的離散結果」）。

## 6. 執行過程的共通挑戰

- **WAN/SSH 間歇性不穩定**：三輪執行過程皆多次遇到 SSH 對 `.31`
  逾時、VPN 斷線（最長一次近 12 小時），driver 本身透過 nohup 真正
  detach 在 `.31` 上執行、不受 Mac 端連線影響，只是期間無法即時
  查看進度。
- **`.suite.done` 缺失是 tooling debt，不是標準做法**：A-A-RO／A-A
  的 driver（GCP 端不經 `tests/common/run.sh`）不會產生
  `.suite.done`，這是 **driver 與既有 marker contract 之間的
  lineage gap**，並非刻意設計的標準流程。目前用
  `check-aaro-artifacts.py` + `phase8.5-fetch`/`phase8.5-check-receipt`
  作為本輪的 workaround（跳過 `phase8.5-static-check`），**不等價於
  完整的 completion marker contract**。後續應讓 profile-aware driver
  補產生完整 marker，或讓 static checker 正式理解雙側 profile，而非
  長期依賴這個 workaround。
- **`phase8.5-fetch` 設計上會整包撈回 `.31` 上累積的全部歷史 suite**
  （非本次 bug），每輪皆需篩出當次目標 suite、其餘 gitignore，已成
  慣例。

## 7. 各 workload 完整分析報告連結

- [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md) — A-S，TS=`20260727T223650+0800`
- [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md) — A-A-RO，TS=`20260730T094406+0800`
- [XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md) — A-A，TS=`20260731T204801+0800`

## 8. 待辦與後續建議

- TiDB 高併發下的吞吐特徵（§3）目前只是**假說**，需依 §3.3 的最小
  控制實驗確認因果後才能寫入正式結論；即使確認，觸發條件也應標注
  清楚（目前只知「雙側負載批次皆觀察到」，其餘變數未控制）。
- P-B 的三種 workload（A-S/A-A-RO/A-A）**執行矩陣已跑過一次**
  （N=1）；重現性與因果仍待控制實驗，**不宜稱為「完整交叉驗證
  基礎」**。
- Placement gate 目前只有 prepare-time 抽樣證據（CRDB A-S 例外，
  有一筆 post-run 全表證據）；若要支撐「P-B 設計在 workload 執行期間
  持續有效」的結論，需要每個 profile/DB 補齊 post-run 全表快照。
- P-B×backup／migration／chaos 仍是 spec-only，未排程。

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-27 至 08-01 各節（含本次
2026-08-03 的事實修正記錄）。
