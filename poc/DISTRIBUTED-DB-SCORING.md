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
| 6 | Failover RTO／RPO | Failover、RTO／RPO、PITR | 6% | `phase-crossregion` F1（P-A×A-S）／C4（P-B×A-A）chaos 實測（見 §3.3） | 待測 | 待測 | 待測 | 待測 |
| 7 | PITR／備份還原 | Failover、RTO／RPO、PITR | 4% | 尚未排入本 PoC 測試矩陣（見 §3.3） | 待測 | 待測 | 待測 | 待測 |
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

- **設計基礎**：`phase-crossregion` 已備妥完整 F1（計畫性 failover，對應
  P-A×A-S）與 C4（chaos leader-die，對應 P-B×A-A）的量測方法論
  （[`RTO-RPO-methodology.md`](./phase-crossregion/failover/RTO-RPO-methodology.md)）與
  實跑腳本（`phase-crossregion/scripts/run-vm6-chaos-execute.sh`，2026-08-06
  新增，已通過 dry-run schema 驗證，尚未對真實叢集執行）。
- **現況**：**全部四家、全部項目標「待測」**。真實 chaos 注入已排定於
  2026-08-07 以互動方式執行（部署→觸發 kill→採樣→teardown，每步驟人工在場
  確認），完成後將回填本表的 RTO/RPO 實測數字與依此換算的星等。MySQL Galera
  Cluster 目前完全未納入 `phase-crossregion` 測試矩陣，若要納入本項比較需另行
  規劃其 failover 測試流程（Galera 的多主複寫模型與本 PoC 既有的 raft-based
  三家測試方法論不同，量測方式需另外設計，不可直接套用 F1/C4 spec）。
- **PITR／備份還原**：本 PoC 目前完全未排入測試矩陣（無 spec、無 script、
  無任何 artifact），四家皆「待測」。

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
> 只有 3 項有分，加權總分＝這 3 項的「星等（1-5）× 各自權重」加總 ÷ 這 3 項
> 權重合計 × 100，換算為百分制），未測項目**不**用任何預設值替代。這代表
> 目前的加權總分**僅反映「延遲與水平擴展」這一個類別**，不是四方資料庫的
> 完整評估結果。

| DB | 已計入項目 | 已計入權重合計 | 加權總分（僅延遲/擴展，百分制） |
|---|---|---:|---:|
| MySQL Galera Cluster | 無 | 0% | 待測（無任何實測項目） |
| TiDB | #3 #4 #5 | 50% | (3×15 + 5×20 + 4×15) / 50 × 20 = **82.0** |
| YugabyteDB | #3 #4 #5 | 50% | (5×15 + 3×20 + 4×15) / 50 × 20 = **78.0** |
| CockroachDB | #3 #4 #5 | 50% | (4×15 + 4×20 + 5×15) / 50 × 20 = **86.0** |

> 計算範例（TiDB）：`(3×15 + 5×20 + 4×15) ÷ (15+20+15) × 20 = 205 ÷ 50 × 20 = 82.0`。
> 乘以 20 是把 1-5 星換算為百分制的比例常數（5 星 = 100 分）。
> **這三個分數差距在 8 分內（78-86 分），且僅代表 50% 的總權重**——在其餘 50%
> 權重（相容性、Failover、DDL、HTAP/Geo）補測前，任何「A 比 B 好」的結論都
> 不成立，本表刻意不對 MySQL Galera Cluster 給出任何加權總分，避免「0 分」
> 被誤讀為「Galera 最差」（正確理解是「Galera 完全未測」）。

## 5. 最終結論

**目前僅能下的結論**：TiDB／YugabyteDB／CockroachDB 三家在 `vm-3node-haproxy-3s3r`
拓樸、W=128、READ COMMITTED 條件下，水平擴展與高併發穩定性各有取捨，且加權
分數差距在 8 分內（78-86，滿分 100，僅計入這 3 項共 50% 權重）——CockroachDB
單節點延遲與擴展倍率兩項皆居中、但高併發穩定性最佳（range/mean 6.9%），
加權後分數最高（86.0）；TiDB 擴展倍率最高（2.06×，且此項權重也最高 20%）
拉高其分數（82.0）但單節點延遲較高；YugabyteDB 單節點延遲最低但擴展倍率
最低，分數居末（78.0）。三者差距不大，**不宜僅憑這 3 項就下「何者較優」的
結論**——加權分數的排序高度取決於「擴展能力權重高於單節點延遲」這個本文件
既定的權重設計，換一組權重排序可能反轉。這些結論僅限於本 PoC 已測的這一組
拓樸與硬體規格，**不可外推**到 Kubernetes 部署（已知 YugabyteDB 在該場景
retention 明顯較差）或跨區部署。

**目前不能下的結論**：
- 不能說任何一家「整體最適合取代 MySQL Galera Cluster」——相容性、
  Failover/RTO/RPO、維運工具、HTAP/Geo 四個類別（合計 50% 權重）完全沒有
  實測數據，跟已測的「延遲與水平擴展」（50% 權重）剛好一半一半。
- 不能用本表現有數字給 MySQL Galera Cluster 任何分數或排名——它是本次比較
  的基準對象，但目前一項都沒測。
- 不能把 `phase-crossregion` 的 P-A/P-B placement 探索性數據當作
  Geo-Distribution 的正式評分依據（該 scope 本身 `baseline_eligible=false`）。

**下一步建議**（依風險與可行性排序）：
1. 完成 §3.3 的真實 chaos 執行（P-A×A-S F1、P-B×A-A C4，已排定 2026-08-07），
   補齊 Failover RTO／RPO 這一項（6% 權重）。
2. 針對 MySQL Galera Cluster 補一輪與本 PoC 相同口徑（W=128、go-tpc
   TPC-C、READ COMMITTED、`vm-1node`/`vm-3node`）的基準測試，否則它永遠無法
   被公平比較。
3. 設計並執行 §3.1 相容性矩陣與 §3.4 Online DDL 測試——這兩項合計 35%
   權重，且往往是實際遷移時最先浮現的痛點，優先度應不低於效能測試。
4. PITR 與 HTAP／Geo-Distribution 合計僅 9% 權重，可視資源排在較後順序。

---

*本文件由 PoC 測試證據自動彙整而成，任何星等與加權總分皆可回溯至上述引用的
`summary.json`／pipeline-log／dispatch-record；如發現本文件數字與來源檔案
不一致，以來源檔案為準，並回報修正。*
