# SQL优化——我是如何将SQL执行性能提升10倍的

本文通过记录一条 SQL 语句的性能优化过程，介绍 MySQL 中 SQL 语句优化的一般思路。

作者：Triagen

## 一、优化前

1. SQL 语句及其执行时长  
   问题：该 SQL 查询需要 6s。

## 二、优化思路

### 1. explain 查看执行计划

执行计划解读（逐行）：

- 存储引擎全量读取了表 b (type=ALL)，预估会读取 8085 条数据 (rows=8085，依赖统计信息，非精确值)。MySQL 服务器对读取结果进行了过滤 (Extra=Using where，where 条件 b.taxdelaytype = '1')，预计过滤后还剩 10% (filtered=10)。
- 存储引擎通过索引读取了表 a，对每个 where 条件值，可能找到多条符合条件的记录 (type=ref)。使用的索引为 idx_pfi_tc (key=idx_pfi_tc，possible_keys 为候选索引列表，key 为选出的索引)。索引过滤相关的条件列为 info.b.ofcode (ref=info.b.ofcode)，并且使用了索引下推 (Extra=Using index condition)。
- 存储引擎全量读取了 <derived2>，这里的 <derived2> 并非真实表，其代表的是执行计划中生成的临时表 (select_type=DERIVED,id=2)。MySQL 在执行 left join 的过程中，使用了 Block Nested-Loop Join (Extra=Using join buffer (Block Nested Loop))，并对连接结果进行了过滤 (Extra=Using where，on 条件 a.tradingcode = c.ofcode)。
- 存储引擎通过索引 idx_period 读取表 app_cmf_rank_screen (type=ref)。MySQL 在执行 left join 的过程中，使用了 Index Nested-Loop Join（默认的 Index Nested-Loop Join），并对连接结果进行了过滤 (Extra=Using where，on 条件 a.tradingcode = d.fund_code)。
- 存储引擎通过索引 un_MF_TimeLimit 读取表 e (type=ref)，在连接后对结果进行了过滤 (Extra=Using where，on 条件 a.SecuID = e.SecuID AND e.startdate = ...)。
- 存储引擎通过索引 un_MF_TimeLimit 读取表 mf_timelimit (type=ref)，并且使用了覆盖索引 (Extra=Using index，因为索引 un_MF_TimeLimit 中包含 startdate 和 SecuID)。
- 存储引擎通过索引 idx_ofcode_mgr 读取表 cmfmbasic (type=ref)，并且同样使用了覆盖索引。

执行计划总结：  
从执行计划来看，初步怀疑是因为第三行的 Using join buffer (Block Nested Loop) 导致查询效率低下，于是尝试通过调整 join_buffer_size 的大小进行优化，然而并没有效果，优化一度陷入僵局。

### 2. show warnings 查看告警信息

在执行了 explain 查看执行计划之后，可以通过 show warnings 查看相关的告警信息。show warnings 的结果显示有索引没有被用上，通过告警里面的字段可知问题出现在表 app_cmf_rank_screen，而与其相关的表是 a (pubfund_info)，两者通过条件 a.tradingcode = d.fund_code 关联。

### 3. 告警信息确认

查看表的列属性的 SQL 如下：

```sql
select table_name, column_name, column_type, character_set_name, collation_name
from information_schema.columns
where table_schema = 'info'
  and table_name in ('app_cmf_rank_screen', 'pubfund_info')
  and column_name in ('fund_code', 'tradingcode');
```

结果显示，两张表关联字段的排序规则确实不一致：表 app_cmf_rank_screen 是按 utf8mb4_general_ci 排序，表 pubfund_info 是按 utf8mb4_bin 排序，导致索引无法被使用。

## 三、优化后

- 方案：将两张表的排序规则统一为 utf8mb4_bin。
- 优化结果：语句性能从 6s 优化到 0.7s，执行时间减少约 10 倍。
- 执行计划变化：表 app_cmf_rank_screen 使用上了更高效的主键/索引，显著减少了存储引擎读取该表的数据量。

## 四、总结

1. 建表时尽量不要单独为表或字段指定与数据库全局不一致的字符集或排序规则，使用数据库默认的全局规则可以避免关联时索引失效的问题。  
2. 做 SQL 优化时，不要急于只看执行计划；在 explain 之后先用 show warnings 查看告警信息，告警信息中通常会给出有价值的优化思路（例如索引未被使用、排序规则不匹配等）。

## 参考阅读

- 索引下推（Index Condition Pushdown）
- Block Nested-Loop Join
- Index Nested-Loop Join
- 覆盖索引（Covering Index）