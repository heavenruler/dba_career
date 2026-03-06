写了 5 年 SQL，才发现可以用 (a, b) > (x, y) 这种神仙写法！
java干货 java干货 2025年12月30日 07:30 天津 原创
关注我 们, 设为星标,每天7:30不见不散,每日java干货分享
java干货 赞 分享 推荐 写留言

你有一张日志表，主键是联合主键 。现在你需要查询“某个分类下的 (category_id, seq_id)
某个序列号” 之后 的所有记录。
普通青年的写法（逻辑噩梦）：
SELECT * FROM logs
WHERE category_id > 100
OR (category_id = 100 AND seq_id > 500 );
这种写法不仅难看，而且括号套括号，一旦字段变成 3 个（比如加上 ），逻辑复杂度 timestamp
呈指数级上升，写错概率极大。
文艺青年的写法（行比较）：
SELECT * FROM logs
WHERE (category_id, seq_id) > ( 100 , 500 );
优雅！极致的优雅！ 这种写法不仅代码短，而且语义清晰，MySQL 和 PostgreSQL 都完
美支持。
1. 核心原理：元组的“字典序”比较
所谓“行比较”，就是把多个字段打包成一个 元组 (Tuple) 进行比较。
数据库在比较 时，遵循的是 字典序 (Lexicographical Order) 规则，逻辑如 (A, B) > (X, Y)
下：
1. 先比第一位： 如果 ，则整个表达式为 True（直接结束，不看 B）。 A > X
2. 如果第一位相等： 如果 ，则继续比较第二位，判断 。 A = X B > Y
3. 如果第一位小于： 如果 ，则整个表达式为 False。 A < X
这和我们查英文字典的逻辑一模一样： 为什么排在 前面？先比 和 ； apple banana a b
为什么排在 前面？因为 , , 但 。 apple apricot a=a p=p p < r
2. 核心实战场景：高性能“游标分页” (Keyset Pagination)
这是行比较 价值最高 的场景，没有之一。
背景：
当表数据量达到千万级时，传统的 会导致数据库扫描 100 万行废 LIMIT 10 OFFSET 1000000
弃数据，性能极差。
我们通常推荐使用 “游标分页” (Seek Method) ，即记录上一页最后一条数据的排序值，下一页
从这里开始查。
痛点：
很多时候，单一字段（如 ）无法保证唯一性（可能有两条记录时间戳完全一样）。 create_time
所以我们通常用 组成的联合键来排序，确保唯一性。 (create_time, id)
传统写法 (痛苦面具)：
我们要查 (ID=888) 之后的数据： 2024-12-01 12:00:00
SELECT * FROM orders
WHERE create_time > '2024-12-01 12:00:00'
OR (create_time = '2024-12-01 12:00:00' AND id > 888 )
ORDER BY create_time, id
LIMIT 10 ;

行比较写法 (丝般顺滑)：
SELECT * FROM orders
WHERE (create_time, id) > ( '2024-12-01 12:00:00' , 888 )
ORDER BY create_time, id
LIMIT 10 ;
这一行代码，完美解决了“时间相同看 ID，时间不同看时间”的复杂逻辑。
3. 实战场景二：复合主键的批量查询 (IN 列表)
背景：
你有一张关联表 ，主键是 。 user_roles (user_id, role_id)
你需要批量删除或查询一批特定的用户-角色关系。
普通写法：
SELECT * FROM user_roles
WHERE (user_id = 1 AND role_id = 10 )
OR (user_id = 1 AND role_id = 20 )
OR (user_id = 2 AND role_id = 15 );
写 100 个这样的条件，SQL 解析器都要累哭了。
行比较写法：
SELECT * FROM user_roles
WHERE (user_id, role_id) IN (
( 1 , 10 ),
( 1 , 20 ),
( 2 , 15 )
);
清晰明了，且大多数数据库优化器能对这种语法进行优化。
4. 实战场景三：版本号/区间重叠检测
背景：
软件版本号通常由 组成，例如 。 (Major, Minor, Patch) 2.5.1
你想找出所有版本号高于 的记录。 2.5.1
行比较写法：
SELECT * FROM software_versions
WHERE (major, minor, patch) > ( 2 , 5 , 1 );
这比拼接字符串 或者复杂的 逻辑要靠谱得多（字符串比较 CONCAT(major, '.', minor...) OR
会有 '10' < '2' 的陷阱，而数字元组比较不会）。
5. 注意事项与索引优化
虽好用，但有坑，特别是 索引 。

1. 索引利用 (MySQL 5.7+)：
在 MySQL 5.7 之前， 这种写法 无法利用 的联合索引，会导致全表扫描。 (a, b) > (x, y) (a, b)
但在 MySQL 5.7 及 8.0+ 中，优化器已经足够智能，可以完美利用联合索引进行 Range Scan。
2. 方向一致性：
如果你的联合索引是 ，那么 可以走索引。 (a ASC, b ASC) (a, b) > (x, y)
但如果你的查询逻辑非常怪异，比如 ，这就不能用行比较简写了。 a > x AND b < y
3. NULL 值陷阱：
如果字段中包含 ，行比较的结果可能是 。在用于主键或非空列（如分页场景）时最 NULL UNKNOWN
安全。
6. 总结
行比较 (Row Comparison) 是 SQL 语言中被严重低估的“语法糖”。
• 它将复杂的布尔逻辑转化为直观的 数学元组对比 。
• 它是实现 高性能深度分页 的最佳拍档。
• 它让你的 SQL 代码看起来更像资深工程师的手笔。
下次遇到多字段联合比较时，试试 ，你会爱上这种简洁。 (a, b) > (x, y)
推荐阅读 点击标题可跳转
50个Java代码示例：全面掌握Lambda表达式与Stream API
16 个 Java 代码“痛点”大改造：“一般写法” VS “高级写法”终极对决，看完代码质量飙升！
为什么高级 Java 开发工程师喜爱用策略模式
精选Java代码片段：覆盖10个常见编程场景的更优写法
提升Java代码可靠性：5个异常处理最佳实践
为什么大佬的代码中几乎看不到 if-else，因为他们都用这个...
还在 Service 里疯狂注入其他 Service？你早就该用 Spring 的事件机制了
看完本文有收获？请转发分享给更多人
关注「java干货」加星标，提升java技能
❤️ 给个 「推荐 」 ，是最大的支持❤️

Page 5
罠 了 5 年 SQL ， 才 爬 現 可 以 用 (a， b﹚ ﹥ (x﹢ y﹚ 玆 种 神 仙 亙 法 !
https﹕//mp﹒weixin﹒qq﹒com/s/aVlUDXmp7XV0U46EH﹣cQvw
Captured by FireShot Pro﹕ 16 1 月 2026， 11﹕13﹕09
https﹕//getfireshot﹒com

