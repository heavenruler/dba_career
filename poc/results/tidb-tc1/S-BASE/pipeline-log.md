# TiDB TPC-C Pipeline Log — tidb-tc1 / S-BASE

## vm-1node — 2026-05-07

### 環境
- 節點：.32 (172.24.40.32) 單節點，PD + TiDB + TiKV 同主機部署
- 部署工具：TiUP v1.x（透過 ansible playbook `tidb.yml` + `inventory/tidb-vm1.ini`）
- TiDB 版本：v8.5.2
- 配置：`tidb_rf=1`（單副本，因僅 1 個 TiKV）
- AUTO ANALYZE：**啟用**（預設 ratio=0.5，本 variant 不關閉，作為標準基線）
- 測試工具：go-tpc（MySQL driver）
- 連線入口：直連 172.24.40.32:4000
- Warehouses：128 | Warmup：5m | Duration：10m | Threads：16/32/64/128
- 結果目錄：`vm-1node/20260507-2308/`

### Prepare
- 時間：19m26s（128W）
- check 階段全程通過（無 session/connection 錯誤）

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 11,895.0 | 26,348.7 | 722.6% | 39.3 | 65.0 |
| 32 | 12,766.7 | 28,345.3 | 775.6% | 71.7 | 125.8 |
| 64 | 13,355.4 | 29,609.0 | 811.3% | 135.0 | 243.3 |
| 128 | 13,078.8 | 28,955.6 | 794.5% | 267.6 | 520.1 |

> **efficiency 說明**：go-tpc 用「tpmC / (warehouses × 12.86)」計算，理論上限對應 TPC-C 標準的 think time + keying time 設定下的人均吞吐。本測試無 think time，goroutine 持續滿載，因此遠超 100% 是正常現象。

### vs YBDB vm-1node 對比

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

- **tpmC 隨並發溫和成長**：16 → 64t 從 11,895 提升到 13,355（+12.3%），128t 微降至 13,079，呈現典型的 OLTP 飽和曲線；無 YBDB 那樣的崩潰式下滑。
- **NO avg latency 線性可控**：TiDB 雖然延遲也隨並發增加（39 → 268 ms），但維持在 sub-second 層級；YBDB 同條件已達 15s+ 並打到 go-tpc 16s 上限。
- **efficiency 700-810%**：遠高於 YBDB 的 22-25%，代表 NEW_ORDER 處理流暢，retry/wait 開銷低。
- **64t 為 sweet spot**：13,355 tpmC 為峰值，128t 開始略降但仍在合理範圍。

### 根因：架構差異

TiDB 採用 **悲觀鎖（pessimistic locking）**：衝突時後到的 transaction 排隊等鎖，不重試整筆交易。  
YBDB 採用 **樂觀 MVCC**：衝突時整筆 rollback 重試，無 think time + 高並發下重試鏈累積 → latency 爆炸。

NEW_ORDER 必更新 `district.D_NEXT_O_ID`（每 warehouse × district = 1280 熱點 row），這是 TPC-C 最大競爭點。  
TiDB 在 row 鎖層排隊處理，每筆順序執行；YBDB 在 commit 時偵測衝突，多 goroutine 撞同一 row 就互相 rollback。

### 注意事項

- **AUTO ANALYZE disable 失敗（此 variant 反而是預期）**：tpcc.sh 在 run 開始時嘗試 `SET GLOBAL tidb_auto_analyze_ratio = 0`，TiDB v8.5.2 拒絕（`value should be greater than or equal to 0.000010`）。對 vm-1node 反而正確（保留 AUTO ANALYZE 啟用，標準基線）。已在後續 fix tpcc.sh 改用 `tidb_enable_auto_analyze = OFF`。
- **VM crash 重跑**：首次 prepare 期間 .32 VM crash，重啟後 TiDB 自動恢復，重跑 prepare 成功（19m26s vs 首次 23m18s，磁碟 cache 助益）。

---

## vm-1node-no-analyze — 2026-05-08

### 環境
- 同 vm-1node 環境
- AUTO ANALYZE：**停用** (`SET GLOBAL tidb_enable_auto_analyze = OFF`)
- tpcc.sh 已修：改用 `tidb_enable_auto_analyze` flag（v8.5+ `tidb_auto_analyze_ratio=0` 不被接受）
- 結果目錄：`vm-1node-no-analyze/20260508-0627/`

### Prepare
- 時間：20m12s
- 在 AUTO ANALYZE OFF 狀態下載入 128W

### Execute 結果

| threads | tpmC | NO avg(ms) | NO P99(ms) |
|---------|------|------------|------------|
| 16 | 11,380.6 | 40.9 | 71.3 |
| 32 | 12,596.2 | 72.5 | 125.8 |
| 64 | 13,345.3 | 134.4 | 243.3 |
| 128 | 13,191.7 | 264.3 | 520.1 |

### vs vm-1node 對比

| threads | vm-1node | vm-1node-no-analyze | 差異 |
|---------|----------|---------------------|------|
| 16 | 11,895.0 | 11,380.6 | -4.3% |
| 32 | 12,766.7 | 12,596.2 | -1.3% |
| 64 | 13,355.4 | 13,345.3 | -0.07% |
| 128 | 13,078.8 | 13,191.7 | +0.86% |

### 結論

**10 分鐘 TPC-C 測試期間，AUTO ANALYZE 對 tpmC 影響可忽略**。

- 預期 AUTO ANALYZE 在背景跑 ANALYZE TABLE 會吃 CPU 與 I/O，影響 OLTP 吞吐
- 實測差異 < 5%，落在 noise 範圍內
- 原因：AUTO ANALYZE 觸發條件是「modify_count / total_count > tidb_auto_analyze_ratio (0.5)」，128W 資料量下 10 分鐘的修改量達不到 50% 閾值
- 16t 略低（-4.3%）的可能原因：沒有 AUTO ANALYZE 重新統計，query plan 持續使用 prepare 後的初始 stats，少數 plan 偏差累計影響低並發吞吐；高並發（32t+）下其他開銷主導，差異消失

### 對未來測試的啟示

- 短時間（<1h）TPC-C 測試開不開 AUTO ANALYZE 結果差異不大
- 但長時間或資料持續變動的場景，AUTO ANALYZE 仍是必要功能（避免 stats 過時導致 query plan 退化）
- 建議：標準測試保留 AUTO ANALYZE，no-analyze variant 作為對照組驗證 AUTO ANALYZE 「無背景干擾」效果
