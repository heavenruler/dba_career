# 分散式資料庫架構 PoC Test Cases

## 1. 文件目的

本文件用於定義分散式資料庫架構 PoC 的 test cases，聚焦驗證以下候選系統在 DBaaS 與 Multi-Region Active-Active 架構下的實際行為差異：

- TiDB
- YugabyteDB

本文件只描述 test cases、驗證方式、指標與預期觀察點，不在此階段定義最終結論。

## 2. 測試目標

本次 PoC 優先驗證：

- 同一筆資料在高併發下的衝突行為
- Multi-Region 寫入延遲與 commit path 差異
- follower read / stale read 實際可用性與延遲
- 節點故障與 region-level 問題時的 failover 行為
- network partition 下是否出現 split-brain 風險或 fail-closed 行為

## 3. 測試範圍

### 3.1 測試系統

- TiDB
- YugabyteDB

### 3.2 測試面向

- 交易衝突
- Multi-Region 寫入
- 讀一致性
- 故障切換
- 網路分區
- 可觀測性

### 3.3 本階段不納入

- 正式導入架構定案
- 生產級容量估算
- 完整成本試算
- 正式 SLA / SLO 承諾

## 4. 測試假設

- 採 3-region 架構進行驗證
- 各系統皆採可支援高可用的官方建議部署方式
- 各系統儘可能採相近節點數與資源規格
- 網路延遲可透過 `tc` 或等效機制模擬
- 所有測試皆需保留 client 與 server 端 metrics

## 5. 共同 Test Cases

### 5.1 Region 配置

- Region A
- Region B
- Region C

### 5.2 負載產生器

- 每個 region 至少 1 組 client
- 建議統一使用 `k6`、`sysbench` 或自製 workload runner
- 所有 client 需記錄 request latency、error、retry、region 資訊

### 5.3 測試資料模型

建議統一使用下列表結構，降低不同系統間測試偏差：

```sql
CREATE TABLE account (
  id BIGINT PRIMARY KEY,
  tenant_id BIGINT NOT NULL,
  balance BIGINT NOT NULL,
  version BIGINT NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

CREATE INDEX idx_tenant_id ON account(tenant_id);
```

資料準備建議：

- 初始化 `1,000,000` rows
- 預留 hot rows：`id in (1,2,3,4,5)`
- 若要驗證 region affinity，可另加 tenant / order 類測試資料

### 5.4 Common Test Cases

### TC-01 concurrent update 同一 row

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證衝突 detection / resolution，並比較 retry、abort、lock wait 行為 |
| Setup | 三個 regions 同時對同一筆 row 執行 update，並發數逐步提高，例如 `32 / 64 / 128`，測試時間建議至少 `10 min` |
| Steps | 1. 啟動三個 regions 的 client。2. 對 `account.id = 1` 持續執行 update transaction。3. 提高並發並持續收集錯誤與延遲。建議交易模型如下：`BEGIN; SELECT balance, version FROM account WHERE id = 1 FOR UPDATE; UPDATE account SET balance = balance + 1, version = version + 1, updated_at = CURRENT_TIMESTAMP WHERE id = 1; COMMIT;` |
| Metrics | Write conflict、serialization failure、deadlock / lock wait timeout、retry 次數、error code 分布、p95 latency |
| Pass / Fail Criteria | Pass：系統在高併發下可持續完成交易，衝突錯誤可被辨識且 retry 後成功率可量測。Fail：出現大量不可解釋錯誤、長時間卡死、或無法區分衝突與系統異常 |

### TC-02 multi-region write latency

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 commit path 是否跨 region quorum，並比較不同 region 寫入時的延遲差異 |
| Setup | Region A / B / C client 各自發送寫入，使用相同資料集與 transaction pattern，比較本地寫入與跨區寫入延遲 |
| Steps | 1. 由三個 regions 同時對相同類型資料發送寫入。2. 保持 transaction pattern 一致。3. 收集 client latency、leader 位置與 network metrics。4. 比較 region 間寫入延遲差異 |
| Metrics | commit latency、p95 / p99 latency、leader 位置、cross-region network 流量、region 間延遲變化 |
| Pass / Fail Criteria | Pass：可明確量出不同 region 寫入延遲差異，且能對應 leader / quorum 路徑解釋。Fail：無法穩定重現延遲差異，或觀測資料不足以解釋 commit path |

### TC-03 follower read delay

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 follower read / stale read 可用性，並量測讀取延遲與 staleness |
| Setup | 固定每秒更新同一筆資料，另一組 client 持續以 follower read / stale read 查詢 |
| Steps | 1. 啟動固定頻率更新。2. 分別以 leader read、follower read、stale read 進行查詢。3. 比較查詢版本、延遲與是否讀到最新值 |
| Metrics | read latency、stale lag、read-your-write 成立率、讀取模式成功率 |
| Pass / Fail Criteria | Pass：可清楚區分 leader read、follower read、stale read 的延遲與一致性差異。Fail：無法穩定判斷讀取來源、staleness 無法量測、或 read consistency 行為不明確 |

### TC-04 node failure

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 leader election 與 failover 行為，並量測服務中斷時間與恢復時間 |
| Setup | 找出 hot partition / tablet leader，在壓測進行中直接中止 leader node 或對應 process |
| Steps | 1. 啟動持續讀寫 workload。2. 識別目前 leader 所在節點。3. 中止 leader node 或 process。4. 持續觀察 client 與 server 端恢復狀態 |
| Metrics | new leader 選出時間、client error 數量、write availability 恢復時間、failover 期間 retry 次數 |
| Pass / Fail Criteria | Pass：節點故障後可重新選主並恢復服務，RTO 與錯誤型態可被量測。Fail：故障後長時間無法恢復、寫入不可用時間不可控、或 failover 行為無法解釋 |

### TC-05 network partition

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 quorum 行為，並確認系統是否 fail-closed 以避免 split-brain |
| Setup | 切斷其中一個 region 與其他 region 之間網路，或隔離 leader 與 follower，期間持續執行寫入與讀取 |
| Steps | 1. 啟動持續讀寫 workload。2. 對指定 region 或 leader/follower 套用 network partition。3. 觀察寫入是否仍被接受。4. 恢復網路並比對資料與 leader 狀態 |
| Metrics | 少數分區接受寫入情況、leader 重新選舉時間、資料一致性檢查結果、cross-region network 狀態 |
| Pass / Fail Criteria | Pass：少數分區不接受不安全寫入，系統呈現 fail-closed 或可預期 quorum 行為。Fail：出現疑似 split-brain、雙寫、或系統在分區期間接受不安全寫入 |

## 6. TiDB Test Cases

### 6.1 建議拓樸

架構草稿參考：[`docs/architecture/tidb.md`](./architecture/tidb.md)

- 3 PD
- 3 TiDB
- 6 TiKV
- 每個 region 至少放置 1 個 TiDB 與 2 個 TiKV

### 6.2 Product-specific Test Cases

#### TiDB-01 TSO 與 commit latency 關聯

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 TSO 取得成本是否明顯影響 commit latency，並區分 PD TSO 與 TiKV quorum 成本 |
| Setup | 在單 key 與多 key transaction 下分別量測寫入延遲，比較單 region 與跨 region 部署 |
| Steps | 1. 執行單 key transaction。2. 執行多 key transaction。3. 分別在單 region 與跨 region 條件下收集 client latency、PD 與 TiKV 指標 |
| Metrics | TSO 相關延遲、2PC prewrite / commit latency、PD 指標、TiKV 指標、p95 commit latency |
| Pass / Fail Criteria | Pass：可分離 PD TSO 與 TiKV commit 成本，並判斷 TSO 是否為主要延遲來源。Fail：無法從 metrics 或行為上辨識 TSO 對 commit latency 的影響 |

#### TiDB-02 follower read 與 stale read 對照

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 follower read 與 stale read 的實際使用差異，並觀察強一致 follower read 的額外成本 |
| Setup | 同一組資料同時執行 leader read、follower read、stale read |
| Steps | 1. 持續更新同一批資料。2. 以三種讀取模式查詢。3. 比較讀延遲、staleness 與成功率 |
| Metrics | `ReadIndex` 延遲、stale read latency、讀一致性結果、query 成功率 |
| Pass / Fail Criteria | Pass：能明確比較 follower read 與 stale read 的延遲和一致性差異。Fail：兩種讀模式行為無法穩定重現，或無法驗證 `ReadIndex` 成本 |

#### TiDB-03 add index 對線上寫入影響

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 online DDL 對熱表寫入的實際影響 |
| Setup | 在持續寫入 `account` 表時執行 `ADD INDEX` |
| Steps | 1. 啟動持續寫入 workload。2. 對熱表執行 `ADD INDEX`。3. 觀察 DDL 期間寫入延遲、衝突與 DDL 進度 |
| Metrics | backfill 期間寫入延遲、write conflict、DDL 完成時間、寫入成功率 |
| Pass / Fail Criteria | Pass：DDL 可在線進行，且對線上寫入的影響可被量測與解釋。Fail：DDL 造成明顯 blocking、不可接受的寫入中斷、或無法完成 |

## 7. YugabyteDB Test Cases

### 7.1 建議拓樸

架構草稿參考：[`docs/architecture/yugabytedb.md`](./architecture/yugabytedb.md)

- 3 master
- 6 tserver
- RF=3，tablet 盡量平均分布於 3 regions
- tablespace / placement policy 需明確定義

### 7.2 Product-specific Test Cases

#### YB-01 HLC / transaction restart 行為

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證高衝突下 transaction restart 與 serialization failure 特徵，並觀察重試成本 |
| Setup | 對同一 row 執行高併發 update |
| Steps | 1. 啟動多區高併發 update。2. 收集 restart error、serialization error、retry 次數。3. 比較高衝突前後延遲與成功率 |
| Metrics | restart error 分布、retry 後成功率、p95 latency、abort rate |
| Pass / Fail Criteria | Pass：可明確觀察 restart / serialization error 模式，並量測 retry 成本。Fail：高衝突下錯誤型態不明、retry 行為不可預測、或交易穩定性過低 |

#### YB-02 geo-placement 與 region failover

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 placement policy 是否直接影響可寫性與 failover 結果 |
| Setup | 定義 3-region placement，模擬單一 region 不可用 |
| Steps | 1. 套用 placement policy。2. 啟動持續寫入 workload。3. 模擬單一 region 故障。4. 觀察剩餘 regions 是否仍保有 quorum 與寫入能力 |
| Metrics | region 故障後可寫性、tablet leader 重分布時間、RTO、client error rate |
| Pass / Fail Criteria | Pass：可驗證 placement policy 與 region failover 結果的直接關聯。Fail：region 故障後行為無法預測，或 placement 設定無法支撐預期可寫性 |

#### YB-03 follower read / read replica 行為

| 欄位 | 內容 |
| --- | --- |
| Objective | 驗證 follower read 與 replica 讀取的一致性與延遲差異 |
| Setup | 持續更新同一筆資料，分別以 leader read 與 follower read 進行查詢 |
| Steps | 1. 啟動固定頻率寫入。2. 分別以 leader read 與 follower read 查詢。3. 比較 stale lag、讀延遲與成功率 |
| Metrics | follower read 可用條件、stale lag、read latency、query 成功率 |
| Pass / Fail Criteria | Pass：可量化 follower read 的延遲收益與 stale lag 行為。Fail：無法穩定使用 follower read，或讀延遲 / 一致性特徵無法辨識 |

## 8. 核心 Metrics

### 8.1 必收指標與 PoC 驗收重要性

| 指標 | 驗收標準重要性 |
| --- | --- |
| `p95 latency` | 反映大多數真實請求的延遲表現，比平均值更能看出系統在壓力下是否穩定。若 p95 過高，代表系統即使平均正常，實際使用者仍會感受到明顯卡頓。 |
| `p99 latency` | 用來觀察尾延遲，能揭露跨 region quorum、leader 切換、鎖衝突、GC 或背景任務造成的極端慢請求。PoC 若只看 p95，容易忽略實際上會影響 SLA 的尖峰延遲。 |
| `commit latency` | 直接對應交易提交成本，是判斷 multi-region write 是否可接受的核心指標。若 commit latency 過高，代表跨區同步寫入成本可能不適合 OLTP 主交易路徑。 |
| `retry count` | 代表系統在衝突、leader 切換或暫時性錯誤下，是否大量依賴 client retry 才能成功。retry 過高通常表示系統雖然表面可用，但實際應用整合成本與不確定性偏高。 |
| `conflict rate` | 用來衡量高併發下同筆資料更新的競爭程度，能直接看出 transaction model 是否適合高衝突 OLTP 場景。若 conflict rate 過高，系統即使理論可擴展，實際熱點交易仍可能無法穩定運作。 |
| `abort rate` | 顯示最終失敗的交易比例，用來區分「可透過重試解決」與「交易實際失敗」兩種情況。PoC 若 abort rate 偏高，代表應用層會承受明顯錯誤與補償邏輯壓力。 |
| `stale lag` | 用來驗證 follower read / stale read 的資料新鮮度，直接關係到這類讀模式是否能安全提供給業務使用。若 stale lag 不穩定或過大，表示該能力只能作為有限場景優化，不能當主力查詢策略。 |
| `time to new leader` | 直接反映故障後共識層恢復能力，是評估 HA 與 RTO 的核心指標。若新 leader 選出時間過長，故障切換即使最終成功，也可能無法滿足業務可用性要求。 |
| `write unavailability window` | 表示在 failover 或 network partition 期間，系統實際不可寫的時間長度。這比單看 leader election 更貼近業務影響，因為使用者真正感受到的是「多久不能寫入」。 |
| `cross-region network bytes` | 用來衡量 multi-region 架構的實際成本與寫入放大程度。若跨區流量過高，代表即使功能可行，正式上線後也可能因 network cost、頻寬壓力或延遲放大而不具經濟可行性。 |

### 8.2 為什麼這組指標適合當 PoC 驗收核心

- `p95 latency`、`p99 latency`、`commit latency`
  - 驗證效能是否可接受
- `retry count`、`conflict rate`、`abort rate`
  - 驗證交易模型是否適合高併發與熱點場景
- `stale lag`
  - 驗證讀一致性能力是否可操作
- `time to new leader`、`write unavailability window`
  - 驗證 HA / failover 是否符合可用性需求
- `cross-region network bytes`
  - 驗證 multi-region 架構是否具備成本可行性

### 8.3 若缺少其中任一項的風險

- 少看 `p99 latency`
  - 容易低估尾延遲對 SLA 的影響
- 少看 `commit latency`
  - 無法準確判斷 multi-region write 是否真的可用
- 少看 `retry count` / `abort rate`
  - 會誤判系統穩定，實際上只是 client 一直重試撐住
- 少看 `stale lag`
  - 無法判斷 follower read 是否真的可上線
- 少看 `write unavailability window`
  - 無法量化 failover 對業務中斷的真實影響
- 少看 `cross-region network bytes`
  - 容易做出技術上可行、成本上不可行的選型

## 9. 驗證方式

### 9.1 Client 端

- 每筆 request 記錄開始時間、結束時間、region、txn 類型、error code
- 區分 read / write / retry / timeout

### 9.2 Server 端

- 收集 DB metrics
- 收集 replication / raft / tablet / region 狀態
- 收集 lock / conflict / slow query / failover 相關指標

### 9.3 網路層

- 測試前後量測 RTT
- 需保留 network partition 與 delay injection 紀錄

## 10. 驗收建議

本階段先不定義絕對門檻，但建議至少回答以下問題：

- 哪一套系統在高衝突寫入下 retry / abort 最可控
- 哪一套系統在 multi-region commit latency 表現最穩定
- follower read / stale read 是否具備可操作性與可預測性
- node failure 與 region failure 時是否能維持可接受服務中斷時間
- network partition 下是否能確保不發生不安全寫入

## 11. 後續待補

- 實際部署拓樸
- 測試腳本
- 指標收集方式
- 驗收門檻
- 測試時程與執行順序
