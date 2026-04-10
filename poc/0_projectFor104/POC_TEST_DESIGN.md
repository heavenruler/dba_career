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

**目的**

- 驗證衝突 detection / resolution
- 比較 retry、abort、lock wait 行為

**測試方式**

- 三個 regions 同時對同一筆 row 執行 update
- 並發數逐步提高，例如 `32 / 64 / 128`
- 測試時間建議至少 `10 min`

**建議交易模型**

```sql
BEGIN;
SELECT balance, version FROM account WHERE id = 1 FOR UPDATE;
UPDATE account
SET balance = balance + 1,
    version = version + 1,
    updated_at = CURRENT_TIMESTAMP
WHERE id = 1;
COMMIT;
```

**觀察重點**

- Write conflict
- Serialization failure
- Deadlock / lock wait timeout
- Retry 次數
- error code 分布

**Pass / Fail Criteria**

- Pass：系統在高併發下可持續完成交易，衝突錯誤可被辨識且 retry 後成功率可量測
- Fail：出現大量不可解釋錯誤、長時間卡死、或無法區分衝突與系統異常

### TC-02 multi-region write latency

**目的**

- 驗證 commit path 是否跨 region quorum
- 比較不同 region 寫入時的延遲差異

**測試方式**

- Region A / B / C client 各自發送寫入
- 使用相同資料集與 transaction pattern
- 比較本地寫入與跨區寫入延遲

**觀察重點**

- commit latency
- p95 / p99 latency
- leader 位置
- cross-region network 流量
- region 間延遲變化對 commit 的影響

**Pass / Fail Criteria**

- Pass：可明確量出不同 region 寫入延遲差異，且能對應 leader / quorum 路徑解釋
- Fail：無法穩定重現延遲差異，或觀測資料不足以解釋 commit path

### TC-03 follower read delay

**目的**

- 驗證 follower read / stale read 可用性
- 量測讀取延遲與 staleness

**測試方式**

- 固定每秒更新同一筆資料
- 另一組 client 持續以 follower read / stale read 查詢
- 比較是否讀到最新版本以及延遲差異

**觀察重點**

- read latency
- stale lag
- read-your-write 是否成立
- follower read 是否需要額外條件或限制

**Pass / Fail Criteria**

- Pass：可清楚區分 leader read、follower read、stale read 的延遲與一致性差異
- Fail：無法穩定判斷讀取來源、staleness 無法量測、或 read consistency 行為不明確

### TC-04 node failure

**目的**

- 驗證 leader election 與 failover 行為
- 量測服務中斷時間與恢復時間

**測試方式**

- 找出 hot partition / tablet leader
- 在壓測進行中直接中止 leader node 或對應 process

**觀察重點**

- new leader 選出時間
- client error 數量
- write availability 恢復時間
- failover 期間是否需要明確 client retry

**Pass / Fail Criteria**

- Pass：節點故障後可重新選主並恢復服務，RTO 與錯誤型態可被量測
- Fail：故障後長時間無法恢復、寫入不可用時間不可控、或 failover 行為無法解釋

### TC-05 network partition

**目的**

- 驗證 quorum 行為
- 驗證是否 fail-closed，避免 split-brain

**測試方式**

- 切斷其中一個 region 與其他 region 之間網路
- 或隔離 leader 與 follower
- 持續執行寫入與讀取請求

**觀察重點**

- 少數分區是否仍接受寫入
- leader 是否重新選舉
- 系統是否明確拒絕不安全寫入

**Pass / Fail Criteria**

- Pass：少數分區不接受不安全寫入，系統呈現 fail-closed 或可預期 quorum 行為
- Fail：出現疑似 split-brain、雙寫、或系統在分區期間接受不安全寫入

## 6. TiDB Test Cases

### 6.1 建議拓樸

- 3 PD
- 3 TiDB
- 6 TiKV
- 每個 region 至少放置 1 個 TiDB 與 2 個 TiKV

### 6.2 Product-specific Test Cases

#### TiDB-01 TSO 與 commit latency 關聯

**目的**

- 驗證 TSO 取得成本是否明顯影響 commit latency
- 區分 PD TSO 成本與 TiKV quorum 成本

**測試方式**

- 在單 key 與多 key transaction 下分別量測寫入延遲
- 比較單 region 與跨 region 部署下的 commit latency
- 收集 PD 與 TiKV 指標，對照 client latency

**觀察重點**

- TSO 相關延遲
- 2PC prewrite / commit latency
- 高併發下 PD 是否成為明顯瓶頸

**Pass / Fail Criteria**

- Pass：可分離 PD TSO 與 TiKV commit 成本，並判斷 TSO 是否為主要延遲來源
- Fail：無法從 metrics 或行為上辨識 TSO 對 commit latency 的影響

#### TiDB-02 follower read 與 stale read 對照

**目的**

- 驗證 follower read 與 stale read 的實際使用差異
- 觀察強一致 follower read 的額外成本

**測試方式**

- 同一組資料同時執行 leader read、follower read、stale read
- 比較 read latency、staleness 與 query 成功率

**觀察重點**

- `ReadIndex` 帶來的額外延遲
- stale read 是否顯著降低讀延遲
- 讀一致性與可預測性

**Pass / Fail Criteria**

- Pass：能明確比較 follower read 與 stale read 的延遲和一致性差異
- Fail：兩種讀模式行為無法穩定重現，或無法驗證 `ReadIndex` 成本

#### TiDB-03 add index 對線上寫入影響

**目的**

- 驗證 online DDL 對熱表寫入的實際影響

**測試方式**

- 在持續寫入 `account` 表時執行 `ADD INDEX`
- 持續觀察寫入 latency、conflict 與 DDL 進度

**觀察重點**

- backfill 期間寫入延遲是否上升
- 是否出現額外 write conflict
- DDL 完成時間與業務影響

**Pass / Fail Criteria**

- Pass：DDL 可在線進行，且對線上寫入的影響可被量測與解釋
- Fail：DDL 造成明顯 blocking、不可接受的寫入中斷、或無法完成

## 7. YugabyteDB Test Cases

### 7.1 建議拓樸

- 3 master
- 6 tserver
- RF=3，tablet 盡量平均分布於 3 regions
- tablespace / placement policy 需明確定義

### 7.2 Product-specific Test Cases

#### YB-01 HLC / transaction restart 行為

**目的**

- 驗證高衝突下 transaction restart 與 serialization failure 特徵
- 觀察 HLC 與 restart 機制是否導致應用重試成本上升

**測試方式**

- 對同一 row 執行高併發 update
- 收集 transaction restart、serialization error、retry 次數

**觀察重點**

- restart error 分布
- retry 後成功率
- 高衝突情境下 p95 latency 變化

**Pass / Fail Criteria**

- Pass：可明確觀察 restart / serialization error 模式，並量測 retry 成本
- Fail：高衝突下錯誤型態不明、retry 行為不可預測、或交易穩定性過低

#### YB-02 geo-placement 與 region failover

**目的**

- 驗證 placement policy 是否直接影響可寫性與 failover 結果

**測試方式**

- 定義 3-region placement
- 模擬單一 region 不可用
- 觀察剩餘 region 是否仍保有 quorum 與寫入能力

**觀察重點**

- region 故障後是否仍可寫入
- tablet leader 重分布時間
- placement 設計對 RTO 的影響

**Pass / Fail Criteria**

- Pass：可驗證 placement policy 與 region failover 結果的直接關聯
- Fail：region 故障後行為無法預測，或 placement 設定無法支撐預期可寫性

#### YB-03 follower read / read replica 行為

**目的**

- 驗證 follower read 與 replica 讀取的一致性與延遲差異

**測試方式**

- 持續更新同一筆資料
- 分別以 leader read 與 follower read 進行查詢
- 比較 stale lag 與 latency

**觀察重點**

- follower read 的可用條件
- stale lag 是否穩定
- read latency 是否明顯優於 leader read

**Pass / Fail Criteria**

- Pass：可量化 follower read 的延遲收益與 stale lag 行為
- Fail：無法穩定使用 follower read，或讀延遲 / 一致性特徵無法辨識

## 8. 核心 Metrics

必收指標：

- p95 latency
- p99 latency
- commit latency
- retry count
- conflict rate
- abort rate
- stale lag
- time to new leader
- write unavailability window
- cross-region network bytes

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
