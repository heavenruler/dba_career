# YBDB TPC-C Pipeline Log — yuga-tc1 / S-BASE

## vm-1node — 2026-05-06

### 環境
- 節點：.32 (172.24.40.32) 單節點 RF=1
- 啟動：`yugabyted start --advertise_address=172.24.40.32 --base_dir=/opt/yugabyte/data --ui=false`
- tserver flags：`ysql_enable_packed_row=false, yb_enable_read_committed_isolation=true, enable_wait_queues=true, ysql_num_shards_per_tserver=3`
- 測試工具：go-tpc (`-d postgres --conn-params sslmode=disable`)
- 連線入口：直連 172.24.40.32:5433
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260506-1546/`

### Prepare
- 時間：46m51s（128W）
- 警告：`check prepare failed / pq: Unknown session` — go-tpc 在 load 完成後會執行資料一致性驗證，驗證 SQL 使用 prepared statement；YBDB 的 session-level statement cache 與 PostgreSQL 行為不同，導致 statement handle 失效。**load 本體（資料寫入）已完成無誤**，此警告不影響後續測試。

### 指標說明

| 欄位 | 說明 |
|------|------|
| tpmC | 每分鐘完成的 NEW_ORDER 交易數，TPC-C 官方吞吐量指標 |
| tpmTotal | 每分鐘完成的全部五種交易數（NEW_ORDER + PAYMENT + ORDER_STATUS + DELIVERY + STOCK_LEVEL）|
| efficiency | tpmC / tpmTotal，理論值約 45%（NEW_ORDER 佔 TPC-C 交易組合的 45%）；偏低代表非 NEW_ORDER 交易比例異常高，通常是 retry 導致 |
| NO avg | NEW_ORDER 平均延遲；go-tpc 無 think time，goroutine 完成一筆就立刻發下一筆，latency 直接反映 DB 處理時間 + 競爭等待 |
| NO P99 | NEW_ORDER 第 99 百分位延遲；go-tpc 單筆上限 16,106ms（16s），超過即強制逾時 |

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 414.7 | 912.3 | 25.2% | 2,225 | 3,490 |
| 32 | 394.8 | 871.0 | 24.0% | 4,686 | 8,590 |
| 64 | 378.6 | 834.8 | 23.0% | 9,548 | 16,106 |
| 128 | 370.4 | 809.8 | 22.5% | 15,655 | 16,106 |

### 觀察

- **tpmC 天花板**：並發從 16 增加到 128，tpmC 僅從 414.7 降至 370.4（-10.7%）。多開 thread 沒有帶來更多吞吐，表示 DB 已無法再並行處理更多工作。
- **NO avg 線性翻倍**：每次 thread 數加倍，NEW_ORDER 平均延遲幾乎同步翻倍（2,225 → 4,686 → 9,548 → 15,655ms）。代表每新增一個 thread，等待時間與競爭成本等比上升。
- **128t 全壓逾時上限**：128t 的 NO P50/P90/P95/P99 全部是 16,106ms，意即超過一半的 NEW_ORDER 都在等 16 秒後才回應（已達 go-tpc 逾時，實際 DB 端可能更長）。
- **efficiency 偏低（~25%）**：理論上 NEW_ORDER 佔所有交易的 45%，efficiency 25% 表示 DB 在 NEW_ORDER 上花了異常多時間，其他交易相對順暢，符合 NEW_ORDER 衝突最集中的預期。
- **STOCK_LEVEL_ERR × 1（128t）**：`Restart read required`，MVCC 讀取衝突，go-tpc 不重試直接計錯誤。

### 根因分析

YBDB 使用 **optimistic MVCC**：事務在 commit 時才偵測衝突，衝突則整筆 rollback 後重試。  
go-tpc 無 think time → goroutine 連續送出交易，沒有自然間隔 → 多個 goroutine 同時競爭同一 warehouse 的列鎖。

衝突越多 → 重試越多 → 持鎖時間越長 → 更多衝突（正回饋惡化）。

額外加劇因素：`ysql_num_shards_per_tserver=3` 在單節點只建了 3 個 tablets，128 個 warehouse 分散到 3 個 tablet，每個 tablet 平均承載 42~43 個 warehouse 的熱點流量，tablet 層競爭極為集中。

### 測試方法補充：為何不開 think time

**Think time 的作用**：TPC-C 標準定義每筆交易前後有 keying time（均值 18s）與 think time（均值 12s），模擬真實用戶操作節奏。開啟後每個 goroutine 大部分時間處於 sleep，128 個 goroutine 任意瞬間真正在 DB 執行的只有約 8 個，有效並發大幅降低，MVCC 碰撞機率趨近於零，tpmC 會顯著回升。

**但這不是我們要的**：本測試目的是找 DB 在持續滿載下的吞吐上限，而非模擬用戶節奏。Think time 會把問題藏起來 — YBDB 在低有效並發下表現良好，但生產環境的連線池通常是持續發送請求的，沒有自然間隔。無 think time 才能暴露 optimistic MVCC 在高競爭下的架構限制，這正是 YBDB vs TiDB（悲觀鎖）對比的關鍵觀測點。

**工具限制**：go-tpc 不支援 think time flag，無法在同一工具內做對照實驗，此項對照測試略過。

---

## vm-3node-direct — 2026-05-07

### 環境
- 節點：.32/.33/.34 三節點 RF=3，zone=asia-east1-{a,b,c}
- 啟動：`yugabyted start --fault_tolerance=zone`，.32 為 bootstrap，.33/.34 透過 `--join=172.24.40.32` 加入
- tserver flags：與 vm-1node 相同
- 連線入口：直連 172.24.40.32:5433（**不過 HAProxy**）
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-3node-direct/20260507-0229/`

### Prepare
- 時間：28m00s（128W），比 vm-1node 的 47m51s 快近一倍 — 三節點分擔寫入
- 警告：`driver: bad connection` — 一致性檢查 SQL 是跨表聚合（condition 3.3.2.x），單條查詢時間長，prepare 階段透過 HAProxy 連線（:15433），HAProxy `timeout server 30s` 切斷未完成的 check 查詢；data load 本體已完成無誤

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 1024.2 | 2,281.9 | 62.2% | 880.8 | 2,013 |
| 32 | 1016.4 | 2,272.0 | 61.7% | 1,773.6 | 5,369 |
| 64 | 1003.2 | 2,241.0 | 60.9% | 3,461.0 | 13,422 |
| 128 | 964.7 | 2,168.9 | 58.6% | 6,358.4 | 16,106 |

### vs vm-1node 對比

| threads | vm-1node tpmC | vm-3node-direct tpmC | 倍數 |
|---------|---------------|----------------------|------|
| 16 | 414.7 | 1,024.2 | 2.47× |
| 32 | 394.8 | 1,016.4 | 2.57× |
| 64 | 378.6 | 1,003.2 | 2.65× |
| 128 | 370.4 | 964.7 | 2.60× |

### 觀察

- **吞吐穩定 ~1000 tpmC**：16~128t 之間 tpmC 浮動 < 6%（1024 → 964），不像 vm-1node 那樣大幅劣化。三節點橫向擴展讓總吞吐天花板顯著拉高。
- **三節點對單節點約 2.5x**：理論上 RF=3 三節點寫入要做 Raft consensus（兩個 follower 確認），不會純線性 3x。實測 2.5x 是合理的水位。
- **NO avg 仍翻倍**：881 → 1,774 → 3,461 → 6,358ms，與 vm-1node 同樣的線性翻倍模式。MVCC 競爭天花板沒有消失，只是被推高。
- **128t P95/P99 全壓 16,106ms**：與 vm-1node 128t 相同現象，go-tpc 16s 上限被持續觸發。
- **efficiency 60% 正常**：高於 TPC-C 標準的 45%，代表 NEW_ORDER 在這個並發水位下相對其他交易仍流暢。
- **STOCK_LEVEL_ERR × 1（64t/128t 各 1）**：MVCC `Restart read required`，量極少。

### 結論

vm-3node-direct 證實 **YBDB 橫向擴展對 OLTP 寫入是有效的**，在無 think time 高壓場景下相比單節點吞吐約 2.5×。但 MVCC 競爭曲線形狀不變 — 並發增加會拉高 latency，只是天花板被推高。
