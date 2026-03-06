# MySQL 内存使用情况排查

作者：Cuihulong

MySQL 使用内存上升到 90%+ 是运维中较常见的问题。MySQL 内存使用率过高可能由多种原因引起，常见的是配置或使用不当，也可能是 MySQL 本身的缺陷。下面介绍一个系统化的排查思路。

## 排查思路概览
1. 确认参数配置是否合理（全局和线程级内存）。
2. 检查存储过程、函数、触发器、视图等设计是否可能导致内存问题。
3. 使用系统库和 performance_schema 统计查询实际内存使用。
4. 使用系统工具（top、free、ps、pmap 等）查看进程级别内存情况并确认是否存在内存泄露。

---

## 1. 参数配置确认（全局与线程级内存）
MySQL 内存分为全局和线程级：

- 全局内存：如 innodb_buffer_pool_size、key_buffer_size、innodb_log_buffer_size 等，启动时或全局使用。
- 线程级内存：如 thread_stack、read_buffer、sort_buffer、join_buffer、tmp 等，只有在需要时分配，并在操作完成后释放。

线程级内存说明：
- 每个连接到 MySQL 的线程都需要自己的缓冲，默认分配 thread_stack（常见 256K、512K），空闲时这些内存仍会被占用。
- 除了线程级内存外，还有网络缓存、表缓存等。综合评估单个连接的线程级内存大致在 1M~3M 左右（视配置而定）。

可以通过 pmap 观察内存变化，例如：
```bash
while true; do pmap -d 374343 | tail -1; sleep 2; done
```

示例：查询当前常用内存相关参数
```sql
SELECT
  @@query_cache_size,
  @@key_buffer_size,
  @@innodb_buffer_pool_size,
  @@innodb_log_buffer_size,
  @@tmp_table_size,
  @@read_buffer_size,
  @@sort_buffer_size,
  @@join_buffer_size,
  @@read_rnd_buffer_size,
  @@binlog_cache_size,
  @@thread_stack,
  (SELECT COUNT(host) FROM information_schema.processlist WHERE command <> 'Sleep') AS active_connections;
```

示例输出（部分）：
```
@@query_cache_size: 1048576
@@key_buffer_size: 8388608
@@innodb_buffer_pool_size: 268435456
@@innodb_log_buffer_size: 8388608
@@tmp_table_size: 16777216
@@read_buffer_size: 131072
@@sort_buffer_size: 1048576
@@join_buffer_size: 1048576
@@read_rnd_buffer_size: 2097152
@@binlog_cache_size: 8388608
@@thread_stack: 524288

active_connections: 1
```

备注：query_cache_size 在 MySQL 8.0 中已废弃。

---

## 2. 存储过程、函数、触发器与视图
实践中，存储过程、函数、触发器与视图在某些 MySQL 场景下可能导致性能问题或内存不释放，建议审查并尽量避免在高并发或复杂逻辑中滥用。

查询数据库中这些对象的示例：

MySQL 5.7（存储过程/函数）
```sql
SELECT db, type, COUNT(*)
FROM mysql.proc
WHERE db NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY db, type;
```

MySQL 8.0（存储过程/函数）
```sql
SELECT ROUTINE_SCHEMA, ROUTINE_TYPE
FROM information_schema.ROUTINES
WHERE ROUTINE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY ROUTINE_SCHEMA, ROUTINE_TYPE;
```

视图
```sql
SELECT TABLE_SCHEMA, COUNT(TABLE_NAME)
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY TABLE_SCHEMA;
```

触发器
```sql
SELECT TRIGGER_SCHEMA, COUNT(*)
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA NOT IN ('mysql', 'information_schema', 'performance_schema', 'sys')
GROUP BY TRIGGER_SCHEMA;
```

---

## 3. 使用系统库与 performance_schema 统计内存
### 总内存使用
```sql
SELECT
  SUM(CAST(REPLACE(current_alloc, 'MiB', '') AS DECIMAL(10,2)))
FROM sys.memory_global_by_current_bytes
WHERE current_alloc LIKE '%MiB%';
```

### 按事件统计内存
```sql
SELECT event_name,
  SUM(CAST(REPLACE(current_alloc, 'MiB', '') AS DECIMAL(10,2)))
FROM sys.memory_global_by_current_bytes
WHERE current_alloc LIKE '%MiB%'
GROUP BY event_name
ORDER BY SUM(CAST(REPLACE(current_alloc, 'MiB', '') AS DECIMAL(10,2))) DESC;
```

或：
```sql
SELECT event_name,
  sys.format_bytes(CURRENT_NUMBER_OF_BYTES_USED)
FROM performance_schema.memory_summary_global_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 10;
```

### 账号级别统计
```sql
SELECT user, event_name, current_number_of_bytes_used/1024/1024 AS MB_CURRENTLY_USED
FROM performance_schema.memory_summary_by_account_by_event_name
WHERE host <> 'localhost'
ORDER BY current_number_of_bytes_used DESC
LIMIT 10;
```
备注：统计用户级别内存有必要，很多环境对接第三方插件或模拟从库的客户端可能会导致内存不释放。

### 线程对应 SQL 语句与内存使用统计
```sql
SELECT thread_id, event_name, sys.format_bytes(CURRENT_NUMBER_OF_BYTES_USED)
FROM performance_schema.memory_summary_by_thread_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20;
```

```sql
SELECT m.thread_id AS tid, m.user, esc.DIGEST_TEXT, m.current_allocated, m.total_allocated
FROM sys.memory_by_thread_by_current_bytes m
JOIN performance_schema.events_statements_current esc
  ON m.thread_id = esc.THREAD_ID;
```

注意：打开所有内存性能监控会影响性能，按需开启/关闭。
开启示例：
```sql
UPDATE performance_schema.setup_instruments SET ENABLED = 'YES' WHERE NAME LIKE 'memory/%';
```
关闭示例：
```sql
UPDATE performance_schema.setup_instruments SET ENABLED = 'NO' WHERE NAME LIKE 'memory/%';
```
查看使用：
```sql
SELECT * FROM performance_schema.memory_summary_global_by_event_name
WHERE EVENT_NAME LIKE 'memory/%'
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC;
```

my.cnf 建议配置：
```
[mysqld]
performance-schema-instrument='memory/%=COUNTED'
```
最好在开启后重启 MySQL 服务以便准确统计。

### 系统表内存监控信息（示例查询）
```sql
SELECT * FROM sys.x$memory_by_host_by_current_bytes;
SELECT * FROM sys.x$memory_by_thread_by_current_bytes;
SELECT * FROM sys.x$memory_by_user_by_current_bytes;
SELECT * FROM sys.x$memory_global_by_current_bytes;
SELECT * FROM sys.x$memory_global_total;

SELECT * FROM performance_schema.memory_summary_by_account_by_event_name;
SELECT * FROM performance_schema.memory_summary_by_host_by_event_name;
SELECT * FROM performance_schema.memory_summary_by_thread_by_event_name;
SELECT * FROM performance_schema.memory_summary_by_user_by_event_name;
SELECT * FROM performance_schema.memory_summary_global_by_event_name;
```

备注：找到对应问题事件或线程后，进行深入排查以解决内存高的问题。

---

## 4. 使用系统工具查看内存
1) top
- top 能显示系统中各进程资源占用状况。
- 在 top 中按 Shift + M 可以按内存排序，关注 RES 指标（实际物理内存占用）。

2) free
- free -h 显示物理内存、交换空间（swap）和内核缓冲区使用情况。
- used 列显示已被使用的内存和交换空间。
- buff/cache 列显示被 buffer 和 cache 使用的内存。
- available 列显示可供应用程序使用的内存。
- Swap 行显示交换空间使用情况。

3) ps
- 查看与 MySQL 相关进程的内存情况，例如：
```bash
ps eo user,pid,vsz,rss $(pgrep -f 'mysqld')
```
示例输出：
```
USER   PID     VSZ      RSS
root   215945  12960    2356
mysql  217246  1291540  241824
root   221056  12960    2428
mysql  374243  1336924  408752
```

4) pmap
- pmap 是定位进程内存使用的好工具，查看进程的内存映像信息。
用法示例 1：持续记录 RSS 变化（最少记录 20 次更可靠）
```bash
while true; do pmap -d 22837 | tail -1; sleep 2; done
```
用法示例 2：导出进程内存映像（22837 为示例 pid）
```bash
pmap -X -p 22837 > /tmp/memmysql.txt
```
说明：
- RSS 表示该进程实际占用的物理内存。
- Dirty 表示脏页字节数（包含共享与私有）。
- Mapping 列展示占用内存的文件或 [anon]（分配的匿名内存）、或 [stack]（栈）。
- writeable/private 表示进程所占用的私有地址空间大小，也就是该进程实际使用的内存大小。

排查流程建议：
1. 首先使用 top/free/ps 在系统级确定是否存在内存泄露。如果有，从 top 输出确定是哪一个进程。
2. 使用 pmap 辅助确定是否存在 memory leak。判断原则：如果 pmap -d 输出的 writeable/private 在重复操作过程中持续增长且不释放，则可能存在内存泄露。

---

## 总结与后续处理建议
- 从参数设置和系统/设计层面尽量合理化，避免不必要的全局或线程级大内存分配。
- 使用 performance_schema 系列表对内存进行排查，找出持续占用内存的事件、用户、线程或账号。
- 使用 Linux 工具（top、free、ps、pmap）进一步确认问题是否为进程级内存泄露。
- 检查官方 bug 列表，确认是否为已知的 memory leak 并查看是否有修复版本。
- 如果以上方法都无法定位问题，可考虑切换到其他服务器或进行主从切换观察，或评估是否升级 MySQL 版本（升级代价可能较大）。
- 如能提供实际环境数据，可以一步步调试并抓取内存变化，确定导致内存泄露的根因，之后向官方提交 bug 请求修复。