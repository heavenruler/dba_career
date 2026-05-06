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
