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

### 3.6 MySQL 相容群組：Percona XtraDB Cluster 8.4（PXC，Galera）跨區 P-A/P-B 穩態吞吐量實測（2026-08-12）

> **狀態說明**：本節是 2026-08-12 新增的實測數據，**與 §2.1 加權評分項目 #3/#4/#5/#6
> 是不同的測試維度**——本節拓樸為 `phase-crossregion` 的 `vm-6node`（3 台 IDC + 3 台
> GCP 組成單一 PXC 叢集，同步多主複寫），不是 §3.2 的 `vm-1node`/`vm-3node-haproxy`；
> 且本節只測穩態吞吐量，**未含任何 chaos/node-kill 注入**，不構成 §3.3.1 Failover
> 的測試證據。比照本文件對 TiDB／YugabyteDB／CockroachDB 跨區 P-A/P-B 數據的既有
> 處理方式（見 §3.5 說明），**本節數據不換算成星等或計入加權總分**，僅作為原始數字
> 並列比較——但作為「相同 VM inventory、相同 W/threads/rounds 與跨區 client 位置下
> PXC vs TiDB 實測比較」（**不是**「同一套內部架構」的比較，兩家的複寫協定、
> placement semantics、程序配置皆不同，見下方「比較邊界」），這是本 PoC 目前唯一
> 一組 Galera 有真實數字可對照的資料，資訊量遠高於單純的「待測」。
>
> **比較邊界**：PXC 的 P-A/P-B 是 **client 連線目標**差異（單寫 IDC vs 雙寫
> IDC+GCP，同一組伺服器部署不變）；TiDB 的 P-A/P-B 是 **server-side placement
> policy** 差異（leader 集中 IDC vs leader 跨區散布）。兩者是方向性的架構對照，
> **不是語意完全等價的 A/B test**。此外 P-B 情境下雙端（IDC+GCP）同時各自發起
> 獨立 offered load，不是「同一份 workload 拆給兩端」，因此 §3.6 的比較**只在同
> profile／同 side／同 thread level 下**有意義，不可拿 P-A 的單端數字與 P-B 的
> 雙端合計數字做擴展率換算。
>
> **P-B artifact lineage**（引用前務必知悉）：PXC P-B 沿用同一 6-node 叢集上 P-A
> 已完成的 W=128 prepare dataset（`prepare-bridge.json` 內明確記錄），並非獨立的
> P-B prepare/gate/collect 鏈——其 `.prepare.done`／`gate/gcp-replica-gate-galera.txt`
> 是 P-A 該兩份檔案的逐位元組副本（topology/ts 欄位字面值仍是 P-A 的，這是
> prepare-bridge 機制的既有設計，不是資料錯置）；`env/`／`db-config/` 為空（缺
> 獨立 collect 證據）；`.suite.done` 為 operator 事後補寫（非原生產出）。詳見
> [`results/x-cross/README.md`](./results/x-cross/README.md) 的 lineage caveat 與該
> suite 目錄下的 `fetch-receipt.json`。
>
> 測試方法：go-tpc TPC-C，W=128，READ COMMITTED，5-round mean，
> `tests/common/summary-from-stdout.py` 彙整。PXC 部署與測試設計見
> [`ansible/playbooks/galera-vm6.yml`](./ansible/playbooks/galera-vm6.yml) 開頭說明、
> [`phase-crossregion/GALERA-EXECUTION-PLAN.md`](./phase-crossregion/GALERA-EXECUTION-PLAN.md)。
> PXC canonical artifact：
> [`results/x-cross/smoke/early-runs/20260812T132801+0800/`](./results/x-cross/smoke/early-runs/20260812T132801+0800/)
> 下的 `galera-vm-6node-{P-A-rc-20260811T201242+0800,P-B-aa-rc-20260812T093709+0800}/summary.json`
> （SHA-256：P-A=`9b2a2c92...61893`，P-B=`51315aba...c89eb1ec`，完整值見該目錄
> `fetch-receipt.json`）。TiDB canonical artifact：
> [`baseline/w128/20260717T143238+0800/`](./results/x-cross/baseline/w128/20260717T143238+0800/)（P-A）與
> [`smoke/early-runs/20260731T204801+0800/`](./results/x-cross/smoke/early-runs/20260731T204801+0800/)（P-B）（詳見
> [`XCROSS-PA-VS-PB-FINAL-COMPARISON.md`](./phase-crossregion/XCROSS-PA-VS-PB-FINAL-COMPARISON.md)、
> [`XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`](./phase-crossregion/XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)）。
> 兩家皆 `N=1`、非同批次執行（Galera 2026-08-12、TiDB 2026-07-17/07-31），不構成
> 統計顯著結論，僅供方向性參考。

#### 3.6.1 P-A×A-S（單寫 IDC，無跨區寫入衝突）

| threads | Galera tpmC_mean | Galera round range/mean | Galera NEW_ORDER p50 | Galera error rate | TiDB tpmC_mean | TiDB round range/mean | TiDB error rate |
|---|---:|---:|---:|---:|---:|---:|---:|
| 16 | 284.9 | 23.0% | 2.1s | 0.000% | 1,584.4 | 52.8% | 0.000% |
| 32 | 304.4 | 13.8% | 4.1s | 0.000% | 3,614.3 | 14.3% | 0.000% |
| 64 | 291.8 | 43.8% | 5.1s | 0.077% | 7,176.1 | 4.3% | 0.000% |
| 128 | 298.8 | 7.5% | 12.1s | 0.006% | 12,526.5 | 5.7% | 0.000% |

**Fact**：四個 thread-level 的 Galera tpmC_mean 彼此接近（285~304），thread=128 時
TiDB tpmC_mean 是 Galera 的 **41.9 倍**（12,526.5 / 298.8）。但 **round-to-round
穩定性並不好**：Galera 的 round range/mean 分別為 23.0%／13.8%／43.8%／7.5%（t=64
單一水位內 5 輪之間變異幅度達 43.8%），**「thread-level mean 彼此接近」不代表
「每輪穩定」**，兩者是不同的統計描述，不可混為一談。TiDB 也有跨 round 變異（t=16
時 range/mean 高達 52.8%），只是在其他三個 thread level 收斂較快（4.3%~14.3%）。
Galera 的 NEW_ORDER p50 隨 thread 數上升（2.1s→12.1s），TiDB 在本次代表點的吞吐量
隨併發提高而**明顯上升**（1,584→12,527）——這裡刻意不用「線性擴展」，因為只有
4 個離散取樣點，且中間存在跨 round 變異，不足以判定嚴格線性關係。

**Inference（非 fact，缺乏充分反證前不應視為定論）**：P-A snapshot 中多個節點的
`wsrep_flow_control_paused` 約 0.73（即 replication 累積時間中約 73% 處於 flow
control 暫停狀態），GCP 端節點的 `wsrep_local_recv_queue_avg`（147~237）明顯高於
IDC 端節點（0.1~7.6）——**但這是整個 run 結束後的單點 status snapshot，不是嚴格
的 timed-run 前後 delta**，無法排除其他時段（如 warmup）貢獻的累積值。以此為線索，
跨區接收端落後與 Galera flow control 很可能是吞吐量受限的重要因素之一；同步
writeset 排序／憑證（certification）本身與跨區 RTT 也構成成本。**不應把單一根因
鎖死為「certification serialization」**——這是待驗證的推論，不是本次證據能單獨
證實的結論；若要精確拆解占比，需要 workload 前後的 wsrep counter delta（詳見
§5.3 建議）。

#### 3.6.2 P-B×A-A（IDC+GCP 雙寫，跨區寫入衝突情境）

**IDC 端 tpmC：**

| threads | Galera IDC tpmC | Galera IDC error rate | TiDB IDC tpmC | TiDB IDC error rate |
|---|---:|---:|---:|---:|
| 16 | 410.5 | 0.004% | 6,141.3 | 0.000% |
| 32 | 294.6 | 0.036% | 8,868.2 | 0.000% |
| 64 | 279.9 | 0.128% | 6,717.9 | 0.000% |
| 128 | 249.9 | 0.606% | 4,413.9 | 0.000% |

**GCP 端吞吐量與成功/失敗量：**

| threads | Galera GCP 成功 NEW_ORDER TPM | TiDB GCP tpmC |
|---|---:|---:|
| 16 | 6.6 | 1,600.2 |
| 32 | 9.1 | 2,619.3 |
| 64 | 14.0 | 2,978.3 |
| 128 | 17.9 | 2,966.6 |

Galera 未逐 thread-level 拆分錯誤率，以下為 4 個 thread level 加總的 GCP 端全交易
彙總（依 `summary.json` 的 `gcp_side.thread_results[*].{NEW_ORDER,PAYMENT,...}` 各
`total_count`/`error_count` 加總計算，**Fact**）：

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
逾時，不是「衝突拒絕」性質的錯誤）。47.0 / 0.158 ≈ 297.5，僅能寫「約 300 倍」，
不宜宣稱精確倍率。

**Fact**：raw go-tpc stdout 顯示 Galera GCP 端錯誤絕大多數（2,438 筆）是 MySQL
`Error 1213 (40001): Deadlock found when trying to get lock`，另有 184 筆
`Error 1205`（lock wait timeout）與 2 筆 `Error 1180`。**本次未擷取 workload 前後
的 `wsrep_local_cert_failures`／`wsrep_local_bf_aborts` counter delta**（P-B 因
上述 collect 缺失，連單點 snapshot 都沒有）。

**不可下的推論**：**不得**直接把這些 `Error 1213` 全部定性為「wsrep certification
failure」——MySQL/InnoDB 本身在單機高併發下也會產生一般的 local deadlock，兩者
對 client 呈現的錯誤碼完全相同，沒有 wsrep counter 佐證無法區分兩者各占多少比例。
同理**不得**斷言「IDC 是贏家、GCP 是輸家」——目前只能說**觀測到的錯誤高度集中在
GCP client 端**，IDC 端的 error_rate（0.004%~0.606%）遠低於 GCP 端的彙總失敗率
（47.0%），但這是「GCP 端記錄到更多失敗」的觀測，不是「IDC 端交易在衝突中獲勝」
的因果證明。**可以合理成立的中性表述**：錯誤型態與「Galera 多主寫入衝突」及
「InnoDB local deadlock」皆相容；PAYMENT 交易更新 `warehouse.w_ytd`／
`district.d_ytd` 這類高度熱點列（每筆 PAYMENT 皆更新同一列）確實是常見的機制性
解釋候選（其 81.5% 失敗率遠高於其他交易類型，方向與此假說一致），但**根因仍需
補測 wsrep counter delta 才能確認**，本次不構成證實。

TiDB 在 P-B 情境下也出現 thread=128 時 IDC 端吞吐量從 th=32 的 8,868 驟降到
4,413（－50%），[`XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md`](./phase-crossregion/XCROSS-PB-AA-CLOSING-REPORT-DRAFT.md)
推測與跨區悲觀鎖競爭有關，**該報告本身也標註此為推測、未證實**，此處沿用同樣的
不確定性標註；Galera 的 IDC 端吞吐量則是從一開始（t=16）就在其單寫情境的量級
附近小幅波動（410→295→280→250），沒有 TiDB 那種「先升後崩」的曲線，但**兩者
背後的機制是否相同（是否都是跨區鎖/憑證競爭飽和）本次未做進一步驗證**，僅記錄
現象上的曲線形狀差異。

**決策意涵（基於目前證據的合理方向，非精確定論）**：若應用情境需要真正的多主
動寫（P-B 這類雙活寫入），Galera 目前觀測到的 GCP 端高失敗率（47.0%，型態
與多主衝突或本地鎖爭用皆相容）代表應用層很可能需要自行處理較高比例的交易失敗
與重試邏輯；TiDB 觀測到的 GCP 端低錯誤率（0.158%，型態偏向鎖等待逾時）代表
應用層需處理的異常比例小得多。**這個方向性差異值得記錄**，但由於兩家的錯誤
分類機制不同、Galera 缺 wsrep counter 佐證根因，**不宜僅憑倍率數字做「哪家架構
更適合雙主寫」的最終品質排名**，只能作為選型時需要進一步驗證的方向。

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

### 5.1 MySQL 相容群組：Percona XtraDB Cluster 8.4（PXC，Galera）vs TiDB

**現況**：本群組**目前無法產出任何星等或加權總分**（見 §4.1）——§2.1 要求的 4 個
可評分項目（同拓樸延遲/擴展、chaos/failover）Galera 仍待測，TiDB 雖已有完整的
§3.2 效能數字與 §3.3.1 Failover 真實數字，但沒有同拓樸/同維度的 Galera 數字可供
相對排序。**2026-08-12 新增**：PXC 已完成跨區（`vm-6node`）P-A/P-B 穩態吞吐量
實測並與 TiDB 相同 VM inventory／W／threads／rounds 下的數字並列比較（見
§3.6）——**MySQL 相容群組完整加權評分尚未完成**；這不是 §2.1 要求的測試維度，
不計入星等，但已是本 PoC 目前唯一一組「PXC vs TiDB 跨區穩態對照」的資料，方向性
發現足以納入選型考量（見下方，注意 fact 與 inference 的區分）。

**§3.6 方向性發現**（跨區穩態吞吐量，非群組內星等評分，fact/inference 分層見
§3.6 原文，此處僅摘要方向）：單寫情境（P-A×A-S）TiDB thread=128 吞吐量是 Galera
的 **41.9 倍**（12,526.5 vs 298.8 tpmC，fact）；Galera 四個 thread-level 的
tpmC_mean 彼此接近，但個別 thread-level 的 round-to-round 變異其實不小（range/mean
最高達 43.8%），可能的貢獻因素包含跨區 flow control 暫停（`wsrep_flow_control_paused`
≈0.73，run 後單點 snapshot）與 GCP 端 recv queue 偏高，但**具體占比與是否為唯一
根因未經本次證據證實**（inference）。雙寫情境（P-B×A-A）Galera 的 GCP 端整體
交易失敗率（47.0%）比 TiDB（0.158%）高約 300 倍（fact）；Galera 端錯誤絕大多數
是 MySQL `Error 1213 Deadlock`，型態與「多主複寫衝突」及「InnoDB local deadlock」
皆相容，但**本次未擷取 wsrep certification counter，不能斷定是哪一種**（inference，
不是 fact）——這代表若應用情境需要真正的跨區多主動寫，Galera 觀測到的高失敗率
方向上代表應用層需要處理更多交易失敗/重試，但具體架構歸因仍待補測確認。

**TiDB 自身數字**（供與 PXC §3.6 比較時的基準，非群組內排名）：`vm-1node`/
`vm-3node` 拓樸下單節點延遲 597ms p99（t=128）、擴展倍率 2.06×（此為三家 DB 中
最高的擴展倍率原始數字，即使不納入跨組排名，這個絕對數字本身仍值得記錄）、高
併發穩定性 range/mean 7.4%；跨區拓樸下 P-A×A-S thread=128 吞吐量 12,526.5 tpmC
（t=16 時 round range/mean 高達 52.8%，非嚴格線性擴展）、P-B×A-A IDC 端
thread=32 峰值 8,868.2 tpmC（thread=128 時降至 4,413.9，來源報告推測與跨區
悲觀鎖競爭有關，未證實）；Failover 方面，F2 真實復原時間 39~44s（且多數時間屬
「儲存層健康但 SQL 層仍不可寫」的區間），F1/C4 單節點 kill 有 6.68~8.4s 的真實
可觀測中斷，write-reject 判定乾淨（`PD server timeout`）。

**不能下的結論**：不能因為 §3.6 的跨區吞吐量/失敗率差距就直接斷言「TiDB 整體優於
Galera」——§2.1 要求的相容性、PITR、Online DDL、同拓樸延遲/擴展、chaos/failover
仍全數待測，§3.6 只涵蓋其中一個面向（跨區穩態吞吐量，且 P-B 缺獨立 collect 證據、
缺 wsrep counter delta，見 §3.6 的 lineage caveat 與 inference 標註）；不能把
Galera 的 P-A/P-B（client routing profile）與 TiDB 的 P-A/P-B（server-side
placement）當作語意等價的 A/B test 直接換算擴展率；也不能把 TiDB 的 Failover
秒數與 YugabyteDB／CockroachDB 的「無可觀測中斷」做倍率換算（見
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
