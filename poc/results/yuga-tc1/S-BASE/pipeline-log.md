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
- 警告：`check prepare failed / pq: Unknown session` — go-tpc consistency check 使用 prepared statement，YBDB session 管理差異導致，load 本體完成無誤

### Execute 結果

| threads | tpmC | tpmTotal | efficiency | NO avg(ms) | NO P99(ms) |
|---------|------|----------|------------|------------|------------|
| 16 | 414.7 | 912.3 | 25.2% | 2,225 | 3,490 |
| 32 | 394.8 | 871.0 | 24.0% | 4,686 | 8,590 |
| 64 | 378.6 | 834.8 | 23.0% | 9,548 | 16,106 |
| 128 | 370.4 | 809.8 | 22.5% | 15,655 | 16,106 |

### 觀察

- tpmC 幾乎不隨 thread 增加（414→370，-10.7%）— 典型 MVCC 競爭天花板
- NO avg 每倍 thread 近乎翻倍（2225 → 4686 → 9548 → 15655ms）
- 128t P50/P90/P95/P99 全壓在 16,106ms（go-tpc 16s 上限），大量 transaction 觸頂
- 128t 出現 STOCK_LEVEL_ERR × 1（`Restart read required`）
- efficiency 25% 遠低於 TPC-C 理論值（~45%）

### 根因
no think time + optimistic MVCC → 高並發下大量衝突重試 → latency 累積 → throughput 無法 scale。
單節點 3 tablets（ysql_num_shards_per_tserver=3）分攤 128W，tablet 層競爭集中。
