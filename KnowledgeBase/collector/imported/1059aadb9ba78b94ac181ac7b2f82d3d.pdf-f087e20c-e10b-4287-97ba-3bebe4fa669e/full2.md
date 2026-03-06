# EXPLAIN TYPE 列的 JOIN 常见场景详解（上）

作者：杨涛涛，爱可生技术专家

连载至此，相信读者们已经对一条 SQL 的优化步骤、执行计划等有了一个大概的了解。接下来对 MySQL 的执行计划输出进行详细解释，以便大家更深入地理解 EXPLAIN 的 type 列在 JOIN 场景下的含义。

从 MySQL 优化器的角度来看，所有的 SQL 都可以视为 JOIN 查询（单表检索可以看成过滤字段和主键做 JOIN 的一种特殊类型）。由于内容较多，本文分为上下两部分，本文为上篇，介绍常见的 type 类型：const、eq_ref、ref、range、index。本文示例中表结构为 t1，原来的自增主键改为联合主键 (f0,f1)，表记录数约为 10W 行。

示例表结构：
```sql
CREATE TABLE `t1` (
  `f0` int NOT NULL,
  `f1` int NOT NULL,
  `r1` int DEFAULT NULL,
  `r2` int DEFAULT NULL,
  `r3` int DEFAULT NULL,
  `log_date` date DEFAULT NULL,
  PRIMARY KEY (`f0`,`f1`)
) ENGINE=InnoDB;
```

## 第一，type 栏为 "const"

当 type 为 const 时，表示基于常量的最优扫描（排除索引性能因素，这种 SQL 一定最优）。例如：

SQL 1：
```sql
select * from t1 where f0=110 and f1 = 778;
```

执行计划示例：
```
debian-ytt1:ytt>desc select * from t1 where f0=110 and f1 = 778\G
*************************** 1. row ***************************
id: 1
select_type: SIMPLE
table: t1
partitions: NULL
type: const
possible_keys: PRIMARY
key: PRIMARY
key_len: 8
ref: const,const
rows: 1
filtered: 100.00
Extra: NULL

1 row in set, 1 warning (0.00 sec)
```

这里 type 为 const，ref 栏为 const,const，表明用主键进行精确常量匹配，一次性定位到唯一行。

## 第二，type 栏为 "eq_ref"

eq_ref 与 const 类似，也是优化比率靠前的类型，但用于两张真实表的 JOIN，且驱动表对被驱动表的检索键必须是主键或唯一索引的全部列。对于被驱动表，每次检索返回至多一行。

例如 SQL 2：
```sql
select * from t1 join t2 using(f0,f1);
```

对表 t1 的执行计划示例（只展示 t1）：
```
debian-ytt1:ytt>desc select * from t1 join t2 using(f0,f1)\G
...
*************************** 2. row ***************************
id: 1
select_type: SIMPLE
table: t1
partitions: NULL
type: eq_ref
possible_keys: PRIMARY
key: PRIMARY
key_len: 8
ref: ytt.t2.f0,ytt.t2.f1
rows: 1
filtered: 100.00
Extra: NULL

2 rows in set, 1 warning (0.00 sec)
```

这种场景在两表内联且联接键为两表主键时（无其他过滤条件）是最优的 JOIN 类型之一。

## 第三，type 栏为 "ref"

ref 与 eq_ref 类似，但 JOIN 键不是主键或唯一索引，而是非唯一索引或非唯一匹配的列。该场景通常性能不如 eq_ref，应尽量避免，或减少参与 JOIN 的记录数。

示例：将 JOIN 条件改为 r1，并对两表的 r1 建索引：

SQL 3：
```sql
select * from t1 a join t2 b using(r1);
```

对表 b 的执行计划示例（只展示被驱动表）：
```
debian-ytt1:ytt>desc select * from t1 a join t2 b using(r1)\G
...
*************************** 2. row ***************************
id: 1
select_type: SIMPLE
table: b
partitions: NULL
type: ref
possible_keys: idx_r1
key: idx_r1
key_len: 5
ref: ytt.a.r1
rows: 19838
filtered: 100.00
Extra: NULL

2 rows in set, 1 warning (0.01 sec)
```

这里 rows 值很大，说明每次用驱动表的 r1 去索引查找时会匹配很多行，整体性能较差。

## 第四，type 栏为 "range"

range 表示范围扫描（索引范围查找），与前面基于常量的类型不同，range 表示使用索引进行区间扫描。

SQL 4：
```sql
select * from t1 where f0 < 120;
```

执行计划示例：
```
debian-ytt1:ytt>desc select * from t1 where f0<120\G
*************************** 1. row ***************************
id: 1
select_type: SIMPLE
table: t1
partitions: NULL
type: range
possible_keys: PRIMARY
key: PRIMARY
key_len: 4
ref: NULL
rows: 93
filtered: 100.00
Extra: Using where

1 row in set, 1 warning (0.00 sec)
```

range 表示对主键进行范围扫描。某些特殊情况下（表数据分布特殊）可以把范围扫描优化为常量扫描。例如如果 f0<120 和 f0=110 的结果集合相同，则可以改写为：

SQL 5：
```sql
select * from t1 where f0=110;
```

执行计划示例（由 range 变为 ref/const）：
```
debian-ytt1:ytt>desc select * from t1 where f0=110\G
*************************** 1. row ***************************
id: 1
select_type: SIMPLE
table: t1
partitions: NULL
type: ref
possible_keys: PRIMARY
key: PRIMARY
key_len: 4
ref: const
rows: 93
filtered: 100.00
Extra: NULL

1 row in set, 1 warning (0.00 sec)
```

从执行计划并不总能直接看出整体性能差异，需结合实际执行成本。使用 EXPLAIN ANALYZE 对比 SQL 4 与 SQL 5 的执行成本：

SQL 4（范围查询）成本示例：
```
debian-ytt1:ytt>desc analyze select * from t1 where f0< 120\G
*************************** 1. row ***************************
EXPLAIN: -> Filter: (t1.f0 < 120) (cost=18.93 rows=93) (actual time=0.040..0.061 rows=93) 
-> Index range scan on t1 using PRIMARY (cost=18.93 rows=93) (actual time=0.038..0.047 rows=93

1 row in set (0.00 sec)
```

SQL 5（等值查询）成本示例：
```
debian-ytt1:ytt>desc analyze select * from t1 where f0=110\G
*************************** 1. row ***************************
EXPLAIN: -> Index lookup on t1 using PRIMARY (f0=110) (cost=9.62 rows=93) (actual time=0.065..0.087

1 row in set (0.00 sec)
```

对比可见，等值查询的成本更低，性能提升明显。

## 第五，type 栏为 "index"

index 表示覆盖索引扫描（也可理解为仅在索引上扫描），通常发生在查询列都包含在某个索引中，且不需要回表的场景；若没有过滤条件则可能是全索引扫描（相当于全表扫的一种形式）。

SQL 6：
```sql
select r1 from t1 limit 10;
```

如果可以使用覆盖索引 idx_r1，则执行计划示例：
```
debian-ytt1:ytt>desc select r1 from t1 limit 10 \G
*************************** 1. row ***************************
id: 1
select_type: SIMPLE
table: t1
partitions: NULL
type: index
possible_keys: NULL
key: idx_r1
key_len: 5
ref: NULL
rows: 106313
filtered: 100.00
Extra: Using index

1 row in set, 1 warning (0.00 sec)
```

注意：尽管 SQL 有 LIMIT 10，MySQL 在没有 ORDER BY 的情况下不知道按何种顺序提前终止，因此可能仍需扫描所有行（此处 rows 显示约为表的总行数）。若利用索引的有序性并加上 ORDER BY，可以提前终止扫描：

SQL 7：
```sql
select r1 from t1 order by r1 limit 10;
```

此时执行计划会显示 rows 为 10，表明可以利用索引预排序并提前终止：
```
debian-ytt1:ytt>explain select r1 from t1 order by r1 limit 10\G
*************************** 1. row ***************************
id: 1
select_type: SIMPLE
table: t1
partitions: NULL
type: index
possible_keys: NULL
key: idx_r1
key_len: 5
ref: NULL
rows: 10
filtered: 100.00
Extra: Using index

1 row in set, 1 warning (0.00 sec)
```

---

关于 EXPLAIN type 栏的 JOIN 常见场景（上篇）就到这里，下一篇将继续讲解其他 type 情况及 JOIN 的更深入优化策略，欢迎订阅后续内容。

关于 SQLE  
SQLE 是一款全方位的 SQL 质量管理平台，覆盖开发至生产环境的 SQL 审核和管理，支持主流的开源、商业和国产数据库，为开发和运维提供流程自动化能力，提升上线效率并提高数据质量。