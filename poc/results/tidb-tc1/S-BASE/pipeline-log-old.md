# TiDB TPC-C Pipeline Log — tidb-tc1 / S-BASE

> **本測試結論**：TiDB 單節點在同等硬體下，吞吐量比 YugabyteDB 高出約 30 倍，延遲控制在 1 秒以內；悲觀鎖設計在高併發下避免了 YugabyteDB 的重試風暴。

---

## 各 variant 拓撲總覽

```
vm-1node                                  client (go-tpc on .31)
                                                  │
                                                  ▼ :4000 (direct)
                              ┌───────────────────────────────────┐
                              │ .32:  PD + TiDB SQL + TiKV        │
                              └───────────────────────────────────┘
  deploy: tidb.yml + tidb-vm1.ini + tidb_rf=1


vm-1node-no-analyze                       同 vm-1node
                                          差別：SET GLOBAL tidb_enable_auto_analyze = OFF


vm-3node-direct                           client (go-tpc on .31)
                                                  │
                                                  ▼ :4000 (direct, no HAProxy)
                              ┌────────────────────────────────────┐
                              │ .32:  PD + TiDB SQL + TiKV ◄───────┤
                              │ .33:  PD + TiDB SQL + TiKV         │
                              │ .34:  PD +            TiKV (no SQL)│
                              └────────────────────────────────────┘
  deploy: tidb.yml + tidb-tc1.ini + tidb_rf=3


vm-3node                                  client (go-tpc on .31)
                                                  │
                                                  ▼ :4000
                              ┌───────────────────────────────────┐
                              │ .34:  HAProxy ─────► roundrobin   │
                              │       PD + TiKV          ▼  ▼     │
                              │ .32:  PD + TiDB SQL + TiKV ◄──────┤
                              │ .33:  PD + TiDB SQL + TiKV ◄──────┤
                              └───────────────────────────────────┘
  deploy: tidb.yml + tidb-tc1.ini + tidb_rf=3 + haproxy.yml(.34)


vm-3node-verify                           同 vm-3node 叢集（不重 prepare）
                                          差別：THREADS_LIST 僅跑 128t 單一 tier


k8s-3node-unlimit                         client (go-tpc on .31)
                                                  │
                                                  ▼ NodePort :30004
                              ┌───────────────────────────────────┐
                              │ k3s cluster (3 nodes)             │
                              │ ┌─ .32 master ─┐ ┌─ .33 worker ─┐ │
                              │ │ PD-0  TiKV-0 │ │ PD-1  TiKV-1 │ │
                              │ │ TiDB-x       │ │ TiDB-y       │ │  ← pod 由 scheduler 排程
                              │ └──────────────┘ └──────────────┘ │
                              │ ┌─ .34 worker ─┐                  │
                              │ │ PD-2  TiKV-2 │                  │
                              │ └──────────────┘                  │
                              └───────────────────────────────────┘
  deploy: tidb-k8s.yml + tidb-tc1-k8s.ini + vars/tidb-k8s-3node-unlimit.yml


k8s-3node-limit                           同 k8s-3node-unlimit 拓撲
                                          差別：k8s_resource_limits=true
                                          TiKV 2c/8GiB、TiDB 1c/3GiB、PD 1c/2GiB
                                          deploy vars: tidb-k8s-3node-limit.yml
                                          result: 20260510-2140
```

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

### vs YugabyteDB vm-1node 對比

> **TiDB / YugabyteDB 倍數 = TiDB tpmC ÷ YugabyteDB tpmC，越高代表 TiDB 相對 YugabyteDB 的優勢越大。**

| threads | TiDB tpmC | YugabyteDB tpmC | TiDB / YugabyteDB |
|---------|-----------|-----------|-------------|
| 16 | 11,895 | 414.7 | 28.7× |
| 32 | 12,767 | 394.8 | 32.3× |
| 64 | 13,355 | 378.6 | 35.3× |
| 128 | 13,079 | 370.4 | 35.3× |

| threads | TiDB NO avg | YugabyteDB NO avg | 差距 |
|---------|-------------|-------------|------|
| 16 | 39 ms | 2,225 ms | TiDB 快 57× |
| 32 | 72 ms | 4,686 ms | TiDB 快 65× |
| 64 | 135 ms | 9,548 ms | TiDB 快 71× |
| 128 | 268 ms | 15,655 ms | TiDB 快 58× |

### 觀察

> **管理層摘要**：TiDB 在同等硬體下的每分鐘交易量約為 YugabyteDB 的 30 倍，延遲保持在 0.3 秒以內。差距來自鎖定機制的根本設計不同：TiDB 讓衝突的請求排隊等候，不重做整筆交易；YugabyteDB 在衝突時整筆重試，高併發下重試不斷堆積導致延遲爆炸。

- **tpmC 隨併發溫和成長**：16 → 64t 從 11,895 提升到 13,355（+12.3%），128t 微降至 13,079，呈現典型的 OLTP（線上交易處理 Online Transaction Processing，指訂單建立、付款等即時短小的資料庫操作）飽和曲線；無 YugabyteDB 那樣的崩潰式下滑。
- **NO avg latency 線性可控**：TiDB 雖然延遲也隨併發增加（39 → 268 ms），但維持在 sub-second（不到一秒）層級；YugabyteDB 同條件已達 15s+ 並打到 go-tpc 16s 上限。
- **efficiency 700-810%**：遠高於 YugabyteDB 的 22-25%，代表 NEW_ORDER 處理流暢，retry/wait 開銷低。
- **64t 為 sweet spot（最佳工作點，效能與資源使用的最佳平衡）**：13,355 tpmC 為峰值，128t 開始略降但仍在合理範圍。

### 根因：架構差異

TiDB 採用 **悲觀鎖（pessimistic locking）**：衝突時後到的 transaction 排隊等鎖，不重試整筆交易。**比喻：類似「先排隊取號，輪到才動作」**。

YugabyteDB 採用 **樂觀 MVCC（Multi-Version Concurrency Control）**：衝突時整筆 rollback 重試。**比喻：類似「先做事，結帳時才確認有沒有衝突，衝突就整筆重做」**。無 think time + 高併發下重試鏈累積 → latency 爆炸。

NEW_ORDER 必更新某個訂單流水號欄位（`district.D_NEXT_O_ID`，每個倉庫區域共用，是 TPC-C 競爭最集中的熱點；每 warehouse × district = 1280 熱點 row）。  
TiDB 在 row 鎖層排隊處理，每筆順序執行；YugabyteDB 在 commit 時偵測衝突，多個 goroutine（程式內的並行執行單元，每個對應一個同時進行的資料庫請求）撞同一 row 就互相 rollback。

### 注意事項

> **整體結論：以下為測試過程中的技術備註，均已解決，不影響最終測試數據的有效性。**

- **AUTO ANALYZE disable 失敗（此 variant 反而是預期）**（此失敗不影響本 variant 的測試目的，本 variant 本來就保留 AUTO ANALYZE 啟用作為基線）：tpcc.sh 在 run 開始時嘗試 `SET GLOBAL tidb_auto_analyze_ratio = 0`，TiDB v8.5.2 拒絕（`value should be greater than or equal to 0.000010`）。已在後續 fix tpcc.sh 改用 `tidb_enable_auto_analyze = OFF`。
- **VM crash 重跑**（虛擬機器意外重啟，TiDB 自動恢復後重跑 prepare，最終數據完整有效）：首次 prepare 期間 .32 VM crash，重啟後 TiDB 自動恢復，重跑 prepare 成功（19m26s vs 首次 23m18s，磁碟 cache 助益）。

---

## vm-1node-no-analyze — 2026-05-08

> **本區塊目的**：對照實驗——關閉 AUTO ANALYZE（自動統計分析）後，重新執行相同的 TPC-C 壓測，確認該功能是否影響交易吞吐量。

### 環境
- 同 vm-1node 環境
- 部署清單：`tidb.yml` + inventory `inventory/tidb-vm1.ini`（同 vm-1node）+ vars `tidb_rf=1`
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
- 部署清單：playbook `tidb.yml` + inventory `inventory/tidb-tc1.ini` + vars `tidb_rf=3`
- 部署工具：TiUP via ansible
- 配置：`tidb_rf=3`（TiKV 三副本，標準容錯部署）
- AUTO ANALYZE：停用（同 vm-1node-no-analyze）
- 連線入口：直連 .32:4000（**不過 HAProxy**）
- 結果目錄：`vm-3node-direct/20260509-2335/`

### Prepare
- 時間：15m21s（128W）— 比 vm-1node 19m26s 快，三節點 TiKV 平行寫入

### Execute 結果

> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）
>
> （efficiency 遠超 100% 屬正常，原因見上方 vm-1node Execute 結果說明；本表保持同樣的「無 think time 持續滿載」測試模式。）

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

- **scaling 增益較小**（vs CockroachDB 與 YugabyteDB）：TiDB 單節點已強，三節點直連僅 +13%（CockroachDB +37%、YugabyteDB +147%）。
- **64t 略降**：cross-node **2PC**（Two-Phase Commit 兩階段提交，跨節點交易需要兩輪確認以保證一致性）與 PD 元資料 **RPC**（Remote Procedure Call 遠端程序呼叫，節點間溝通的方式）開銷在中度併發時主導。
- **峰值 128t**（14,779）：與 vm-1node 64t 峰值相近，但有更高的吞吐天花板。

---

## vm-3node — 2026-05-10（重新 prepare 的乾淨重跑）

### 環境
- 節點：與 vm-3node-direct 同一個叢集（**tpcc DB 重建 + 重新 prepare**，避免前段測試殘留累積效應）
- 部署清單：`inventory/tidb-tc1.ini`（同 vm-3node-direct，僅切換連線入口為 HAProxy；HAProxy 由 `playbooks/haproxy.yml` 部署於 .34）
- 連線入口：HAProxy 172.24.40.34:4000（位於獨立 proxy 主機 .34，輪流轉發至 .32:4000 / .33:4000 — 注意 .34 沒跑 TiDB SQL，只有 PD + TiKV + HAProxy）
- Prepare 時間：17m41s（128W）
- 結果目錄：`vm-3node/20260510-0206/`（取代先前 `20260510-0021/` 為主數據）

### Execute 結果（採用為基準）

> （efficiency 遠超 100% 屬正常，原因見上方 vm-1node Execute 結果說明；本表保持同樣的「無 think time 持續滿載」測試模式。）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 13,573.7 | 30,151.5 | 824.6% | 35.8 | 67.1 |
| 32 | 19,205.1 | 42,749.4 | 1166.7% | 50.3 | 88.1 |
| 64 | 21,992.7 | 48,854.2 | 1336.1% | 86.6 | 167.8 |
| 128 | **22,841.0** | 50,689.1 | 1387.6% | 161.5 | 335.5 |

### 多次測量驗證（128t）

| 測量 | tpmC | 條件 |
|------|------|------|
| 連跑 ① 原始 | 21,875 | 第一次完整 16→128t |
| 獨立 verify | 23,746 | 僅 128t、`.32` reboot 後 fresh state |
| **Clean 重跑（採用）** | **22,841** | 重 prepare + 完整 16→128t |

三次測量範圍 21,875–23,746，**離散 ±4.3%**，落在 noise 內，互相驗證 21,000+ 的真實水準。Clean 重跑 22,841 取為基準（資料新建、無前段累積、有完整 4 個 tier）。

### vs vm-3node-direct 對比（HAProxy 提升）

> **差距 = vm-3node (HAProxy) 相對 vm-3node-direct 的 tpmC 增減，正數代表 HAProxy 版本比直連快。**

| threads | vm-3node-direct | vm-3node (HAProxy, clean) | 差距 |
|---------|-----------------|--------------------------|------|
| 16 | 12,882 | 13,573 | +5.4% |
| 32 | 14,385 | 19,205 | +33.5% |
| 64 | 13,204 | 21,992 | **+66.6%** |
| 128 | 14,779 | **22,841** | **+54.5%** |

### 觀察

- **HAProxy 大幅優於 direct**（+5% ~ +67%）：與 CockroachDB 同向（CockroachDB +9% ~ +26%），與 YugabyteDB 反向。
- **原因**：TiDB SQL 節點只有 .32 與 .33，direct 全部 SQL 集中在 .32 處理，HAProxy roundrobin 將 SQL 平均分散到兩個節點，整體 SQL parsing/planning 容量翻倍。

  > **澄清：HAProxy 增益不是來自「連線復用」**
  >
  > HAProxy 在 TCP mode（MySQL／PostgreSQL 協定）下不做連線池——client 連線 1:1 對應 backend 連線；go-tpc 每個 worker 是持久長連線，整個測試期無連線開關，沒有「重複開新連線」可省。
  >
  > 真正的機制是 **SQL 節點分散**：
  > - **direct 模式**：128 條長連線全部打到 `.32`，TiDB SQL parse/plan/exec 都集中在單節點
  > - **HAProxy 模式**：roundrobin 把 64 條導去 `.33`，兩個 TiDB SQL 節點各分擔一半，整體 SQL 處理容量翻倍
  >
  > 反證：若是連線復用，無論底下幾個 SQL 節點都應有近似增益。實測：
  > - **TiDB（2 SQL 節點）+55%**
  > - **CockroachDB（3 對稱節點，每個都能服務 SQL）+26%**
  > - **YugabyteDB（tserver 一體，加 SQL 節點受 MVCC 競爭限制）+1%**
  >
  > 增益幅度與「可分散到的 SQL 節點數／架構是否容許 SQL 層水平擴充」高度相關，與連線復用無關。

- **64t / 128t peak ~22,400 tpmC**：兩個 TiDB SQL 節點在 64t 後達飽和。
- **128t NO P99 335ms**：遠低於 go-tpc 16s 上限，無 hang 風險。

### 三家 vm-3node 對比

| | TiDB peak | CockroachDB peak | YugabyteDB peak |
|--|---|---|---|
| vm-3node-direct | 14,779 (128t) | 11,142 (128t) | 1,024 (16t) |
| **vm-3node (HAProxy)** | **22,841 (128t)** | **14,014 (128t)** | **1,036 (16t)** |
| HAProxy / direct | **+55%** | +26% | +1% |

- **TiDB**：HAProxy 增益最高（+48%），SQL 節點分散最有效
- **CockroachDB**：symmetric architecture 任一節點都能服務 SQL，HAProxy 也有 +26% 增益
- **YugabyteDB**：tserver 既是儲存又是 SQL，HAProxy 增益最小（+1%），且 direct 與 HAProxy 差異 < 5%

### 結論

TiDB 三節點 + HAProxy 是 **OLTP 高併發場景的最佳部署模式**。clean 重跑 peak 22,841 tpmC 為單節點 13,355 的 **1.71×**，超越 CockroachDB 同等部署 1.63×。
TiDB SQL/儲存層分離設計讓「加台機器跑 SQL」效益最大化，這是與 CockroachDB（symmetric）和 YugabyteDB（tserver 一體）架構最大的差異。
（白話：TiDB 的 SQL 接收層與儲存層分離，意味著「加機器跑 SQL」可以單獨進行；CockroachDB 把兩個角色合在每個節點上、YugabyteDB 則把 SQL 與儲存綁在同一進程，所以同樣加 HAProxy 分流，TiDB 取得最大的擴展空間。）

---

## vm-3node-verify — 2026-05-10（128t 獨立驗證，已被 clean 重跑取代為基準，保留作對照）

### 目的
驗證 vm-3node 128t（首測 21,875）是否為連跑模式累積暖機效應（前段測試讓資料庫快取已預熱，可能讓末段數字虛高）造成的虛高，獨立跑 128t 從 fresh state 比較。

### 環境
- 同 vm-3node 叢集（`.32` reboot 後 fresh state，無前段累積）
- 部署清單：`inventory/tidb-tc1.ini`（同 vm-3node 叢集，無重 prepare）
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

1. **21,875 不是連跑暖機虛高**（即「前段測試累積快取效應拉抬末段數字」）：若為虛高，獨立跑應該更低；實測更高，邏輯反向。
2. **連跑模式 60 分鐘累積效應拉低末段數字**（以下為連跑模式末段數字偏低的技術成因，管理層可略讀；摘要：前段測試在背景累積的清理工作會稍微拖慢後段）：可能來自 TiKV transaction log 累積、**GC pressure**（垃圾回收——資料庫自動清掉舊版本資料的背景機制——壓力）升高、**Region 分裂**（TiKV 內部資料區塊切割，資料量增大時自動細分）在前段 tier 進行時佔用 **IOPS**（磁碟每秒輸入輸出次數）。
3. **TiDB vm-3node HAProxy 真實 peak**：保守 21,875，獨立測量 23,746，**範圍 21,875–23,746**。
4. **三家對比修正**（vm-3node HAProxy peak）：
   - TiDB：**21,875–23,746**
   - CockroachDB：14,014
   - YugabyteDB：1,036
   - TiDB / CockroachDB：**1.56–1.69×**

### 方法學啟示

- 連跑模式（16→32→64→128t）方便、節省時間，但**末段數字偏保守**。
- 獨立跑（單一 thread tier + 自帶 warmup）更貼近穩態。
- 若需精確 peak 數字，建議獨立驗證關鍵 thread level；若只需相對比較，連跑模式公平且足夠。

---

## k8s-3node-unlimit — 2026-05-10

> **本段落用 K8s（容器化平台）取代直接在虛擬機跑 TiDB。除了部署方式不同，叢集元件數量與資料複本配置與 vm-3node 完全相同；差別僅在「跑在容器裡」這一層的額外消耗。**

### 環境
- 拓撲：**k3s**（輕量版 Kubernetes 容器編排平台）v1.29.14 三節點（.32 master，.33/.34 worker）+ **TiDB Operator**（TiDB 官方提供的 K8s 自動化部署工具，把 TiDB 包成 K8s 可管理的資源）+ **TidbCluster**（在 K8s 內定義 TiDB 叢集的設定物件）(PD×3 / TiKV×3 / TiDB SQL×2)
- 部署清單：playbook `playbooks/tidb-k8s.yml` + inventory `inventory/tidb-tc1-k8s.ini` + vars `vars/tidb-k8s-3node-unlimit.yml`（TidbCluster CR template `roles/tidb_cluster/templates/tidbcluster.yaml.j2`，namespace `tidb-cluster`）
- TidbCluster `tidb-poc`：PD 10Gi **PV**（Persistent Volume，持續性資料儲存空間，避免 pod 重啟資料消失）、TiKV 100Gi PV、TiDB 無 PV（無狀態）
- 容器資源限制：**無**（unlimit variant；對應 TidbCluster CR 的 spec 區塊 — 詳見 Item #9 對照表）
- 連線入口：**NodePort**（K8s 服務對外暴露的固定埠口）`.32:30004` → tidb-poc-tidb Service → TiDB SQL pods (.32/.33)
- 結果目錄：`k8s-3node-unlimit/20260510-1409/`

### Prepare
- 時間：15m23s（128W）— 與 VM 相當

### Execute 結果

> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）
>
> （efficiency 遠超 100% 屬正常，原因見上方 vm-1node Execute 結果說明；本表保持同樣的「無 think time 持續滿載」測試模式。）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 13,160.9 | 29,207.6 | 799.5% | 36.4 | 58.7 |
| 32 | 16,304.1 | 36,228.4 | 990.5% | — | — |
| 64 | **18,918.8** | 41,915.3 | 1149.3% | — | — |
| 128 | 18,871.3 | 42,053.0 | 1146.4% | — | — |

### vs vm-3node clean run 對比（K8s 容器化 overhead）

> 兩組同樣三節點 RF=3，差異僅為 deployment runtime（VM bare process vs k3s containerd pod）。

| threads | vm-3node | k8s-unlimit | overhead |
|---------|----------|-------------|----------|
| 16 | 13,573.7 | 13,160.9 | -3.0% |
| 32 | 19,205.1 | 16,304.1 | -15.1% |
| 64 | 21,992.7 | 18,918.8 | -14.0% |
| 128 | 22,841.0 | 18,871.3 | -17.4% |
| **peak** | 22,841 | **18,919** | **-17.2%** |

### 觀察

- **K8s overhead 平均 ~12%**：低併發（16t）僅 -3%，高併發（128t）達 -17%。
- **原因**：高併發下 container network（CNI flannel）的 packet 處理、cgroup 計算、namespace 切換開銷等比放大。低併發時 CPU 都閒置，overhead 被吸收。  
  （白話：高併發下容器網路與資源隔離機制處理量放大，使容器部署比 VM 慢約 17%；低併發 CPU 還有閒置容量時這些 overhead 被吸收。）
- **64t 為峰值**（18,919）：與 VM 同樣在 64t 達飽和，但天花板被 K8s overhead 拉低。
- **128t 略降**（18,871）：與 64t 幾乎持平（-0.2%），仍處於穩態，無 hang。

### 結論

K8s 部署的 TiDB 比 VM bare-process 部署 **慢約 12-17%**（高併發更明顯），但仍遠優於 CockroachDB（14,014）和 YugabyteDB（1,036）的 VM 部署。
若選 K8s 為部署模式，需留意：
1. 高 CPU 利用率場景（OLTP 高峰）overhead 可達 17%
2. 容器 networking（Flannel/Calico）對 TPC-C 這種高 RPS workload 影響顯著
3. 若選擇 K8s + 資源限制，需依下方 k8s-3node-limit 結果預估約 41% peak 下降

### k8s-3node 資源限制對照（unlimit vs limit 結構）

```yaml
# unlimit variant（本段）
spec:
  pd:
    requests:    {}     # 無
    limits:      {}     # 無
  tikv:
    requests:    {}     # 無
    limits:      {}     # 無
  tidb:
    requests:    {}     # 無
    limits:      {}     # 無

# limit variant（詳見下方 k8s-3node-limit 段落）
spec:
  pd:
    requests:    { cpu: 500m, memory: 1Gi }
    limits:      { cpu: 1,    memory: 2Gi }
  tikv:
    requests:    { cpu: 1,    memory: 4Gi }
    limits:      { cpu: 2,    memory: 8Gi }   # 即 README "TiKV Nc" = 2 cores
  tidb:
    requests:    { cpu: 500m, memory: 1Gi }
    limits:      { cpu: 1,    memory: 3Gi }
```

---

## k8s-3node-limit — 2026-05-10

### 環境
- 同 k8s-3node-unlimit 拓撲，**TidbCluster CR 重建**（刪除舊 CR + PVC，重新部署帶 limits）
- 容器資源限制：
  - PD：limit cpu=1, mem=2Gi（request 0.5/1Gi）
  - TiDB SQL：limit cpu=1, mem=3Gi（request 0.5/1Gi）
  - **TiKV：limit cpu=2, mem=8Gi**（request 1/4Gi）— 最關鍵限制（vs unlimit 可吃滿 4 vCPU）
- 連線入口：NodePort `.32:30004`
- 結果目錄：`k8s-3node-limit/20260510-2140/`

### Prepare
- 時間：21m57s（128W，比 unlimit 15m23s 慢 +43%）— TiKV 2 CPU 限制下寫入頻寬下降

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 10,470.5 | 23,317.3 | 636.1% | 45.9 | 109.1 |
| 32 | **11,080.7** | 24,589.3 | 673.2% | 85.9 | 201.3 |
| 64 | 10,895.5 | 24,263.2 | 661.9% | 173.1 | 369.1 |
| 128 | 10,519.7 | 23,395.6 | 639.1% | 352.0 | 805.3 |

### vs k8s-3node-unlimit 對比（資源限制 overhead）

> **差距 = limit 相對 unlimit 的 tpmC 變動，負數代表限制造成的吞吐減損。**

| threads | k8s-unlimit | k8s-limit | limit overhead |
|---------|-------------|-----------|----------------|
| 16 | 13,160.9 | 10,470.5 | -20.4% |
| 32 | 16,304.1 | 11,080.7 | -32.0% |
| 64 | 18,918.8 | 10,895.5 | **-42.4%** |
| 128 | 18,871.3 | 10,519.7 | **-44.3%** |
| **peak** | 18,919 | **11,081** | **-41.4%** |

### 觀察

- **32t 即達飽和**：32t peak 11,080，64t/128t 反而略降。不像 unlimit 在 64t 達 18,919 才飽和。原因：TiKV 2 CPU 限制（vs unlimit 可吃 ~3-4 CPU），32t 已榨乾運算資源。
- **限制 overhead 隨併發放大**：16t 僅 -20%，128t 達 -44%。低併發下 CPU 不滿，限制不顯影響；高併發下完全被 CPU cap 攔截。
- **DELIVERY_ERR × 2（128t）**：少量交易因資源不足逾時失敗（unlimit 從未出現此錯誤）。
- **吞吐天花板 ~11,000 tpmC**：CPU cap 直接決定上限。

### 五組 TiDB 對比（vm-1node → k8s-3node-limit）

| variant | peak tpmC | scale 區間 |
|---------|-----------|-----------|
| vm-1node | 13,355 (64t) | 平緩，飽和於 64t |
| vm-3node-direct | 14,779 (128t) | +11% vs vm-1node |
| vm-3node (HAProxy) | 22,841 (128t) | **+71%** vs vm-1node |
| k8s-3node-unlimit | 18,919 (64t) | -17% vs vm（K8s 容器化開銷）|
| **k8s-3node-limit** | **11,081 (32t)** | **-51% vs vm**（CPU cap 主導）|

### Parameter delta（unlimit → limit 各參數對 overhead 的影響）

| 元件 | unlimit | limit | 預期影響 |
|---|---|---|---|
| TiKV CPU | 無上限（4 cores） | 2 cores | 高併發 IO 處理被截斷（最主要影響來源）|
| TiKV memory | 無上限 | 8 GiB | block cache 被壓縮，磁碟 read 增加 |
| TiDB CPU | 無上限（4 cores） | 1 core | SQL parsing throughput 受限 |
| TiDB memory | 無上限 | 3 GiB | 大查詢可能 OOM |
| PD CPU | 無上限 | 1 core | scheduler 排程延遲 |

### 結論

**資源限制（CPU 2 cores per TiKV pod）對 OLTP 吞吐影響極大**：
1. peak 從 unlimit 的 18,919 → limit 的 11,081，**減少 41%**
2. scaling 曲線明顯改變：unlimit 在 64t 才飽和，limit 在 32t 就到頂
3. 高併發下吞吐反而略降（128t 比 32t 低 5%），CPU cap 開始引發排隊延遲反噬

**部署建議**：
- 不建議在 OLTP 場景對 TiKV 設過嚴 CPU limit（≤2 cores 損失 40%+ 吞吐）
- 若需 multi-tenancy 隔離，至少給 TiKV 3 cores 留 burst 空間
- request/limit 比 request 應接近 limit（避免 throttling 抖動）

---

## vm-1node-rc — 2026-05-18（PoC v4.7 baseline，5 round × 5 min × 4 threads）

> **本段目的**：在 PoC v4.7 新框架（detached suite wrapper + 多輪平均 + isolation 雙閘）下重建 vm-1node RC 基準，取代 2026-05-07 單次 10 min 結果作為後續 rr/strict 與其他 DB 對標的可重現基線。

### 環境
- 節點：.32 (172.24.40.32) 單節點，PD + TiDB + TiKV 同主機部署，RF=1
- TiDB 版本：v8.5.2
- 部署工具：TiUP via ansible playbook `tidb-vm1.yml`（含 systemd drop-in `no-proxy.conf` 避免 gRPC 經 HTTP proxy）
- AUTO ANALYZE：**停用**（`SET GLOBAL tidb_enable_auto_analyze = OFF`）+ `tidb_txn_mode='pessimistic'`
- 連線入口：直連 172.24.40.32:4000
- 測試工具：go-tpc on .31（MySQL driver，`--conn-params transaction_isolation='READ-COMMITTED'&tidb_txn_mode='pessimistic'`）
- Warehouses：128
- Warmup：**20 min @ 64 threads**（取代舊版 5 min，理由：見 2026-05-17 warmup duration 觀察）
- Run：**每組 5 round × 5 min**（取代舊版單次 10 min，可得 round-to-round variance）
- Threads：16 / 32 / 64 / 128（共 4 組，每組 5 round，總 run 時長 2h41min）
- TPCC_TS：`20260518T154918+0800`
- 結果目錄：`vm-1node-rc/tidb-vm-1node-rc-20260518T154918+0800/`

### Suite 階段時序

| Phase | 起 | 訖 | 耗時 |
|-------|-----|------|------|
| gate (OS / chrony / disk / iso pre) | 15:59 | 15:59 | <1min |
| prepare (128W + check-all + analyze + explain) | 15:59 | 16:53 | 54min |
| gate-isolation (post-prepare active gate) | — | 16:54 | <1min |
| run (4 thread × 5 round + 20min warmup) | 16:54 | 19:35 | 2h41min |
| collect (DB log tail + config dump + env snapshot) | 19:35 | 19:35 | <1s |
| **total (suite)** | **15:49** | **19:35** | **3h46min** |

### Gate 結果
- `transaction_isolation = READ-COMMITTED, tidb_txn_mode = pessimistic`（prepare 前 + 後雙閘驗證一致）
- THP=`never`、`vm.swappiness=1`、`ulimit -n=65536`
- NTP drift：System time `0.000084s slow of NTP time`（遠低於 1ms 閾值）
- disk：sda3 已 growpart 至 100GB

### Prepare
- 時間：54m05s（128W）
- check-all 128 warehouse 全條件通過，無 error
- TiDB schema：`CLUSTERED PK`，CHARSET=utf8mb4，COLLATE=utf8mb4_bin

### Execute 結果（5 round 平均）

> （tpmC：越高越好；NO p99：越低越好；efficiency 遠超 100% 屬正常，原因見 vm-1node Execute 結果說明）

| threads | tpmC mean | range/mean | tpmTotal mean | efficiency mean | NO p50 (ms) | NO p95 (ms) | NO p99 (ms) |
|---------|-----------|-----------|---------------|-----------------|------------|------------|------------|
| 16  | **9,677**  | 7.4%   | 21,546 | 587.9%   | 52    | 76    | 96   |
| 32  | 10,987 | **18.8%** ⚠️ | 24,396 | 667.4%   | 94    | 138   | 176  |
| 64  | 12,838 | 9.6%   | 28,481 | 779.9%   | 156   | 235   | 305  |
| 128 | **13,209** | 5.9%   | 29,305 | 802.4%   | 289   | 473   | 612  |

### Round-by-round tpmC（檢驗穩定性）

| Threads | r1 | r2 | r3 | r4 | r5 |
|---------|-----|-----|-----|-----|-----|
| 16  | 9377  | 10036 | 9468  | 9411  | 10094 |
| 32  | 10638 | 9702  | 11136 | 11769 | 11688 |
| 64  | 12349 | 13576 | 12464 | 12800 | 13001 |
| 128 | 13331 | 13240 | 13241 | 13508 | 12723 |

- **32 threads 變異最大**（range/mean 18.8%）：round-2 (9702) vs round-4 (11769) 差 21%；其他組均 ≤10%。
- 推測 32t 處於 cache hit / commit batching 的 transition zone，建議 rr/strict 重跑時將 WARMUP_SEC 從 1200 提至 1800 觀察是否收斂。

### vs vm-1node (2026-05-07, 10 min 單次) 對比

| threads | 2026-05-07 (10min×1) | 2026-05-18 (5min×5 avg) | 差異 | 解讀 |
|---------|---------------------|------------------------|------|------|
| 16  | 11,895 | 9,677  | **-18.6%** | 短 run 噪聲較大；舊版單次可能落在偏高側 |
| 32  | 12,767 | 10,987 | -13.9% | 同上，但 32t 變異尤其大（見上表）|
| 64  | 13,355 | 12,838 | -3.9%  | 接近，落在統計誤差內 |
| 128 | 13,079 | 13,209 | +1.0%  | 一致 |

**啟示**：高併發（64t/128t）穩定可重現；低併發（16t/32t）短 run 噪聲顯著，**多輪平均比單次更準確**，建議所有後續對標採 5 round × 5 min 為標準。

### Saturation 分析

```
threads:  16 ───── 32 ───── 64 ───── 128
tpmC:    9677    10987   12838    13209
                 +14%    +17%     +3%       ← 邊際收益崩潰
p99(ms):   96      176     305     612
                +84%    +73%    +101%       ← latency 翻倍
```

**結論**：vm-1node RC 的甜點在 **64 threads**。128 threads 只多 +3% throughput 換來 2x latency，已過飽和點。

### 觀察

- **tpmC 隨併發溫和成長至 64t**：9,677 → 10,987 → 12,838，scaling 還在線性區間。
- **64 → 128 邊際收益僅 +3%**：明確的飽和訊號；單節點 16GB RAM + 4 vCPU 的天花板在這個工作負載大約是 13k tpmC。
- **latency 在 64t 之後翻倍**：p99 305ms → 612ms，但都遠低於 1s，無 hang 風險。
- **效率比舊版略低**：efficiency 顯示 588-802%（舊版 723-811%），與 tpmC 一致；新方法多輪平均較保守。
- **memory 健康**：DB host 11Gi used / 15Gi total（73%），無 swap，block-cache 5GB + mem-quota 3GB 配置合適。

### 缺陷與限制 ⚠️

1. **無 DB-host 端 OS 監控**（嚴重）  
   `mpstat / iostat / vmstat / sar` 全部跑在 **TPCC client `.31`**，CPU 88-93% idle 只能證明客戶端不是瓶頸，**無法**回答以下關鍵問題：
   - `.32` TiKV 是 CPU-bound 還是 IO-bound？
   - 128t 飽和真實成因是 commit batching、Raft replication、還是磁碟 fsync？
   - 32t round 間變異 18.8% 是否對應 `.32` 上 background compaction / GC 噪聲？
   
   **修法**：`run.sh` 已修：所有監控指令同時 ssh 採樣到 `.32`，輸出 `*-db.txt` 對照檔（見 commit）。
   
2. **`efficiency > 100%` 不可與 TPC-C 官網數字直接比**：go-tpc 不打 keying/think time，是本 PoC 內部對標的相對指標。

### 結論

vm-1node RC 在 PoC v4.7 框架下穩定可重現，**64 threads 為甜點，128 threads 已飽和**。本輪資料作為後續 `vm-1node-rr`、`vm-1node-strict`、以及 CRDB/YBDB 對標的 baseline。`run.sh` 已補上 DB-host 端監控；下輪測試可直接觀察 TiKV CPU / disk %util 並回答上述瓶頸歸因問題。

---

# Archived from active pipeline-log on 2026-05-20 — TiDB K8s sections (2026-05-10, pre-v4.7 wrapper)

> 以下兩段（`k8s-3node-unlimit` / `k8s-3node-limit`）來自 2026-05-10 流程，採單次 10min run，非 PoC v4.7 標準的 5-round × 20min warmup × DB-host 雙邊監控格式。
> 為避免與 v4.7 baseline 混用，已從 active `pipeline-log.md` 移除至此存檔；待 K8s 環境用 v4.7 wrapper 重跑後再以正式段落形式重新納入。

## k8s-3node-unlimit — 2026-05-10

> **本段落用 K8s（容器化平台）取代直接在虛擬機跑 TiDB。除了部署方式不同，叢集元件數量與資料複本配置與 vm-3node 完全相同；差別僅在「跑在容器裡」這一層的額外消耗。**

### 環境
- 拓撲：**k3s**（輕量版 Kubernetes 容器編排平台）v1.29.14 三節點（.32 master，.33/.34 worker）+ **TiDB Operator**（TiDB 官方提供的 K8s 自動化部署工具，把 TiDB 包成 K8s 可管理的資源）+ **TidbCluster**（在 K8s 內定義 TiDB 叢集的設定物件）(PD×3 / TiKV×3 / TiDB SQL×2)
- 部署清單：playbook `playbooks/tidb-k8s.yml` + inventory `inventory/tidb-tc1-k8s.ini` + vars `vars/tidb-k8s-3node-unlimit.yml`（TidbCluster CR template `roles/tidb_cluster/templates/tidbcluster.yaml.j2`，namespace `tidb-cluster`）
- TidbCluster `tidb-poc`：PD 10Gi **PV**（Persistent Volume，持續性資料儲存空間，避免 pod 重啟資料消失）、TiKV 100Gi PV、TiDB 無 PV（無狀態）
- 容器資源限制：**無**（unlimit variant；對應 TidbCluster CR 的 spec 區塊 — 詳見 Item #9 對照表）
- 連線入口：**NodePort**（K8s 服務對外暴露的固定埠口）`.32:30004` → tidb-poc-tidb Service → TiDB SQL pods (.32/.33)
- 結果目錄：`k8s-3node-unlimit/20260510-1409/`

### Prepare
- 時間：15m23s（128W）— 與 VM 相當

### Execute 結果

> （tpmC / tpmTotal：越高越好；NO avg / NO P99：越低越好）
>
> （efficiency 遠超 100% 屬正常，原因見上方 vm-1node Execute 結果說明；本表保持同樣的「無 think time 持續滿載」測試模式。）

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 13,160.9 | 29,207.6 | 799.5% | 36.4 | 58.7 |
| 32 | 16,304.1 | 36,228.4 | 990.5% | — | — |
| 64 | **18,918.8** | 41,915.3 | 1149.3% | — | — |
| 128 | 18,871.3 | 42,053.0 | 1146.4% | — | — |

### vs vm-3node clean run 對比（K8s 容器化 overhead）

> 兩組同樣三節點 RF=3，差異僅為 deployment runtime（VM bare process vs k3s containerd pod）。

| threads | vm-3node | k8s-unlimit | overhead |
|---------|----------|-------------|----------|
| 16 | 13,573.7 | 13,160.9 | -3.0% |
| 32 | 19,205.1 | 16,304.1 | -15.1% |
| 64 | 21,992.7 | 18,918.8 | -14.0% |
| 128 | 22,841.0 | 18,871.3 | -17.4% |
| **peak** | 22,841 | **18,919** | **-17.2%** |

### 觀察

- **K8s overhead 平均 ~12%**：低併發（16t）僅 -3%，高併發（128t）達 -17%。
- **原因**：高併發下 container network（CNI flannel）的 packet 處理、cgroup 計算、namespace 切換開銷等比放大。低併發時 CPU 都閒置，overhead 被吸收。
  （白話：高併發下容器網路與資源隔離機制處理量放大，使容器部署比 VM 慢約 17%；低併發 CPU 還有閒置容量時這些 overhead 被吸收。）
- **64t 為峰值**（18,919）：與 VM 同樣在 64t 達飽和，但天花板被 K8s overhead 拉低。
- **128t 略降**（18,871）：與 64t 幾乎持平（-0.2%），仍處於穩態，無 hang。

### 結論

K8s 部署的 TiDB 比 VM bare-process 部署 **慢約 12-17%**（高併發更明顯），但仍遠優於 CockroachDB（14,014）和 YugabyteDB（1,036）的 VM 部署。
若選 K8s 為部署模式，需留意：
1. 高 CPU 利用率場景（OLTP 高峰）overhead 可達 17%
2. 容器 networking（Flannel/Calico）對 TPC-C 這種高 RPS workload 影響顯著
3. 若選擇 K8s + 資源限制，需依下方 k8s-3node-limit 結果預估約 41% peak 下降

### k8s-3node 資源限制對照（unlimit vs limit 結構）

```yaml
# unlimit variant（本段）
spec:
  pd:
    requests:    {}     # 無
    limits:      {}     # 無
  tikv:
    requests:    {}     # 無
    limits:      {}     # 無
  tidb:
    requests:    {}     # 無
    limits:      {}     # 無

# limit variant（詳見下方 k8s-3node-limit 段落）
spec:
  pd:
    requests:    { cpu: 500m, memory: 1Gi }
    limits:      { cpu: 1,    memory: 2Gi }
  tikv:
    requests:    { cpu: 1,    memory: 4Gi }
    limits:      { cpu: 2,    memory: 8Gi }   # 即 README "TiKV Nc" = 2 cores
  tidb:
    requests:    { cpu: 500m, memory: 1Gi }
    limits:      { cpu: 1,    memory: 3Gi }
```

---

## k8s-3node-limit — 2026-05-10

### 環境
- 同 k8s-3node-unlimit 拓撲，**TidbCluster CR 重建**（刪除舊 CR + PVC，重新部署帶 limits）
- 容器資源限制：
  - PD：limit cpu=1, mem=2Gi（request 0.5/1Gi）
  - TiDB SQL：limit cpu=1, mem=3Gi（request 0.5/1Gi）
  - **TiKV：limit cpu=2, mem=8Gi**（request 1/4Gi）— 最關鍵限制（vs unlimit 可吃滿 4 vCPU）
- 連線入口：NodePort `.32:30004`
- 結果目錄：`k8s-3node-limit/20260510-2140/`

### Prepare
- 時間：21m57s（128W，比 unlimit 15m23s 慢 +43%）— TiKV 2 CPU 限制下寫入頻寬下降

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 10,470.5 | 23,317.3 | 636.1% | 45.9 | 109.1 |
| 32 | **11,080.7** | 24,589.3 | 673.2% | 85.9 | 201.3 |
| 64 | 10,895.5 | 24,263.2 | 661.9% | 173.1 | 369.1 |
| 128 | 10,519.7 | 23,395.6 | 639.1% | 352.0 | 805.3 |

### vs k8s-3node-unlimit 對比（資源限制 overhead）

> **差距 = limit 相對 unlimit 的 tpmC 變動，負數代表限制造成的吞吐減損。**

| threads | k8s-unlimit | k8s-limit | limit overhead |
|---------|-------------|-----------|----------------|
| 16 | 13,160.9 | 10,470.5 | -20.4% |
| 32 | 16,304.1 | 11,080.7 | -32.0% |
| 64 | 18,918.8 | 10,895.5 | **-42.4%** |
| 128 | 18,871.3 | 10,519.7 | **-44.3%** |
| **peak** | 18,919 | **11,081** | **-41.4%** |

### 觀察

- **32t 即達飽和**：32t peak 11,080，64t/128t 反而略降。不像 unlimit 在 64t 達 18,919 才飽和。原因：TiKV 2 CPU 限制（vs unlimit 可吃 ~3-4 CPU），32t 已榨乾運算資源。
- **限制 overhead 隨併發放大**：16t 僅 -20%，128t 達 -44%。低併發下 CPU 不滿，限制不顯影響；高併發下完全被 CPU cap 攔截。
- **DELIVERY_ERR × 2（128t）**：少量交易因資源不足逾時失敗（unlimit 從未出現此錯誤）。
- **吞吐天花板 ~11,000 tpmC**：CPU cap 直接決定上限。

### 五組 TiDB 對比（vm-1node → k8s-3node-limit）

| variant | peak tpmC | scale 區間 |
|---------|-----------|-----------|
| vm-1node | 13,355 (64t) | 平緩，飽和於 64t |
| vm-3node-direct | 14,779 (128t) | +11% vs vm-1node |
| vm-3node (HAProxy) | 22,841 (128t) | **+71%** vs vm-1node |
| k8s-3node-unlimit | 18,919 (64t) | -17% vs vm（K8s 容器化開銷）|
| **k8s-3node-limit** | **11,081 (32t)** | **-51% vs vm**（CPU cap 主導）|

### Parameter delta（unlimit → limit 各參數對 overhead 的影響）

| 元件 | unlimit | limit | 預期影響 |
|---|---|---|---|
| TiKV CPU | 無上限（4 cores） | 2 cores | 高併發 IO 處理被截斷（最主要影響來源）|
| TiKV memory | 無上限 | 8 GiB | block cache 被壓縮，磁碟 read 增加 |
| TiDB CPU | 無上限（4 cores） | 1 core | SQL parsing throughput 受限 |
| TiDB memory | 無上限 | 3 GiB | 大查詢可能 OOM |
| PD CPU | 無上限 | 1 core | scheduler 排程延遲 |

### 結論

**資源限制（CPU 2 cores per TiKV pod）對 OLTP 吞吐影響極大**：
1. peak 從 unlimit 的 18,919 → limit 的 11,081，**減少 41%**
2. scaling 曲線明顯改變：unlimit 在 64t 才飽和，limit 在 32t 就到頂
3. 高併發下吞吐反而略降（128t 比 32t 低 5%），CPU cap 開始引發排隊延遲反噬

**部署建議**：
- 不建議在 OLTP 場景對 TiKV 設過嚴 CPU limit（≤2 cores 損失 40%+ 吞吐）
- 若需 multi-tenancy 隔離，至少給 TiKV 3 cores 留 burst 空間
- request/limit 比 request 應接近 limit（避免 throttling 抖動）

---
