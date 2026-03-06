MySQL 锁定位实践指南
作者：Digital Observer（施嘉伟）

简介
在数据库日常运维中，锁问题常常成为性能瓶颈和系统卡顿的根源。本文系统总结了 MySQL 中常见的锁类型及其排查方法，涵盖全局读锁（Global Read Lock）、表锁（Table Lock）、元数据锁（MDL）及行锁（Row Lock），并提供标准化的诊断脚本，适用于 MySQL 5.6、5.7 与 8.0 多个版本。建议在生产环境中提前开启并配置 performance_schema 与 sys，以提升锁问题的可观测性和处理效率。

一、全局读锁（Global Read Lock）
说明
全局读锁通常由 FLUSH TABLES WITH READ LOCK 添加，常用于逻辑备份或主从切换。另一种风险情形是权限设置不合理，具备 RELOAD 权限的账号可能误操作导致加锁。

排查方法
- 检查 metadata_locks（当 performance_schema 可用时）：
```sql
select *
from performance_schema.metadata_locks
where owner_thread_id != sys.ps_thread_id(connection_id());
```

- 查找执行 FLUSH TABLES WITH READ LOCK 的语句（performance_schema.events_statements_history 可用时）：
```sql
select
  concat('kill ', l.id, ';') as kill_command,
  e.THREAD_ID,
  e.event_name,
  e.CURRENT_SCHEMA,
  e.SQL_TEXT,
  round(e.TIMER_WAIT / 1000000000000, 2) as TIMER_WAIT_s,
  l.host,
  l.db,
  l.state,
  e.TIMER_START
from performance_schema.events_statements_history e
inner join information_schema.processlist l
  on e.THREAD_ID = sys.ps_thread_id(l.id)
where e.event_name = 'statement/sql/flush'
order by e.TIMER_START;
```

二、表锁（Table Lock）
说明
表锁通常由显式语句如 LOCK TABLE t READ/WRITE 引入，用于控制表级别的并发访问。表锁也可能在某些存储引擎或管理操作中被隐式持有。

排查方法
- 使用 metadata_locks 查看表级锁占用（同 Global Read Lock）：
```sql
select *
from performance_schema.metadata_locks
where owner_thread_id != sys.ps_thread_id(connection_id());
```

三、MDL 锁（Metadata Lock）
说明
MDL（元数据锁）在访问表对象时自动加锁，用于保证读写操作的元数据一致性。若遇到 DDL 阻塞等情形，往往与 MDL 锁有关。

排查方法
- 未开启 sys 扩展（适用于 MySQL 5.7/8.0，依赖 performance_schema）：
```sql
use performance_schema;

select
  p.THREAD_ID,
  concat('kill ', l.id, ';') as kill_command,
  p.event_name,
  p.TIMER_START,
  round(p.TIMER_WAIT / 1000000000000, 2) as TIMER_WAIT_s,
  p.CURRENT_SCHEMA,
  p.SQL_TEXT,
  l.host,
  l.db,
  l.STATE,
  l.INFO as mdl_blocking_info
from performance_schema.events_statements_history p
inner join information_schema.processlist l
  on p.THREAD_ID = sys.ps_thread_id(l.id)
where l.state = 'Waiting for table metadata lock'
order by p.TIMER_START;
```

- 已开启 sys 扩展时：
```sql
select * from sys.schema_table_lock_waits;
```

四、行锁（Row Lock）
说明
行锁是 InnoDB 的核心特性之一，支持高并发访问。常见的行锁类型包括：
- 意向锁（表级）：IX（意向独占）、IS（意向共享）
- Next-Key 锁：锁定记录本身及其前间隙（排他性）
- 记录锁（仅记录本身）：X,REC_NOT_GAP（排他） / S,REC_NOT_GAP（共享）
- 纯间隙锁：X,GAP / S,GAP
- 插入意向锁：X,GAP,INSERT_INTENTION

排查方法
- MySQL 5.7 / 8.0（performance_schema 与 sys 建议启用）  
  推荐直接使用 sys 提供的视图，或结合 performance_schema 的历史语句来定位阻塞：
```sql
-- 借助 sys.innodb_lock_waits（推荐）
select * from sys.innodb_lock_waits;

-- 或者结合 events_statements_history 获取等待与阻塞的 SQL 文本
select
  ilw.waiting_thread as waiting_thread,
  ilw.waiting_pid,
  ilw.waiting_query,
  ilw.blocking_thread as blocking_thread,
  ilw.blocking_pid,
  ilw.blocking_query,
  ilw.wait_started,
  ilw.wait_age
from sys.innodb_lock_waits ilw
order by ilw.wait_started;
```

- MySQL 5.6（未启用 performance_schema，使用 information_schema）：
```sql
SELECT
  r.trx_wait_started AS wait_started,
  TIMEDIFF(NOW(), r.trx_wait_started) AS wait_age,
  TIMESTAMPDIFF(SECOND, r.trx_wait_started, NOW()) AS wait_age_secs,
  rl.lock_table AS locked_table,
  r1.lock_index AS locked_index,
  r1.lock_type AS locked_type,
  r.trx_id AS waiting_trx_id,
  r.trx_started AS waiting_trx_started,
  TIMEDIFF(NOW(), r.trx_started) AS waiting_trx_age,
  r.trx_rows_locked AS waiting_trx_rows_locked,
  r.trx_rows_modified AS waiting_trx_rows_modified,
  r.trx_mysql_thread_id AS waiting_pid,
  sys.format_statement(r.trx_query) AS waiting_query,
  r1.lock_id AS waiting_lock_id,
  r1.lock_mode AS waiting_lock_mode,
  b.trx_id AS blocking_trx_id,
  b.trx_mysql_thread_id AS blocking_pid,
  sys.format_statement(b.trx_query) AS blocking_query,
  bl.lock_id AS blocking_lock_id,
  bl.lock_mode AS blocking_lock_mode,
  b.trx_started AS blocking_trx_started,
  TIMEDIFF(NOW(), b.trx_started) AS blocking_trx_age,
  b.trx_rows_locked AS blocking_trx_rows_locked,
  b.trx_rows_modified AS blocking_trx_rows_modified,
  concat('KILL QUERY ', b.trx_mysql_thread_id) AS sql_kill_blocking_query,
  concat('KILL ', b.trx_mysql_thread_id) AS sql_kill_blocking_connection
from information_schema.innodb_lock_waits w
inner join information_schema.innodb_trx b on b.trx_id = w.blocking_trx_id
inner join information_schema.innodb_trx r on r.trx_id = w.requesting_trx_id
inner join information_schema.innodb_locks bl on bl.lock_id = w.blocking_lock_id
inner join information_schema.innodb_locks r1 on r1.lock_id = w.requested_lock_id
order by r.trx_wait_started;
```

总结与建议
- 在生产环境中建议开启并合理配置 performance_schema 与 sys 扩展，以便实时监控与历史诊断。
- 定期审计拥有 RELOAD / SUPER 等高权限的账号，避免误操作引发全局或表级锁。
- 对于频繁出现的行锁争用，优先从 SQL 优化、索引设计与事务粒度入手，必要时调整隔离级别或拆分热表。
- 在处理阻塞时，优先通过查询语句定位占用锁的线程（并在确认安全后使用 KILL 或调整应用重试逻辑），避免粗暴中断导致更大范围的问题。

通过上述脚本与方法，可以对 MySQL 不同层级的锁进行精准排查与定位，提升数据库系统的稳定性和可维护性。