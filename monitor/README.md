# 合理的監控應該包含哪些資訊

## 抽象化的定義

- Number of Errors(錯誤數)
- Users Experiencing Errors(出現錯誤的用戶)
- Failure Rate(失敗率)
- Transaction Duration(transaction 時長)
- Apdex(應用性能指數)
- Largest Contentful Paint(最大內容繪製)
- First Input Delay(首次輸入延遲)
- Cumulative Layout Shift(累積佈局偏移)
- Custom Metric(自定義指標)
- Throughput(吞吐量

## Alert / Warning 的差別定義 (服務可用不可用)

### Key metrics included

#### Container
```
container_last_seen
container_cpu_usage_seconds_total
container_memory_usage_bytes
container_network_receive_bytes_total
container_network_transmit_bytes_total
container_network_tcp_usage_total
```

#### OS
```
node_arp_entries
node_boot_time_seconds
node_context_switches_total
node_cooling_device_cur_state
node_cooling_device_max_state
node_cpu_seconds_total
node_disk_discard_time_seconds_total
node_disk_discarded_sectors_total
node_disk_discards_completed_total
node_disk_discards_merged_total
node_disk_flush_requests_time_seconds_total
node_disk_flush_requests_total
node_disk_info
node_disk_io_now
node_disk_io_time_seconds_total
node_disk_io_time_weighted_seconds_total
node_disk_read_bytes_total
node_disk_read_time_seconds_total
node_disk_reads_completed_total
node_disk_reads_merged_total
node_disk_write_time_seconds_total
node_disk_writes_completed_total
node_disk_writes_merged_total
node_disk_written_bytes_total
node_dmi_info
node_entropy_available_bits
node_entropy_pool_size_bits
node_exporter_build_info
node_filefd_allocated
node_filefd_maximum
```

#### Redis
```
redis_commands_total
redis_commands_duration_seconds_total
redis_keyspace_hits_total
redis_keyspace_misses_total
redis_memory_used_bytes
redis_memory_max_bytes
redis_memory_used_rss_bytes
redis_memory_fragmentation_ratio
redis_evicted_keys_total
redis_connected_clients
redis_blocked_clients
redis_db_keys
redis_db_keys_expiring
redis_connected_slaves
redis_master_last_io_seconds_ago
```

#### RDBMS
```
Current QPS
MySQL Slow Queries
MySQL Connections
MySQL Aborted Connections
MySQL Table Locks
Uptime
InnoDB Buffer Pool
MySQL Client Thread Activity
MySQL Questions
MySQL Thread Cache
MySQL Temporary Objects
MySQL Select Types
MySQL Sorts
MySQL Network Traffic
MySQL Internal Memory Overview
Top Command Counters
MySQL Handlers
MySQL Transaction Handlers
Process States
Top Process States Hourly
MySQL Query Cache Memory
MySQL Query Cache Activity
MySQL File Openings
MySQL Open Files
MySQL Table Open Cache Status
MySQL Open Tables
```

### Key alerting rules included

#### OS
```
NodeFilesystemAlmostOutOfSpace
NodeFilesystemFilesFillingUp
NodeFilesystemAlmostOutOfFiles
NodeNetworkReceiveErrs
NodeNetworkTransmitErrs
NodeHighNumberConntrackEntriesUsed
NodeTextFileCollectorScrapeError
NodeClockSkewDetected
NodeClockNotSynchronising
NodeRAIDDegraded
NodeRAIDDiskFailure
NodeFileDescriptorLimit
```

#### RDBMS
```
MySQLDown
MySQLReplicationNotRunning
MySQLReplicationLag
MySQLInnoDBLogWaits
MySQLGaleraOutOfSync
MySQLGaleraNotReady
MySQLGaleraDonorFallingBehind
```

#### MongoDB
```
MongodbDown: A MongoDB instance is down - Critical
MongodbReplicationLag: MongoDB replication lag is more than 10s - Critical
MongodbReplicationHeadroom: MongoDB replication headroom is <= 0 - Critical
MongodbNumberCursorsOpen: Too many cursors opened by MongoDB for clients (> 10k) - Warning
MongodbCursorsTimeouts: Too many cursors are timing out - Warning
MongodbTooManyConnections: Too many connections (above 80% of the historical average) - warning
MongodbVirtualMemoryUsage: MongoDB virtual memory usage more than 3x higher than mapped memory - warning
```

#### Redis
```
RedisDown
RedisOutOfMemory
RedisTooManyConnections
```

## 作業系統層級看哪些資訊

### OS Level

- CPU Usage > 90
```
(100-(avg by (mode, instance)(rate(node_cpu_seconds_total{mode="idle"}[1m])))*100) > 90
```

- Inode Usage > 90
```
(100 - ((node_filesystem_files_free * 100) / node_filesystem_files))>90
```

- sshd service down
```
(namedprocess_namegroup_num_procs{groupname="sshd"}) == 0
```

- Memory Usage > 95
```
(node_memory_MemTotal_bytes - node_memory_MemFree_bytes - (node_memory_Cached_bytes + node_memory_Buffers_bytes))/node_memory_MemTotal_bytes*100 > 95
```

- File handles > 90
```
(node_filefd_allocated{}/node_filefd_maximum{}*100)
```

- IO wait > 30%
```
avg by (instance) (rate(node_cpu_seconds_total{mode="iowait"}[5m])) * 100 > 30
```

- Last 1 min DISK IO Utilization > 80
```
(rate(node_disk_io_time_seconds_total{} [1m]) *100) > 80
```

- Ping > 1s
```
avg_over_time(probe_icmp_duration_seconds[1m]) > 1
```

- CPU Load AVG > 2
```
(avg(node_load1) by(instance)/count by (instance)(node_cpu_seconds_total{mode='idle'})) >2 
```

- TCP Retransmission Rate > 5%
```
(rate(node_netstat_Tcp_RetransSegs{}[5m])/ rate(node_netstat_Tcp_OutSegs{}[5m])*100)  > 5 
```

- DISK Space Capacity > 85%
```
(100 - ((node_filesystem_avail_bytes * 100) / node_filesystem_size_bytes) ) > 85
```

- Node Restarted.
```
node_reboot_required > 0
```

### Service Level

- Service Restarted. 
```
mysql_global_status_uptime < 60
```

- ConCurrent Connection > 80%
```
avg by (instance) (mysql_global_status_threads_connected) / avg by (instance) (mysql_global_variables_max_connections) * 100 > 80
```

- Slow Queries last 1 min
```
increase(mysql_global_status_slow_queries[1m]) > 0
```

## 服務層級看哪些資訊