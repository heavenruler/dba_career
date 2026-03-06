# 写了 5 年 SQL，才发现可以用 (a, b) > (x, y) 这种神仙写法！

作者：java干货 | 2025-12-30 07:30 | 天津

你有一张日志表，主键是联合主键。现在你需要查询某个分类下 (category_id, seq_id) 在某个序列号之后的所有记录。

普通青年的写法（逻辑噩梦）：
```sql
SELECT * FROM logs
WHERE category_id > 100
   OR (category_id = 100 AND seq_id > 500);
```
这种写法不仅难看，而且括号套括号，一旦字段变成 3 个（比如加上 timestamp），逻辑复杂度呈指数级上升，写错概率极大。

文艺青年的写法（行比较）：
```sql
SELECT * FROM logs
WHERE (category_id, seq_id) > (100, 500);
```
优雅！极致的优雅！这种写法不仅代码短，而且语义清晰，MySQL 和 PostgreSQL 都完美支持。

## 1. 核心原理：元组的“字典序”比较

所谓“行比较”，就是把多个字段打包成一个元组（Tuple）进行比较。数据库在比较时，遵循的是字典序（Lexicographical Order）规则，逻辑如下：

1. 先比第一位：如果 A > X，则整个表达式为 True（直接结束，不看 B）。
2. 如果第一位相等：则继续比较第二位，判断 B > Y。
3. 如果第一位小于：则整个表达式为 False。

这和查字典的逻辑一模一样：先比第一个字母，再比第二个字母，依此类推。

## 2. 核心实战场景：高性能“游标分页” (Keyset Pagination)

这是行比较价值最高的场景。

背景：当表数据量达到千万级时，传统的 LIMIT ... OFFSET 会导致数据库扫描大量废弃数据，性能极差。通常推荐使用“游标分页”（Seek Method），记录上一页最后一条数据的排序值，下一页从这里开始查。

痛点：很多时候，单一字段（如 create_time）无法保证唯一性（可能有多条记录时间戳相同）。所以通常用 (create_time, id) 组成的联合键来排序，确保唯一性。

传统写法（痛苦面具）：
```sql
-- 假设上一页最后一条记录是 (create_time='2024-12-01 12:00:00', id=888)
SELECT * FROM orders
WHERE create_time > '2024-12-01 12:00:00'
   OR (create_time = '2024-12-01 12:00:00' AND id > 888)
ORDER BY create_time, id
LIMIT 10;
```

行比较写法（丝般顺滑）：
```sql
SELECT * FROM orders
WHERE (create_time, id) > ('2024-12-01 12:00:00', 888)
ORDER BY create_time, id
LIMIT 10;
```
这一行代码，完美表达了“时间相同看 ID，时间不同看时间”的复杂逻辑。

## 3. 实战场景二：复合主键的批量查询 (IN 列表)

背景：有张关联表 user_roles，主键是 (user_id, role_id)。需要批量删除或查询一批特定的用户-角色关系。

普通写法：
```sql
SELECT * FROM user_roles
WHERE (user_id = 1 AND role_id = 10)
   OR (user_id = 1 AND role_id = 20)
   OR (user_id = 2 AND role_id = 15);
```
写 100 个这样的条件，SQL 很难阅读。

行比较写法：
```sql
SELECT * FROM user_roles
WHERE (user_id, role_id) IN (
  (1, 10),
  (1, 20),
  (2, 15)
);
```
清晰明了，且大多数数据库优化器能对这种语法进行优化。

## 4. 实战场景三：版本号/区间比较

背景：软件版本号通常由 (major, minor, patch) 组成，例如 2.5.1。想找出所有版本号高于 2.5.1 的记录。

行比较写法：
```sql
SELECT * FROM software_versions
WHERE (major, minor, patch) > (2, 5, 1);
```
这比拼接字符串（如 CONCAT(major, '.', minor, ...)）或复杂的 OR 逻辑要靠谱得多，避免出现 '10' < '2' 的字符串比较陷阱。

## 5. 注意事项与索引优化

虽好用，但有坑，特别是与索引相关：

1. 索引利用（MySQL 5.7+）：
   - 在早期 MySQL 版本中，这种写法可能无法充分利用联合索引，导致全表扫描。
   - 在 MySQL 5.7 及 8.0+ 中，优化器已经足够智能，可以利用联合索引进行 Range Scan。

2. 方向一致性：
   - 如果你的联合索引是 (a ASC, b ASC)，那么 (a, b) > (x, y) 可以走索引。
   - 如果查询逻辑方向不一致（例如 a > x AND b < y），就无法用行比较简写并走索引。

3. NULL 值陷阱：
   - 如果字段可能包含 NULL，行比较的结果可能为 UNKNOWN。在用于主键或非空列（如分页场景）时最安全。

## 6. 总结

行比较（Row Comparison）是 SQL 中被低估的语法糖：

- 它将复杂的布尔逻辑转化为直观的元组比较。
- 它是实现高性能深度分页的最佳拍档。
- 它让 SQL 代码更简洁、更易读。

下次遇到多字段联合比较时，试试 (a, b) > (x, y)，你会爱上这种简洁。