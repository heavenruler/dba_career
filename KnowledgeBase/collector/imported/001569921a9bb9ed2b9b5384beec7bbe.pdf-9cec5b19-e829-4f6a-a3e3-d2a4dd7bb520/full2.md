# MySQL8.0 统计信息总结

作者：闫建 (Rock Yan)，云和恩墨技术服务团队  
日期：2025-03-17

在 MySQL 8.0 中，统计信息（Statistics）是优化器（Optimizer）用来生成执行计划的重要依据，直接影响 SQL 性能。MySQL 提供了两种统计信息的管理方式：非持久化统计信息（Non-Persistent Statistics）和持久化统计信息（Persistent Statistics）。这两种方式在存储、更新机制以及对执行计划的影响上有所不同。

## 1. 非持久性优化器统计信息

非持久优化器统计信息（non-persistent optimizer statistics）是指 InnoDB 存储引擎的统计信息仅存储在内存中，不会持久化到磁盘。MySQL 服务重启时，这些统计信息会丢失，并在下次访问表时重新计算。非持久化统计信息的行为由参数 `innodb_stats_persistent` 控制；当该参数设置为 OFF 时，统计信息为非持久化。缺省情况下 MySQL 的统计信息是持久化的（`innodb_stats_persistent=ON`）。

非持久优化器统计信息通常在以下几种情况下触发更新：
1. 手动执行 `ANALYZE TABLE` 命令。
2. 在 `innodb_stats_on_metadata=ON` 的情况下，执行 `SHOW TABLE STATUS`、`SHOW INDEX` 或查询 `information_schema` 库下的 `TABLES` 和 `STATISTICS` 表（说明：默认情况下 `innodb_stats_on_metadata` 是关闭的；开启会降低大量表或索引库的访问速度，并减少查询语句执行计划的稳定性）。
3. MySQL 客户端连接时启用自动补全功能 `--auto-rehash`（默认启用）。（说明：禁用 `--no-auto-rehash` 可以加快连接速度，减少内存占用，但需要手动输入完整的 SQL 语句。）
4. 首次打开表时。
5. 自上次统计信息更新后，InnoDB 检测到表有 1/16 的数据被修改时。

另外，`innodb_stats_transient_sample_pages` 参数控制非持久化统计信息的采样页面数，统计信息数据更新机制基于 InnoDB 表的索引页数量来估算。默认值为 8 页。增大该值会提高统计信息的准确性，但会增加计算开销；减小该值会降低准确性但减少开销。默认值通常是合理的平衡点；如果优化器选择了不理想的执行计划，可尝试逐步调整该参数。

## 2. 持久性优化器统计信息

为解决非持久化统计信息频繁变化和计算开销的问题，从 MySQL 5.6 起引入了持久化统计信息功能，将统计信息持久化存储到磁盘，并在表数据发生重大变化时自动更新。持久化统计信息主要由参数 `innodb_stats_persistent` 决定，默认开启（ON）。

### 3. 持久化统计信息存储在哪里？

主要存储在系统库 `mysql` 的以下两张表中：

- mysql.innodb_table_stats：存储表级统计信息（如行数、聚集索引大小等）。

示例表结构（输出为 DESC）： 
```
mysql> DESC mysql.innodb_table_stats;
+--------------------------+-----------------+------+-----+-------------------+-----------------------------------------------+
| Field                    | Type            | Null | Key | Default           | Extra                                         |
+--------------------------+-----------------+------+-----+-------------------+-----------------------------------------------+
| database_name            | varchar(64)     | NO   | PRI | NULL              |                                               |
| table_name               | varchar(199)    | NO   | PRI | NULL              |                                               |
| last_update              | timestamp       | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED                             |
| n_rows                   | bigint unsigned | NO   |     | NULL              |                                               |
| clustered_index_size     | bigint unsigned | NO   |     | NULL              |                                               |
| sum_of_other_index_sizes | bigint unsigned | NO   |     | NULL              |                                               |
+--------------------------+-----------------+------+-----+-------------------+-----------------------------------------------+
```

主要字段说明：
- `database_name`：数据库名
- `table_name`：表名
- `last_update`：最近更新时间
- `n_rows`：表的行数
- `clustered_index_size`：聚集索引的大小，单位为页（pages）
- `sum_of_other_index_sizes`：其他索引的总大小，单位为页（pages）

- mysql.innodb_index_stats：存储索引级统计信息（如基数、叶子页数等）。

示例表结构：
```
mysql> DESC mysql.innodb_index_stats;
+------------------+-----------------+------+-----+-------------------+-----------------------------------------------+
| Field            | Type            | Null | Key | Default           | Extra                                         |
+------------------+-----------------+------+-----+-------------------+-----------------------------------------------+
| database_name    | varchar(64)     | NO   | PRI | NULL              |                                               |
| table_name       | varchar(199)    | NO   | PRI | NULL              |                                               |
| index_name       | varchar(64)     | NO   | PRI | NULL              |                                               |
| last_update      | timestamp       | NO   |     | CURRENT_TIMESTAMP | DEFAULT_GENERATED                             |
| stat_name        | varchar(64)     | NO   | PRI | NULL              |                                               |
| stat_value       | bigint unsigned | NO   |     | NULL              |                                               |
| sample_size      | bigint unsigned | YES  |     | NULL              |                                               |
| stat_description | varchar(1024)   | NO   |     | NULL              |                                               |
+------------------+-----------------+------+-----+-------------------+-----------------------------------------------+
```

主要字段说明：
- `database_name`：数据库名
- `table_name`：表名
- `index_name`：索引名
- `last_update`：最近更新时间
- `stat_name`：统计信息名称（如 `n_diff_pfx01`、`n_leaf_pages`、`size` 等）
- `stat_value`：统计信息值
- `sample_size`：样本大小
- `stat_description`：统计信息描述

示例：查询 `large_table` 表索引的统计信息
```
mysql> SELECT * FROM mysql.innodb_index_stats WHERE table_name='large_table';
+---------------+-------------+---------------+---------------------+--------------+------------+-------------+-----------------------------------+
| database_name | table_name  | index_name    | last_update         | stat_name    | stat_value | sample_size | stat_description                 |
+---------------+-------------+---------------+---------------------+--------------+------------+-------------+-----------------------------------+
| testdb        | large_table | PRIMARY       | 2025-03-14 14:53:46 | n_diff_pfx01 | 496403     |             |                                   |
| testdb        | large_table | PRIMARY       | 2025-03-14 14:53:46 | n_leaf_pages | 4111       |             |                                   |
| testdb        | large_table | PRIMARY       | 2025-03-14 14:53:46 | size         | 4134       |             |                                   |
| testdb        | large_table | idx_lt_field1 | 2025-03-14 14:53:46 | n_diff_pfx01 | 97645      |             |                                   |
| testdb        | large_table | idx_lt_field1 | 2025-03-14 14:53:46 | n_diff_pfx02 | 500041     |             |                                   |
| testdb        | large_table | idx_lt_field1 | 2025-03-14 14:53:46 | n_leaf_pages | 662        |             |                                   |
| testdb        | large_table | idx_lt_field1 | 2025-03-14 14:53:46 | size         | 803        |             |                                   |
+---------------+-------------+---------------+---------------------+--------------+------------+-------------+-----------------------------------+
```

说明常见 `stat_name`：
- `n_diff_pfx01`：索引第一列的不同值数量
- `n_diff_pfx02`：索引前两列的不同值数量（对于多列索引，例如 (col1, col2)，`n_diff_pfx02` 表示 col1, col2 的组合不同值数）
- `n_leaf_pages`：索引的叶子页数量
- `size`：索引的总页数，包括叶子页和非叶子页

### 4. 持久化统计信息的准确性由谁来决定？

在 MySQL 8.0 中，持久化统计信息的准确性由采样数据和统计信息计算方式决定。MySQL 通过分析表的索引和数据分布来生成统计信息，影响查询优化器的决策。具体包括：

1. 采样数据：由参数 `innodb_stats_persistent_sample_pages` 控制采样页数，默认值为 20。采样页越多，统计信息越准确，但计算开销越大。
2. 统计信息计算方式：例如基数估算（通过索引中的不同值估算选择性）和直方图（MySQL 8.0 引入，用于更精确地估算数据分布）。
3. 自动重新计算：由 `innodb_stats_auto_recalc` 控制，默认启用；如果表中超过 10% 的数据发生变化，MySQL 会自动重新计算统计信息。
4. 手动更新：可以使用 `ANALYZE TABLE` 命令手动更新统计信息：
```
ANALYZE TABLE table_name;
```

### 5. 统计信息的准确性如何受影响？

持久性统计信息的准确性可能受以下因素影响：
- 采样页数不足：`innodb_stats_persistent_sample_pages` 过小可能无法准确反映数据分布。
- 数据分布不均匀：高频值或偏斜分布使得采样难以代表整体。
- 索引结构变化：添加或删除索引后，统计信息可能过时。
- 表数据变化：大量插入、更新或删除会导致统计信息失真。
- 直方图未启用：未使用直方图时，对于复杂或偏斜数据分布的选择性估算可能不准确。

### 6. 如何提高统计信息的准确性？

常见做法：
1. 增加采样页数：
```
SET GLOBAL innodb_stats_persistent_sample_pages = 50;
```
2. 启用直方图统计信息（按列生成直方图）：
```
ANALYZE TABLE table_name UPDATE HISTOGRAM ON column_name;
```
3. 定期更新统计信息：定期执行 `ANALYZE TABLE`，确保统计信息是最新的。
4. 优化表碎片：表碎片可能影响统计信息，定期优化表，例如：
```
OPTIMIZE TABLE example_table;
-- 或
ALTER TABLE my_table ENGINE=InnoDB;
```
说明：上述操作会导致表被锁定，生产环境中对大表执行时需谨慎安排维护窗口或使用在线 DDL（若可用）。
5. 优化索引：设计合理的索引，避免冗余或无效索引。
6. 针对关键查询，可以手动创建直方图或手动更新统计信息以提高特定列的估算精度。

### 7. 相关参数

- `innodb_stats_persistent`：是否启用持久化统计信息（默认 ON）。
- `innodb_stats_auto_recalc`：是否自动重新计算统计信息（默认 ON）。
- `innodb_stats_persistent_sample_pages`：采样页数（默认 20）。
- `innodb_stats_transient_sample_pages`：非持久统计的采样页数（默认 8）。
- `innodb_stats_method`：统计信息计算方法（如 `nulls_equal`、`nulls_unequal` 等）。

## 总结

持久化优化器统计信息的准确性由采样数据、统计信息计算方式和表数据分布等多种因素共同决定。为提高准确性，可以增加采样页数、启用直方图、定期更新统计信息、优化表和索引设计。通过合理配置与监控，可以帮助查询优化器选择更优的执行计划，从而提升 SQL 性能。

## 参考文档

- https://dev.mysql.com/doc/refman/8.0/en/innodb-persistent-stats.html
- https://dev.mysql.com/doc/refman/8.0/en/innodb-statistics-estimation.html
- https://dev.mysql.com/doc/refman/8.0/en/innodb-performance-optimizer-statistics.html