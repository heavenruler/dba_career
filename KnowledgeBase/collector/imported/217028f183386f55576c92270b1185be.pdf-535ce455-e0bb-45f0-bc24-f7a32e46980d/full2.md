# MySQL 索引下推（Index Condition Pushdown，ICP）

作者：超爱吃士力架 · 2024-11-30 · 专栏：MySQL篇

## 概述
索引下推（Index Condition Pushdown，简称 ICP）是一种在存储引擎层对索引进行过滤的优化技术。它允许 MySQL 在使用联合索引查找数据时，将部分查询条件“下推”到存储引擎层进行过滤，从而减少回表（根据二级索引找到主键后访问基表行）的次数，降低 I/O 开销并提升查询性能。索引下推仅适用于基于索引列可判断的条件，通常用于联合索引的场景。

通俗来说，未启用 ICP 时，存储引擎通过索引定位到基表行并返回给 server 层，由 server 层继续用 WHERE 中的其他条件过滤；启用 ICP 后，能用索引列判断的条件会在存储引擎层先行过滤，只有满足的索引条目才回表取行，从而减少回表和数据传输。

## 工作原理（使用前后对比）
- 不使用 ICP 的索引扫描过程：
  - 存储引擎：将满足索引范围条件的索引记录对应的整行记录取出，返回给 server 层。
  - server 层：对返回的数据使用后续的 WHERE 条件过滤，直到输出最终结果。

- 使用 ICP 的索引扫描过程：
  - 存储引擎：确定索引范围后在索引上使用 index filter（即下推的条件）进行过滤，只有满足 index filter 的索引记录才回表取整行并返回给 server 层；不满足的索引记录被丢弃，不回表也不返回 server 层。
  - server 层：对返回的数据再使用 table filter 条件做最后的过滤。

ICP 的加速效果取决于在存储引擎内被 ICP 筛掉的数据比例，筛掉得越多，节约的回表/传输成本越大。

## 何时适用（使用条件）
- 表访问类型为 range、ref、eq_ref 和 ref_or_null 的查询可以使用 ICP。
- 支持的引擎：InnoDB、MyISAM（包括分区表）。
- 对于 InnoDB/MyISAM，ICP 仅用于二级索引（secondary index）。
- 如果 SQL 使用覆盖索引（covering index），则不支持 ICP，因为覆盖索引本身不需要回表，ICP 的作用是减少回表。
- 相关子查询中的条件通常不能使用 ICP。
- ICP 仅能下推那些仅依赖索引列就能判断的条件，不能下推依赖非索引列或复杂表达式的条件。

## 开启/关闭 ICP
默认情况下索引条件下推是启用的。可以通过设置系统变量 optimizer_switch 中的 index_condition_pushdown 项来关闭或开启：

```sql
-- 关闭索引下推
SET optimizer_switch = 'index_condition_pushdown=off';

-- 打开索引下推
SET optimizer_switch = 'index_condition_pushdown=on';
```

在 EXPLAIN 的输出中，如果语句使用了索引条件下推，Extra 列会显示 `Using index condition`。

## 使用案例

建表与索引：

```sql
CREATE TABLE `people` (
  `id` INT NOT NULL AUTO_INCREMENT,
  `zipcode` VARCHAR(20) COLLATE utf8_bin DEFAULT NULL,
  `firstname` VARCHAR(20) COLLATE utf8_bin DEFAULT NULL,
  `lastname` VARCHAR(20) COLLATE utf8_bin DEFAULT NULL,
  `address` VARCHAR(50) COLLATE utf8_bin DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `zip_last_first` (`zipcode`, `lastname`, `firstname`)
) ENGINE=InnoDB AUTO_INCREMENT=5 DEFAULT CHARSET=utf8mb3 COLLATE=utf8_bin;
```

插入示例数据：

```sql
INSERT INTO `people` VALUES
(1, '000001', '三', '张', '北京市'),
(2, '000002', '四', '李', '南京市'),
(3, '000003', '五', '王', '上海市'),
(4, '000001', '六', '赵', '天津市');
```

示例查询：

```sql
SELECT * FROM people
WHERE zipcode = '000001'
  AND lastname LIKE '%张%'
  AND address LIKE '%北京市%';
```

解释：如果执行 EXPLAIN 时 Extra 列显示 `Using index condition`，表示使用了索引下推。注意 `address LIKE '%北京市%'` 不是索引列，仍需在 server 层做额外过滤；但通过在存储引擎层先利用索引列（zipcode、lastname）进行过滤，能显著减少回表行数。

## 实际性能对比（测试思路）
为了观察差异，可以插入大量 zipcode='000001' 的数据，使得在存储引擎层做过滤的效果更明显。示例的存储过程用于插入大量数据：

```sql
DELIMITER //

CREATE PROCEDURE insert_people(max_num INT)
BEGIN
  DECLARE i INT DEFAULT 0;
  SET autocommit = 0;
  REPEAT
    SET i = i + 1;
    INSERT INTO people (zipcode, firstname, lastname, address) VALUES ('000001', '六', '赵', '天津市');
  UNTIL i = max_num
  END REPEAT;
  COMMIT;
END //

DELIMITER ;
```

调用示例：

```sql
CALL insert_people(1000000);
```

开启会话级 profiling（旧版本 MySQL 支持）并执行查询以比较使用 ICP 与不使用 ICP 的性能：

```sql
-- 查看 profiling 是否可用
SHOW VARIABLES LIKE 'profiling%';

-- 打开 profiling
SET profiling = 1;

-- 使用默认（通常为开启 ICP）
SELECT * FROM people WHERE zipcode = '000001' AND lastname LIKE '%张%';

-- 显式不使用 ICP（示例 hint，视 MySQL 版本支持情况）
SELECT /*+ no_icp(people) */ * FROM people WHERE zipcode = '000001' AND lastname LIKE '%张%';

-- 查看 profiling 结果
SHOW PROFILES\G
```

多次测试的结论通常是：使用 ICP 可以提高查询效率，尤其是在大数据量且能在存储引擎层筛掉大量不满足条件的索引条目时，效果更明显。

## 使用前后的成本差别
- 使用前：存储层会返回许多需要由 server 层 index filter 过滤掉的整行记录，导致额外的回表和 I/O。
- 使用后：存储层直接丢弃不满足 index filter 的索引记录，减少回表和数据传输，从而降低 I/O 和 server 层处理成本。

ICP 的效果取决于能在存储引擎层被筛掉的数据比例；若大多数候选索引条目最终会被过滤掉，ICP 的加速效果就显著。

## 小结
- ICP 是在存储引擎层对索引进行额外筛选的优化手段，主要目的是减少回表次数与 I/O。
- 适用于能够在二级索引上判断的条件（联合索引场景），对覆盖索引无效。
- 可以通过 optimizer_switch 控制开关，EXPLAIN 中的 `Using index condition` 表示启用了 ICP。
- 在大数据量场景下，合理利用 ICP（并配合合适的索引设计）能带来显著性能提升。

如果你对这篇文章有疑问或想深入讨论具体的查询优化案例，欢迎留言交流。