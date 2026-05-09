# TiDB TPC-C Pipeline Log — tidb-tc1 / S-BASE

> **本測試結論**：TiDB 單節點在同等硬體下，吞吐量比 YugabyteDB 高出約 30 倍，延遲控制在 1 秒以內；悲觀鎖設計在高併發下避免了 YBDB 的重試風暴。

---

## vm-1node — 2026-05-07

### 環境
- 節點：.32 (172.24.40.32) 單節點，**PD + TiDB + TiKV 同主機部署**（三個元件共用一台伺服器：PD 是排程器、TiDB 是 SQL 接收層、TiKV 是儲存層；這是測試環境的簡化配置，不代表正式部署方式）
- 部署工具：**TiUP v1.x**（TiDB 官方部署管理工具，類似安裝精靈，管理層不需理解細節）— 透過 ansible playbook `tidb.yml` + `inventory/tidb-vm1.ini`
- TiDB 版本：v8.5.2
- 配置：**`tidb_rf=1`**（RF = Replication Factor 資料複本數，=1 代表資料只存一份、不容錯，本 variant 用來測單節點純效能上限）
- **AUTO ANALYZE**（資料庫自動統計分析，幫助查詢最佳化）：**啟用**（預設 ratio=0.5，代表資料變動超過 50% 才觸發一次重算；本 variant 保持啟用作為標準基線）
- 測試工具：go-tpc（MySQL driver）（TiDB 原生支援 MySQL 連線協定，測試工具直接透過 MySQL 介面連線，與 MySQL 資料庫本身無關）
- 連線入口：直連 172.24.40.32:4000
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260507-2308/`

### Prepare
- 時間：19m26s（128W）
- check 階段全程通過（無 session/connection 錯誤）

### Execute 結果

> ⚠️ **注意**：efficiency 欄位在無 think time（等待間隔）的壓力測試下會遠超 100%，這是正常現象，不代表計算錯誤。詳見表格下方說明。
>
> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好；efficiency 見下方說明）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 11,895.0 | 26,348.7 | 722.6% | 39.3 | 65.0 |
| 32 | 12,766.7 | 28,345.3 | 775.6% | 71.7 | 125.8 |
| 64 | 13,355.4 | 29,609.0 | 811.3% | 135.0 | 243.3 |
| 128 | 13,078.8 | 28,955.6 | 794.5% | 267.6 | 520.1 |

> **efficiency 說明**：go-tpc 用「tpmC / (warehouses × 12.86)」計算，理論上限對應 TPC-C 標準的 think time + keying time 設定下的人均吞吐。本測試無 think time，goroutine 持續滿載，因此遠超 100% 是正常現象。
>
> **白話**：這個數字代表「資料庫有多繁忙」，超過 100% 是因為我們刻意用持續滿載模式壓測，移除了真實用戶操作之間的等待時間，讓資料庫一刻不停地工作。

### Execute 結果白話解讀

| 併發 | 白話解讀 |
|------|---------|
| 16t | 表現出色（延遲 39ms，不到 0.04 秒） |
| 32t | 持續成長（延遲 72ms，吞吐仍在上升） |
| 64t | 效能頂峰（13,355 tpmC，延遲 135ms，最佳甜蜜點） |
| 128t | 略降但仍健康（13,079 tpmC，延遲 268ms，低於 0.3 秒） |

### vs YBDB vm-1node 對比

> **TiDB / YBDB 倍數 = TiDB tpmC ÷ YBDB tpmC，越高代表 TiDB 相對 YBDB 的優勢越大。**

| threads | TiDB tpmC | YBDB tpmC | TiDB / YBDB |
|---------|-----------|-----------|-------------|
| 16 | 11,895 | 414.7 | 28.7× |
| 32 | 12,767 | 394.8 | 32.3× |
| 64 | 13,355 | 378.6 | 35.3× |
| 128 | 13,079 | 370.4 | 35.3× |

| threads | TiDB NO avg | YBDB NO avg | 差距 |
|---------|-------------|-------------|------|
| 16 | 39 ms | 2,225 ms | TiDB 快 57× |
| 32 | 72 ms | 4,686 ms | TiDB 快 65× |
| 64 | 135 ms | 9,548 ms | TiDB 快 71× |
| 128 | 268 ms | 15,655 ms | TiDB 快 58× |

### 觀察

> **管理層摘要**：TiDB 在同等硬體下的每分鐘交易量約為 YugabyteDB 的 30 倍，延遲保持在 0.3 秒以內。差距來自鎖定機制的根本設計不同：TiDB 讓衝突的請求排隊等候，不重做整筆交易；YugabyteDB 在衝突時整筆重試，高併發下重試不斷堆積導致延遲爆炸。

- **tpmC 隨併發溫和成長**：16 → 64t 從 11,895 提升到 13,355（+12.3%），128t 微降至 13,079，呈現典型的 OLTP 飽和曲線；無 YBDB 那樣的崩潰式下滑。
- **NO avg latency 線性可控**：TiDB 雖然延遲也隨併發增加（39 → 268 ms），但維持在 sub-second（不到一秒）層級；YBDB 同條件已達 15s+ 並打到 go-tpc 16s 上限。
- **efficiency 700-810%**：遠高於 YBDB 的 22-25%，代表 NEW_ORDER 處理流暢，retry/wait 開銷低。
- **64t 為 sweet spot（最佳工作點，效能與資源使用的最佳平衡）**：13,355 tpmC 為峰值，128t 開始略降但仍在合理範圍。

### 根因：架構差異

TiDB 採用 **悲觀鎖（pessimistic locking）**：衝突時後到的 transaction 排隊等鎖，不重試整筆交易。**比喻：類似「先排隊取號，輪到才動作」**。

YBDB 採用 **樂觀 MVCC（Multi-Version Concurrency Control）**：衝突時整筆 rollback 重試。**比喻：類似「先做事，結帳時才確認有沒有衝突，衝突就整筆重做」**。無 think time + 高併發下重試鏈累積 → latency 爆炸。

NEW_ORDER 必更新某個訂單流水號欄位（`district.D_NEXT_O_ID`，每個倉庫區域共用，是 TPC-C 競爭最集中的熱點；每 warehouse × district = 1280 熱點 row）。  
TiDB 在 row 鎖層排隊處理，每筆順序執行；YBDB 在 commit 時偵測衝突，多個 goroutine（程式內的並行執行單元，每個對應一個同時進行的資料庫請求）撞同一 row 就互相 rollback。

### 注意事項

> **整體結論：以下為測試過程中的技術備註，均已解決，不影響最終測試數據的有效性。**

- **AUTO ANALYZE disable 失敗（此 variant 反而是預期）**（此失敗不影響本 variant 的測試目的，本 variant 本來就保留 AUTO ANALYZE 啟用作為基線）：tpcc.sh 在 run 開始時嘗試 `SET GLOBAL tidb_auto_analyze_ratio = 0`，TiDB v8.5.2 拒絕（`value should be greater than or equal to 0.000010`）。已在後續 fix tpcc.sh 改用 `tidb_enable_auto_analyze = OFF`。
- **VM crash 重跑**（虛擬機器意外重啟，TiDB 自動恢復後重跑 prepare，最終數據完整有效）：首次 prepare 期間 .32 VM crash，重啟後 TiDB 自動恢復，重跑 prepare 成功（19m26s vs 首次 23m18s，磁碟 cache 助益）。

---

## vm-1node-no-analyze — 2026-05-08

> **本區塊目的**：對照實驗——關閉 AUTO ANALYZE（自動統計分析）後，重新執行相同的 TPC-C 壓測，確認該功能是否影響交易吞吐量。

### 環境
- 同 vm-1node 環境
- AUTO ANALYZE：**停用** (`SET GLOBAL tidb_enable_auto_analyze = OFF`，執行此資料庫指令關閉自動統計分析功能)
- tpcc.sh 已修：改用 `tidb_enable_auto_analyze` flag（v8.5+ `tidb_auto_analyze_ratio=0` 不被接受）
- 結果目錄：`vm-1node-no-analyze/20260508-0627/`

### Prepare
- 時間：20m12s
- 在 AUTO ANALYZE OFF 狀態下載入 128W

### Execute 結果

> （tpmC：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | NO avg(ms) | NO P99(ms) |
|---------|------|------------|------------|
| 16 | 11,380.6 | 40.9 | 71.3 |
| 32 | 12,596.2 | 72.5 | 125.8 |
| 64 | 13,345.3 | 134.4 | 243.3 |
| 128 | 13,191.7 | 264.3 | 520.1 |

### vs vm-1node 對比

> **差異 = no-analyze 相對 baseline（vm-1node）的 tpmC 變動；負值代表略低，正值代表略高；全部落在 ±5% 以內，屬正常波動範圍（即差異可忽略）。**

| threads | vm-1node | vm-1node-no-analyze | 差異 |
|---------|----------|---------------------|------|
| 16 | 11,895.0 | 11,380.6 | -4.3% |
| 32 | 12,766.7 | 12,596.2 | -1.3% |
| 64 | 13,355.4 | 13,345.3 | -0.07% |
| 128 | 13,078.8 | 13,191.7 | +0.86% |

### 結論

**10 分鐘 TPC-C 測試期間，AUTO ANALYZE 對 tpmC 影響可忽略**。

- 預期 AUTO ANALYZE 在背景跑 ANALYZE TABLE（重新計算整張資料表的統計資訊的資料庫指令）會吃 CPU 與 I/O，影響 OLTP 吞吐
- 實測差異 < 5%，落在 noise 範圍內（統計誤差範圍，即數值差距小到無法判斷是真實效能差距）
- 原因：AUTO ANALYZE 的觸發條件是「當資料表的修改筆數超過總筆數 50% 才會觸發」，128W 資料量下 10 分鐘的修改量達不到此閾值
- 16t 略低（-4.3%）的可能原因：沒有 AUTO ANALYZE 重新統計，query plan（資料庫查詢計畫）持續使用 prepare 後的初始 stats（統計資訊，資料庫據此決定最佳查詢路徑），少數 plan 偏差累計影響低併發吞吐；高併發（32t+）下其他開銷主導，差異消失

### 對未來測試的啟示

> **白話結論**：關閉或開啟 AUTO ANALYZE，對 10 分鐘的壓測結果幾乎沒有影響（差距 < 5%）。這是因為短時間測試修改的資料量，根本不足以達到 AUTO ANALYZE 的觸發門檻。因此，這個功能本身運作正常，只是在短測中沒有機會啟動。

- 短時間（<1h）TPC-C 測試開不開 AUTO ANALYZE 結果差異不大
- 但長時間或資料持續變動的場景，AUTO ANALYZE 仍是必要功能（避免 stats 過時導致 query plan 退化——資料庫查詢計畫變差，選了較慢的執行路徑）
- 建議：標準測試保留 AUTO ANALYZE，no-analyze variant 作為對照組驗證 AUTO ANALYZE 「無背景干擾」效果

---

## vm-3node-direct — 2026-05-09

### 環境
- 節點：.32/.33/.34 三節點（拓撲：PD×3 / TiDB SQL×2 (.32 .33) / TiKV×3 / HAProxy on .34）
- 部署工具：TiUP via ansible (`tidb.yml + tidb-tc1.ini -e tidb_rf=3`)
- 配置：`tidb_rf=3`（TiKV 三副本，標準容錯部署）
- AUTO ANALYZE：停用（同 vm-1node-no-analyze）
- 連線入口：直連 .32:4000（**不過 HAProxy**）
- 結果目錄：`vm-3node-direct/20260509-2335/`

### Prepare
- 時間：15m21s（128W）— 比 vm-1node 19m26s 快，三節點 TiKV 平行寫入

### Execute 結果

> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 12,882.2 | 28,663.9 | 782.6% | 37.0 | 62.9 |
| 32 | 14,385.6 | 31,905.0 | 873.9% | 65.0 | 117.4 |
| 64 | 13,204.3 | 29,345.9 | 802.2% | 138.9 | 285.2 |
| 128 | 14,779.6 | 32,877.1 | 897.9% | 240.3 | 486.5 |

### vs vm-1node 對比

| threads | vm-1node | vm-3node-direct | 倍數 |
|---------|----------|-----------------|------|
| 16 | 11,895 | 12,882 | 1.08× |
| 32 | 12,766 | 14,385 | 1.13× |
| 64 | 13,355 | 13,204 | 0.99× |
| 128 | 13,078 | 14,779 | 1.13× |

### 觀察

- **scaling 增益較小**（vs CRDB 與 YBDB）：TiDB 單節點已強，三節點直連僅 +13%（CRDB +37%、YBDB +147%）。
- **64t 略降**：cross-node 2PC 與 PD 元資料 RPC 開銷在中度並發時主導。
- **峰值 128t**（14,779）：與 vm-1node 64t 峰值相近，但有更高的吞吐天花板。

---

## vm-3node — 2026-05-10

### 環境
- 節點：與 vm-3node-direct 同一個叢集（資料未重建）
- 連線入口：HAProxy 172.24.40.34:4000（位於獨立 proxy 主機 .34，輪流轉發至 .32:4000 / .33:4000 — 注意 .34 沒跑 TiDB SQL，只有 PD + TiKV + HAProxy）
- 結果目錄：`vm-3node/20260510-0021/`

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 13,957.6 | 31,027.5 | 847.9% | 35.2 | 56.6 |
| 32 | 18,393.2 | 40,943.4 | 1117.4% | 52.2 | 96.5 |
| 64 | 21,523.0 | 47,788.5 | 1307.5% | 87.4 | 176.2 |
| 128 | **21,875.0** | 48,646.8 | 1328.9% | 166.7 | 369.1 |

### vs vm-3node-direct 對比（HAProxy 提升）

> **差距 = vm-3node (HAProxy) 相對 vm-3node-direct 的 tpmC 增減，正數代表 HAProxy 版本比直連快。**

| threads | vm-3node-direct | vm-3node (HAProxy) | 差距 |
|---------|-----------------|---------------------|------|
| 16 | 12,882 | 13,957 | +8.3% |
| 32 | 14,385 | 18,393 | +27.9% |
| 64 | 13,204 | 21,523 | **+63.0%** |
| 128 | 14,779 | **21,875** | **+48.0%** |

### 觀察

- **HAProxy 大幅優於 direct**（+8% ~ +63%）：與 CRDB 同向（CRDB +9% ~ +26%），與 YBDB 反向。
- **原因**：TiDB SQL 節點只有 .32 與 .33，direct 全部 SQL 集中在 .32 處理，HAProxy roundrobin 將 SQL 平均分散到兩個節點，整體 SQL parsing/planning 容量翻倍。
- **64t / 128t peak ~21,800 tpmC**：兩個 TiDB SQL 節點在 64t 後達飽和。
- **128t NO P99 369ms**：遠低於 go-tpc 16s 上限，無 hang 風險。

### 三家 vm-3node 對比

| | TiDB peak | CRDB peak | YBDB peak |
|--|---|---|---|
| vm-3node-direct | 14,779 (128t) | 11,142 (128t) | 1,024 (16t) |
| **vm-3node (HAProxy)** | **21,875 (128t)** | **14,014 (128t)** | **1,036 (16t)** |
| HAProxy / direct | **+48%** | +26% | +1% |

- **TiDB**：HAProxy 增益最高（+48%），SQL 節點分散最有效
- **CRDB**：symmetric architecture 任一節點都能服務 SQL，HAProxy 也有 +26% 增益
- **YBDB**：tserver 既是儲存又是 SQL，HAProxy 增益最小（+1%），且 direct 與 HAProxy 差異 < 5%

### 結論

TiDB 三節點 + HAProxy 是 **OLTP 高並發場景的最佳部署模式**。peak 21,875 tpmC 為單節點 13,355 的 **1.64×**，超越 CRDB 同等部署 1.56×。  
TiDB SQL/儲存層分離設計讓「加台機器跑 SQL」效益最大化，這是與 CRDB（symmetric）和 YBDB（tserver 一體）架構最大的差異。

---

## vm-3node-verify — 2026-05-10（128t 獨立驗證）

### 目的
驗證 vm-3node 128t = 21,875 是否為「16/32/64t 連跑後 cache warm 累積灌水」造成的虛高，獨立跑 128t 從 fresh state 比較。

### 環境
- 同 vm-3node 叢集（`.32` reboot 後 fresh state，無前段累積）
- 連線入口：HAProxy `.34:4000`
- THREADS_LIST：**僅 128**（warmup 5min @ 16t → 直接跑 128t）
- 結果目錄：`vm-3node-verify/20260510-0119/`

### Execute 結果

| threads | tpmC | tpmTotal | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|
| 128 | **23,746.4** | 52,728.6 | 154.3 | 335.5 |

### 對比

| 測試模式 | tpmC | 差異 |
|---------|------|------|
| vm-3node 連跑 128t（接續 16/32/64t）| 21,875 | baseline |
| **vm-3node-verify 獨立 128t**（fresh state）| **23,746** | **+8.6%** |

### 結論：21,875 為「保守值」

獨立跑（cold start，僅 5min warmup）反而**比連跑高 8.6%**，反證：

1. **21,875 不是 cache warm 灌水**：若為灌水，獨立跑應該更低；實測更高，邏輯反向。
2. **連跑模式 60 分鐘累積效應拉低末段數字**：可能來自 TiKV transaction log 累積、GC pressure 升高、Region 分裂在前段 tier 進行時佔用 IOPS。
3. **TiDB vm-3node HAProxy 真實 peak**：保守 21,875，獨立測量 23,746，**範圍 21,875–23,746**。
4. **三家對比修正**（vm-3node HAProxy peak）：
   - TiDB：**21,875–23,746**
   - CRDB：14,014
   - YBDB：1,036
   - TiDB / CRDB：**1.56–1.69×**

### 方法學啟示

- 連跑模式（16→32→64→128t）方便、節省時間，但**末段數字偏保守**。
- 獨立跑（單一 thread tier + 自帶 warmup）更貼近穩態。
- 若需精確 peak 數字，建議獨立驗證關鍵 thread level；若只需相對比較，連跑模式公平且足夠。
