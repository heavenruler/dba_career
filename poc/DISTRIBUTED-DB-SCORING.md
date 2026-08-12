# 分散式資料庫 PoC 評分表 — MySQL Galera Cluster / TiDB / YugabyteDB / CockroachDB

> 本文件對應 [ITDBA-3596](https://104corp.atlassian.net/browse/ITDBA-3596)。
> 資料口徑：凡標「⭐」評分的項目，皆附測試證據連結；凡本 PoC 尚未實測或無法引用現有
> artifact 佐證的項目，一律標記 **「待測」**，不自行推算或補值。
> 星等換算方式（僅適用於已有實測數字的項目）：於**已測的資料庫之間**依實測數值相對
> 排序給星（最佳 = ⭐⭐⭐⭐⭐，其餘依名次遞減），**不代表跨業界的絕對基準**，換算依據
> 於每個章節內明列，供覆核與覆寫。
>
> **⚠️ 分組評分原則（2026-08-11 調整）**：MySQL Galera Cluster／TiDB（MySQL wire
> protocol）與 YugabyteDB／CockroachDB（PostgreSQL wire protocol）**不放在同一個星等
> 排序或加權總分裡直接比較**——這兩組不只協定不同（協定不同代表遷移時應用層改動成本
> 完全不同量級，不是「效能差一點」的程度差異，是「能不能直接換」的門檻差異），
> `phase-crossregion` chaos/failover 實測也證實兩組在架構上有本質差異（TiDB 將 SQL
> 層與儲存/共識層分離為獨立元件；YugabyteDB／CockroachDB 皆為單一 process 整合
> SQL+共識層），導致同一種故障注入在兩組上呈現完全不同類型的量測結果（TiDB 有真實
> 觀測到的中斷秒數；YugabyteDB／CockroachDB 觀測不到中斷，見 §3.3.1）。把兩組放在
> 同一張表用同一套星等直接排名，會產生看似精確、實則比較基礎不同的假排名。因此本文件
> 星等與加權總分**改為兩個獨立群組分別呈現**：
> - **MySQL 相容群組**：MySQL Galera Cluster vs TiDB
> - **PostgreSQL 相容群組**：YugabyteDB vs CockroachDB
>
> 原始實測數字（tpmC、p99、RTO 秒數等）仍以三/四家並列的表格呈現供交叉參考——這些是
> 客觀量測值本身沒有比較基礎的問題，只有「拿來評星等排名」時才需要分組；讀者仍可自行
> 交叉比對原始數字，本文件只是不再替讀者做跨組的星等/總分排名。

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

## 2. 評分總表（依協定/架構分組）

### 2.1 MySQL 相容群組：MySQL Galera Cluster vs TiDB

| # | 評分細項 | 類別 | 權重 | 驗證方法 | MySQL Galera Cluster | TiDB |
|---|---|---|---:|---|:---:|:---:|
| 1 | MySQL 協定相容性 | MySQL 相容性 | 20% | 既有應用 SQL／ORM 相容性矩陣測試（見 §3.1） | 待測 | 待測 |
| 3 | 單節點/低併發延遲 | 延遲與水平擴展 | 15% | go-tpc TPC-C，`vm-1node` RC，W=128（見 §3.2.1） | 待測§ | 待比較基準（Galera 未測此拓樸） |
| 4 | 水平擴展能力 | 延遲與水平擴展 | 20% | go-tpc TPC-C，`vm-1node`→`vm-3node-haproxy-3s3r` 擴展比（見 §3.2.2） | 待測§ | 待比較基準（Galera 未測此拓樸） |
| 5 | 高併發穩定性 | 延遲與水平擴展 | 15% | go-tpc TPC-C，t=128 5-round range/mean 與 error rate（見 §3.2.3） | 待測§ | 待比較基準（Galera 未測此拓樸） |
| 6 | Failover RTO／RPO | Failover、RTO／RPO、PITR | 6% | `phase-crossregion` chaos 實測，2026-08-11 完成（見 §3.3.1） | 待測¶ | 待比較基準（Galera 未測；TiDB 自身數字見 §3.3.1） |
| 7 | PITR／備份還原 | Failover、RTO／RPO、PITR | 4% | 尚未排入本 PoC 測試矩陣（見 §3.3.2） | 待測 | 待測 |
| 8 | Online DDL 與維運工具 | Online DDL 與維運工具 | 10% | 尚未排入本 PoC 測試矩陣（見 §3.4） | 待測 | 待測 |
| 9 | HTAP／TiFlash | TiDB HTAP／TiFlash | 5% | 分析型查詢尚未排入（見 §3.5） | n/a | 待測 |
| | **合計** | | **95%**† | | | |

† 本群組不計入項目 2（PostgreSQL 相容性，5% 權重），故合計 95%。**目前本群組所有加權
評分項目仍「待測」**，本群組尚無法產出任何星等或加權總分（見 §4.1）。

§ 2026-08-12 已完成 Galera 的 `phase-crossregion` 跨區（`vm-6node`）P-A/P-B 穩態吞吐量
實測，但**拓樸與 §3.2 要求的 `vm-1node`/`vm-3node-haproxy-3s3r` 不同**，不可互相替代
——兩者是不同的測試維度（單機房 vs 跨區），故本欄仍列「待測」。新增的跨區實測數字見
新設 §3.6，與 TiDB 既有的同拓樸數字並列比較。

¶ 2026-08-12 的 Galera 測試僅涵蓋**穩態吞吐量**（P-A×A-S 單寫、P-B×A-A 雙寫），**未包含
任何 chaos/node-kill 注入**，不構成 Failover RTO/RPO 的測試證據，故本欄仍列「待測」。

### 2.2 PostgreSQL 相容群組：YugabyteDB vs CockroachDB

| # | 評分細項 | 類別 | 權重 | 驗證方法 | YugabyteDB | CockroachDB |
|---|---|---|---:|---|:---:|:---:|
| 2 | PostgreSQL 協定相容性 | PostgreSQL 相容性 | 5% | 既有應用 SQL／ORM 相容性矩陣測試（見 §3.1） | 待測 | 待測 |
| 3 | 單節點/低併發延遲 | 延遲與水平擴展 | 15% | go-tpc TPC-C，`vm-1node` RC，W=128（見 §3.2.1） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐☆☆ |
| 4 | 水平擴展能力 | 延遲與水平擴展 | 20% | go-tpc TPC-C，`vm-1node`→`vm-3node-haproxy-3s3r` 擴展比（見 §3.2.2） | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ |
| 5 | 高併發穩定性 | 延遲與水平擴展 | 15% | go-tpc TPC-C，t=128 5-round range/mean 與 error rate（見 §3.2.3） | ⭐⭐⭐⭐☆ | ⭐⭐⭐⭐⭐ |
| 6 | Failover RTO／RPO | Failover、RTO／RPO、PITR | 6% | `phase-crossregion` chaos 實測，2026-08-11 真實重跑完成（見 §3.3.1） | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐☆ |
| 7 | PITR／備份還原 | Failover、RTO／RPO、PITR | 4% | 尚未排入本 PoC 測試矩陣（見 §3.3.2） | 待測 | 待測 |
| 8 | Online DDL 與維運工具 | Online DDL 與維運工具 | 10% | 尚未排入本 PoC 測試矩陣（見 §3.4） | 待測 | 待測 |
| 9 | Geo-Distribution | YugabyteDB／CockroachDB Geo-Distribution | 5% | `phase-crossregion` placement 實測，非正式排名依據（見 §3.5） | 待測 | 待測 |
| | **合計** | | **80%**‡ | | | |

‡ 本群組不計入項目 1（MySQL 相容性，20% 權重），故合計 80%。**已有星等的項目為
#3/#4/#5/#6，合計 56% 權重**（見 §4.2 加權總分）。

> 註：TiDB 與 YugabyteDB／CockroachDB 的原始效能/RTO 數字仍並列於 §3.2、§3.3.1 供交叉
> 參考（例如「TiDB 的 p99 是 YBDB 的幾倍」這類數字本身沒有比較基礎的問題），本文件只是
> 不再把這些數字換算成跨群組的星等或加權總分。

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

星等換算（依 §2 分組規則，僅在 PostgreSQL 相容群組內比較，p99 數值越低越優）：
YugabyteDB 216ms → ⭐⭐⭐⭐⭐；CockroachDB 440ms（約 2 倍） → ⭐⭐⭐☆☆。TiDB 597ms 為
MySQL 相容群組成員，因 Galera 尚無數字可比較，暫不評星等（見 §2.1）。**此比較的
代表點 thread 數不同**（YugabyteDB t=32、CockroachDB t=64，各自為該 DB 的飽和甜點），
是「各自最佳單節點延遲」的比較，不是同 thread 下的直接對照，解讀時需留意。

#### 3.2.2 水平擴展能力（vm-1node → vm-3node-haproxy-3s3r）

| DB | vm-1node tpmC | haproxy-3s3r tpmC（t=128） | 擴展倍率 | vs direct-3s3r 增益 |
|---|---:|---:|---:|---:|
| MySQL Galera Cluster | 待測 | 待測 | 待測 | 待測 |
| TiDB | 13,064 | 26,947 | **2.06×** | +78.7% |
| YugabyteDB | 11,436 | 15,632 | **1.37×** | +79.1% |
| CockroachDB | 9,134 | 15,033 | **1.65×** | +37.5% |

星等換算（依 §2 分組規則，僅在 PostgreSQL 相容群組內比較，擴展倍率越高越優）：
CockroachDB 1.65× → ⭐⭐⭐⭐⭐；YugabyteDB 1.37× → ⭐⭐⭐⭐☆。TiDB 2.06× 為 MySQL
相容群組成員，因 Galera 尚無數字可比較，暫不評星等（見 §2.1）。理論擴展上限為
3×（3 節點）；三家皆未達理論值，反映 RF=3 寫入 quorum 成本與各自架構的協調開銷。

#### 3.2.3 高併發穩定性（t=128，5-round range/mean 與 error rate）

| DB | tpmC (t=128 mean) | range/mean（5 輪間變異） | error rate |
|---|---:|---:|---:|
| MySQL Galera Cluster | 待測 | 待測 | 待測 |
| TiDB | 26,947 | 7.4% | 0.000% |
| YugabyteDB | 15,632 | 7.1% | 0.000% |
| CockroachDB | 15,033 | 6.9%（t=64 最高達 8.9%） | 0.000% |

星等換算（依 §2 分組規則，僅在 PostgreSQL 相容群組內比較，range/mean 越低越穩定；
兩家 error rate 皆 0%，本項不作額外區分）：CockroachDB 6.9% → ⭐⭐⭐⭐⭐；YugabyteDB
7.1% → ⭐⭐⭐⭐☆（差距在 0.5 個百分點內，實務上可視為同級，僅供參考排序）。TiDB
7.4% 為 MySQL 相容群組成員，因 Galera 尚無數字可比較，暫不評星等（見 §2.1）。

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
- **星等換算**（依 §2 分組規則，僅在 PostgreSQL 相容群組內比較；依 F2 真實復原時間為
  主要依據，F1/C4 觀測結果與 write-reject 正確性為輔助判斷）：YugabyteDB F2 最快（~3s）
  且 F1/C4 全數無可觀測中斷、write-reject 乾淨 → ⭐⭐⭐⭐⭐；CockroachDB F2 居中（~7s）
  且 F1/C4 同樣全數無可觀測中斷，但 write-reject 需應用層額外處理 → ⭐⭐⭐⭐☆。
  **TiDB 為 MySQL 相容群組成員，因 Galera 完全未納入 chaos 測試矩陣，暫不評星等**（見
  §2.1）——TiDB 自身的真實數字（F2≈39~44s，F1/C4 有 6.68~8.4s 的真實觀測中斷）仍列於
  上表供未來與 Galera 比較時使用，也可作為「架構差異如何反映在故障恢復行為上」的參考：
  TiDB 因 SQL 層與儲存/共識層分離，單節點 kill 造成的 client 可感知延遲明顯長於
  YugabyteDB／CockroachDB 這類單一 process 整合架構的等效機制，這是架構差異的直接體現，
  不代表 TiDB 的容錯能力「較差」。
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

### 3.5 TiDB HTAP／TiFlash 與 YugabyteDB／CockroachDB Geo-Distribution

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

### 3.6 MySQL 相容群組：MySQL Galera Cluster 跨區 P-A/P-B 穩態吞吐量實測（2026-08-12）

> **狀態說明**：本節是 2026-08-12 新增的實測數據，**與 §2.1 加權評分項目 #3/#4/#5/#6
> 是不同的測試維度**——本節拓樸為 `phase-crossregion` 的 `vm-6node`（3 台 IDC + 3 台
> GCP 組成單一 Galera 叢集，同步多主複寫），不是 §3.2 的 `vm-1node`/`vm-3node-haproxy`；
> 且本節只測穩態吞吐量，**未含任何 chaos/node-kill 注入**，不構成 §3.3.1 Failover
> 的測試證據。比照本文件對 TiDB／YugabyteDB／CockroachDB 跨區 P-A/P-B 數據的既有
> 處理方式（見 §3.5 說明），**本節數據不換算成星等或計入加權總分**，僅作為原始數字
> 並列比較——但作為「同一套硬體/topology 下 Galera vs TiDB 實測比較」，這是本 PoC
> 目前唯一一組 Galera 有真實數字可對照的資料，資訊量遠高於單純的「待測」。
>
> 測試方法：go-tpc TPC-C，W=128，READ COMMITTED，5-round mean，
> `tests/common/summary-from-stdout.py` 彙整。Galera 部署與測試設計見
> [`ansible/playbooks/galera-vm6.yml`](./ansible/playbooks/galera-vm6.yml) 開頭說明、
> [`phase-crossregion/GALERA-EXECUTION-PLAN.md`](./phase-crossregion/GALERA-EXECUTION-PLAN.md)。
> Galera 原始 artifact：`phase-crossregion/results-galera-w128/{P-A-w128,P-B-aa-w128}/summary.json`。
> TiDB 原始 artifact：`phase-crossregion/results/x-cross/baseline/w128/20260717T143238+0800/`
> 與 `.../smoke/early-runs/20260731T204801+0800/`（詳見
> [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./phase-crossregion/XCROSS-PA-VS-PB-FINAL-COMPARISON.md)、
> [`XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`](./phase-crossregion/XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)）。
> 兩家皆 `N=1`、非同批次執行（Galera 2026-08-12、TiDB 2026-07-17/07-31），不構成
> 統計顯著結論，僅供方向性參考。

#### 3.6.1 P-A×A-S（單寫 IDC，無跨區寫入衝突）

| threads | Galera tpmC | Galera NEW_ORDER p50 | Galera error rate | TiDB tpmC | TiDB error rate |
|---|---:|---:|---:|---:|---:|
| 16 | 284.9 | 2.1s | 0.000% | 1,584.4 | 0.000% |
| 32 | 304.4 | 4.1s | 0.000% | 3,614.3 | 0.000% |
| 64 | 291.8 | 5.1s | 0.077% | 7,176.1 | 0.000% |
| 128 | 298.8 | 12.1s | 0.006% | 12,526.5 | 0.000% |

**核心發現**：Galera 的 tpmC 在四個 thread level 幾乎打平（285~304，範圍僅
±3.5%），TiDB 則隨 thread 數持續線性擴展（1,584→12,527，8× 成長）。thread=128 時
TiDB 吞吐量是 Galera 的 **41.9 倍**。這不是「TiDB 調校比較好」的程度差異，而是兩種
複寫架構的本質差異：Galera 的同步憑證複寫（certification-based replication）讓
每筆交易在 commit 前都要等全叢集憑證完成，這個序列化點很早就把單寫吞吐量封頂；
TiDB 的 leader-based Raft 複寫允許多個 region 的 leader 平行處理不同 key range 的
寫入，擴展空間大得多。延遲面也對應：Galera 的 NEW_ORDER p50 從 2.1s（t=16）一路
惡化到 12.1s（t=128），代表多開 thread 只是讓交易排隊等憑證，換不到更高吞吐量。

#### 3.6.2 P-B×A-A（IDC+GCP 雙寫，跨區寫入衝突情境）

**IDC 端 tpmC：**

| threads | Galera IDC tpmC | Galera IDC error rate | TiDB IDC tpmC | TiDB IDC error rate |
|---|---:|---:|---:|---:|
| 16 | 410.5 | 0.004% | 6,141.3 | 0.000% |
| 32 | 294.6 | 0.036% | 8,868.2 | 0.000% |
| 64 | 279.9 | 0.128% | 6,717.9 | 0.000% |
| 128 | 249.9 | 0.606% | 4,413.9 | 0.000% |

**GCP 端吞吐量與衝突/錯誤率：**

| threads | Galera GCP NEW_ORDER TPM | Galera GCP 寫入失敗率* | TiDB GCP tpmC | TiDB GCP 錯誤率 |
|---|---:|---:|---:|---:|
| 16 | 6.6 | 見下方彙總 | 1,600.2 | 見下方彙總 |
| 32 | 9.1 | 見下方彙總 | 2,619.3 | 見下方彙總 |
| 64 | 14.0 | 見下方彙總 | 2,978.3 | 見下方彙總 |
| 128 | 17.9 | 見下方彙總 | 2,966.6 | 見下方彙總 |

\* Galera 未逐 thread-level 拆分錯誤率，以下為 4 個 thread level 加總的 GCP 端全交易
彙總（依 `summary.json` 的 `gcp_side.thread_results[*].{NEW_ORDER,PAYMENT,...}` 各
`total_count`/`error_count` 加總計算）：

| 交易類型 | 成功 | 失敗 | 失敗率 |
|---|---:|---:|---:|
| NEW_ORDER | 839 | 238 | 22.1% |
| PAYMENT | 214 | 941 | **81.5%** |
| DELIVERY | 95 | 15 | 13.6% |
| ORDER_STATUS | 90 | 0 | 0% |
| STOCK_LEVEL | 107 | 0 | 0% |
| **全部合計** | **1,345** | **1,194** | **47.0%** |

對照組：TiDB GCP 端全交易彙總錯誤率約 **0.158%**（
[`XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`](./phase-crossregion/XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)
§5，主因是 `context deadline exceeded`／`query execution canceled`，即跨區鎖等待
逾時，不是真正的寫入衝突拒絕）。

**核心發現**：Galera 在 P-B 雙寫情境下的 GCP 端整體失敗率（47.0%）比 TiDB
（0.158%）高約 **300 倍**，且失敗性質不同——Galera 是**樂觀憑證複寫的真實衝突拒絕**
（wsrep certification failure：IDC 與 GCP 同時對同一列送出交易，先憑證成功的一方
贏，另一方直接 abort），TiDB 則是**悲觀鎖跨區等待逾時**（交易會排隊等鎖，只是等
太久被判定逾時，不是被判定衝突）。PAYMENT 交易的失敗率（81.5%）遠高於其他交易
類型，這與 PAYMENT 更新 `warehouse.w_ytd`／`district.d_ytd` 這類高度熱點列
（每筆 PAYMENT 都會更新同一列）完全吻合——這正是 Galera 官方文件明確警告的
「多主寫入熱點衝突」情境，本次測試等於直接把這個已知限制在真實跨區環境下量測
出具體數字。IDC 端本身的錯誤率仍低（0.004%~0.606%），代表衝突主要由「輸家」
（GCP 端）承擔，IDC 端交易多半能成功憑證。

TiDB 在 P-B 情境下也出現 thread=128 時 IDC 端吞吐量從 th=32 的 8,868 驟降到
4,413（－50%），推測與跨區悲觀鎖競爭有關（見
[`XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`](./phase-crossregion/XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)，
該報告本身也標註此為推測、未證實）；Galera 的 IDC 端吞吐量則是從一開始（t=16）
就已經逼近其單寫上限附近小幅波動（410→295→280→250），沒有 TiDB 那種「先升後崩」
的曲線——因為 Galera 的吞吐量瓶頸在更早的憑證序列化點，跨區鎖競爭造成的邊際
影響相對有限。

**決策意涵**：若應用情境需要真正的多主動寫（P-B 這類雙活寫入），Galera 的樂觀
複寫模型會直接把跨區衝突轉嫁成大量交易失敗，需要應用層自行處理重試邏輯（且
重試本身在高熱點衝突下未必能收斂）；TiDB 的悲觀鎖模型則是把跨區衝突轉嫁成
延遲增加與少量逾時，應用層處理相對單純（重試邏輯成熟度需求較低）。這是選型
時的關鍵質性差異，比單純比較 tpmC 數字更重要。

## 4. 加權總分（依 §2 分組規則，分別計算）

> 計算方式：僅對**已有實測星等**的項目計入加權分母重新正規化，未測項目**不**用任何
> 預設值替代。**不同群組（MySQL 相容 vs PostgreSQL 相容）的加權總分不互相比較**——
> 兩組驗證方法/協定/架構皆不同，見文件開頭「分組評分原則」。

### 4.1 MySQL 相容群組：MySQL Galera Cluster vs TiDB

| DB | 已計入項目 | 已計入權重合計 | 加權總分 |
|---|---|---:|---:|
| MySQL Galera Cluster | 無 | 0% | 待測（§2.1 加權項目皆待測；§3.6 有跨區穩態吞吐量實測但非加權評分項目） |
| TiDB | 無（本群組內無其他已測對象可比較） | — | 待評（見下方說明） |

本群組**目前無法產出任何加權總分**：§2.1 的 4 個可評分項目（#3/#4/#5/#6）皆要求
`vm-1node`/`vm-3node-haproxy` 拓樸的延遲/擴展數字或 chaos/failover 數字，Galera
目前只有 §3.6 的跨區（`vm-6node`）穩態吞吐量數字，測試維度不同，不能互相替代
——「星等」的定義是相對排序，本群組內沒有第二個同維度已測對象可供排序，勉強給
TiDB 滿星等同於自我比較沒有意義。待 Galera 補測 §3.2 同拓樸基準（延遲/擴展）與
§3.3.1 chaos/failover 後，才能回填本節。

### 4.2 PostgreSQL 相容群組：YugabyteDB vs CockroachDB

| DB | 已計入項目 | 已計入權重合計 | 加權總分（百分制） |
|---|---|---:|---:|
| YugabyteDB | #3 #4 #5 #6 | 56% | (5×15 + 4×20 + 4×15 + 5×6) / 56 × 20 = **87.5** |
| CockroachDB | #3 #4 #5 #6 | 56% | (3×15 + 5×20 + 5×15 + 4×6) / 56 × 20 = **87.1** |

> 計算範例（YugabyteDB）：`(5×15 + 4×20 + 4×15 + 5×6) ÷ (15+20+15+6) × 20
> = 245 ÷ 56 × 20 = 87.5`。乘以 20 是把 1-5 星換算為百分制的比例常數（5 星 = 100 分）。
> **兩者差距僅 0.4 分（87.1-87.5），且僅代表 56% 的總權重**——在其餘 44% 權重
> （相容性、PITR、DDL、Geo-Distribution）補測前，不宜下「YugabyteDB 優於
> CockroachDB」或反之的結論。這個 0.4 分的差距本身也遠小於量測不確定度（F1/C4 探測
> 解析度 100ms 級、單次樣本雜訊，見 §3.3.1 已知限制），**在群組內部兩者也應視為
> 非常接近，而非有明確優劣**——任一項目的星等微調都可能翻轉排序，這具體示範了本文件
> 加權設計對結論高度敏感的既有風險，使用本表做決策時應同時檢視原始數據而非只看最終
> 加權分數。

## 5. 最終結論（依 §2 分組規則，分別敘述）

> 兩組結論**互不比較**——決策情境本身通常也是分岔的：若受限於必須沿用 MySQL 協定
> （既有應用/工具鏈不可改），比較基礎是 Galera vs TiDB；若能接受換成 PostgreSQL 協定，
> 比較基礎是 YugabyteDB vs CockroachDB。兩條路線目前都不構成「整體最適合取代
> MySQL Galera Cluster」的完整答案——相容性、PITR、維運工具（合計 34~39% 權重視群組）
> 兩組皆完全沒有可用的實測數據。

### 5.1 MySQL 相容群組：MySQL Galera Cluster vs TiDB

**現況**：本群組**目前無法產出任何星等或加權總分**（見 §4.1）——§2.1 要求的 4 個
可評分項目（同拓樸延遲/擴展、chaos/failover）Galera 仍待測，TiDB 雖已有完整的
§3.2 效能數字與 §3.3.1 Failover 真實數字，但沒有同拓樸/同維度的 Galera 數字可供
相對排序。**2026-08-12 新增**：Galera 已完成跨區（`vm-6node`）P-A/P-B 穩態吞吐量
實測並與 TiDB 同拓樸數字並列比較（見 §3.6）——這不是 §2.1 要求的測試維度，不計入
星等，但已是本 PoC 目前唯一一組「Galera vs TiDB 同硬體環境實測比較」的資料，
質性發現足以影響選型判斷（見下方）。

**§3.6 核心發現**（跨區穩態吞吐量，非群組內星等評分，但為重要參考）：單寫情境
（P-A×A-S）TiDB thread=128 吞吐量是 Galera 的 **41.9 倍**（12,526.5 vs 298.8
tpmC），且 Galera 吞吐量在四個 thread level 幾乎打平、不隨並發數擴展，反映
Galera 同步憑證複寫很早就把單寫吞吐量封頂；雙寫情境（P-B×A-A）Galera 的 GCP 端
整體交易失敗率（47.0%）比 TiDB（0.158%）高約 300 倍，且失敗性質是**真實的樂觀
複寫衝突拒絕**（wsrep certification failure），而非 TiDB 的**悲觀鎖跨區逾時**
——這代表若應用情境需要真正的跨區多主動寫，Galera 需要應用層自行處理大量交易
失敗與重試，這是比單純效能數字更關鍵的架構限制。

**TiDB 自身數字**（供與 Galera §3.6 比較時的基準，非群組內排名）：`vm-1node`/
`vm-3node` 拓樸下單節點延遲 597ms p99（t=128）、擴展倍率 2.06×（此為三家 DB 中
最高的擴展倍率原始數字，即使不納入跨組排名，這個絕對數字本身仍值得記錄）、高
併發穩定性 range/mean 7.4%；跨區拓樸下 P-A×A-S thread=128 吞吐量 12,526.5 tpmC、
P-B×A-A IDC 端 thread=32 峰值 8,868.2 tpmC（thread=128 時降至 4,413.9，推測與跨區
悲觀鎖競爭有關，未證實）；Failover 方面，F2 真實復原時間 39~44s（且多數時間屬
「儲存層健康但 SQL 層仍不可寫」的區間），F1/C4 單節點 kill 有 6.68~8.4s 的真實
可觀測中斷，write-reject 判定乾淨（`PD server timeout`）。

**不能下的結論**：不能因為 §3.6 的跨區吞吐量/衝突率差距就直接斷言「TiDB 整體優於
Galera」——§2.1 要求的相容性、PITR、Online DDL、同拓樸延遲/擴展、chaos/failover
仍全數待測，§3.6 只涵蓋其中一個面向（跨區穩態吞吐量與雙寫衝突行為）；也不能把
TiDB 的 Failover 秒數與 YugabyteDB／CockroachDB 的「無可觀測中斷」做倍率換算（見
§3.3.1，兩者不是同一種量測基準）。

### 5.2 PostgreSQL 相容群組：YugabyteDB vs CockroachDB

**現況**：兩家皆已完成 §3.2 效能測試與 §3.3.1 Failover 真實重跑（2026-08-11），
加權總分 YugabyteDB（87.5）／CockroachDB（87.1），差距僅 0.4 分（見 §4.2）——**兩者
在目前已測的 56% 權重範圍內表現非常接近，不宜下「何者較優」的結論**。

**核心發現**：F2（3 台 IDC 同時停止+重啟）真實復原時間 YugabyteDB（≈3s）明顯快於
CockroachDB（≈7s），這個方向性排序在兩次獨立執行（2026-08-08、2026-08-11）中重現，
是兩者之間信心最高的差異點；F1/C4 單節點 kill 兩家皆兩次獨立執行觀測不到中斷（探測
解析度 100ms 級）；CockroachDB 在 quorum 遺失時回報 `ambiguous`（無法確認是否已
提交，兩次重跑皆確認），需要應用層額外處理重試/查詢邏輯才能確認最終狀態，這是兩者
唯一觀察到的正確性層面差異；YugabyteDB 曾在 2026-08-08 觀察到一次真實的 master 執行緒
暴增穩定性異常（2026-08-11 重跑未再重現，屬間歇性問題）。

**不能下的結論**：不能僅憑 0.4 分的加權總分差距判定何者較優——這個差距遠小於量測
本身的不確定度（F1/C4 探測解析度、單次樣本雜訊）；不能把 `phase-crossregion` 的
P-A/P-B placement 探索性數據當作 Geo-Distribution 的正式評分依據（該 scope 本身
`baseline_eligible=false`，目前仍列「待測」）。

### 5.3 兩組共通的下一步建議（依風險與可行性排序）

1. 針對 MySQL Galera Cluster 補一輪與本 PoC §3.2 相同口徑（`vm-1node`/
   `vm-3node-haproxy-3s3r` 拓樸）的基準測試，以及 §3.3.1 同規格的 chaos/failover
   測試，否則 MySQL 相容群組永遠無法產出星等或加權總分（見 §5.1）。
   **2026-08-12 已完成的部分**：跨區（`vm-6node`）P-A/P-B 穩態吞吐量與 TiDB 的
   實測比較（見 §3.6）——這是不同拓樸/不同維度的資料，不能取代本項待補的
   `vm-1node`/`vm-3node` 基準測試與 chaos/failover 測試，但已提供了「Galera vs
   TiDB 同硬體環境比較」的第一手質性證據（吞吐量上限差距、雙寫衝突行為），
   後續若要補測 chaos/failover，建議設計 §5.3 補充：Galera 無 leader/lease，
   既有 F1/C4（leader kill）測試框架不能直接套用，需另外設計節點 kill／
   quorum 邊界測試情境（詳見
   [`GALERA-EXECUTION-PLAN.md`](./phase-crossregion/GALERA-EXECUTION-PLAN.md) §Stage 5）。
2. 設計並執行 §3.1 相容性矩陣與 §3.4 Online DDL 測試——這兩項在兩個群組合計皆佔
   相當權重，且往往是實際遷移時最先浮現的痛點，優先度應不低於效能測試。
3. 若條件允許，針對 YugabyteDB 2026-08-08 觀察到的 master 執行緒暴增異常安排更長
   時間、更高並發的專門壓力測試，確認觸發條件——2026-08-11 真實重跑未再重現，代表
   這是間歇性穩定性問題而非確定性 bug，若要在生產環境使用 YugabyteDB 建議先釐清
   觸發條件。
4. 若要進一步細分 CockroachDB／YugabyteDB 單節點 kill 的真實中斷時間（目前只知
   「短於 100ms 探測解析度」），需要更高解析度的探測工具重新設計 F1/C4，非本次範圍。
5. PostgreSQL 相容群組的 Geo-Distribution（5% 權重）與兩組共通的 PITR（4~9% 視群組）
   合計權重較低，可視資源排在較後順序。

---

*本文件由 PoC 測試證據自動彙整而成，任何星等與加權總分皆可回溯至上述引用的
`summary.json`／pipeline-log／dispatch-record；如發現本文件數字與來源檔案
不一致，以來源檔案為準，並回報修正。*
