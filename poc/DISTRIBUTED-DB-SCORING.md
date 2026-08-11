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
| 6 | Failover RTO／RPO | Failover、RTO／RPO、PITR | 6% | `phase-crossregion` 3DB×2placement×5情境 chaos 實測；2026-08-11 真實重跑完成（見 §3.3.1） | 待測 | ⭐⭐⭐☆☆ | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| 7 | PITR／備份還原 | Failover、RTO／RPO、PITR | 4% | 尚未排入本 PoC 測試矩陣（見 §3.3.2） | 待測 | 待測 | 待測 | 待測 |
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

#### 3.3.1 Failover RTO／RPO — 2026-08-11 真實重跑完成

> **背景**：本節原本（2026-08-08）依 `phase-crossregion` 3DB×2placement×5情境 chaos 實測
> 回填了三家的星等。2026-08-10 稽核逐筆核對 raw `probe.txt` 後發現 CockroachDB／YugabyteDB
> 全部 16 組 F1/C4 情境事件後探測皆為 `err=0`（`outage_observed=false`），回報的「RTO」實為
> 探測排程延遲，已撤回星等改列「待重測」（詳見
> [`CHAOS-FAILOVER-AUDIT-2026-08-10.md`](./phase-crossregion/CHAOS-FAILOVER-AUDIT-2026-08-10.md)）。
> **2026-08-11 已用修正後的 4 支腳本（`wall-clock-wrapper.sh`／`chaos-c1-partition-execute.sh`／
> `run-vm6-f2-idc-death-execute.sh`／`chaos-c7-disk-slow-execute.sh`）在全新重建的 4 個環境
> （CockroachDB×2 placement、YugabyteDB×2 placement，VM 全部 destroy 後重新 apply）上完整
> 重跑全部 5 情境**。TiDB 段（15/16 組真實觀測到中斷）未重跑，原始 2026-08-08 數字維持有效。
> 完整逐項數字與方法論見
> [`XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md`](./phase-crossregion/XCROSS-CHAOS-FAILOVER-3DB-COMPARISON.md)。

- **設計基礎**：量測方法論見
  [`RTO-RPO-methodology.md`](./phase-crossregion/failover/RTO-RPO-methodology.md)；
  實跑腳本為 `phase-crossregion/scripts/run-vm6-chaos-execute.sh`（F1/C4）、
  `run-vm6-f2-idc-death-execute.sh`（F2）、`chaos/chaos-c1-partition-execute.sh`（C1）、
  `chaos/chaos-c7-disk-slow-execute.sh`（C7）。

- **F2（3 台 IDC DB process 同時停止 + 重啟）真實復原時間** — 三家皆有可信數字，此為本項
  星等的主要依據：

  | DB | 復原時間（重啟→首次成功寫入） | write-reject 判定 |
  |---|---:|---|
  | YugabyteDB | ≈2.99s（P-A）／≈3.65s（P-B） | `write_correctly_rejected`（乾淨逾時） |
  | CockroachDB | ≈7.01s（P-A）／≈7.12s（P-B） | `ambiguous_result_manual_review_required`（無法確認是否已提交，需應用層額外處理） |
  | TiDB | ≈44.3s（P-A）／≈39.1s（P-B），其中 38.9~44.1s 屬「儲存層健康但 SQL 層仍不可寫」區間 | `write_correctly_rejected`（乾淨逾時） |

  YugabyteDB／CockroachDB 的數字皆為 2026-08-11 真實重跑所得，且與 2026-08-08 原始執行的
  數字方向一致、量級吻合（YugabyteDB 兩次皆 ~3s、CockroachDB 兩次皆 ~7s 上下），這是本項
  信心最高的跨 DB 比較依據。

- **F1/C4（單節點 leader/follower kill）** — 2026-08-11 真實重跑後，CockroachDB／
  YugabyteDB 全部 16 組情境**再次確認 `outage_observed=false`**（兩次獨立執行皆一致，非
  單次巧合），代表這兩家 DB 在本測試規模下，單節點 kill 造成的 client 可見中斷短於 100ms
  探測解析度；TiDB 15/16 組有真實觀測到的中斷（6.68~8.4s）。這代表 TiDB 因 SQL 層與儲存/
  共識層分離的架構，單節點 failover 對 client 造成的可感知延遲明顯長於另兩家單一進程整合
  架構的等效機制。
- **正確性底線**：三家 DB 在「quorum 遺失時拒絕/無法確認寫入」上皆有真實佐證，僅
  CockroachDB 回報 `ambiguous`（兩次獨立執行皆確認，非單次雜訊）需要應用層額外處理重試/
  查詢邏輯才能確認最終狀態，這是三家中唯一需要應用層額外處理的正確性差異。
- **星等換算**（依 F2 真實復原時間為主要依據，F1/C4 觀測結果與 write-reject 正確性為輔助
  判斷；F2 為三家唯一皆有可信、可直接比較數字的情境）：YugabyteDB F2 最快（~3s）且 F1/C4
  全數無可觀測中斷、write-reject 乾淨 → ⭐⭐⭐⭐⭐；CockroachDB F2 居中（~7s）且 F1/C4 同樣
  全數無可觀測中斷，但 write-reject 需應用層額外處理 → ⭐⭐⭐⭐☆；TiDB F2 最慢（39~44s，
  其中多數時間屬 SQL 層不可寫）且是唯一在 F1/C4 觀測到真實中斷（6.68~8.4s）的 DB，但
  write-reject 乾淨、且是唯一有完整探測解析度覆蓋全部情境的 DB → ⭐⭐⭐☆☆。
- **MySQL Galera Cluster**：完全未納入 `phase-crossregion` 測試矩陣，標「待測」——Galera
  的多主複寫模型與本 PoC 既有的 raft-based 三家測試方法論不同，量測方式需另外設計，不可
  直接套用 F1/C4/F2 spec。
- **本項星等的已知限制**（務必與星等一併閱讀）：
  - 每個 DB×placement×情境僅 `N=1`（CockroachDB/YugabyteDB 因 2026-08-11 重跑，F1/C4/F2
    現為 `N=2` 兩次獨立執行互相印證），仍不構成統計顯著結論。
  - F1/C4 探測解析度上限為 100ms 級（且非固定週期），CockroachDB/YugabyteDB 的
    `outage_observed=false` 只能證明「中斷短於這個解析度」，不能證明「零中斷」；若要進一步
    細分「哪家真的更快」需要更高解析度的探測工具，本次未做。
  - 探測皆從 IDC 側（`.31`）發起，未驗證 GCP 側 client 的真實體驗（C1 情境尤其明顯，見比較
    報告 §4/§10）。
  - TiDB 段未重跑，其 F1/C4 計時基準（graceful resign 排除在 t_incident 前）與 CockroachDB
    （graceful drain 計入 t_incident 後）存在已知的計時基準不對稱問題，跨 DB 比較 F1/C4 具體
    秒數時應留意此限制（本項星等主要依據 F2 而非 F1/C4，已盡量規避此問題，但無法完全消除）。
  - YugabyteDB 曾在 2026-08-08 P-B 段觀察到一次真實的 master 執行緒暴增穩定性異常
    （2026-08-11 重跑未再重現），這項風險未反映在上方星等中，決策時應一併考慮（見 §5
    下一步建議）。

#### 3.3.2 PITR／備份還原

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

> **2026-08-11 更新**：#6 Failover RTO／RPO 已於 §3.3.1 用 2026-08-11 真實重跑數字重新
> 評分（YugabyteDB ⭐⭐⭐⭐⭐／CockroachDB ⭐⭐⭐⭐☆／TiDB ⭐⭐⭐☆☆），本節納入 #3/#4/#5/#6
> 四項計算加權總分。

> 計算方式：僅對**已有實測星等**的項目計入加權分母重新正規化，未測項目**不**用任何
> 預設值替代。目前的加權總分反映「延遲與水平擴展」＋「Failover RTO/RPO」兩個類別
> （合計 56% 權重），仍不是四方資料庫的完整評估結果。

| DB | 已計入項目 | 已計入權重合計 | 加權總分（百分制） |
|---|---|---:|---:|
| MySQL Galera Cluster | 無 | 0% | 待測（無任何實測項目） |
| TiDB | #3 #4 #5 #6 | 56% | (3×15 + 5×20 + 4×15 + 3×6) / 56 × 20 = **79.6** |
| YugabyteDB | #3 #4 #5 #6 | 56% | (5×15 + 3×20 + 4×15 + 5×6) / 56 × 20 = **80.4** |
| CockroachDB | #3 #4 #5 #6 | 56% | (4×15 + 4×20 + 5×15 + 4×6) / 56 × 20 = **85.4** |

> 計算範例（TiDB）：`(3×15 + 5×20 + 4×15 + 3×6) ÷ (15+20+15+6) × 20 = 223 ÷ 56 × 20 = 79.6`。
> 乘以 20 是把 1-5 星換算為百分制的比例常數（5 星 = 100 分）。
> **這三個分數差距在 6 分內（79.6-85.4 分），且僅代表 56% 的總權重**——在其餘 44%
> 權重（相容性、PITR、DDL、HTAP/Geo）補測前，任何「A 比 B 好」的結論都不成立，本表
> 刻意不對 MySQL Galera Cluster 給出任何加權總分，避免「0 分」被誤讀為「Galera 最差」
> （正確理解是「Galera 完全未測」）。
>
> **與 2026-08-10 稽核前的比較**：納入 #6 後，TiDB（79.6）／YugabyteDB（80.4）名次
> 出現交叉——這與 2026-08-09 曾短暫出現、後來因數據無效而撤回的反轉（77.5 vs 80.4）
> 方向相同，但這次是建立在 2026-08-11 真實重跑（`N=2`，兩次獨立執行互相印證）的有效
> 數據上，不是無效數據的假象。即便如此，79.6 vs 80.4 的差距（0.8 分）遠小於量測本身
> 的不確定度（見 §3.3.1 已知限制：F1/C4 探測解析度、單次樣本雜訊），**不應解讀為
> 「YugabyteDB 確定優於 TiDB」**，只能說「在目前的權重設計與量測精度下，兩者非常接近，
> 排序對任一項目的星等微調都可能再次翻轉」——這具體示範了本文件加權設計對結論高度
> 敏感的既有風險，使用本表做決策時應同時檢視原始數據而非只看最終加權分數。

## 5. 最終結論

**延遲與水平擴展**：TiDB／YugabyteDB／CockroachDB 三家在 `vm-3node-haproxy-3s3r`
拓樸、W=128、READ COMMITTED 條件下，水平擴展與高併發穩定性各有取捨——CockroachDB
單節點延遲與擴展倍率兩項皆居中、但高併發穩定性最佳（range/mean 6.9%）；TiDB
擴展倍率最高（2.06×，且此項權重也最高 20%）但單節點延遲較高；YugabyteDB 單節點
延遲最低但擴展倍率最低。這些結論僅限於本 PoC 已測的這一組拓樸與硬體規格，
**不可外推**到 Kubernetes 部署（已知 YugabyteDB 在該場景 retention 明顯較差）
或跨區部署。

**Failover RTO／RPO（#6）現況**：三家 DB 已於 2026-08-11 完成真實重跑（CockroachDB／
YugabyteDB 在全新重建的環境上重跑全部 5 情境，TiDB 沿用 2026-08-08 有效數字），已
回填星等（詳見 §3.3.1）。核心發現：**F2（3 台 IDC 同時停止+重啟）的真實復原時間
YugabyteDB（≈3s）＜ CockroachDB（≈7s）＜ TiDB（39~44s）**，這個方向性排序在兩次
獨立執行中重現，是本 PoC 信心最高的跨 DB 觀察之一；**F1/C4 單節點 kill 在
CockroachDB／YugabyteDB 上兩次獨立執行皆觀測不到中斷**（探測解析度 100ms 級），
TiDB 則有 6.68~8.4s 的真實可觀測中斷——這反映 TiDB SQL 層與儲存/共識層分離的
架構，在單節點 failover 時對 client 造成的可感知延遲明顯長於另兩家單一進程整合
架構；CockroachDB 在 quorum 遺失時回報 `ambiguous`（無法確認是否已提交，兩次
重跑皆確認），是三家中唯一需要應用層額外處理重試/查詢邏輯才能確認最終狀態的正確性
差異。

**納入加權總分後**：TiDB（79.6）／YugabyteDB（80.4）／CockroachDB（85.4），三者
差距在 6 分內、且僅代表 56% 總權重，**不宜僅憑此下「何者較優」的結論**——尤其
TiDB／YugabyteDB 的 0.8 分差距遠小於量測本身的不確定度，任一項目的星等微調都可能
翻轉排序（見 §4 附註）。

**目前不能下的結論**：
- 不能說任何一家「整體最適合取代 MySQL Galera Cluster」——相容性、PITR、維運工具、
  HTAP/Geo 四個類別（合計 44% 權重）完全沒有可用的實測數據。
- 不能用本表現有數字給 MySQL Galera Cluster 任何分數或排名——它是本次比較
  的基準對象，但目前一項都沒測（含 Failover：Galera 的多主複寫模型需要
  另外設計量測方式，不可直接套用本次的 F1/C4/F2 spec，見 §3.3.1）。
- 不能把 `phase-crossregion` 的 P-A/P-B placement 探索性數據當作
  Geo-Distribution 的正式評分依據（該 scope 本身 `baseline_eligible=false`）。
- 不能把 F1/C4 的具體秒數（尤其 TiDB 的 6.68~8.4s）當成跨 DB 之間可直接換算倍率
  的量測值——CockroachDB／YugabyteDB 的「無可觀測中斷」與 TiDB 的「真實觀測到中斷」
  不是同一種量測基準，兩者間的差距只能定性描述（見比較報告 §2）。

**稽核教訓**：#6 的星等曾在 2026-08-09 短暫計入又於 2026-08-10 因數據無效被撤回，
2026-08-11 真實重跑後再次計入時出現方向相同的 TiDB／YugabyteDB 名次交叉。同一個
反轉現象出現兩次（一次建立在無效數據上、一次建立在有效重跑數據上）具體示範了本
文件的加權設計「對單一項目的星等/權重變動高度敏感」——決策者引用本表時應同時
檢視原始測試證據，不能只看最終加權分數。

**下一步建議**（依風險與可行性排序）：
1. 針對 MySQL Galera Cluster 補一輪與本 PoC 相同口徑（W=128、go-tpc
   TPC-C、READ COMMITTED、`vm-1node`/`vm-3node`）的基準測試，否則它永遠無法
   被公平比較，也無法納入 #6 Failover 這一項。
2. 設計並執行 §3.1 相容性矩陣與 §3.4 Online DDL 測試——這兩項合計 35%
   權重，且往往是實際遷移時最先浮現的痛點，優先度應不低於效能測試。
3. 若條件允許，針對 YugabyteDB P-B 段 2026-08-08 觀察到的執行緒暴增異常安排更長
   時間、更高並發的專門壓力測試，確認觸發條件——2026-08-11 真實重跑未再重現，
   代表這是間歇性穩定性問題而非確定性 bug，若要在生產環境使用 YugabyteDB 建議
   先釐清觸發條件。
4. 若要進一步細分 CockroachDB／YugabyteDB 單節點 kill 的真實中斷時間（目前只知
   「短於 100ms 探測解析度」），需要更高解析度的探測工具重新設計 F1/C4，非本次
   範圍。
5. PITR 與 HTAP／Geo-Distribution 合計僅 9% 權重，可視資源排在較後順序。

---

*本文件由 PoC 測試證據自動彙整而成，任何星等與加權總分皆可回溯至上述引用的
`summary.json`／pipeline-log／dispatch-record；如發現本文件數字與來源檔案
不一致，以來源檔案為準，並回報修正。*
