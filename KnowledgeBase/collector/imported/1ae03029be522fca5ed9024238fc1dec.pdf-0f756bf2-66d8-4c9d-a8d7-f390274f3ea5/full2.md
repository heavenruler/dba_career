# Oracle 优化示例：索引小技巧——包含 NULL 值

Oracle 中索引默认不存储所有列都为 NULL 的行。因此当查询条件为 `col IS NULL` 时，即使索引看起来是最优解，Oracle 也可能执行全表扫描。下面介绍一个小技巧：通过在索引中增加一个常量列，使包含 NULL 值的行也能被索引，从而让查询走索引。

## 优化效果（示例）
- 优化前：访问行数 4461
- 优化后：访问行数 8
- 访问量减少：约 99.8%

## 测试案例

### 1. 创建测试表
- 使用 DBA_OBJECTS 或任意大表生成测试数据（示例大约 274,777 行）：

```sql
CREATE TABLE schema_name.tbl_test AS
  SELECT * FROM dba_objects;

SELECT COUNT(1) FROM schema_name.tbl_test;
-- 结果示例：274777
```

### 2. 查询 NULL 值（原始查询）
```sql
SELECT owner, object_name
FROM schema_name.tbl_test
WHERE object_id IS NULL;
```
- 假设返回 25 行。

示例执行计划（未命中索引，做全表扫描）：
```
| Id | Operation           | Name        | Starts | E-Rows | A-Rows | A-Time       |
|----|---------------------|-------------|--------|--------|--------|--------------|
|    | SELECT STATEMENT     |             | 1      |        | 25     | 00:00:00.26  |
|  1 | TABLE ACCESS FULL    | TBL_TEST    | 1      | 50     | 25     | 00:00:00.20  |
     filter("OBJECT_ID" IS NULL)
```

问题：执行的是全表扫描，遇到较大表时成本很高（示例访问 4461 行）。

### 3. 创建普通索引（不能索引全 NULL）
```sql
CREATE INDEX schema_name.idx_object_id
  ON schema_name.tbl_test(object_id);
```
再次执行相同查询，执行计划仍为全表扫描：
```
| Id | Operation           | Name        | Starts | E-Rows | A-Rows | A-Time       |
|    | SELECT STATEMENT     |             | 1      |        | 25     | 00:00:00.03  |
|  1 | TABLE ACCESS FULL    | TBL_TEST    | 1      | 50     | 25     | 00:00:00.03  |
     filter("OBJECT_ID" IS NULL)
```
原因：普通索引不包含所有列均为 NULL 的行，因此查询 `object_id IS NULL` 不能利用该索引。

### 4. 建存有 NULL 的索引（在索引中加入常量列）
通过在索引中增加一个常量列（例如 0），可以避免索引键列全为 NULL，从而使这些行被收录到索引中：

```sql
CREATE INDEX schema_name.idx_object_id_with_null
  ON schema_name.tbl_test(object_id, 0);
```

再次执行相同查询，执行计划示例：
```
| Id | Operation                        | Name                         | Starts | E-Rows | A-Rows |
|----|----------------------------------|------------------------------|--------|--------|--------|
|    | SELECT STATEMENT                 |                              | 1      |        | 25     |
|  1 | TABLE ACCESS BY INDEX ROWID      | TBL_TEST                     | 1      | 50     | 25     |
|  2 |  INDEX RANGE SCAN                | IDX_OBJECT_ID_WITH_NULL      | 1      | 14614  | 8      |
     access("OBJECT_ID" IS NULL)
```
结果：查询使用了索引，访问行数从 4461 降到 8，性能显著提升。

## 结论
- Oracle 索引默认不会保存所有索引列均为 NULL 的行。
- 在索引中增加一个常量列（例如 0）可以使包含 NULL 值的行被索引，从而让原本的 `IS NULL` 查询走索引，避免全表扫描。
- 此技巧适用于结果集较小且查询包含 `IS NULL` 或 `IS NOT NULL` 的场景。

## 核心原理
- Oracle 索引不存储完全为 NULL 的索引键。
- 在索引中添加一个恒定值列（常量列），即使主列为 NULL，索引键也不是全 NULL，因此该行会被索引。
- 查询不变即可使用索引，避免全表扫描。

## 使用场景建议
- 查询条件包含 `IS NULL` 或 `IS NOT NULL`。
- 查询返回结果集较小，适合走索引而不是全表扫描。
- 注意维护索引开销与查询频率的平衡。

## 测试脚本（示例）
```sql
ALTER SESSION SET STATISTICS_LEVEL = ALL;

DROP TABLE schema_name.tbl_test PURGE;

CREATE TABLE schema_name.tbl_test AS
  SELECT * FROM dba_objects;

SELECT owner, object_name
FROM schema_name.tbl_test
WHERE object_id IS NULL;

-- 普通索引
CREATE INDEX schema_name.idx_object_id
  ON schema_name.tbl_test(object_id);

-- 包含常量的索引（使 NULL 值也被索引）
CREATE INDEX schema_name.idx_object_id_with_null
  ON schema_name.tbl_test(object_id, 0);
```

备注：某些 Oracle 版本/配置下，对表达式或常量列建索引可能有差异。可以根据实际环境选择等效的做法（例如基于函数的索引或虚拟列索引）来达到包含 NULL 值行的目的。