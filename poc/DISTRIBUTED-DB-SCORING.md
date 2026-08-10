# 分散式資料庫 PoC 評分表 — MySQL Galera Cluster / TiDB / YugabyteDB / CockroachDB

> 本文件對應 [ITDBA-3596](https://104corp.atlassian.net/browse/ITDBA-3596)。
> 資料口徑：凡標「⭐」評分的項目，皆附測試證據連結；凡本 PoC 尚未實測或無法引用現有
> artifact 佐證的項目，一律標記 **「待測」**，不自行推算或補值。
> 星等換算方式（僅適用於已有實測數字的項目）：於**已測的資料庫之間**依實測數值相對
> 排序給星（最佳 = ⭐⭐⭐⭐⭐，其餘依名次遞減），**不代表跨業界的絕對基準**，換算依據
> 於每個章節內明列，供覆核與覆寫。

## 1. PoC 目的

> 依 [`1_MeetingMinutes/0400-to-dba.md`](./1_MeetingMinutes/0400-to-dba.md) 與
> [`0_projectFor104/README.md`](./0_projectFor104/README.md)。

- **業務目標**：「停機維護是 104 的事，不影響到客戶使用權益」——評估現有
  MySQL Galera Cluster 架構之外，是否有分散式 SQL 資料庫可在**相容性、效能、
  可用性、維運成本**四個維度上提供更好的權衡，作為未來架構選型依據。
- **範圍**：本 PoC 已完成 MySQL Galera 與 TiDB 的架構特性初步對照，並補齊
  PostgreSQL-compatible 路線（以 YugabyteDB 為主要觀察標的），本文件新增
  CockroachDB 納入同一張評分表，形成四方比較。
- **不做的事**：不是效能跑分競賽，不產出「哪家絕對最好」的排名結論；目的是
  在「換掉現行 HA 架構」這個決策情境下，量化每個維度的相對優劣與風險，
  留給決策者依業務優先序自行加權判斷（本文件的加權總分僅為**參考起點**，
  非最終決策依據）。
- **證據紀律**：所有可測項目一律以本 repo 既有 PoC 測試證據（`results/`、
  `phase-crossregion/`）為準，不得引用未在本 repo 留下 artifact 的數字；
  尚未執行的測試項目一律標「待測」。

## 2. 評分總表

| # | 評分細項 | 類別 | 權重 | 驗證方法 | MySQL Galera Cluster | TiDB | YugabyteDB | CockroachDB |
|---|---|---|---:|---|:---:|:---:|:---:|:---:|
| 1 | MySQL 協定相容性 | MySQL／PostgreSQL 相容性 | 20% | 既有應用 SQL／ORM 相容性矩陣測試（見 §3.1） | 待測 | 待測 | n/a（非 MySQL 協定） | n/a（非 MySQL 協定） |
| 2 | PostgreSQL 協定相容性 | MySQL／PostgreSQL 相容性 | 5% | 同上，PostgreSQL wire protocol 版本 | n/a | n/a | 待測 | 待測 |
| 3 | 單節點/低併發延遲 | 延遲與水平擴展 | 15% | go-tpc TPC-C，`vm-1node` RC，W=128（見 §3.2.1） | 待測 | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| 4 | 水平擴展能力 | 延遲與水平擴展 | 20% | go-tpc TPC-C，`vm-1node`→`vm-3node-haproxy-3s3r` 擴展比（見 §3.2.2） | 待測 | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐☆ |
| 5 | 高併發穩定性 | 延遲與水平擴展 | 15% | go-tpc TPC-C，t=128 5-round range/mean 與 error rate（見 §3.2.3） | 待測 | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ |
| 6 | Failover RTO／RPO | Failover、RTO／RPO、PITR | 6% | `phase-crossregion` 3DB×2placement×5情境 chaos 實測，50 次真實注入（見 §3.3） | 待測 | ⭐⭐☆☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| 7 | PITR／備份還原 | Failover、RTO／RPO、PITR | 4% | 尚未排入本 PoC 測試矩陣（見 §3.3.6） | 待測 | 待測 | 待測 | 待測 |
| 8 | Online DDL 與維運工具 | Online DDL 與維運工具 | 10% | 尚未排入本 PoC 測試矩陣（見 §3.4） | 待測 | 待測 | 待測 | 待測 |
| 9 | HTAP／TiFlash 與 Geo-Distribution | TiDB HTAP／TiFlash 與 YugabyteDB Geo-Distribution | 5% | TiFlash 分析型查詢尚未排入；Geo-Distribution 部分見 `phase-crossregion` placement 實測（見 §3.5） | n/a | 待測（HTAP 面） | 待測（Geo 面，P-B 已有 placement 實測但非正式排名依據） | n/a |
| | **合計** | | **100%** | | | | | |

## 3. 各章節說明

### 3.1 MySQL／PostgreSQL 相容性

- **驗證方法設計**：以現行應用（或代表性 ORM／SQL 測試集）分別對 MySQL 協定
  （Galera、TiDB）與 PostgreSQL 協定（YugabyteDB、CockroachDB）跑相容性矩陣，
  記錄語法差異、不支援的 SQL 特性、driver/ORM 相容度、既有維運工具鏈
  （monitoring、backup 工具）是否可直接沿用。
- **現況**：本 PoC 尚未執行此矩陣測試，**全部四家標「待測」**。TiDB 官方文件
  宣稱高度 MySQL 相容（詳細差異未經本 PoC 實測驗證）；YugabyteDB／CockroachDB
  皆為 PostgreSQL wire protocol，相容程度亦未經本 PoC 實測驗證——這兩點僅為
  官方能力面資訊，不可當作已驗證結論引用。
- **待補測試**：建議至少涵蓋現行應用實際使用的 SQL 語法子集、常用 ORM（如
  有）、既有備份/監控工具鏈相容性。

### 3.2 延遲與水平擴展

> 資料來源：[`results/README.md`](./results/README.md) §已驗證結果表、
> `results/{tidb,crdb,yuga}-tc1/S-BASE/pipeline-log.md`。口徑：W=128、
> READ COMMITTED、5-round mean，per
> [`tests/common/summary-from-stdout.py`](./tests/common/summary-from-stdout.py)。
> 全部為 `N=1`，`baseline_family=vm`——可在同 family 內比較，但未達 `N=3`
> 驗證，不构成決策級結論。

#### 3.2.1 單節點/低併發延遲（vm-1node RC）

| DB | 代表點 | tpmC | NEW_ORDER p99 | error rate |
|---|---:|---:|---:|---:|
| MySQL Galera Cluster | — | 待測 | 待測 | 待測 |
| TiDB | t=128 | 13,064 | 597 ms | 0.000% |
| YugabyteDB | t=32 | 11,436 | 216 ms | 0.000% |
| CockroachDB | t=64 | 9,134 | 440 ms | 0.000% |

星等換算（僅依 p99 相對排序，數值越低越優）：YugabyteDB 216ms 最低 → ⭐⭐⭐⭐⭐；
CockroachDB 440ms 次低 → ⭐⭐⭐⭐☆；TiDB 597ms → ⭐⭐⭐☆☆。**此比較的三家代表點
thread 數不同**（32/64/128，各自為該 DB 的飽和甜點），是「各自最佳單節點延遲」
的比較，不是同 thread 下的直接對照，解讀時需留意。

#### 3.2.2 水平擴展能力（vm-1node → vm-3node-haproxy-3s3r）

| DB | vm-1node tpmC | haproxy-3s3r tpmC（t=128） | 擴展倍率 | vs direct-3s3r 增益 |
|---|---:|---:|---:|---:|
| MySQL Galera Cluster | 待測 | 待測 | 待測 | 待測 |
| TiDB | 13,064 | 26,947 | **2.06×** | +78.7% |
| YugabyteDB | 11,436 | 15,632 | **1.37×** | +79.1% |
| CockroachDB | 9,134 | 15,033 | **1.65×** | +37.5% |

星等換算（依擴展倍率相對排序）：TiDB 2.06× → ⭐⭐⭐⭐⭐；CockroachDB 1.65× →
⭐⭐⭐⭐☆；YugabyteDB 1.37× → ⭐⭐⭐☆☆。理論擴展上限為 3×（3 節點）；三家皆未達
理論值，反映 RF=3 寫入 quorum 成本與各自架構的協調開銷。

#### 3.2.3 高併發穩定性（t=128，5-round range/mean 與 error rate）

| DB | tpmC (t=128 mean) | range/mean（5 輪間變異） | error rate |
|---|---:|---:|---:|
| MySQL Galera Cluster | 待測 | 待測 | 待測 |
| TiDB | 26,947 | 7.4% | 0.000% |
| YugabyteDB | 15,632 | 7.1% | 0.000% |
| CockroachDB | 15,033 | 6.9%（t=64 最高達 8.9%） | 0.000% |

星等換算（依 range/mean 相對排序，越低越穩定；三家 error rate 皆 0%，本項不
作額外區分）：CockroachDB 6.9% → ⭐⭐⭐⭐⭐；YugabyteDB 7.1% → ⭐⭐⭐⭐☆；TiDB
7.4% → ⭐⭐⭐⭐☆（三者差距在 0.5 個百分點內，實務上可視為同級，僅供參考排序）。

**注意**：以上 §3.2 全部數字皆為 `vm-3node-haproxy-3s3r` 這一組特定拓樸下的
`N=1` 結果，且三家硬體規格相同但架構本質不同（TiDB 計算/儲存分離、
CockroachDB 單體、YugabyteDB 雙 process），不代表其他拓樸（如 K8s 部署、
跨區部署）下會有相同排序——`phase-k8s` 的量測即顯示 YugabyteDB 在 K8s 部署層
的 retention 遠低於 TiDB/CockroachDB（詳見
[`1_MeetingMinutes/analytics-S-K8S-2026-06-15.md`](./1_MeetingMinutes/analytics-S-K8S-2026-06-15.md)），
與本節排序不一致，說明「延遲與擴展能力」對部署環境高度敏感。

### 3.3 Failover、RTO／RPO、PITR

#### 3.3.1 Failover RTO／RPO — 現況與範圍說明

- **設計基礎**：`phase-crossregion` 的量測方法論見
  [`RTO-RPO-methodology.md`](./phase-crossregion/failover/RTO-RPO-methodology.md)；
  實跑腳本為 `phase-crossregion/scripts/run-vm6-chaos-execute.sh`（F1/C4）、
  `run-vm6-f2-idc-death-execute.sh`（F2）、`chaos/chaos-c1-partition-execute.sh`（C1）、
  `chaos/chaos-c7-disk-slow-execute.sh`（C7）。
- **範圍已擴大，與本節原始設計不同（已知落差，非疏漏）**：本節原文字曾寫
  「F1（對應 P-A×A-S）／C4（對應 P-B×A-A）」這種「各 placement 各測一個情境」
  的窄範圍設計。**實際執行的測試範圍遠大於此**——TiDB／YugabyteDB／CockroachDB
  三家皆在 **P-A×A-S 與 P-B×A-A 兩個 placement 上各自完整跑滿 C7（磁碟慢）→
  C1（網路分區）→ F1（graceful kill，含 leader／follower 子情境）→ C4
  （ungraceful kill，含 leader／follower 子情境）→ F2（IDC 全滅）共 5 個情境**，
  合計 **6 環境、50 次真實 chaos 注入**（TiDB 因額外測試「多殺一個共置 PD
  成員」的 ±pd 變體，注入次數略多於其餘兩家）。本節下方數字即依此實際完成
  的完整範圍回填，比原設計更全面，不是縮水。
- **現況**：TiDB／YugabyteDB／CockroachDB 三家皆已完成，實測數字與星等見
  下方 §3.3.2～§3.3.4。**MySQL Galera Cluster 完全未納入 `phase-crossregion`
  測試矩陣，標「待測」**——Galera 的多主複寫模型與本 PoC 既有的 raft-based
  三家測試方法論不同，量測方式需另外設計，不可直接套用 F1/C4/F2 spec。
- **完整過程與逐環境細節**：見
  [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](./phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)
  （以下簡稱「3DB 比較報告」），本節數字全數摘錄自該報告，如有出入以該報告
  與其引用的 6 份逐環境結案報告（`results/x-cross/chaos/<db>-vm-6node-
  <placement>-rc-<TS>-SUMMARY.md`）與 raw artifact（`rto-rpo.json` 等）為準。

#### 3.3.2 F1／C4 leader-kill、follower-kill 完整數據

RTO 單位：秒；三家 DB 在全部情境下 **RPO 皆為 0**（write-reject 驗證全數通過，
quorum 遺失期間未偵測到任何誤判寫入成功的情況）。TiDB 含 ±pd 兩變體
（`tidb+tikv` / `tidb+tikv+pd`）；YugabyteDB／CockroachDB 無此變體。

| DB | Placement | F1-leader (graceful) | F1-follower (graceful) | C4-leader (ungraceful) | C4-follower (ungraceful) |
|---|---|---:|---:|---:|---:|
| TiDB | P-A | 6.934 / 6.692(+pd) | 7.315 / 6.909(+pd) | 6.844 / 6.684(+pd) | 0.030†(離群) / 6.715(+pd) |
| TiDB | P-B | 7.064 / 7.011(+pd) | 4.180†(離群) / 6.877(+pd) | 8.372 / 7.480(+pd) | 7.389 / 6.722(+pd) |
| YugabyteDB | P-A | 0.260 | 0.391 | 0.375 | 0.328 |
| YugabyteDB | P-B | 2.627 | 0.009 | 3.518 | 0.455 |
| CockroachDB | P-A | 0.035 | 0.081 | 0.100 | 0.131 |
| CockroachDB | P-B | 0.037 | 0.104 | 0.105 | 0.105 |

† 2 筆離群值（TiDB P-A C4-follower 0.030s、P-B F1-follower 4.180s）與同組其餘
3 筆變體（皆 6.7～8.4s）差距極大，3DB 比較報告 §3 判定為量測雜訊（HAProxy
round-robin 是否剛好避開故障 backend 所致），不計入下方星等換算依據。

**跨 DB 觀察**（詳見 3DB 比較報告 §2／§3／§7）：
- 三家 DB 的 leader-kill RTO 排序一致為 CockroachDB（35～131ms）< YugabyteDB
  （0.26～3.5s）< TiDB（6.7～8.4s），差距達兩個數量級。
- graceful（F1）vs ungraceful（C4）在三家 DB 上差異都很小（65ms～1.5s），
  三家皆未展現「graceful resign 顯著縮短 RTO」的效果。
- leader vs follower kill 在三家 DB 上皆未觀察到結構性 RTO 差異（follower
  理論上不需 failover，但實測數字不支持這個假設有可量測的效果）。
- **YugabyteDB 是唯一一家 leader-kill RTO 對 placement 高度敏感的 DB**（P-A
  0.26～0.38s vs P-B 殺到真實 tablet 資料 leader 時 2.6～3.5s，近 10 倍
  差距）；CockroachDB 兩個 placement 幾乎完全一致，顯示其 range lease
  failover 對「leader 是否被 pin」不敏感。

#### 3.3.3 F2（IDC 全滅）真實復原時間 — 本項星等換算依據

F2 對 3 台 IDC host 同時發出真實 kill，驗證「quorum 遺失時應正確拒絕寫入」
且量測「重啟後到能再次成功寫入」的時間。腳本原生輸出的
`write_recovery_sec`／`cluster_rebuild_sec` 內含「偵測 kill 完成＋
write-reject 驗證＋送出 restart 指令」的前置操作時間，**不是真實復原時間**；
下表已統一改用 `t_first_write_ok − t_restart_start`（3DB 比較報告 §6 已建立
之修正公式）。

| DB | P-A 真實復原時間 | P-B 真實復原時間 | Write-reject 驗證 | RPO |
|---|---:|---:|---|---:|
| TiDB | 44.3s | 39.1s | `PD server timeout` → 正確拒絕 | 0 |
| YugabyteDB | ≈3.2s | ≈3.05s | `psql: timeout expired` → 正確拒絕 | 0 |
| CockroachDB | ≈12.95s | ≈7.21s | 真實 `lost quorum`／`waiting 62.00s for slow proposal` → 正確拒絕 | 0 |

**跨 DB 排序（快→慢，兩個 placement 下皆重現一致排序）**：YugabyteDB（~3s）
< CockroachDB（7～13s）< TiDB（39～44s）。3DB 比較報告 §7 將此列為「信心
最高的跨 DB 結論」——因為它是唯一一組在兩個 placement 下都重現相同排序的
指標，不像 F1/C4 leader-kill 那樣受 placement 影響劇烈（尤其 YBDB）。

**本項（#6）星等換算依據與理由**：F1/C4 單節點 kill 的 RTO 因情境/placement
組合眾多（8 組數據／DB）且部分數字受量測雜訊影響（見 §3.3.2 離群值），
不適合直接化約為單一星等；F2 則是**唯一乾淨、單一、且跨 placement 穩定
重現的代表指標**，同時對應業務上最嚴重的失效模式（整區故障，而非單一
節點），故本項星等以「兩個 placement 中較慢（保守）的一次 F2 真實復原
時間」為換算依據：TiDB 44.3s、YugabyteDB 3.2s、CockroachDB 12.95s。
RPO 三家皆為 0，未產生區分度，星等純依 RTO 排序。

星等換算（依 F2 真實復原時間相對排序，數值越低越優）：**三家的相對差距
（YugabyteDB→CockroachDB 約 4.0 倍、CockroachDB→TiDB 約 3.4 倍）遠大於
本文件其餘章節的排序差距（多在 1.2～2 倍內），故本項不沿用其餘章節慣用的
「5-4-3」等距配分，改反映實際量級差距**：YugabyteDB 3.2s → ⭐⭐⭐⭐⭐；
CockroachDB 12.95s → ⭐⭐⭐⭐☆；TiDB 44.3s → ⭐⭐☆☆☆（與 YugabyteDB 相差
近 14 倍，明顯是獨立一個量級，故給予比本文件其他章節「敬陪末座」通常
給的 3 星更低的 2 星）。此換算為主觀判斷，數字本身完整列於上表，供覆核
與覆寫。

#### 3.3.4 C1（網路分區）／C7（磁碟慢）韌性敘述（不計入星等）

- 三家 DB、兩個 placement，C1（30 秒 WAN 分區）與 C7（30 秒磁碟 I/O 競爭）
  合計各 6 次注入，**全數維持 6/6（或全 store/node）ALIVE/available/live**，
  無任何一次因這兩類注入導致節點被判定下線或需人工介入復原。
- 此二情境設計上不測 leader failover（C1 測網路容忍度、C7 測磁碟降級容忍度），
  故不產生 RTO/RPO 數字，僅列為韌性佐證，不影響本項星等。
- 已知限制：C1/C7 期間未量測 tpmC-during-incident（背景 workload log 覆蓋
  問題／量測工具限制，見 3DB 比較報告 §10），僅有定性的存活敘述。

#### 3.3.5 已知限制（適用於本項全部數字）

- **N=1**：每個 DB×placement×情境組合僅執行一次真實注入（TiDB 因需修復
  過程中發現的腳本 bug 有 2～3 次重跑，視為同一次「有效」量測，非獨立重複
  樣本）。所有數字皆可能受單次執行的環境雜訊影響，不構成統計顯著結論。
- **RPO 量測精確度上限**：全程使用簡化版（per-warehouse `max(o_id)`
  high-water-mark），非完整 driver-hooked FIFO buffer。「RPO=0」代表「未
  偵測到遺失」，不等同「數學上證明零遺失」。
- **YugabyteDB P-B 段觀察到一次真實穩定性異常**：yb-master 執行緒暴增至
  1147（正常值 26～30）、RPC 延遲飆升至 5～80 秒、叢集 12+ 分鐘選不出新
  leader，重啟該節點後恢復正常。樣本數 N=1，根因僅基於現象推測、未複測
  驗證是否可重現，未反映在本項星等中（因該次異常發生於 F1-follower 情境，
  重跑後乾淨完成並取得本節採用的 0.009s 數字）。若後續採用 YugabyteDB 且
  規劃不 pin leader 的 placement 策略，建議在正式部署前針對此風險項做更
  長時間、更高並發的壓力測試驗證。詳見
  [ybdb-vm-6node-P-B-aa-rc-20260808T172141+0800-SUMMARY.md](./results/x-cross/chaos/ybdb-vm-6node-P-B-aa-rc-20260808T172141+0800-SUMMARY.md)。
- 三家 DB 在「quorum 遺失時正確拒絕寫入」的正確性底線上**沒有差異**，本項
  星等差異純粹反映恢復速度，不反映資料正確性風險。

#### 3.3.6 PITR／備份還原

- 本 PoC 目前完全未排入測試矩陣（無 spec、無 script、無任何 artifact），
  四家皆「待測」。

### 3.4 Online DDL 與維運工具

- **現況**：本 PoC 目前未排入測試矩陣，四家皆「待測」。
- **建議驗證方法**（尚未執行，供未來排程參考）：對一張含資料的大表執行
  `ADD COLUMN`／`ADD INDEX` 等常見 Online DDL 操作，量測（a）DDL 執行期間
  對前台 TPC-C 負載的 tpmC/p99 影響幅度與持續時間，（b）DDL 是否需要
  應用層停機或降級，（c）既有維運工具（如慢查詢分析、線上參數調整、
  監控整合）的成熟度與學習成本。

### 3.5 TiDB HTAP／TiFlash 與 YugabyteDB Geo-Distribution

- **HTAP／TiFlash（TiDB 特有能力）**：本 PoC 未執行分析型查詢（OLAP-style）
  測試，「待測」。CockroachDB／MySQL Galera Cluster 無對應原生 HTAP 能力，
  標記 `n/a`。
- **Geo-Distribution**：`phase-crossregion` 已針對 TiDB／YugabyteDB／
  CockroachDB 三家執行 P-A（leader 集中單一 region）與 P-B（leader 跨區
  混合分佈）的實測（詳見
  [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./phase-crossregion/XCROSS-PA-VS-PB-FINAL-COMPARISON.md)），
  三家皆已具備跨區 placement 能力的實測證據——**但這批數據屬於
  `baseline_family=crossregion`、`baseline_eligible=false` 的探索性 scope，
  每個 cell 僅 `N=1`，且該報告本身的比較是「P-A vs P-B 兩種 placement 策略」，
  不是「三家 Geo-Distribution 能力的正式排名」，不可直接搬進本評分表當作
  已驗證的星等分數**。若要把 Geo-Distribution 正式納入本評分表，需另外設計
  「以相同 workload/RTT 條件比較三家跨區延遲與可用性權衡」的對照實驗，
  故本項仍標「待測」。MySQL Galera Cluster 原生不支援跨區散置寫入架構，
  標記 `n/a`。

## 4. 加權總分

> 計算方式：僅對**已有實測星等**的項目計入加權分母重新正規化（例如某 DB
> 只有 4 項有分，加權總分＝這 4 項的「星等（1-5）× 各自權重」加總 ÷ 這 4 項
> 權重合計 × 100，換算為百分制），未測項目**不**用任何預設值替代。這代表
> 目前的加權總分**反映「延遲與水平擴展」（§3.2，#3/#4/#5）與「Failover
> RTO／RPO」（§3.3，#6）合計 4 個項目**，不是四方資料庫的完整評估結果——
> 相容性、PITR、Online DDL、HTAP/Geo 共 44% 權重仍未計入。

| DB | 已計入項目 | 已計入權重合計 | 加權總分（延遲/擴展＋Failover，百分制） |
|---|---|---:|---:|
| MySQL Galera Cluster | 無 | 0% | 待測（無任何實測項目） |
| TiDB | #3 #4 #5 #6 | 56% | (3×15 + 5×20 + 4×15 + 2×6) / 56 × 20 = **77.5** |
| YugabyteDB | #3 #4 #5 #6 | 56% | (5×15 + 3×20 + 4×15 + 5×6) / 56 × 20 = **80.4** |
| CockroachDB | #3 #4 #5 #6 | 56% | (4×15 + 4×20 + 5×15 + 4×6) / 56 × 20 = **85.4** |

> 計算範例（TiDB）：`(3×15 + 5×20 + 4×15 + 2×6) ÷ (15+20+15+6) × 20 = 217 ÷ 56 × 20 = 77.5`。
> 乘以 20 是把 1-5 星換算為百分制的比例常數（5 星 = 100 分）。
> **本次新增 #6 Failover RTO／RPO（6% 權重，見 §3.3）後，總分排序由「TiDB
> (82.0) > CockroachDB(86.0，原本已最高) > YugabyteDB(78.0)」變為
> 「CockroachDB(85.4) > YugabyteDB(80.4) > TiDB(77.5)」——YugabyteDB 因
> Failover 表現最佳（F2 真實復原 ~3.2s，全表最優）反超 TiDB；TiDB 因
> Failover 明顯較慢（F2 ~44.3s）從原本次高名次降為最低。這個排序反轉本身
> 就是「加權設計對結論敏感」的具體例證（見下方 §5 討論），換一組權重
> （例如把 Failover 權重調高至業務實際重視的水準）結果可能再次不同。**四家
> 分數差距從原本 3 項的 8 分（78-86）微幅縮小為 4 項的 7.9 分（77.5-85.4），
> 仍代表約 56% 的總權重**——在其餘 44% 權重（相容性、PITR、DDL、HTAP/Geo）
> 補測前，任何「A 比 B 好」的結論都不成立，本表刻意不對 MySQL Galera Cluster 給出任何
> 加權總分，避免「0 分」被誤讀為「Galera 最差」（正確理解是「Galera 完全
> 未測」）。

## 5. 最終結論

**目前僅能下的結論**：TiDB／YugabyteDB／CockroachDB 三家已完成「延遲與水平
擴展」（§3.2，50% 權重）與「Failover RTO／RPO」（§3.3，6% 權重）合計 56%
權重的實測，加權分數差距在 7.9 分內（77.5-85.4，滿分 100）：
- **CockroachDB**（85.4）：延遲/擴展三項皆居中偏優（高併發穩定性最佳，
  range/mean 6.9%），Failover 表現次佳（F2 真實復原 ~12.95s），四項加總
  最高。
- **YugabyteDB**（80.4）：單節點延遲最低但擴展倍率最低，**Failover 表現
  全表最佳**（F2 真實復原 ~3.2s，比另兩家快 4～14 倍），這項優勢把總分
  從原本（未計入 Failover 時）的殿後（78.0）拉到第二（80.4，反超 TiDB）。
  但需注意 YugabyteDB P-B 段的 leader-kill RTO 對 placement 高度敏感
  （§3.3.2），且觀察到一次真實穩定性異常（§3.3.5），這兩點未反映在單一
  加權分數裡，決策時應個別考量。
- **TiDB**（77.5）：擴展倍率最高（2.06×）原本拉高其分數，但 **Failover
  明顯是三家中最慢**（F2 真實復原 39～44s，比 YugabyteDB 慢一個數量級），
  加入這項後總分從原本次高（82.0）降為殿後（77.5）。

**這次排序反轉本身就是本文件加權設計「對結論高度敏感」的具體例證**（見
§4 附註）：加入 Failover 這一項（僅 6% 權重）就足以讓 TiDB／YugabyteDB
的名次互換，說明**現有 56% 已測權重仍不足以支撐「何者整體較優」的穩定
結論**——換一組更貼近實際業務優先序的權重（例如若業務對 RTO SLA 要求
嚴格，Failover 權重理應遠高於 6%），排序可能再度反轉。這些結論僅限於
本 PoC 已測的拓樸、硬體規格與 chaos 注入設計，**不可外推**到 Kubernetes
部署（已知 YugabyteDB 在該場景 retention 明顯較差）或本次未測的其他
故障模式（如網路分區持續超過 30 秒、單一磁碟完全故障等）。

**目前不能下的結論**：
- 不能說任何一家「整體最適合取代 MySQL Galera Cluster」——相容性、
  PITR、維運工具、HTAP/Geo 四個類別（合計 44% 權重）完全沒有實測數據，
  已測的「延遲/擴展＋Failover」僅 56% 權重。
- 不能用本表現有數字給 MySQL Galera Cluster 任何分數或排名——它是本次比較
  的基準對象，但目前一項都沒測（含 Failover：Galera 的多主複寫模型需要
  另外設計量測方式，不可直接套用本次的 F1/C4/F2 spec，見 §3.3.1）。
- 不能把 `phase-crossregion` 的 P-A/P-B placement 探索性數據（§3.5 提及
  的 Geo-Distribution 部分）當作正式評分依據（該 scope 本身
  `baseline_eligible=false`）——**但 §3.3 的 Failover RTO／RPO 數字雖然
  同屬 `baseline_family=crossregion`、`baseline_eligible=false` 的探索性
  scope，仍已依使用者指示正式納入本表 #6 項評分**，與 §3.5 Geo-Distribution
  刻意不採用的處理方式不同，特此註明兩者處理原則不一致之處：Failover
  數字有明確的 RTO/RPO 量化指標與跨 placement 重現的排序（§3.3.3），
  Geo-Distribution 目前僅有探索性觀察、缺乏「以相同條件比較三家」的
  對照實驗設計，故仍標「待測」。
- 不能忽略 §3.3.5 列出的已知限制（N=1、簡化版 RPO 量測、YugabyteDB 未複測
  的穩定性異常）逕自把 Failover 星等當作精確、可重現的排名依據。

**下一步建議**（依風險與可行性排序，已更新）：
1. 針對 MySQL Galera Cluster 補一輪與本 PoC 相同口徑（W=128、go-tpc
   TPC-C、READ COMMITTED、`vm-1node`/`vm-3node`）的基準測試，並設計其
   專屬的 failover 測試方法（多主複寫模型），否則它永遠無法被公平比較，
   也永遠無法填入 #6 項。
2. 設計並執行 §3.1 相容性矩陣與 §3.4 Online DDL 測試——這兩項合計 35%
   權重，且往往是實際遷移時最先浮現的痛點，優先度應不低於效能測試。
3. 若條件允許，針對 YugabyteDB P-B 段觀察到的執行緒暴增異常（§3.3.5）
   安排複測，確認是否可重現、根因為何——這是本次唯一一項「發現但未驗證」
   的真實資料庫穩定性風險，關係到是否可放心採用 YugabyteDB 的不 pin
   leader placement 策略。
4. PITR 與 HTAP／Geo-Distribution 合計僅 9% 權重，可視資源排在較後順序。

---

*本文件由 PoC 測試證據自動彙整而成，任何星等與加權總分皆可回溯至上述引用的
`summary.json`／pipeline-log／dispatch-record；如發現本文件數字與來源檔案
不一致，以來源檔案為準，並回報修正。*
