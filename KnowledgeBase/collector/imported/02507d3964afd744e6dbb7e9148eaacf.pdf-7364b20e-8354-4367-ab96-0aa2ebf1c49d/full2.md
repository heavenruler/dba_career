# MySQL 内存使用率高问题排查

本⽂为墨天轮数据库管理服务团队原创内容。  
作者：蔡璐  
墨天轮数据库管理服务团队技术顾问  
十年数据库技术顾问经验，擅长 MySQL、PostgreSQL、openGauss，数据库架构设计、容灾、日常管理、疑难故障诊断、性能优化、迁移升级改造等。

## 一、问题现象
实例：mysql 进程实际内存使用率过高。  
环境示例：MySQL 8.0.39，slow query log 未开启，innodb_buffer_pool_size = 12G（机器内存 62G，相对配置较低），临时文件在 /tmp 目录下。

## 二、问题排查

### 2.1 参数检查
查看与内存相关的参数，例如：
```sql
SELECT @@key_buffer_size,
       @@innodb_buffer_pool_size,
       @@innodb_log_buffer_size,
       @@tmp_table_size,
       @@read_buffer_size,
       @@sort_buffer_size,
       @@join_buffer_size,
       @@read_rnd_buffer_size,
       @@binlog_cache_size,
       @@thread_stack,
       @@max_connections;
```

查看当前活跃连接数（非 Sleep）：
```sql
SELECT COUNT(host) FROM information_schema.processlist WHERE command <> 'Sleep';
```

### 2.2 检查内存使用（变量/配置层面）
可参考 sys 与 performance_schema 提供的视图来查看内存分配和使用情况。

### 2.3 存储过程、函数、视图、触发器
检查数据库对象数量（排除系统库）：

存储过程与函数：
```sql
SELECT Routine_schema, Routine_type
FROM information_schema.Routines
WHERE Routine_schema NOT IN ('mysql','information_schema','performance_schema')
GROUP BY Routine_schema, Routine_type;
```

视图：
```sql
SELECT TABLE_SCHEMA, COUNT(TABLE_NAME)
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA NOT IN ('mysql','information_schema','performance_schema')
GROUP BY TABLE_SCHEMA;
```

触发器：
```sql
SELECT TRIGGER_SCHEMA, COUNT(*)
FROM information_schema.triggers
WHERE TRIGGER_SCHEMA NOT IN ('mysql','information_schema','performance_schema')
GROUP BY TRIGGER_SCHEMA;
```

（目的是确认是否有大量存储过程/函数/视图/触发器在运行时占用内存）

### 2.4 排查实际占用

1. 总内存使用（来自 sys.memory_global_by_current_bytes）：
```sql
SELECT SUM(CAST(REPLACE(current_alloc,'MiB','') AS DECIMAL(10,2)))
FROM sys.memory_global_by_current_bytes
WHERE current_alloc LIKE '%MiB%';
```

2. 按事件统计内存：
```sql
SELECT event_name,
       SUM(CAST(REPLACE(current_alloc,'MiB','') AS DECIMAL(10,2))) AS MiB_used
FROM sys.memory_global_by_current_bytes
WHERE current_alloc LIKE '%MiB%'
GROUP BY event_name
ORDER BY MiB_used DESC;
```

或使用 performance_schema：
```sql
SELECT event_name,
       sys.format_bytes(CURRENT_NUMBER_OF_BYTES_USED) AS used
FROM performance_schema.memory_summary_global_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 10;
```

3. 按账号统计（示例，按 MB 排序）：
```sql
SELECT user,
       event_name,
       current_number_of_bytes_used/1024/1024 AS MB_CURRENTLY_USED
FROM performance_schema.memory_summary_by_account_by_event_name
WHERE host <> 'localhost'
ORDER BY current_number_of_bytes_used DESC
LIMIT 10;
```

### 2.5 操作系统排查
在操作系统层面确认哪个进程占用内存，以及内存使用的类型。

常用工具与命令：
- top（可按 M 排序）
- ps：查看 mysqld 相关进程内存情况
```bash
ps eo user,pid,vsz,rss $(pgrep -f 'mysqld')
```
- pmap：查看进程内存映射
```bash
pmap -d <pid> | tail -1
# 或导出到文件
pmap -X -p <pid> > /tmp/memmysql.txt
```
也可以持续监控：
```bash
while true; do pmap -d <pid> | tail -1; sleep 2; done
```

pmap 输出说明要点：
- RSS：进程实际占用的物理内存。
- Dirty：脏页字节数（包括共享和私有）。
- Mapping 列出占用内存的文件、[anon]（分配的匿名内存）、[stack]（堆栈）等。
- writeable/private：表示私有地址空间大小，即进程实际使用的内存大小。

排查原则：
1) 先用 top/free/ps 在系统级别确定是否有内存泄露，以及是哪一个 process。
2) pmap 可以帮助确认进程是否有 memory leak。若 writeable/private（pmap -d 输出）在重复操作过程中持续增长，则可能存在内存泄露。

### 2.6 检查大页（Transparent Huge Pages, THP）配置
大页（THP）在某些情况下会导致内存行为异常或性能问题，需检查是否启用并据情况处理。

## 三、解决方案

1) 临时关闭 THP（立即生效，重启后恢复）：
```bash
echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag
```

2) 永久关闭（重启后仍生效）：在 /etc/rc.local 中加入如下内容（示例脚本）：
```sh
#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here.
touch /var/lock/subsys/local
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
  echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
  echo never > /sys/kernel/mm/transparent_hugepage/defrag
fi
```

（保存后确保 /etc/rc.local 可执行并在系统 init 中被调用）

---

备注：排查 MySQL 内存使用高的问题需要同时从 MySQL 层（参数、内存分配、会话/账户、存储过程与对象）和操作系统层（进程、内存映射、THP 等）进行定位。以上步骤为常见且实用的检查与处理方法。