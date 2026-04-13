# PoC Monitoring Guide

## 1. 文件目的

本文件用於定義分散式資料庫架構 PoC 執行期間的監控閱讀方式，說明各 test case 應觀察的 metrics、判讀重點、火焰圖分析方法與異常對應方向，作為測試驗證、效能分析與結果解讀依據。

## 2. 適用範圍

- TiDB
- YugabyteDB
- IDC `172.24.*.*` <-> GCP `10.160.*.*`
- `POC_TEST_DESIGN.md` 定義之 common / product-specific test cases

## 3. 使用時機

## 4. 監控來源

## 5. 指標分類

## 6. Common Test Cases 對應監控

## 7. TiDB 觀察重點

## 8. YugabyteDB 觀察重點

## 9. 火焰圖怎麼看

### 9.1 核心概念

- 火焰圖主要用來看「時間花在哪裡」，不是只看「誰被呼叫最多次」
- 橫向寬度代表累積時間占比，越寬表示該 function 或 call stack 消耗的 CPU / on-CPU 時間越多
- 縱向高度代表 call stack 深度，不代表問題嚴重度
- 最上層寬框不一定是根因，需往下看整條 stack 才能知道時間真正耗在哪一層
- 同一 workload、同一採樣條件下的火焰圖才適合互相比較

### 9.2 判讀流程

1. 先確認抓圖時機
- 要知道當下是哪個 test case、哪個時間點、哪種負載條件
- 至少對應到 `p95 / p99 latency`、`commit latency` 或 `retry count` 異常時段

2. 先找最寬的框
- 不要一開始就看最深層細節
- 先確認最大時間花在哪個模組，例如 SQL layer、transaction layer、storage layer、consensus、network wait

3. 往下追完整 stack
- 確認寬框是來自哪條呼叫路徑
- 區分是業務查詢、交易提交、背景工作、GC、compaction、raft apply 還是 client 端重試

4. 對照 metrics
- 火焰圖不能單獨下結論，必須對照：
- `p95 / p99 latency`
- `commit latency`
- `retry count`
- `conflict rate`
- `CPU / load average / context switch`

5. 判斷是否可優化
- 確認問題是配置、架構限制、測試條件，還是實作瓶頸
- 若是 quorum / cross-region RTT 造成，就不應誤判成單純 tuning 可解

### 9.3 常見 Pattern

#### Pattern A. SQL / Query Layer 過寬

可能代表：

- SQL parsing / planning 成本偏高
- query execution 本身吃 CPU
- 應用端請求過度集中在 SQL 層

PoC 解讀：

- 先確認是不是 workload 設計問題
- 再看是否為 TiDB SQL layer 或 YSQL 層的額外成本

#### Pattern B. Transaction / Lock / Retry 路徑過寬

可能代表：

- 高衝突寫入
- transaction restart / retry 成本高
- lock handling 成本增加

PoC 解讀：

- 常出現在 `TC-01 concurrent update 同一 row`
- 要對照 `retry count`、`abort rate`、`conflict rate`

#### Pattern C. Consensus / Raft 路徑過寬

可能代表：

- commit path 高度依賴 quorum
- cross-site replication 成本高
- leader 壓力集中

PoC 解讀：

- 常出現在 `TC-02 multi-region write latency`
- 要對照 `commit latency` 與 `cross-region network bytes`

#### Pattern D. Storage / IO 路徑過寬

可能代表：

- disk latency 高
- compaction / flush / WAL 壓力高
- storage 層成為瓶頸

PoC 解讀：

- 先區分是資源不足，還是產品本身寫入放大
- 不可直接把 storage 壓力誤判成 transaction model 問題

#### Pattern E. Network / Timeout / Wait 路徑過寬

可能代表：

- cross-region RTT 偏高
- network partition / packet loss
- client / server 在等待 remote quorum 或 reconnect

PoC 解讀：

- 常出現在 `TC-04 node failure`、`TC-05 network partition`
- 要對照 `time to new leader`、`write unavailability window`

### 9.4 判斷優化優先順序

優先順序建議如下：

1. 先處理最寬、且直接影響驗收指標的 stack
- 例如直接對應 `commit latency`、`p99 latency`、`abort rate`

2. 先處理可重現、可量化的問題
- 偶發單次尖峰先記錄，不要優先投入大量調整

3. 先區分架構限制與可調參問題
- cross-region quorum 導致的延遲，通常不是單純改參數能消除
- hotspot 寫入導致的 retry storm，也未必能只靠 tuning 解決

4. 先優化主路徑，再看背景工作
- 若主要交易路徑已經過高，不要先花時間在次要背景 thread

5. 先對 PoC 驗收有幫助的項目
- 能改善 `commit latency`、`retry count`、`write unavailability window` 的項目，優先度高於純技術潔癖式優化

### 9.5 常見誤解

#### 誤解 1. 最寬的框就是根因

- 不一定
- 最寬框只是「時間最多」，真正根因可能在更下層或更早的 stack

#### 誤解 2. 火焰圖可以單獨說明問題

- 不行
- 一定要搭配 latency、retry、abort、network、system metrics 一起看

#### 誤解 3. 高 CPU 就一定是壞事

- 不一定
- 高 CPU 可能代表系統有效工作；真正要看的是 CPU 花在哪裡，以及是否對應驗收指標惡化

#### 誤解 4. 所有寬框都值得優化

- 不一定
- 若某段時間屬於正常 quorum / replication 成本，可能只是架構事實，不是優化標的

#### 誤解 5. 不寬就不重要

- 不一定
- 某些 failover、timeout、retry 路徑雖然不一定最寬，但可能直接對應 PoC 驗收失敗

#### 誤解 6. 比較兩張火焰圖時，只看畫面像不像

- 不夠
- 必須確認 workload、並發、資料量、採樣方式、時間區間都一致，否則比較沒有意義

## 10. 火焰圖在 PoC 如何應用

## 11. 異常判讀

## 12. 輸出與保存
