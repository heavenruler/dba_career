# X-CROSS P-A vs P-B 最終比較報告

> **Scope**：`X-CROSS`，`baseline_family=crossregion`，`baseline_eligible=false`。
> 本報告內所有數字皆為探索性 PoC 觀察，每個 placement×workload×DB cell 僅
> `N=1`，**不構成 S-BASE 正式跨家排名，也不構成已驗證的 placement 因果效應**。
> 兩個 placement 的採用批次分屬不同日期（見 §1），**非同批同時執行**，故本報告
> 的跨 placement 比較是觀察性對照，不是嚴格的 paired control 實驗。
>
> **口徑**：tpmC/read_tpmTotal 為 R1-R5 五輪算術平均；延遲為 p50/p95/p99 五輪
> 平均；錯誤率 = `error_count / (total_count + error_count)`，IDC/GCP 分開列（不
> 合併口徑）。所有數字可回溯至對應 `summary.json` 或 raw `go-tpc-stdout*.txt`，
> 逐項連結見 §9。

## 0. 本報告與既有文件的關係

- [`P-A-vs-P-B-explainer.md`](./P-A-vs-P-B-explainer.md) 是**動工前**的概念對齊
  文件，其 §1/§2/§4/§5（一句話差異、Raft 圖解、決策樹、application owner
  問題）屬架構說明，本報告不重寫。
- 該文件 §3「量化對比」明確標示「上表為 PoC sweep 啟動前預估值；實測數字需
  sweep 完成才能確認，目前**沒有實測 PoC 數據**」。P-A、P-B 三個 workload
  （A-S、A-A-RO、A-A）皆已完成至少一次 W=128 正式執行，本報告用實測數字取代
  該預估表，並在 §7 逐項對照預測與實測的落差。
- 本報告是彙整層級文件，逐項細節仍以各自結案報告為準（§9）。

## 1. 覆蓋範圍與缺口（fact）

| Placement | Workload | 狀態 | 採用批次 | 結案報告 |
|---|---|---|---|---|
| P-A | A-S | ✅ | `20260717T143238+0800` | [XCROSS-CLOSING-REPORT-DRAFT.md](./XCROSS-CLOSING-REPORT-DRAFT.md) |
| P-A | A-A-RO（修正後） | ✅ | `20260723T133843+0800` | [XCROSS-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-AARO-CLOSING-REPORT-DRAFT.md) |
| P-A | A-A | ⚪ 未執行 | — | — |
| P-B | A-S | ✅ | `20260727T223650+0800` | [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md) |
| P-B | A-A-RO | ✅ | `20260730T094406+0800` | [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md) |
| P-B | A-A | ✅ | `20260731T204801+0800` | [XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md) |

**最大缺口**：P-A×A-A 從未執行，因此「兩端同時寫」情境完全沒有 P-A 對照組
（見 §4）。A-S、A-A-RO 兩個 profile 有雙 placement 數據，是本報告唯一能做
跨 placement 對照的範圍（§2、§3）。

## 2. A-S 對照（IDC-only，兩邊 total offered concurrency 相同）

A-S 兩個 placement 皆為 IDC client 128 threads、GCP client 不發負載，是本次
唯一「workload 定義完全相同、只有 placement 不同」的對照軸。

### 2.1 IDC 側 tpmC（fact）

| threads | TiDB P-A | TiDB P-B | Δ | YBDB P-A | YBDB P-B | Δ | CRDB P-A | CRDB P-B | Δ |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 1,584.4 | 6,642.6 | +319.2% | 6,856.0 | 1,297.2 | −81.1% | 9,573.6 | 4,494.1 | −53.1% |
| 32 | 3,614.3 | 10,828.2 | +199.6% | 9,317.0 | 1,901.8 | −79.6% | 10,515.9 | 8,109.7 | −22.9% |
| 64 | 7,176.1 | 14,203.0 | +97.9% | 10,201.9 | 1,558.8 | −84.7% | 11,075.8 | 11,227.6 | +1.4% |
| **128** | **12,526.5** | **15,107.4** | **+20.6%** | **12,769.5** | **2,485.6** | **−80.5%** | **10,163.4** | **11,640.0** | **+14.5%** |

### 2.2 NEW_ORDER p99@128（fact，ms）

| DB | P-A | P-B | Δ |
|---|---:|---:|---:|
| TiDB | 677.8 | 664.4 | −2.0% |
| YBDB | 758.3 | 6,227.7 | +721.3% |
| CRDB | 1,020.1 | 1,301.9 | +27.6% |

### 2.3 錯誤率（fact）

| DB | P-A IDC | P-A GCP | P-B IDC | P-B GCP |
|---|---|---|---|---|
| TiDB | 0% | n/a（無 GCP workload） | 0% | n/a |
| YBDB | 156/2,167,489 ≈ 0.0072%（既有跨 WAN 協調錯誤，見 [XCROSS-CLOSING-REPORT-DRAFT.md §6.3](./XCROSS-CLOSING-REPORT-DRAFT.md)） | n/a | 0/180,741 = 0% | n/a |
| CRDB | 0% | n/a | 0/888,719 = 0% | n/a |

### 2.4 Placement gate（fact）

- P-A：設計上 leader/lease 100% 固定 IDC（三家皆 idc=100%，屬 by-design，非
  抽樣結果）。
- P-B：`prepare.sh` §6.6 抽樣 3 表落在 30-70% 窗口內通過——TiDB idc=10/19
  (52%)、YBDB idc=1/3 (33%)、CRDB idc=7/12 (58%)。**此為兩個 placement 的
  定義性差異，不是需要控制的混淆變數。**

### 2.5 判讀

- **fact**：TiDB、CRDB 在 A-S 全部 4 個 threads 檔位，P-B tpmC 皆 ≥ P-A（多數
  檔位明顯更高）；只有 YBDB 在全部檔位大幅低於 P-A（−80% 上下）。
- **inference（非已確認）**：這與 [`P-A-vs-P-B-explainer.md`](./P-A-vs-P-B-explainer.md)
  §3 預測的「P-B tpmC 全面顯著低於 P-A（低 40-50%）」方向相反——僅 YBDB 符合
  預測方向，且降幅遠超預測（−80% vs 預測 −40~50%），TiDB/CRDB 完全不符合。
  YBDB 的劣化在 [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md)
  中已判斷「與既有 GCP 側吞吐調查（pd-standard 磁碟 I/O 瓶頸）方向一致，非
  本輪新增問題」，但該推論本身也未經拿掉磁碟因素的獨立對照實驗證實，仍是
  假說。
- **不可下的結論**：不可用上表宣稱「P-B 對 TiDB/CRDB 比 P-A 更好」——兩批
  分屬不同日期（07-17 vs 07-27）、非同批同時執行、各僅 `N=1`，環境漂移、
  WAN 狀況等混淆因素未排除。

## 3. A-A-RO 對照（IDC 128 + GCP 唯讀 128，兩邊 workload 定義相同）

### 3.1 IDC 側 tpmC（fact，標準 TPCC mix）

| threads | TiDB P-A | TiDB P-B | Δ | YBDB P-A | YBDB P-B | Δ | CRDB P-A | CRDB P-B | Δ |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 16 | 1,865.7 | 6,037.6 | +223.6% | 4,930.5 | 2,325.7 | −52.8% | 9,765.9 | 3,898.8 | −60.1% |
| 32 | 3,401.9 | 9,379.1 | +175.7% | 5,945.4 | 3,638.5 | −38.8% | 11,386.1 | 5,986.1 | −47.4% |
| 64 | 6,396.2 | 12,205.0 | +90.8% | 7,844.3 | 9,785.0 | +24.7% | 11,538.6 | 11,294.9 | −2.1% |
| **128** | **11,680.0** | **5,699.7** | **−51.2%** | **10,661.5** | **11,989.8** | **+12.5%** | **10,694.1** | **13,777.1** | **+28.8%** |

### 3.2 GCP 側 read_tpmTotal（fact，唯讀 mix）

| threads | TiDB P-A | TiDB P-B | YBDB P-A | YBDB P-B | CRDB P-A | CRDB P-B |
|---:|---:|---:|---:|---:|---:|---:|
| 16 | 10,493.0 | 8,369.5 | 9,887.5 | 31,239.9 | 34,298.8 | 25,794.1 |
| 32 | 15,242.7 | 14,312.7 | 22,404.1 | 35,182.5 | 41,736.3 | 41,108.0 |
| 64 | 13,867.6 | 13,632.8 | 15,019.6 | 40,402.4 | 40,894.2 | 39,330.5 |
| **128** | **16,511.4** | **23,120.0** | **12,817.2** | **42,116.4** | **40,328.9** | **38,194.9** |

### 3.3 錯誤率（fact）

| DB | P-A IDC | P-A GCP | P-B IDC | P-B GCP |
|---|---|---|---|---|
| TiDB | 3/1,300,573 ≈ 0.00023% | 1,186/1,399,965 ≈ 0.0847% | 8/833,276 ≈ 0.00096% | ≈0.0803% |
| YBDB | 5/1,625,299 ≈ 0.0003% | 1,194/1,503,732 ≈ 0.0794% | 0/690,879 = 0% | ≈0.03227% |
| CRDB | 0/2,410,368 = 0% | 1,111/3,927,268 ≈ 0.0283% | 0/874,860 = 0% | ≈0.03189% |

### 3.4 判讀

- **fact**：TiDB th=16/32/64 三個檔位 P-B tpmC 皆遠高於 P-A（+91% 到 +224%）；
  但 th=128 反轉——P-A 持續正常擴展至 11,680.0，P-B 崩潰至 5,699.7（見
  [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md §3](./XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md)，
  該檔位 5 輪為 `[9003.0, 14948.5, 2113.0, 953.7, 1480.2]`，前兩輪正常、
  R3-R5 持續低迷未在該 5 輪內恢復）。
- **fact**：YBDB、CRDB 在 th=16/32 反而是 P-A 較高、P-B 較低；th=64/128 轉為
  P-B 略高於 P-A。呈非單調、非一致方向的型態，**不支持任何簡單的「P-B 全面
  優於／劣於 P-A」敘述**。
- **fact**：這是本報告中唯一「同 workload 定義、同 total threads 配置、僅
  placement 不同」且 th=128 出現明顯反轉的對照——比同一 placement 內跨
  workload 比較（A-S vs A-A-RO，見 [P-B 三 workload 彙整 §3.2 混淆因素](./XCROSS-PB-ALL-WORKLOADS-SUMMARY.md)）
  乾淨，但仍非同批同時執行的 paired control。
- **inference（非已確認）**：TiDB th=128 在 P-B 兩個 profile（A-A-RO、A-A，
  見 §4）皆出現崩潰或劣化，P-A 的 A-S、A-A-RO 在 th=128 皆未出現同現象，
  與「P-B 跨區混合 leader 使 Percolator 兩階段悲觀鎖在高併發下鎖競爭加劇」
  假說相容。但每個 cell 僅 `N=1`、兩 placement 非同批執行，**不可**推論為
  已證明的 placement 因果效應；YBDB/CRDB 未見同等現象，可能反映不同鎖協定
  對跨區 leader 混合的耐受度較高，但同樣未經控制實驗證實。待驗證的最小控制
  實驗清單見 [XCROSS-PB-ALL-WORKLOADS-SUMMARY.md §3.3](./XCROSS-PB-ALL-WORKLOADS-SUMMARY.md)。

## 4. A-A — 僅 P-B 有資料，缺 P-A 對照（fact + 明確缺口）

P-A×A-A 從未執行，故本節**無法做跨 placement 比較**，只能陳述 P-B 側已測數字：

| threads | TiDB IDC | YBDB IDC | CRDB IDC | TiDB GCP | YBDB GCP | CRDB GCP |
|---:|---:|---:|---:|---:|---:|---:|
| 16 | 6,141.3 | 2,287.8 | 3,966.7 | 1,600.2 | 1,853.6 | 2,333.9 |
| 32 | 8,868.2 | 2,150.7 | 4,897.3 | 2,619.3 | 2,806.8 | 4,845.1 |
| 64 | 6,717.9 | 9,135.8 | 6,593.8 | 2,978.3 | 2,806.2 | 5,677.3 |
| 128 | 4,413.9 | 11,605.5 | 9,880.6 | 2,966.6 | 3,379.9 | 5,704.9 |

錯誤率：IDC 三家皆 0%；GCP 側 TiDB≈0.158%／YBDB≈0.134%／CRDB≈0.111%（詳見
[XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)）。
TiDB th=32 見頂（8,868.2）後於 th=64/128 反而下滑，型態與 A-A-RO 的 th=128
崩潰相容於同一假說，但兩者根因是否相同尚未經控制實驗確認（§3.4）。

**明確缺口**：沒有 P-A×A-A 數據，無法回答「兩端同時寫」情境下 P-A 是否也會
劣化、或 P-B 的劣化幅度相對 P-A 有多大。這是本報告目前最大的單一證據缺口。

## 5. 綜合觀察與待驗證假說

**可下的 fact**：

- 除 TiDB th=128 在 A-A-RO／A-A 的劣化外，本次已測的 A-S、A-A-RO 大多數
  cell（尤其低併發檔位）P-B tpmC **不低於**甚至高於 P-A，與 pre-sweep 「P-B
  全面顯著低於 P-A」的預測方向不符。
- TiDB 高併發（th=128）劣化只在 P-B 的兩個 profile（A-A-RO、A-A）觀察到；
  P-A 的 A-S、A-A-RO 在同一 th=128 檔位都持續正常擴展、未崩潰——這是本報告
  中與「P-B 對 TiDB 有額外代價」方向最一致的訊號。
- YBDB 在 A-S 呈現的大幅劣化（−80.5%）與 CRDB/TiDB 在同一 profile 的表現
  方向相反，顯示「P-B 對三家一致造成劣化」不成立，劣化程度高度 DB-specific。

**不可下的結論（inference 上限）**：

- 不可宣稱「P-B 已證明比 P-A 對 TiDB 造成額外效能限制」——僅 `N=1`、非同批
  paired control，無法排除環境漂移、WAN 狀況等混淆。
- 不可宣稱「YBDB/CRDB 在 P-B 下完全不受影響」——A-S 的 YBDB 劣化幅度極大，
  只是方向與 TiDB 不同、且有既有磁碟瓶頸的替代解釋（同樣未證實）。
- 不可用 A-A-RO 的 th=128 反轉去外推 A-S 或其他檔位的 placement 效應，反之
  亦然——本節數據本身就呈現非單調、跨 profile 不一致的型態。

**待驗證**（優先序）：

1. 同批同時執行 P-A vs P-B（同 workload、同 threads、同一天），移除跨批
   環境漂移混淆。
2. IDC-only 固定 threads baseline，與 P-A、P-B 三方對照（見
   [XCROSS-PB-ALL-WORKLOADS-SUMMARY.md §3.3](./XCROSS-PB-ALL-WORKLOADS-SUMMARY.md)
   已列出的控制實驗設計）。
3. TiDB th=128 崩潰窗口內的 TiKV lock wait／resolve latency／PD schedule
   指標採樣，而非僅靠 tpmC 曲線推論。
4. N≥3 重複，量化 range/mean 或標準差意義下的變異度，而非單次觀察。
5. 補跑 P-A×A-A，填補 §4 的缺口。

## 6. 決策意涵（謹慎用語）

- **若優先考量 TiDB 高併發下的吞吐穩定性**：目前資料顯示 P-A 的 A-S、
  A-A-RO 在 th=128 皆未重現 P-B 觀察到的崩潰／劣化；但這只是 `N=1` 觀察
  相關，非已證明的 placement 因果差異，正式決策前應完成 §5 的控制實驗。
- **若優先考量地理 DR（IDC 整體故障秒級接手）**：P-B 的結構性優勢（leader
  已分布兩地、故障不需跨區重選 leader）目前僅為
  [`P-A-vs-P-B-explainer.md`](./P-A-vs-P-B-explainer.md) §1/§2 的架構推論，
  本 PoC 的 chaos／failover 測試尚未執行（`MILESTONES.md` 待排程），此優勢
  **尚未經實測 RTO/RPO 驗證**——不可直接引用 explainer 的預估 RTO 數字
  （~5-10 秒）作為已驗證結論。
- **若兩端都需要寫**：只有 P-B 有 A-A 實測資料（§4），P-A 完全沒有對照，
  無法比較兩者在此情境下的相對代價。
- YBDB／CRDB 在已測 profile 下都沒有出現 TiDB 級別的 th=128 崩潰，但證據
  仍為 `N=1`、非重複驗證，不足以作為「兩家對 P-B 更耐受」的定案結論。

## 7. 與 pre-sweep 預測（`P-A-vs-P-B-explainer.md` §3）對照

| 指標 | 預測 | 實測（本報告） | 判讀 |
|---|---|---|---|
| TiDB tpmC，P-B vs P-A | 全面低 40-50% | A-S 全檔位 +20~319% 更高；A-A-RO th16-64 +91~224% 更高，僅 th128 −51.2%；A-A 無 P-A 對照 | 預測方向與實測大致相反；唯一方向相符的點（A-A-RO th128）幅度雖接近預測，但成因是單一檔位持續劣化事件，非全檔位一致的縮放代價 |
| NEW_ORDER p99，P-B vs P-A | 高 2-3 倍 | A-S t128：TiDB −2.0%、CRDB +27.6%、YBDB +721.3% | 方向部分相符（CRDB／YBDB 皆升高）但幅度差異極大（TiDB 幾乎持平、YBDB 遠超預測倍數），不支持統一的「2-3 倍」估計 |
| 跨區 failover RTO | P-B 快 5-10 倍 | 未測（chaos/failover ⚪ 待排程） | 無法對照，此預測目前仍是純架構推論，未經 PoC 實測驗證 |
| WAN runtime bytes | P-B 約 2-3 倍 | 未測（本報告未納入 WAN 位元組跨 placement 對照） | 無法對照，列入 §8 缺口 |

## 8. 未解決缺口

- P-A×A-A 完全缺失——本報告最大的單一缺口（§4）。
- 無同批同時執行的 paired control；兩個 placement 的比較皆為跨批觀察。
- TiDB th=128 崩潰／劣化的根因仍待 §5 所列控制實驗，目前只能列為假說。
- Chaos／failover 尚未執行，P-B 的地理 DR 優勢僅為架構推論，未經 RTO/RPO
  實測驗證。
- WAN runtime bytes 的跨 placement 實測比較未做，explainer §3 的估計值仍
  未經驗證。
- 各 cell 皆 `N=1`，未建立 round-level 或 batch-level 重現性。

## 9. 證據入口

- [P-A-vs-P-B-explainer.md](./P-A-vs-P-B-explainer.md)（概念對齊，pre-sweep 預測）
- [XCROSS-CLOSING-REPORT-DRAFT.md](./XCROSS-CLOSING-REPORT-DRAFT.md)（P-A×A-S）
- [XCROSS-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-AARO-CLOSING-REPORT-DRAFT.md)（P-A×A-A-RO 修正後）
- [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md)（P-B×A-S）
- [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md)（P-B×A-A-RO）
- [XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)（P-B×A-A）
- [XCROSS-PB-ALL-WORKLOADS-SUMMARY.md](./XCROSS-PB-ALL-WORKLOADS-SUMMARY.md)（P-B 三 workload 彙整、控制實驗設計）
- [MILESTONES.md](../MILESTONES.md) §6.2（placement × workload 進度總表）
- [results/x-cross/README.md](../results/x-cross/README.md)（已採用批次索引）
