# X-CROSS P-B Placement 三 Workload 綜合彙總 — TiDB/YBDB/CRDB W=128 正式測試

> 目的：橫向彙總 P-B placement（散置 RF=3 全 voter、leader 跨區混合
> 分佈 30-70%）在 A-S、A-A-RO、A-A 三種 workload 下的完整 W=128 正式
> 測試結果，找出跨 workload 一致的行為模式。三個 profile 皆已於
> 2026-07-27~08-01 完成正式執行，個別完整數字與逐項分析見對應結案
> 報告（§8 連結）。本文件只做橫向彙總與交叉比對，不重複列出原始數據。

## 1. 測試矩陣總覽

| Workload | TS | TiDB tpmC@128 | YBDB tpmC@128 | CRDB tpmC@128 | 三家錯誤率 |
|---|---|---:|---:|---:|---:|
| **A-S**（IDC 單寫，GCP standby） | `20260727T223650+0800` | 15,107.4 | 2,485.6 | 11,640.0 | 全 0% |
| **A-A-RO**（IDC 讀寫，GCP 唯讀） | `20260730T094406+0800` | 5,699.7 ⚠ | 11,989.8 | 13,777.1 | 全 0%（TiDB 崩潰輪次 0.004%） |
| **A-A**（IDC/GCP 同時讀寫，W 全重疊） | `20260731T204801+0800` | 4,413.9 ⚠ | 11,605.5 | 9,880.6 | 全 0% |

三個 profile 的 P-B placement gate（`prepare.sh` §6.6 抽樣）**全數 PASS**，
證實同一套跨 DB 修復設計（TiDB 雙 `PRIMARY_REGION` policy／YBDB 雙
tablespace+主動 enforcer／CRDB 雙 `lease_preferences`+`PARTITION BY
RANGE`）在三種 workload 型態下皆穩定有效，不受 client 端讀寫模式影響。

## 2. 核心發現：TiDB 高併發限制與「雙邊並發存取」強相關，非單純
「執行緒數高」

比對三個 profile 在 th=128 的 TiDB 表現，呈現清楚的規律：

| Workload | GCP 側是否同時打流量 | TiDB th=128 表現 |
|---|---|---|
| A-S | 否（GCP 僅 standby，無主動負載） | **正常擴展**（th=64→128：14,203.0→15,107.4，持續成長） |
| A-A-RO | 是（唯讀 mix） | **災難性崩潰**（前兩輪正常甚至最高，第 3-5 輪崩潰到個位數 tpmC，見結案報告 §3） |
| A-A | 是（標準讀寫 mix，與 IDC 同批 warehouse） | **持續性劣化**（th=32 見頂 8,868.2 後单調下滑，未崩潰但延遲持續惡化） |

**結論非常一致**：只要 GCP 側有真實查詢流量同時打在同一顆 cluster
上（無論唯讀或讀寫），TiDB 在高併發下就會出現效能問題；GCP 側完全
靜置（A-S）時，即使同樣的 P-B 跨區混合 leader 設計，TiDB 在 th=128
反而是全程最佳表現。這排除了「單純執行緒數過高」這個表面解釋，
指向根因是 **P-B 跨區混合 leader 下，TiDB percolator 式兩階段悲觀鎖
遇上雙邊（IDC+GCP）同時對叢集發起請求時的鎖解析競賽**——A-A-RO 的
唯讀查詢雖不寫入，但仍會透過 `closest-replicas`/follower-read 機制
對 TiKV 產生跨區 RPC 流量，與 IDC 端的悲觀鎖交易爭搶同一批 TiKV
region 的處理資源，觸發率隨兩端同時施壓的強度而定：A-A（雙邊皆寫，
衝突最兇猛）呈現持續劣化；A-A-RO（GCP 純讀）呈現較短暫但更劇烈的
崩潰-恢復循環；A-S（GCP 無負載）完全不受影響。

**建議**：後續若要在正式報告中呈現 P-B 對 TiDB 的效能結論，應明確
標注「僅在雙邊（IDC+GCP）同時發起負載的 workload 下出現」這個條件，
避免讀者誤以為 P-B 本身導致 TiDB 全面不可用於高併發場景（A-S 場景
下完全正常）。

## 3. YBDB／CRDB：三種 workload 下皆表現穩定

### YBDB

三個 profile 皆在中段執行緒檔位（th=32 或 th=64）出現一次性的 tpmC
小幅波動（A-S：th=32→64 由 1,901.8 降到 1,558.8；A-A：th=16→32 由
2,287.8 降到 2,150.7），但**皆在 th=128 恢復到全程最高值**，且延遲
未出現 TiDB 那種持續惡化。判斷是 YBDB 在中段併發下的正常雜訊
（`tpmC_range_mean_pct` 在該檔位確實偏高），非系統性問題。

### CRDB

三個 profile 下 CRDB 皆呈現**單調遞增**的 tpmC 曲線（A-S：
th=64→128 僅 +3.7%，接近飽和；A-A-RO／A-A：持續成長到 th=128），
是三家中擴展性最穩定的一個，未在任何 profile 下出現 TiDB 那種
劣化或崩潰模式。

## 4. Placement Gate 跨 workload 一致性

| DB | A-S | A-A-RO | A-A |
|---|---|---|---|
| TiDB | idc=10/19（52%） | idc=10/19（52%） | idc=10/19（52%） |
| YBDB | idc=1/3（33%） | idc=2/3（66%） | idc=2/3（66%） |
| CRDB | idc=7/12（58%） | idc=7/12（58%） | idc=7/12（58%） |

TiDB／CRDB 三個 profile 下數字完全一致（同一套 placement SQL、同一種
抽樣邏輯，workload 類型不影響 leader 分佈結果，符合預期）。YBDB 在
A-S 與 A-A-RO/A-A 間有 33% vs 66% 的差異，但兩者皆落在 30-70% 窗口
內 PASS——3 表抽樣基數小（分母僅 3），1 個樣本翻轉即造成 33 個百分點
差距，屬抽樣雜訊而非系統性差異。

## 5. 執行過程的共通挑戰（跨三輪皆出現，非單一 workload 特有）

- **WAN/SSH 間歇性不穩定**：三輪執行過程皆多次遇到 SSH 對 `.31`
  逾時、VPN 斷線（最長一次近 12 小時），皆確認 driver 本身透過
  nohup 真正 detach 在 `.31` 上執行、不受 Mac 端連線影響，只是
  期間無法即時查看進度。
- **`.suite.done` 結構性缺失**：aaro／aa profile（GCP 端不經
  `tests/common/run.sh`）皆不會產生 `.suite.done`，`phase9` 的
  `phase8.5-static-check` 必定誤判 FAIL，統一改用
  `phase8.5-fetch`+`phase8.5-check-receipt`（跳過 static-check，
  依賴 driver 自身 `check-aaro-artifacts.py` 逐家驗證）收尾，已成為
  aa/aaro profile 的標準做法。
- **`phase8.5-fetch` 設計上會整包撈回 `.31` 上累積的全部歷史 suite**
  （非本次 bug），每輪皆需篩出當次目標 suite、其餘 gitignore，已成
  慣例。

## 6. 待辦與後續建議

- **TiDB 高併發限制**（§2）為三輪測試一致收斂的最重要發現，建議排入
  專項調校（`tidb_lock_ttl`、悲觀鎖重試策略、或評估降低 P-B 下
  gcp 優先組表的比例），並在正式對外報告中明確標注觸發條件（雙邊
  並發存取）。
- P-B 的三種 workload（A-S/A-A-RO/A-A）W=128 正式測試矩陣至此
  **全數完成**，三家資料庫在 P-B 下的行為特徵已有完整交叉驗證基礎，
  可考慮進入結果彙總對外呈現、或與 P-A 側對應數字做 P-A vs P-B 的
  最終比較。
- P-B×backup／migration／chaos 仍是 spec-only，未排程。

## 7. 各 workload 完整分析報告連結

- [XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AS-CLOSING-REPORT-DRAFT.md) — A-S，TS=`20260727T223650+0800`
- [XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AARO-CLOSING-REPORT-DRAFT.md) — A-A-RO，TS=`20260730T094406+0800`
- [XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md](./XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md) — A-A，TS=`20260731T204801+0800`

詳細踩坑過程見 `SESSION-HISTORY.md` 2026-07-27 至 08-01 各節。
