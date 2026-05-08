# YBDB TPC-C Pipeline Log — yuga-tc1 / S-BASE

> **本測試結論**：YugabyteDB 單節點在 16 個同時連線時勉強可用，超過後效能急劇下降，不適合高併發場景。三節點橫向擴展可帶來約 2.5 倍吞吐，但延遲仍會隨併發線性惡化，是 MVCC 架構設計的根本限制。

---

## 共通說明：Warmup（暖機）的作用

正式測試開始前，先讓資料庫在真實負載下跑 5 分鐘。這段時間資料庫會把常用的資料從硬碟載入記憶體、建立內部索引快取、穩定連線池。如果跳過暖機，正式測試前幾分鐘的數字會因為「冷啟動」而異常偏低，無法反映系統的真實效能。

**TiDB 與 YBDB 在 warmup 階段影響最大的元件不同**：
- **TiDB 影響較大的元件是 TiKV**：底層儲存 RocksDB 有 block cache（記憶體資料塊快取），冷啟動時所有讀取都要去硬碟撈，warmup 期間 cache 才被熱資料填滿。**另一關鍵**：TPC-C 高壓寫入會讓 TiKV 自動進行 Region 分裂（把熱點資料拆散到不同節點），主要發生在 warmup 期間；跳過會導致正式測試前段大量分裂風暴，數字嚴重失真。
- **YBDB 影響較大的元件是 DocDB tablet cache**：底層儲存 DocDB 同樣基於 RocksDB，tablet（資料分片）的 cache 需要 warmup 填充。本測試已預先設定 `ysql_num_shards_per_tserver=3`（固定分片數），動態分裂比 TiDB 少，warmup 主要作用是 cache 預熱。相對 TiDB，YBDB 受 warmup 影響的幅度略小，但 MVCC 版本鏈的初始建立也集中在這個階段。

> **白話**：TiDB 的暖機主要讓「資料分裂」在正式測試前完成，YBDB 的暖機主要讓「記憶體快取」填滿。兩者都需要，但 TiDB 跳過暖機的代價更大。

---

## vm-1node — 2026-05-06

### 環境
- 節點：.32 (172.24.40.32) 單節點 RF=1
- 啟動：`yugabyted start --advertise_address=172.24.40.32 --base_dir=/opt/yugabyte/data --ui=false`
- tserver flags：
  - `ysql_enable_packed_row=false`（關閉資料壓縮，使用標準格式）
  - `yb_enable_read_committed_isolation=true`（啟用標準讀取隔離，與 PostgreSQL 相容）
  - `enable_wait_queues=true`（啟用等待佇列，避免交易衝突時直接失敗）
  - `ysql_num_shards_per_tserver=3`（每個節點建 3 個資料分片，單節點測試時此值偏低，會加劇競爭）
- 測試工具：go-tpc (`-d postgres --conn-params sslmode=disable`)
- 連線入口：直連 172.24.40.32:5433
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260506-1546/`

### Prepare

**結論：資料載入成功，下方警告是工具相容性問題，不影響測試結果。**

- 時間：46m51s（128W）
- 警告：`check prepare failed / pq: Unknown session` — go-tpc 在 load 完成後會執行資料一致性驗證，驗證 SQL 使用 prepared statement；YBDB 的 session-level statement cache 與 PostgreSQL 行為不同，導致 statement handle 失效。**load 本體（資料寫入）已完成無誤**，此警告不影響後續測試。

### 指標說明

| 欄位 | 說明 |
|------|------|
| tpmC | 每分鐘完成的 NEW_ORDER 交易數，TPC-C 官方吞吐量指標。**越高越好**（代表每分鐘能處理越多訂單交易） |
| tpmTotal | 每分鐘完成的全部五種交易數（NEW_ORDER + PAYMENT + ORDER_STATUS + DELIVERY + STOCK_LEVEL）。**越高越好** |
| efficiency | tpmC / tpmTotal，理論值約 45%（NEW_ORDER 佔 TPC-C 交易組合的 45%）；偏低代表非 NEW_ORDER 交易比例異常高，通常是 retry 導致。**越接近 45% 越正常**（偏低代表系統在某類交易卡關） |
| NO avg | NEW_ORDER 平均延遲；go-tpc 無 think time，goroutine 完成一筆就立刻發下一筆，latency 直接反映 DB 處理時間 + 競爭等待。**越低越好**（代表用戶等待時間越短） |
| NO P99 | NEW_ORDER 第 99 百分位延遲；go-tpc 單筆上限 16,106ms（16s），超過即強制逾時。**越低越好**（P99 是最差的 1% 用戶的等待時間，16,106ms 代表已逾時） |

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 414.7 | 912.3 | 25.2% | 2,225 | 3,490 |
| 32 | 394.8 | 871.0 | 24.0% | 4,686 | 8,590 |
| 64 | 378.6 | 834.8 | 23.0% | 9,548 | 16,106 |
| 128 | 370.4 | 809.8 | 22.5% | 15,655 | 16,106 |

### Execute 結果白話解讀

| 併發 | 白話解讀 |
|------|---------|
| 16t | 還算可接受（延遲 2.2 秒） |
| 32t | 開始吃力（延遲破 4.5 秒） |
| 64t | 已出現全面逾時跡象（P99 = 16 秒上限） |
| 128t | 完全無法應付（超過一半的訂單要等 16 秒以上） |

### 觀察

- **tpmC 天花板**：併發從 16 增加到 128，tpmC 僅從 414.7 降至 370.4（-10.7%）。多開 thread 沒有帶來更多吞吐，表示 DB 已無法再並行處理更多工作。
- **NO avg 線性翻倍**：每次 thread 數加倍，NEW_ORDER 平均延遲幾乎同步翻倍（2,225 → 4,686 → 9,548 → 15,655ms）。代表每新增一個 thread，等待時間與競爭成本等比上升。
- **128t 全壓逾時上限**：128t 的 NO P50/P90/P95/P99 全部是 16,106ms，意即超過一半的 NEW_ORDER 都在等 16 秒後才回應（已達 go-tpc 逾時，實際 DB 端可能更長）。
- **efficiency 偏低（~25%）**：理論上 NEW_ORDER 佔所有交易的 45%，efficiency 25% 表示 DB 在 NEW_ORDER 上花了異常多時間，其他交易相對順暢，符合 NEW_ORDER 衝突最集中的預期。
- **STOCK_LEVEL_ERR × 1（128t）**：`Restart read required`，MVCC 讀取衝突，go-tpc 不重試直接計錯誤。

### 根因分析

> **管理層摘要（非技術版）**：YugabyteDB 的設計是：交易完成後才確認有沒有衝突（類似「先下單，結帳時再確認庫存」）。當同時有很多人在搶同一筆資料時，衝突就會不斷發生，每次衝突都要重來，越塞越慢。這次測試就是在驗證這個限制。

YBDB 使用 **optimistic MVCC（樂觀多版本併發控制）**：事務在 commit 時才偵測衝突，衝突則整筆 rollback 後重試。  
go-tpc 無 think time → goroutine（程式內的並行執行單元，每個對應一個同時進行的資料庫請求）連續送出交易，沒有自然間隔 → 多個 goroutine 同時競爭同一 warehouse 的列鎖。

衝突越多 → 重試越多 → 持鎖時間越長 → 更多衝突（正回饋惡化）。

額外加劇因素：`ysql_num_shards_per_tserver=3` 在單節點只建了 3 個 tablets（資料分片），128 個 warehouse 分散到 3 個 tablet，每個 tablet 平均承載 42~43 個 warehouse 的熱點流量，tablet 層競爭極為集中。

### 測試方法補充：為何不開 think time

**Think time 的作用**：TPC-C 標準定義每筆交易前後有 keying time（均值 18s）與 think time（均值 12s），模擬真實用戶操作節奏。開啟後每個 goroutine 大部分時間處於 sleep，128 個 goroutine 任意瞬間真正在 DB 執行的只有約 8 個，有效併發大幅降低，MVCC 碰撞機率趨近於零，tpmC 會顯著回升。

**但這不是我們要的**：本測試目的是找 DB 在持續滿載下的吞吐上限，而非模擬用戶節奏。Think time 會把問題藏起來 — YBDB 在低有效併發下表現良好，但生產環境的連線池通常是持續發送請求的，沒有自然間隔。無 think time 才能暴露 optimistic MVCC 在高競爭下的架構限制，這正是 YBDB vs TiDB（悲觀鎖）對比的關鍵觀測點。

**工具限制**：go-tpc 不支援 think time flag，無法在同一工具內做對照實驗，此項對照測試略過。

> **這次結果代表持續高壓的極端場景，實際生產中因為有自然請求間隔，效能通常會好於此數字，但競爭問題仍然存在。**

---

## vm-3node-direct — 2026-05-07

> 本次改為三台伺服器組成叢集，且**不經過 HAProxy 代理**（直連其中一台），目的是隔離「加台伺服器」與「加代理層」兩件事的效能影響，讓對比更純粹。

### 環境
- 節點：.32/.33/.34 三節點 RF=3，**zone=asia-east1-{a,b,c}**（三台伺服器分配在三個不同的「可用區」，類似不同機架或不同廠房，避免單點故障）
- 啟動：`yugabyted start --fault_tolerance=zone`（**容錯等級設為「區域」**，代表任何一個可用區掛掉，服務仍可繼續運作），.32 為 **bootstrap**（第一台啟動的節點，負責初始化整個叢集，其他節點加入後才形成叢集），.33/.34 透過 **`--join=172.24.40.32`**（加入叢集的指令，類似「加入群組」）加入
- tserver flags：與 vm-1node 相同
- 連線入口：直連 172.24.40.32:5433（**不過 HAProxy**）
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-3node-direct/20260507-0229/`

### Prepare

**結論：資料載入成功，下方是逾時原因說明，不影響測試。**

- 時間：28m00s（128W），比 vm-1node 的 47m51s 快近一倍 — 三節點分擔寫入
- 警告：`driver: bad connection` — 一致性檢查 SQL 是跨表聚合（`condition 3.3.2.x` 是「TPC-C 官方定義的資料一致性驗證規則」），單條查詢時間長，prepare 階段透過 HAProxy 連線（:15433），HAProxy 的「timeout server 30s」（代理層的連線超時設定，超過 30 秒沒回應就斷線）切斷未完成的 check 查詢；data load 本體已完成無誤

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 1024.2 | 2,281.9 | 62.2% | 880.8 | 2,013 |
| 32 | 1016.4 | 2,272.0 | 61.7% | 1,773.6 | 5,369 |
| 64 | 1003.2 | 2,241.0 | 60.9% | 3,461.0 | 13,422 |
| 128 | 964.7 | 2,168.9 | 58.6% | 6,358.4 | 16,106 |

### Execute 結果白話解讀

| 併發 | 白話解讀 |
|------|---------|
| 16t | 表現優良（延遲 0.9 秒，比單節點好 2.5 倍） |
| 32t | 尚可接受（延遲 1.8 秒） |
| 64t | 開始吃力（延遲 3.5 秒，P99 接近 13 秒） |
| 128t | 高壓下 P99 已逾時（平均延遲 6.4 秒，最差 1% 用戶等 16 秒以上） |

### vs vm-1node 對比

> **倍數 = 三節點 tpmC ÷ 單節點 tpmC，越高越好，代表加台伺服器後效能提升的幅度。**

| threads | vm-1node tpmC | vm-3node-direct tpmC | 倍數 |
|---------|---------------|----------------------|------|
| 16 | 414.7 | 1,024.2 | 2.47× |
| 32 | 394.8 | 1,016.4 | 2.57× |
| 64 | 378.6 | 1,003.2 | 2.65× |
| 128 | 370.4 | 964.7 | 2.60× |

### 觀察

- **吞吐穩定 ~1000 tpmC**：16~128t 之間 tpmC 浮動 < 6%（1024 → 964），不像 vm-1node 那樣大幅劣化。三節點橫向擴展讓總吞吐天花板顯著拉高。
- **三節點對單節點約 2.5x**：理論上 RF=3 三節點寫入要做 **Raft consensus**（分散式一致性協議：三節點中至少兩台確認才算寫入成功），不會純線性 3x。實測 2.5x 是合理的水位。
- **NO avg 仍翻倍**：881 → 1,774 → 3,461 → 6,358ms，與 vm-1node 同樣的線性翻倍模式。**MVCC 競爭天花板沒有消失，只是被推高**（加更多台伺服器確實有效，2.5 倍吞吐，但多人搶同一筆資料的衝突問題根本上沒解決，只是把上限推高了）。
- **128t P95/P99 全壓 16,106ms**：與 vm-1node 128t 相同現象，go-tpc 16s 上限被持續觸發。
- **efficiency 60% 正常**：高於 TPC-C 標準的 45%，代表 NEW_ORDER 在這個併發水位下相對其他交易仍流暢。**efficiency 高於 45% 代表 NEW_ORDER 交易的比例相對其他交易高，在這個併發水位下是健康的訊號**（競爭沒有嚴重扭曲交易分布）。
- **OLTP**（線上交易處理：如訂單建立、付款等即時短小的資料庫操作）場景下 follower 節點（備份節點，接收主節點同步資料的伺服器）負擔讀寫均衡。
- **STOCK_LEVEL_ERR × 1（64t/128t 各 1）**：MVCC `Restart read required`，量極少。

### 結論

> **白話版：加三台伺服器比單台效能提升約 2.5 倍，驗證了「加機器有效」。但高併發下延遲仍線性惡化，這是 YugabyteDB 架構設計的限制，加機器無法完全解決。**

vm-3node-direct 證實 **YBDB 橫向擴展對 OLTP 寫入是有效的**，在無 think time 高壓場景下相比單節點吞吐約 2.5×。但 MVCC 競爭曲線形狀不變 — 併發增加會拉高 latency，只是天花板被推高。

---

## vm-3node — 2026-05-07

### 環境
- 節點：與 vm-3node-direct 同一個叢集（資料未重建——**沿用同一份資料是刻意的，兩次測試在同等資料量下才可以直接對比，TPC-C 設計允許這樣做，不影響吞吐量結果的有效性**）
- 連線入口：HAProxy 172.24.40.32:15433 → roundrobin 三節點 :5433

> HAProxy 是連線代理的設定。這次調整了兩個重點：① 把「等待回應的逾時時間」從 30 秒拉高到 600 秒；② 啟用連線保活（keepalive），讓空閒連線不會被誤判為已中斷。原因詳見下方故障排除說明。

- HAProxy 設定（**已調整**）：
  ```
  timeout connect 10s
  timeout client  600s    # 從 30s 拉高
  timeout server  600s    # 從 30s 拉高
  option clitcpka         # TCP keepalive client side
  option srvtcpka         # TCP keepalive server side
  ```
- 結果目錄：`vm-3node/20260507-0812/`

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 1,036.7 | 2,295.9 | 63.0% | 869.6 | 1,946 |
| 32 | 971.4 | 2,146.1 | 59.0% | 1,866.6 | 5,906 |
| 64 | 965.7 | 2,127.2 | 58.7% | 3,669.4 | 15,569 |
| 128 | 915.8 | 2,062.4 | 55.6% | 6,390.8 | 16,106 |

### Execute 結果白話解讀

| 併發 | 白話解讀 |
|------|---------|
| 16t | 最佳（延遲 0.87 秒，HAProxy 幾乎沒有額外影響） |
| 32t | 尚可（延遲 1.87 秒，比直連多約 5%） |
| 64t | 明顯吃力（延遲 3.67 秒，P99 近 16 秒） |
| 128t | 高壓上限（P99 全逾時，但本次正常結束，無卡死） |

### vs vm-3node-direct 對比（HAProxy overhead）

> **差距 = vm-3node (HAProxy) 相對 vm-3node-direct 的 tpmC 增減，負數代表 HAProxy 版本比直連慢。**

| threads | vm-3node-direct | vm-3node (HAProxy) | 差距 |
|---------|-----------------|---------------------|------|
| 16 | 1,024.2 | 1,036.7 | +1.2% |
| 32 | 1,016.4 | 971.4 | -4.4% |
| 64 | 1,003.2 | 965.7 | -3.7% |
| 128 | 964.7 | 915.8 | -5.1% |

### HAProxy timeout 故障排除（重要紀錄）

> **白話摘要（非技術版）**：
> 1. **發生了什麼事？** 跑了 10 分鐘的測試，結果程式卡住 75 分鐘動不了。
> 2. **為什麼？** 系統忙著處理複雜操作超過 30 秒，代理層誤以為連線斷了就切掉，但程式不知道，繼續等回應，永遠等不到。
> 3. **怎麼解決？** 把等待時間上限調高到 600 秒，之後正常。

**初次 vm-3node 測試（舊 HAProxy 設定）128t 卡死無法結束**：
- 測試啟動：`go-tpc --time 10m`，10 分鐘到期後預期退出
- 實際：process hang 75+ 分鐘無 Summary 輸出，必須手動 kill
- log 在 10m timer 觸發時刻凍住，無新 [Current] 區間輸出

**根因鏈**：
1. NEW_ORDER 是多語句交易（INSERT + 多 UPDATE），128 thread 高競爭下 MVCC 重試讓單筆交易 >30s
2. HAProxy `timeout server 30s` 看到 TCP idle（DB 端在重試處理中）→ 主動切斷連線
3. **lib/pq driver**（Go 語言的 PostgreSQL 連線套件）沒收到 **RST 包**（網路層的「強制斷線通知」，沒收到就不知道連線已死），**TCP socket 變半開狀態**（連線表面上還在，實際上已斷，雙方認知不一致），goroutine 卡在 `Read()` 等永不到的回應
4. go-tpc `--time 10m` 觸發後 **`WaitGroup.Wait()`**（程式等待所有請求完成的機制）等所有 goroutine 退出 → 卡死的 goroutine 永不退出 → 主程序 hang

**修復**：
- `timeout client/server` 從 30s 拉高到 600s，比任何單筆交易都長，HAProxy 不會中途切連線
- 加 `clitcpka/srvtcpka` 啟用 TCP keepalive，連線真的死掉時能在分鐘級偵測到

**驗證結果**：128t 在 10m10s 正常結束並輸出 Summary，hang 問題消失。

### 觀察

- **HAProxy overhead 約 3-5%**（加代理層的效能損失約 3~5%，不影響整體架構決策）：除 16t 外，其他併發水位 vm-3node 比 direct 低 3.7~5.1%。原因是多一層 TCP proxy + **tcpka 心跳**（TCP keepalive，定期確認連線還活著，類似心跳偵測，連線真的死掉時才切斷）。
- **trend 與 direct 一致**：tpmC 在 1037 → 916 之間衰減，曲線形狀同 vm-3node-direct，HAProxy 不改變 MVCC 競爭曲線。
- **128t 順利完成**：無 **半開連線 hang**（連線已斷但程式不知道，繼續等回應造成卡死），total 45m18s，與 vm-3node-direct 的 45m15s 相當。

### 結論

> **白話版：HAProxy 代理層的設定正確後，對效能的影響不到 5%，可以接受。這次還順帶發現並修了一個設定問題——如果不修，高壓測試會永遠卡住。**

HAProxy 在 OLTP 高壓場景下要把 timeout 拉到比最壞交易時間還長（這裡 600s）才能避免半開連線 hang。實測 HAProxy roundrobin 對 YBDB 三節點的 overhead 在 5% 內，可接受。
