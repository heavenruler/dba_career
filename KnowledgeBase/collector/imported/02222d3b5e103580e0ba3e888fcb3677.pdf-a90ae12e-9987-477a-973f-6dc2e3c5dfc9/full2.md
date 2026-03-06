# PG vs MySQL 统计信息收集的异同

作者：进击的CJR  
日期：2025-02-05

## 统计信息的作用

对于一条 SQL，数据库需要根据统计信息估算代价并选择最低代价的执行计划。收集统计信息主要是为了让优化器做出正确的判断，选择最佳的执行计划。

## PG 的统计信息相关表

在 PostgreSQL 里，统计信息存放于系统表 `pg_statistics` 中，但 `pg_statistics` 的内容人为不易阅读，因此提供了 `pg_stats` 视图。

可以通过 `pg_class` 查看页数和行数估算，例如：

```sql
postgres=# select relname, relpages, reltuples::bigint
from pg_class
where relname='test';
```

示例输出：

```
 relname   | relpages | reltuples
-----------+----------+-----------
 test      |      443 |    100000
```

通过 `pg_stat_all_tables` 可以查看活元组、死元组和上次统计信息收集时间：

```sql
postgres=# select * from pg_stat_all_tables where relname='test'\gx
```

示例输出（精简）：

```
-[ RECORD 1 ]------+------------------------------
relid              | 16388
schemaname         | public
relname            | test
seq_scan           | 0
seq_tup_read       | 0
n_tup_ins          | 100000
n_tup_upd          | 0
n_tup_del          | 0
n_live_tup         | 100000
n_dead_tup         | 0
last_vacuum        |
last_autovacuum    | 2025-01-21 10:46:51.330118+08
last_analyze       | 2025-01-17
last_autoanalyze   | 2025-01-21 10:46:51.353753+08
autovacuum_count   | 1
autoanalyze_count  | 1
```

查看 `pg_stats` 结构：

```text
\d pg_stats
```

示例（部分字段）：

```
View "pg_catalog.pg_stats"
Column                   | Type     | Collation | Nullable | Default
-------------------------+----------+-----------+----------+---------
schemaname               | name     |           |          |
tablename                | name     |           |          |
attname                  | name     |           |          |
inherited                | boolean  |           |          |    -- 是否是继承列
null_frac                | real     |           |          |    -- null 空值的比率
avg_width                | integer  |           |          |    -- 平均宽度，字节
n_distinct               | real     |           |          |    -- >0: 非重复值数，<0: 非重复值数为 -n_distinct * rows
most_common_vals         | anyarray |           |          |    -- 高频值
most_common_freqs        | real[]   |           |          |    -- 高频值的频率
histogram_bounds         | anyarray |           |          |    -- 直方图
correlation              | real     |           |          |    -- 物理顺序和逻辑顺序的相关性
most_common_elems        | anyarray |           |          |    -- 高频元素（如数组）
most_common_elem_freqs   | real[]   |           |          |    -- 高频元素的频率
elem_count_histogram     | real[]   |           |          |    -- 元素直方图
```

## PG 自动收集统计信息

Autovacuum/autoanalyze 触发条件之一是当表上的新增（insert/update/delete）数 >= autovacuum_analyze_scale_factor * reltuples + autovacuum_analyze_threshold 时会触发 analyze。

查看相关配置示例：

```sql
postgres=# show autovacuum_analyze_scale_factor;
 autovacuum_analyze_scale_factor
---------------------------------
 0.1
(1 row)

postgres=# show autovacuum_analyze_threshold;
 autovacuum_analyze_threshold
------------------------------
 50
(1 row)
```

## PG 手动收集统计信息

手动收集统计信息的命令是 `ANALYZE`，语法：

```
ANALYZE [VERBOSE] [table[(column[, ...])]]
```

- VERBOSE：显示处理进度以及表的一些统计信息。
- table：要分析的表名，若不指定则对整个数据库的所有表分析。
- column：要分析的特定字段名，默认分析所有字段。

`ANALYZE` 会在表上加读锁（PostgreSQL 是 SHARE UPDATE EXCLUSIVE），不影响表上其它 SQL 的并发执行。对于大表，`ANALYZE` 只会读取表中部分数据（抽样）。

## MySQL 的统计信息相关表

MySQL（InnoDB）收集的表统计信息存放在 `mysql.innodb_table_stats`，索引统计信息存放在 `mysql.innodb_index_stats`。

示例查询及输出：

```sql
mysql> select * from mysql.innodb_table_stats where table_name='actor';
```

输出示例（精简）：

```
+---------------+------------+---------------------+--------+----------------------+--------------------------+
| database_name | table_name | last_update         | n_rows | clustered_index_size | sum_of_other_index_sizes |
+---------------+------------+---------------------+--------+----------------------+--------------------------+
| sakila        | actor      | 2025-01-21 16:06:31 |    200 | ...                  | ...                      |
+---------------+------------+---------------------+--------+----------------------+--------------------------+
```

查看索引统计：

```sql
mysql> select * from mysql.innodb_index_stats where table_name='actor';
```

输出示例（精简）：

```
+---------------+------------+---------------------+---------------------+--------------+------------+-------------+-----------------------------------+
| database_name | table_name | index_name          | last_update         | stat_name    | stat_value | ...         | ...
+---------------+------------+---------------------+---------------------+--------------+------------+-------------+-----------------------------------+
| sakila        | actor      | PRIMARY             | 2025-01-21 16:06:31 | n_leaf_pages | ...        | ...         | ...
| sakila        | actor      | idx_actor_last_name | 2025-01-21 16:06:31 | n_diff_pfx01 | ...        | ...         | ...
+---------------+------------+---------------------+---------------------+--------------+------------+-------------+-----------------------------------+
```

## MySQL 自动收集统计信息（InnoDB）

主要相关变量和表选项：

- `innodb_stats_persistent`：是否将统计信息持久化。对应表选项 STATS_PERSISTENT。
- `innodb_stats_auto_recalc`：当一个表的数据变化超过 10% 时是否自动收集统计信息。两次统计收集之间时间间隔不能少于 10 秒。对应表选项 STATS_AUTO_RECALC。
- `innodb_stats_on_metadata`：当表的元数据发生变化（如执行 ALTER TABLE）时触发统计信息的自动更新。
- `innodb_stats_persistent_sample_pages`：统计索引时的抽样页数，设置越大准确度越高但消耗更多资源。对应表选项 STATS_SAMPLE_PAGES。

查看示例变量：

```sql
mysql> show variables like 'innodb_stat%';
+--------------------------------------+-------------+
| Variable_name                        | Value       |
+--------------------------------------+-------------+
| innodb_stats_auto_recalc             | ON          |
| innodb_stats_include_delete_marked   | OFF         |
| innodb_stats_method                  | nulls_equal |
| innodb_stats_on_metadata             | OFF         |
| innodb_stats_persistent              | ON          |
| innodb_stats_persistent_sample_pages | 20          |
| innodb_stats_transient_sample_pages  | 8           |
| innodb_status_output                 | OFF         |
| innodb_status_output_locks           | OFF         |
+--------------------------------------+-------------+
```

可以通过表选项设置：

```sql
ALTER TABLE actor STATS_AUTO_RECALC = 0;
```

## MySQL 手动收集统计信息

使用 `ANALYZE TABLE` 语句，例如：

```sql
ANALYZE LOCAL TABLE actor, rental;
```

`ANALYZE TABLE` 会加 MDL 读锁（metadata lock），不影响 DML 的并行操作。

## PG vs MySQL 的比较

- 自动收集统计信息的触发灵活性：PostgreSQL 更灵活。PG 可以通过调整 `autovacuum_analyze_scale_factor` 来控制以比例方式触发 analyze，并且有 `autovacuum_analyze_threshold` 作为最小更新量保护，避免对小表频繁触发统计收集影响性能。MySQL 的自动触发阈值是固定的（通常以 10% 为基准）。
- 手动收集的影响：PG 和 MySQL 在手动收集统计信息时都不会阻塞 DML 并发。MySQL 使用元数据读锁（MDL），PG 使用 SHARE UPDATE EXCLUSIVE（共享更新独占），两者都不会阻止普通 DML。
- 统计信息种类：MySQL 的统计信息相对简单；PostgreSQL 提供更丰富的统计信息（例如多列统计、多字段组合统计、数组元素统计等），可以为复杂查询提供更精确的优化依据。
- 对性能的影响：MySQL 的自动统计信息收集在数据量大且修改频繁时可能增加系统负载；PostgreSQL 的 autovacuum 在后台运行，对系统影响相对较小，但在大规模数据变更或系统负载高时同样可能出现性能波动。

## 结论（简要）

- PostgreSQL 在统计信息的灵活性和丰富性上占优，尤其适合需要更精细统计（如多列相关性、复杂数据类型）以支持复杂查询优化的场景。
- MySQL（InnoDB）在易用性上较为直观，配置较少，但在数据高度不均匀或需要多列统计时可能不够精确。