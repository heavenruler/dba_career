# TiDB information_schema 繪製與彙整（繁體中文）

本文檔說明在 TiDB 8.5.x 中與 TiDB 特性密切相關的 `information_schema` 擴充視圖，並對其用途、常見欄位與典型查詢場景做中文（繁體）分類整理。完整欄位列表請參考同目錄的 `information_schema_tidb_tables.md`。

## 分類總覽

| 類別 | 主要表 (部分) | 核心用途 |
|------|---------------|----------|
| 集群拓撲 / 組件 | `cluster_info`, `cluster_config`, `cluster_systeminfo`, `cluster_hardware`, `cluster_load`, `cluster_log` | 節點版本、配置、硬體與負載觀察 |
| 慢查詢 / SQL 統計 | `slow_query`, `cluster_slow_query`, `statements_summary(_history)`, `cluster_statements_summary(_history)` | 全局與歷史 SQL 延遲、次數、計劃 Digest 聚合 |
| 儲存 / Region | `tikv_region_status`, `tikv_region_peers`, `tidb_hot_regions_history`, `table_storage_stats` | 定位 Region 分佈、熱點、表/索引大小 |
| DDL / 元資料 | `tidb_ddl_jobs`, `tidb_indexes`, `tidb_table_lock`, `tidb_owners`, `placement_policies`, `tidb_placement` | 追蹤 DDL 進度、索引可見性、放置策略 |
| 統計資訊 (Optimizer) | `stats_meta`, `stats_histograms`, `stats_buckets`, `stats_healthy`, `analyze_status` | 決策是否 ANALYZE、基數與分佈健康度 |
| 交易 / 鎖 | `tidb_trx`, `data_lock_waits`, `deadlocks`, `cluster_deadlocks` | 線上鎖等待與死鎖分析 |
| 變數 / 使用者 | `tidb_session_variables`, `tidb_global_variables`, `tidb_user_privileges`, `tidb_servers_info` | 變數偏差排查、權限稽核 |
| 巡檢 / 診斷 | `inspection_rules`, `inspection_result`, `inspection_summary` | 自動化巡檢結果、健康快照 |
| 其它 | `client_errors_summary`, `tidb_plugins`, `tidb_table_lock` (亦屬 DDL) | 補充診斷與外掛管理 |

## 1. 集群拓撲 / 組件視圖
**cluster_info**：列出 TiDB / TiKV / PD / TiFlash 等執行個體、版本、Git Hash。
**cluster_config**：各節點目前有效配置（動態+靜態），用於交叉比對差異。
**cluster_systeminfo** / **cluster_hardware**：作業系統、CPU、記憶體、磁碟與 Kernel 版本。
**cluster_load**：採樣級 CPU / Memory / IO / Network，用於初步找出高負載節點。
**cluster_log**：具備過濾條件的集中查詢（不替代集中日誌系統）。

快速查看版本一致性：
```
SELECT type, version, COUNT(*) cnt
FROM information_schema.cluster_info
GROUP BY type, version;
```

## 2. 慢查詢與 SQL 統計
**slow_query / cluster_slow_query**：原始慢 SQL 記錄（單節點 / 集群彙總）。
**statements_summary(_history)**：對 SQL Digest 聚合（執行次數、耗時、寫讀量等）。
**cluster_statements_summary(_history)**：跨節點聚合版本。

找出平均延遲最高的 SQL：
```
SELECT digest, exec_count,
			 FORMAT_US(sum_latency/exec_count) AS avg_latency,
			 FORMAT_US(max_latency) AS max_latency
FROM information_schema.statements_summary
ORDER BY avg_latency DESC LIMIT 10;
```

## 3. 儲存與 Region 觀察
**tikv_region_status**：Region 尺寸、讀寫 Bytes、對應資料表 ID，定位熱區。
**tikv_region_peers**：各 Region 副本狀態（Leader/Follower）。
**tidb_hot_regions_history**：歷史熱點演變。
**table_storage_stats**：表與索引在 KV 層累積大小、鍵數、Analyze 版本。

找出最大 20 個表：
```
SELECT table_schema, table_name, total_size
FROM information_schema.table_storage_stats
ORDER BY total_size DESC LIMIT 20;
```

## 4. DDL 與元資料管理
**tidb_ddl_jobs**：DDL 任務生命周期（排隊、執行、完成）。
**tidb_indexes**：索引可見性 (is_visible)、狀態（建立中 / 不可見 / 正常）。
**tidb_table_lock**：DDL/Online schema 變更時的表級鎖資訊。
**placement_policies / tidb_placement**：規則與表/分區實際放置策略綁定。
**tidb_owners**：統計 / DDL / GC 等模組 Owner 節點。

最近 10 條 DDL：
```
SELECT job_id, type, schema_name, table_name, state, start_time, end_time
FROM information_schema.tidb_ddl_jobs
ORDER BY job_id DESC LIMIT 10;
```

## 5. 統計資訊（影響執行計劃）
**stats_meta**：row_count 與 modify_count（修改累計）。modify_count 高 → 需 ANALYZE。
**stats_histograms / stats_buckets**：列/索引基數、分佈。
**stats_healthy**：健康度（低於閾值建議重新 ANALYZE）。
**analyze_status**：Analyze 任務進度與結果。

找出統計偏差大的表：
```
SELECT db_name, table_name, count AS row_count, modify_count,
			 ROUND(modify_count / NULLIF(count,0), 4) AS mod_ratio
FROM information_schema.stats_meta
WHERE count > 0
ORDER BY mod_ratio DESC LIMIT 20;
```

## 6. 交易與鎖觀測
**tidb_trx**：活躍/長事務清單（start_ts, state, lock_for_update_count）。
**data_lock_waits**：等待鎖對（阻塞 vs 等待）。
**deadlocks / cluster_deadlocks**：近幾次死鎖圖（JSON 片段）。

檢測長事務 (> 300 秒)：
```
SELECT * FROM information_schema.tidb_trx
WHERE time_elapsed > 300
ORDER BY time_elapsed DESC;
```

## 7. 變數、使用者與節點資訊
**tidb_session_variables / tidb_global_variables**：與 SHOW VARIABLES 等價但可 SQL 過濾。
**tidb_user_privileges**：使用者權限視圖。
**tidb_servers_info**：TiDB 節點參數、Git Hash、DDL Owner 標記。

檢查 GC 參數：
```
SELECT variable_name, variable_value
FROM information_schema.tidb_global_variables
WHERE variable_name IN ('tidb_gc_life_time','tidb_gc_run_interval');
```

## 8. 巡檢 / 診斷
**inspection_rules**：可用規則列表（如 config, version, threshold）。
**inspection_result**：具體規則執行結果（PASS/WARN/FAIL）。
**inspection_summary**：匯總概述。

查看非 PASS 記錄：
```
SELECT rule, item, status, details
FROM information_schema.inspection_result
WHERE status <> 'PASS'
ORDER BY rule, item;
```

## 9. 其他輔助 / 擴充
**client_errors_summary**：客戶端錯誤碼聚合（頻繁報錯偵測）。
**tidb_plugins**：已載入外掛。

## 篩選規則建議
快速挑 TiDB 擴充表：
```
SELECT table_name
FROM information_schema.tables
WHERE table_schema='information_schema'
	AND (table_name REGEXP '^(tidb_|tikv_|cluster_)'
			 OR table_name IN ('SLOW_QUERY','DATA_LOCK_WAITS','DEADLOCKS','TABLE_STORAGE_STATS',
												 'ANALYZE_STATUS','STATEMENTS_SUMMARY','STATEMENTS_SUMMARY_HISTORY',
												 'STATS_META','STATS_HISTOGRAMS','STATS_BUCKETS','STATS_HEALTHY',
												 'INSPECTION_RESULT','INSPECTION_SUMMARY','INSPECTION_RULES'))
ORDER BY table_name;
```

## 更新流程建議
1. 版本升級後重新抓取 `information_schema.columns`。
2. 自動比較新舊表名集合，產出差異 (新增/移除/欄位變更)。
3. 補充本 README 新增視圖用途。

## 參考
* 官方文件：TiDB Information Schema 擴充視圖（對應版本 8.5.x）
* 本倉庫：`information_schema_tidb_tables.md` 含欄位清單

---
如需加入「標準 MySQL vs TiDB 差集」或自動化比較腳本，可再提出需求。

