# SQL优化实战：从慢如蜗牛到快如闪电的必杀技

作者：farerboy（小林聊编程）

为什么你的SQL总是“跑不动”？
根据 Oracle 官方数据，80%的数据库性能问题源自低效 SQL。一条全表扫描的耗时可能是索引查询的 100 倍以上。本文将从执行原理到实战技巧，手把手教你成为 SQL 调优高手。

## 一、核心优化原则：让索引为你打工

### 1. 避免索引失效的常见禁忌
- 字段计算陷阱：WHERE 子句中避免对索引字段进行运算
  ```sql
  -- 反例（会导致索引失效）
  WHERE salary/12 > 5000

  -- 正例
  WHERE salary > 5000 * 12
  ```
- 模糊查询黑洞：前导通配符导致索引失效
  ```sql
  -- 反例（前导通配符，无法使用索引）
  WHERE name LIKE '%张三%'

  -- 正例（避免前导通配符）
  WHERE name LIKE '张三%'
  ```
- 类型转换灾难：隐式类型转换让优化器迷茫
  ```sql
  -- 反例（id 为数值型，会发生隐式转换）
  WHERE id = '100'

  -- 正例
  WHERE id = 100
  ```

### 2. 索引设计的黄金法则
- 复合索引顺序：遵循最左前缀原则，高频查询字段放左侧。
- 覆盖索引妙用：SELECT 字段尽量包含在索引中，减少回表查询（避免额外的 I/O）。
- 索引数量控制：单表索引不宜过多（通常建议不超过 5 个），过多索引会显著影响写性能和维护成本。

## 二、实战技巧：改写 SQL 的智慧

### 1. 拒绝“无脑查询”
- 只取所需字段，减少数据传输量和列回表开销。
  ```sql
  -- 反例
  SELECT * FROM orders;

  -- 正例
  SELECT order_id, amount FROM orders;
  ```
- 使用 UNION ALL 替代 UNION：如果确定不需要去重，使用 UNION ALL 避免重复数据过滤的开销。

### 2. 复杂条件优化
- OR 条件拆分：复杂的 OR 有时会导致索引无法有效使用，可考虑拆分为多条查询再用 UNION ALL 合并，或使用 IN/EXISTS 视情况选择。
  ```sql
  -- 反例
  WHERE id = 1 OR id = 3

  -- 可替代
  SELECT ... FROM table WHERE id = 1
  UNION ALL
  SELECT ... FROM table WHERE id = 3
  ```
- EXISTS 妙用：当小表驱动大表时，使用 EXISTS/IN/半连接（取决于数据库优化器）通常能提升性能，避免大范围回表。

### 3. 批量操作的艺术
- 批量插入：一次提交多条记录显著快于逐条插入，建议根据事务和内存选择合适的批次（例如每次 500–2000 条）。
  ```sql
  INSERT INTO users (id, name) VALUES
  (1, '张三'), (2, '李四'), (3, '王五');
  ```
- 分页优化：避免使用深度偏移的 LIMIT（如 LIMIT 100000, 20），改用基于索引的范围查询（ID 范围或使用带排序键的 WHERE 条件）实现高效分页。

## 三、高阶武器：性能分析工具

### 1. EXPLAIN 执行计划解读
查看执行计划是优化的第一步，重点关注：
- type：如果为 ALL，表示全表扫描，尽量优化为 ref、range 等更优的访问类型。
- rows：估算扫描行数，越少越好。
- Extra：出现 Using filesort、Using temporary 等需警惕，说明可能存在排序或临时表开销。

### 2. 慢查询日志分析
- 开启慢查询日志（示例）：
  ```sql
  SET GLOBAL slow_query_log = ON;
  ```
- 分析工具：推荐使用 Percona Toolkit 中的 pt-query-digest 对慢查询日志进行整理和归类，找出最耗时的 SQL。

### 3. SHOW PROFILE 深度追踪（MySQL）
- 用于查看 SQL 各阶段耗时（注意：新版本 MySQL 已弃用 profiling，使用慢查询和性能模式代替）。
  ```sql
  SET profiling = 1;
  SELECT * FROM orders;
  SHOW PROFILES;
  SHOW PROFILE FOR QUERY 1;
  ```

## 四、避坑指南：这些“优化”可能是毒药
- 过度索引：索引维护成本可能超过查询收益，尤其是写密集型场景。
- 盲目并行：并行执行在高并发下可能引起资源争用，需基于实际负载评估。
- 游标滥用：对万行以上数据操作应优先考虑集合运算（批处理、批量更新）而非逐行游标处理。

## 文末福利
关注公众号并回复 “MySQL 数据库设计规范”，可领取《MySQL 数据库设计规范》。

如果有其它问题，欢迎在评论区沟通。