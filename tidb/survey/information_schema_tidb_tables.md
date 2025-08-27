# TiDB-related information_schema tables (v8.5.x captured)
生成时间: placeholder
分类规则: 前缀 tidb_/tikv_/cluster_ 或特定诊断/统计表。
## `ANALYZE_STATUS`
列 | 类型 | Nullable | Extra
---|---|---|---
TABLE_SCHEMA | varchar(64) | YES | 
TABLE_NAME | varchar(64) | YES | 
PARTITION_NAME | varchar(64) | YES | 
JOB_INFO | longtext | YES | 
PROCESSED_ROWS | bigint unsigned | YES | 
START_TIME | datetime | YES | 
END_TIME | datetime | YES | 
STATE | varchar(64) | YES | 
FAIL_REASON | longtext | YES | 
INSTANCE | varchar(512) | YES | 
PROCESS_ID | bigint unsigned | YES | 
REMAINING_SECONDS | varchar(512) | YES | 
PROGRESS | double(22,6) | YES | 
ESTIMATED_TOTAL_ROWS | bigint unsigned | YES | 

## `DATA_LOCK_WAITS`
列 | 类型 | Nullable | Extra
---|---|---|---
KEY | text | NO | 
KEY_INFO | text | YES | 
TRX_ID | bigint unsigned | NO | 
CURRENT_HOLDING_TRX_ID | bigint unsigned | NO | 
SQL_DIGEST | varchar(64) | YES | 
SQL_DIGEST_TEXT | text | YES | 

## `DEADLOCKS`
列 | 类型 | Nullable | Extra
---|---|---|---
DEADLOCK_ID | bigint | NO | 
OCCUR_TIME | timestamp(6) | YES | 
RETRYABLE | tinyint(1) | NO | 
TRY_LOCK_TRX_ID | bigint unsigned | NO | 
CURRENT_SQL_DIGEST | varchar(64) | YES | 
CURRENT_SQL_DIGEST_TEXT | text | YES | 
KEY | text | YES | 
KEY_INFO | text | YES | 
TRX_HOLDING_LOCK | bigint unsigned | NO | 

## `INSPECTION_RESULT`
列 | 类型 | Nullable | Extra
---|---|---|---
RULE | varchar(64) | YES | 
ITEM | varchar(64) | YES | 
TYPE | varchar(64) | YES | 
INSTANCE | varchar(64) | YES | 
STATUS_ADDRESS | varchar(64) | YES | 
VALUE | varchar(64) | YES | 
REFERENCE | varchar(64) | YES | 
SEVERITY | varchar(64) | YES | 
DETAILS | varchar(256) | YES | 

## `INSPECTION_RULES`
列 | 类型 | Nullable | Extra
---|---|---|---
NAME | varchar(64) | YES | 
TYPE | varchar(64) | YES | 
COMMENT | varchar(256) | YES | 

## `INSPECTION_SUMMARY`
列 | 类型 | Nullable | Extra
---|---|---|---
RULE | varchar(64) | YES | 
INSTANCE | varchar(64) | YES | 
METRICS_NAME | varchar(64) | YES | 
LABEL | varchar(64) | YES | 
QUANTILE | double | YES | 
AVG_VALUE | double(22,6) | YES | 
MIN_VALUE | double(22,6) | YES | 
MAX_VALUE | double(22,6) | YES | 
COMMENT | varchar(256) | YES | 

## `SLOW_QUERY`
列 | 类型 | Nullable | Extra
---|---|---|---
Time | timestamp(6) | NO | 
Txn_start_ts | bigint unsigned | YES | 
User | varchar(64) | YES | 
Host | varchar(64) | YES | 
Conn_ID | bigint unsigned | YES | 
Session_alias | varchar(64) | YES | 
Exec_retry_count | bigint unsigned | YES | 
Exec_retry_time | double | YES | 
Query_time | double | YES | 
Parse_time | double | YES | 
Compile_time | double | YES | 
Rewrite_time | double | YES | 
Preproc_subqueries | bigint unsigned | YES | 
Preproc_subqueries_time | double | YES | 
Optimize_time | double | YES | 
Wait_TS | double | YES | 
Prewrite_time | double | YES | 
Wait_prewrite_binlog_time | double | YES | 
Commit_time | double | YES | 
Get_commit_ts_time | double | YES | 
Commit_backoff_time | double | YES | 
Backoff_types | varchar(64) | YES | 
Resolve_lock_time | double | YES | 
Local_latch_wait_time | double | YES | 
Write_keys | bigint | YES | 
Write_size | bigint | YES | 
Prewrite_region | bigint | YES | 
Txn_retry | bigint | YES | 
Cop_time | double | YES | 
Process_time | double | YES | 
Wait_time | double | YES | 
Backoff_time | double | YES | 
LockKeys_time | double | YES | 
Request_count | bigint unsigned | YES | 
Total_keys | bigint unsigned | YES | 
Process_keys | bigint unsigned | YES | 
Rocksdb_delete_skipped_count | bigint unsigned | YES | 
Rocksdb_key_skipped_count | bigint unsigned | YES | 
Rocksdb_block_cache_hit_count | bigint unsigned | YES | 
Rocksdb_block_read_count | bigint unsigned | YES | 
Rocksdb_block_read_byte | bigint unsigned | YES | 
DB | varchar(64) | YES | 
Index_names | varchar(100) | YES | 
Is_internal | tinyint(1) | YES | 
Digest | varchar(64) | YES | 
Stats | varchar(512) | YES | 
Cop_proc_avg | double | YES | 
Cop_proc_p90 | double | YES | 
Cop_proc_max | double | YES | 
Cop_proc_addr | varchar(64) | YES | 
Cop_wait_avg | double | YES | 
Cop_wait_p90 | double | YES | 
Cop_wait_max | double | YES | 
Cop_wait_addr | varchar(64) | YES | 
Mem_max | bigint | YES | 
Disk_max | bigint | YES | 
KV_total | double | YES | 
PD_total | double | YES | 
Backoff_total | double | YES | 
Write_sql_response_total | double | YES | 
Result_rows | bigint | YES | 
Warnings | longtext | YES | 
Backoff_Detail | varchar(4096) | YES | 
Prepared | tinyint(1) | YES | 
Succ | tinyint(1) | YES | 
IsExplicitTxn | tinyint(1) | YES | 
IsWriteCacheTable | tinyint(1) | YES | 
Plan_from_cache | tinyint(1) | YES | 
Plan_from_binding | tinyint(1) | YES | 
Has_more_results | tinyint(1) | YES | 
Resource_group | varchar(64) | YES | 
Request_unit_read | double | YES | 
Request_unit_write | double | YES | 
Time_queued_by_rc | double | YES | 
Tidb_cpu_time | double | YES | 
Tikv_cpu_time | double | YES | 
Plan | longtext | YES | 
Plan_digest | varchar(128) | YES | 
Binary_plan | longtext | YES | 
Prev_stmt | longtext | YES | 
Query | longtext | YES | 

## `STATEMENTS_SUMMARY`
列 | 类型 | Nullable | Extra
---|---|---|---
SUMMARY_BEGIN_TIME | timestamp | NO | 
SUMMARY_END_TIME | timestamp | NO | 
STMT_TYPE | varchar(64) | NO | 
SCHEMA_NAME | varchar(64) | YES | 
DIGEST | varchar(64) | YES | 
DIGEST_TEXT | text | NO | 
TABLE_NAMES | text | YES | 
INDEX_NAMES | text | YES | 
SAMPLE_USER | varchar(64) | YES | 
EXEC_COUNT | bigint unsigned | NO | 
SUM_ERRORS | int unsigned | NO | 
SUM_WARNINGS | int unsigned | NO | 
SUM_LATENCY | bigint unsigned | NO | 
MAX_LATENCY | bigint unsigned | NO | 
MIN_LATENCY | bigint unsigned | NO | 
AVG_LATENCY | bigint unsigned | NO | 
AVG_PARSE_LATENCY | bigint unsigned | NO | 
MAX_PARSE_LATENCY | bigint unsigned | NO | 
AVG_COMPILE_LATENCY | bigint unsigned | NO | 
MAX_COMPILE_LATENCY | bigint unsigned | NO | 
SUM_COP_TASK_NUM | bigint unsigned | NO | 
MAX_COP_PROCESS_TIME | bigint unsigned | NO | 
MAX_COP_PROCESS_ADDRESS | varchar(256) | YES | 
MAX_COP_WAIT_TIME | bigint unsigned | NO | 
MAX_COP_WAIT_ADDRESS | varchar(256) | YES | 
AVG_PROCESS_TIME | bigint unsigned | NO | 
MAX_PROCESS_TIME | bigint unsigned | NO | 
AVG_WAIT_TIME | bigint unsigned | NO | 
MAX_WAIT_TIME | bigint unsigned | NO | 
AVG_BACKOFF_TIME | bigint unsigned | NO | 
MAX_BACKOFF_TIME | bigint unsigned | NO | 
AVG_TOTAL_KEYS | bigint unsigned | NO | 
MAX_TOTAL_KEYS | bigint unsigned | NO | 
AVG_PROCESSED_KEYS | bigint unsigned | NO | 
MAX_PROCESSED_KEYS | bigint unsigned | NO | 
AVG_ROCKSDB_DELETE_SKIPPED_COUNT | double unsigned | NO | 
MAX_ROCKSDB_DELETE_SKIPPED_COUNT | int unsigned | NO | 
AVG_ROCKSDB_KEY_SKIPPED_COUNT | double unsigned | NO | 
MAX_ROCKSDB_KEY_SKIPPED_COUNT | int unsigned | NO | 
AVG_ROCKSDB_BLOCK_CACHE_HIT_COUNT | double unsigned | NO | 
MAX_ROCKSDB_BLOCK_CACHE_HIT_COUNT | int unsigned | NO | 
AVG_ROCKSDB_BLOCK_READ_COUNT | double unsigned | NO | 
MAX_ROCKSDB_BLOCK_READ_COUNT | int unsigned | NO | 
AVG_ROCKSDB_BLOCK_READ_BYTE | double unsigned | NO | 
MAX_ROCKSDB_BLOCK_READ_BYTE | int unsigned | NO | 
AVG_PREWRITE_TIME | bigint unsigned | NO | 
MAX_PREWRITE_TIME | bigint unsigned | NO | 
AVG_COMMIT_TIME | bigint unsigned | NO | 
MAX_COMMIT_TIME | bigint unsigned | NO | 
AVG_GET_COMMIT_TS_TIME | bigint unsigned | NO | 
MAX_GET_COMMIT_TS_TIME | bigint unsigned | NO | 
AVG_COMMIT_BACKOFF_TIME | bigint unsigned | NO | 
MAX_COMMIT_BACKOFF_TIME | bigint unsigned | NO | 
AVG_RESOLVE_LOCK_TIME | bigint unsigned | NO | 
MAX_RESOLVE_LOCK_TIME | bigint unsigned | NO | 
AVG_LOCAL_LATCH_WAIT_TIME | bigint unsigned | NO | 
MAX_LOCAL_LATCH_WAIT_TIME | bigint unsigned | NO | 
AVG_WRITE_KEYS | double unsigned | NO | 
MAX_WRITE_KEYS | bigint unsigned | NO | 
AVG_WRITE_SIZE | double unsigned | NO | 
MAX_WRITE_SIZE | bigint unsigned | NO | 
AVG_PREWRITE_REGIONS | double unsigned | NO | 
MAX_PREWRITE_REGIONS | int unsigned | NO | 
AVG_TXN_RETRY | double unsigned | NO | 
MAX_TXN_RETRY | int unsigned | NO | 
SUM_EXEC_RETRY | bigint unsigned | NO | 
SUM_EXEC_RETRY_TIME | bigint unsigned | NO | 
SUM_BACKOFF_TIMES | bigint unsigned | NO | 
BACKOFF_TYPES | varchar(1024) | YES | 
AVG_MEM | bigint unsigned | NO | 
MAX_MEM | bigint unsigned | NO | 
AVG_DISK | bigint unsigned | NO | 
MAX_DISK | bigint unsigned | NO | 
AVG_KV_TIME | bigint unsigned | NO | 
AVG_PD_TIME | bigint unsigned | NO | 
AVG_BACKOFF_TOTAL_TIME | bigint unsigned | NO | 
AVG_WRITE_SQL_RESP_TIME | bigint unsigned | NO | 
AVG_TIDB_CPU_TIME | bigint unsigned | NO | 
AVG_TIKV_CPU_TIME | bigint unsigned | NO | 
MAX_RESULT_ROWS | bigint | NO | 
MIN_RESULT_ROWS | bigint | NO | 
AVG_RESULT_ROWS | bigint | NO | 
PREPARED | tinyint(1) | NO | 
AVG_AFFECTED_ROWS | double unsigned | NO | 
FIRST_SEEN | timestamp | NO | 
LAST_SEEN | timestamp | NO | 
PLAN_IN_CACHE | tinyint(1) | NO | 
PLAN_CACHE_HITS | bigint | NO | 
PLAN_IN_BINDING | tinyint(1) | NO | 
QUERY_SAMPLE_TEXT | text | YES | 
PREV_SAMPLE_TEXT | text | YES | 
PLAN_DIGEST | varchar(64) | YES | 
PLAN | text | YES | 
BINARY_PLAN | text | YES | 
CHARSET | varchar(64) | YES | 
COLLATION | varchar(64) | YES | 
PLAN_HINT | varchar(64) | YES | 
MAX_REQUEST_UNIT_READ | double unsigned | NO | 
AVG_REQUEST_UNIT_READ | double unsigned | NO | 
MAX_REQUEST_UNIT_WRITE | double unsigned | NO | 
AVG_REQUEST_UNIT_WRITE | double unsigned | NO | 
MAX_QUEUED_RC_TIME | bigint unsigned | NO | 
AVG_QUEUED_RC_TIME | bigint unsigned | NO | 
RESOURCE_GROUP | varchar(64) | YES | 
PLAN_CACHE_UNQUALIFIED | bigint | NO | 
PLAN_CACHE_UNQUALIFIED_LAST_REASON | text | YES | 

## `STATEMENTS_SUMMARY_HISTORY`
列 | 类型 | Nullable | Extra
---|---|---|---
SUMMARY_BEGIN_TIME | timestamp | NO | 
SUMMARY_END_TIME | timestamp | NO | 
STMT_TYPE | varchar(64) | NO | 
SCHEMA_NAME | varchar(64) | YES | 
DIGEST | varchar(64) | YES | 
DIGEST_TEXT | text | NO | 
TABLE_NAMES | text | YES | 
INDEX_NAMES | text | YES | 
SAMPLE_USER | varchar(64) | YES | 
EXEC_COUNT | bigint unsigned | NO | 
SUM_ERRORS | int unsigned | NO | 
SUM_WARNINGS | int unsigned | NO | 
SUM_LATENCY | bigint unsigned | NO | 
MAX_LATENCY | bigint unsigned | NO | 
MIN_LATENCY | bigint unsigned | NO | 
AVG_LATENCY | bigint unsigned | NO | 
AVG_PARSE_LATENCY | bigint unsigned | NO | 
MAX_PARSE_LATENCY | bigint unsigned | NO | 
AVG_COMPILE_LATENCY | bigint unsigned | NO | 
MAX_COMPILE_LATENCY | bigint unsigned | NO | 
SUM_COP_TASK_NUM | bigint unsigned | NO | 
MAX_COP_PROCESS_TIME | bigint unsigned | NO | 
MAX_COP_PROCESS_ADDRESS | varchar(256) | YES | 
MAX_COP_WAIT_TIME | bigint unsigned | NO | 
MAX_COP_WAIT_ADDRESS | varchar(256) | YES | 
AVG_PROCESS_TIME | bigint unsigned | NO | 
MAX_PROCESS_TIME | bigint unsigned | NO | 
AVG_WAIT_TIME | bigint unsigned | NO | 
MAX_WAIT_TIME | bigint unsigned | NO | 
AVG_BACKOFF_TIME | bigint unsigned | NO | 
MAX_BACKOFF_TIME | bigint unsigned | NO | 
AVG_TOTAL_KEYS | bigint unsigned | NO | 
MAX_TOTAL_KEYS | bigint unsigned | NO | 
AVG_PROCESSED_KEYS | bigint unsigned | NO | 
MAX_PROCESSED_KEYS | bigint unsigned | NO | 
AVG_ROCKSDB_DELETE_SKIPPED_COUNT | double unsigned | NO | 
MAX_ROCKSDB_DELETE_SKIPPED_COUNT | int unsigned | NO | 
AVG_ROCKSDB_KEY_SKIPPED_COUNT | double unsigned | NO | 
MAX_ROCKSDB_KEY_SKIPPED_COUNT | int unsigned | NO | 
AVG_ROCKSDB_BLOCK_CACHE_HIT_COUNT | double unsigned | NO | 
MAX_ROCKSDB_BLOCK_CACHE_HIT_COUNT | int unsigned | NO | 
AVG_ROCKSDB_BLOCK_READ_COUNT | double unsigned | NO | 
MAX_ROCKSDB_BLOCK_READ_COUNT | int unsigned | NO | 
AVG_ROCKSDB_BLOCK_READ_BYTE | double unsigned | NO | 
MAX_ROCKSDB_BLOCK_READ_BYTE | int unsigned | NO | 
AVG_PREWRITE_TIME | bigint unsigned | NO | 
MAX_PREWRITE_TIME | bigint unsigned | NO | 
AVG_COMMIT_TIME | bigint unsigned | NO | 
MAX_COMMIT_TIME | bigint unsigned | NO | 
AVG_GET_COMMIT_TS_TIME | bigint unsigned | NO | 
MAX_GET_COMMIT_TS_TIME | bigint unsigned | NO | 
AVG_COMMIT_BACKOFF_TIME | bigint unsigned | NO | 
MAX_COMMIT_BACKOFF_TIME | bigint unsigned | NO | 
AVG_RESOLVE_LOCK_TIME | bigint unsigned | NO | 
MAX_RESOLVE_LOCK_TIME | bigint unsigned | NO | 
AVG_LOCAL_LATCH_WAIT_TIME | bigint unsigned | NO | 
MAX_LOCAL_LATCH_WAIT_TIME | bigint unsigned | NO | 
AVG_WRITE_KEYS | double unsigned | NO | 
MAX_WRITE_KEYS | bigint unsigned | NO | 
AVG_WRITE_SIZE | double unsigned | NO | 
MAX_WRITE_SIZE | bigint unsigned | NO | 
AVG_PREWRITE_REGIONS | double unsigned | NO | 
MAX_PREWRITE_REGIONS | int unsigned | NO | 
AVG_TXN_RETRY | double unsigned | NO | 
MAX_TXN_RETRY | int unsigned | NO | 
SUM_EXEC_RETRY | bigint unsigned | NO | 
SUM_EXEC_RETRY_TIME | bigint unsigned | NO | 
SUM_BACKOFF_TIMES | bigint unsigned | NO | 
BACKOFF_TYPES | varchar(1024) | YES | 
AVG_MEM | bigint unsigned | NO | 
MAX_MEM | bigint unsigned | NO | 
AVG_DISK | bigint unsigned | NO | 
MAX_DISK | bigint unsigned | NO | 
AVG_KV_TIME | bigint unsigned | NO | 
AVG_PD_TIME | bigint unsigned | NO | 
AVG_BACKOFF_TOTAL_TIME | bigint unsigned | NO | 
AVG_WRITE_SQL_RESP_TIME | bigint unsigned | NO | 
AVG_TIDB_CPU_TIME | bigint unsigned | NO | 
AVG_TIKV_CPU_TIME | bigint unsigned | NO | 
MAX_RESULT_ROWS | bigint | NO | 
MIN_RESULT_ROWS | bigint | NO | 
AVG_RESULT_ROWS | bigint | NO | 
PREPARED | tinyint(1) | NO | 
AVG_AFFECTED_ROWS | double unsigned | NO | 
FIRST_SEEN | timestamp | NO | 
LAST_SEEN | timestamp | NO | 
PLAN_IN_CACHE | tinyint(1) | NO | 
PLAN_CACHE_HITS | bigint | NO | 
PLAN_IN_BINDING | tinyint(1) | NO | 
QUERY_SAMPLE_TEXT | text | YES | 
PREV_SAMPLE_TEXT | text | YES | 
PLAN_DIGEST | varchar(64) | YES | 
PLAN | text | YES | 
BINARY_PLAN | text | YES | 
CHARSET | varchar(64) | YES | 
COLLATION | varchar(64) | YES | 
PLAN_HINT | varchar(64) | YES | 
MAX_REQUEST_UNIT_READ | double unsigned | NO | 
AVG_REQUEST_UNIT_READ | double unsigned | NO | 
MAX_REQUEST_UNIT_WRITE | double unsigned | NO | 
AVG_REQUEST_UNIT_WRITE | double unsigned | NO | 
MAX_QUEUED_RC_TIME | bigint unsigned | NO | 
AVG_QUEUED_RC_TIME | bigint unsigned | NO | 
RESOURCE_GROUP | varchar(64) | YES | 
PLAN_CACHE_UNQUALIFIED | bigint | NO | 
PLAN_CACHE_UNQUALIFIED_LAST_REASON | text | YES | 

## `TABLE_STORAGE_STATS`
列 | 类型 | Nullable | Extra
---|---|---|---
TABLE_SCHEMA | varchar(64) | YES | 
TABLE_NAME | varchar(64) | YES | 
TABLE_ID | bigint | YES | 
PEER_COUNT | bigint | YES | 
REGION_COUNT | bigint | YES | 
EMPTY_REGION_COUNT | bigint | YES | 
TABLE_SIZE | bigint | YES | 
TABLE_KEYS | bigint | YES | 

