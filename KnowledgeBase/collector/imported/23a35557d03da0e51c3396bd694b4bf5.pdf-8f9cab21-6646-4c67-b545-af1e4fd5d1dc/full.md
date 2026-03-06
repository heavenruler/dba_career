理解  MySQL 的分组机制： GROUP BY 、
SELECT 、 HAVING 及索引优化
Asthenian2025-03-30141阅读 5 分钟 关注
理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化
MySQL 的  GROUP BY  是  SQL 中⼀个核⼼功能，⽤于分组统计数据。你可能已经对它的基本⽤
法有所了解，但⼀些细节，⽐如  SELECT  中⾮聚合列的限制，或者  HAVING  的作⽤，可能还让
⼈困惑。今天我们不仅会拆解这些机制，还会深⼊探讨⼀个更实际的问题：在  HAVING  中使⽤
函数是否影响索引，以及如何优化。
⼀、GROUP BY  到底是怎么分组的？
简单来说，GROUP BY  按指定列的值将数据分成组，然后对每组应⽤聚合操作。就像整理⼀堆
学⽣成绩单，按班级分成⼏组，再计算每组的平均分。
示例表：学⽣成绩
假设有表  scores ：
体验 AI 代码助⼿
| student_id | class | score |
|------------|-------|-------|
| 1          | A     | 80    |
| 2          | A     | 90    |
| 3          | B     | 85    |
1
2
3
4
5
探 索 稀 ⼟ 掘 ⾦
登录⾸⻚
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 1/10

查询：
结果：
分组过程
1. 按  class  分组：数据分成  A 和  B 两组。
2. 聚合计算：对每组的  score  计算平均值。
3. 返回结果：每组⼀⾏，显示分组列和聚合结果。
⼆、为什么  SELECT  外的⾮聚合列必须分组？
如果查询写成：
在严格模式下会报错，因为  student_id  不是分组依据，也没有聚合函数处理。分组后每组只
有⼀⾏，但  student_id  在  A 组有多个值（ 1 、 2 、 5 ）， MySQL ⽆法决定显示哪个值。 SQL 标
准要求：SELECT  中⾮聚合列必须出现在  GROUP BY  中。
| 4          | B     | 95    |
| 5          | A     | 70    |
6
7
体验 AI 代码助⼿
SELECT class, AVG(score)
FROM scores
GROUP BY class;
1
2
3
体验 AI 代码助⼿
| class | AVG(score) |
|-------|------------|
| A     | 80         |
| B     | 90         |
1
2
3
4
体验 AI 代码助⼿
SELECT student_id, class, AVG(score)
FROM scores
GROUP BY class;
1
2
3
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 2/10

解决⽅法
⽤聚合函数：SELECT MAX(student_id), class, AVG(score) GROUP BY class;
调整分组：GROUP BY student_id, class; （但可能改变业务逻辑）。
三、HAVING  的作⽤及常⻅⽤法
HAVING  是分组后的条件过滤器。⽐如：
结果只显示平均分⼤于  85 的班级：
互联⽹场景⽤法
1. 活跃⽤户：
2. ⾼消费⽤户：
体验 AI 代码助⼿
SELECT class, AVG(score)
FROM scores
GROUP BY class
HAVING AVG(score) > 85;
1
2
3
4
体验 AI 代码助⼿
| class | AVG(score) |
|-------|------------|
| B     | 90         |
1
2
3
体验 AI 代码助⼿
SELECT user_id, COUNT(*) as login_count
FROM user_logins
GROUP BY user_id
HAVING COUNT(*) > 5;
1
2
3
4
体验 AI 代码助⼿
SELECT user_id, SUM(order_amount)
FROM orders
1
2
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 3/10

3. 异常检测：
四、HAVING  中使⽤函数会影响索引吗？
你可能注意到，上⾯例⼦中  HAVING  ⽤到了  COUNT(*)  或  SUM(order_amount)  这类聚合函
数。这引发了⼀个关键问题：在  HAVING  中使⽤函数会不会导致索引失效？
索引的影响
答案是：是的，HAVING  中的聚合函数通常⽆法直接利⽤索引。原因如下：
聚合是计算结果：COUNT 、SUM  等函数是对分组后的数据进⾏计算，索引只能加速数据的
查找和分组（GROUP BY  部分），但⽆法直接优化聚合结果的过滤。
执⾏顺序： MySQL 的查询执⾏顺序是  FROM  -> WHERE  -> GROUP BY  -> HAVING  ->
SELECT  -> ORDER BY 。HAVING  在分组和聚合之后执⾏，此时索引的作⽤已经局限于前
⾯的步骤（如  WHERE  过滤或  GROUP BY  排序）。
例如：
如果  order_date  有索引，WHERE  可以利⽤它快速过滤数据。
如果  user_id  有索引，GROUP BY  可能利⽤它加速分组。
但  HAVING SUM(order_amount) > 1000  是基于聚合结果的条件，⽆法直接⽤索引优化。
GROUP BY user_id
HAVING SUM(order_amount) > 1000;
3
4
体验 AI 代码助⼿
SELECT ip_address, COUNT(*)
FROM api_logs
GROUP BY ip_address
HAVING COUNT(*) > 1000;
1
2
3
4
体验 AI 代码助⼿
SELECT user_id, SUM(order_amount)
FROM orders
WHERE order_date > '2025-01-01'
GROUP BY user_id
HAVING SUM(order_amount) > 1000;
1
2
3
4
5
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 4/10

验证索引使⽤
可以⽤  EXPLAIN  检查：
结果中通常不会显示  HAVING  使⽤索引，因为它是后置过滤。
五、索引优化的解决策略
既然  HAVING  中的函数会导致性能瓶颈，从索引优化的⻆度，我们可以采取以下⽅法：
1. 提前过滤（⽤  WHERE  替代部分  HAVING ）
尽量把条件前移到  WHERE ，减少分组的数据量。⽐如：
WHERE login_time > '2025-01-01'  可以⽤  login_time  索引，减少扫描⾏数。
HAVING  只处理剩下的聚合结果。
2. 创建覆盖索引
为  GROUP BY  和  WHERE  涉及的列创建复合索引。例如：
体验 AI 代码助⼿
EXPLAIN SELECT user_id, SUM(order_amount)
FROM orders
GROUP BY user_id
HAVING SUM(order_amount) > 1000;
1
2
3
4
体验 AI 代码助⼿
SELECT user_id, COUNT(*) as login_count
FROM user_logins
WHERE login_time > '2025-01-01'
GROUP BY user_id
HAVING COUNT(*) > 5;
1
2
3
4
5
体验 AI 代码助⼿
CREATE INDEX idx_orders_user_date ON orders (user_id, order_date);
1
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 5/10

这可以加速  GROUP BY user_id  和  WHERE order_date > '2025-01-01' ，间接减少  HAVING
的负担。
3. 物化中间结果
对于复杂查询，可以⽤⼦查询或临时表先计算聚合结果，再过滤：
⼦查询先完成分组和聚合。
WHERE  替代  HAVING ，可能利⽤物化表的索引（如果数据库⽀持）。
4. 避免不必要的聚合
如果业务允许，可以简化查询逻辑。⽐如，如果只需要知道哪些⽤户消费超过  1000 ，不⼀定⾮
要⽤  SUM ：
这避免了分组和  HAVING ，直接⽤索引（如果  order_amount  有索引）。
5. 分区表或分⽚
在互联⽹场景下，数据量巨⼤时，可以按时间（如  order_date ）或  user_id  分区，分⽽治
之，减少单次查询的计算量。
六、总结
体验 AI 代码助⼿
SELECT user_id, total_amount
FROM (
SELECT user_id, SUM(order_amount) as total_amount
FROM orders
GROUP BY user_id
) AS temp
WHERE total_amount > 1000;
1
2
3
4
5
6
7
体验 AI 代码助⼿
SELECT DISTINCT user_id
FROM orders
WHERE order_amount > 1000;
1
2
3
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 6/10

标签： 后端
评论  0
暂⽆评论数据
本⽂收录于以下专栏
上⼀篇 SQL 执⾏顺序与 ON vs WHERE… 下⼀篇 如何为这条 sql 语句建⽴索引：…
MYSQL ⾯试
MYSQL ⾯试
12 订阅·66 篇⽂章
订阅
专栏⽬录
0/ 1000 发送
抢⾸评，友善交流
登录  / 注册 即可发布评论！
GROUP BY ：按列值分组，聚合统计。
SELECT  限制：⾮聚合列需在  GROUP BY  中，确保结果明确。
HAVING ：分组后过滤，常⽤于统计分析。
索引与  HAVING ：聚合函数⽆法直接⽤索引，但可以通过提前过滤、覆盖索引、物化结果等
优化。
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 7/10

⽬录 收起
理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化
⼀、 GROUP BY 到底是怎么分组的？
示例表：学⽣成绩
分组过程
⼆、为什么  SELECT 外的⾮聚合列必须分组？
解决⽅法
三、 HAVING 的作⽤及常⻅⽤法
互联⽹场景⽤法
四、 HAVING 中使⽤函数会影响索引吗？
索引的影响
验证索引使⽤
五、索引优化的解决策略
1. 提前过滤（⽤  WHERE 替代部分  HAVING ）
2. 创建覆盖索引
3. 物化中间结果
4. 避免不必要的聚合
5. 分区表或分⽚
六、总结
相关推荐
⼤数据学习（⼀）： HDFS
68 阅读 · 0 点赞
外企也半夜发布上线吗？
75 阅读 · 0 点赞
Java 源码  - 本地变量 ThreadLocal
47 阅读 · 0 点赞
使⽤ Spring Boot 对接印度股票数据源：实战指南
75 阅读 · 0 点赞
JVM 字节码详解
37 阅读·0 点赞
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 8/10

37 阅读  0 点赞
为你推荐
Mysql ：第 06 章 _DQL-Mysql 内置函数 -- 分组函数和分⻚查询
MySQL 后端花粥之间3 年前 5262 评论
MySQL 的聚合函数该如何使⽤？
MySQL 后端快乐⼤队⻓2 年前 1.3k 41
MySQL 索引怎么⽤？ 4 个点让你秒懂！
JavaJava ⼩叮当 4 年前 7947 评论
MySQL 中这些关键字的⽤法，佬们 get 到了嘛
后端⼩威要向诸佬学习呀1 年前 7613 评论
【 MySQL 】 MySQL 索引及调优
后端Kimizu01 年前 141 点赞 评论
SQL 优化 _ 优化分组
MySQL⼀只⼩码农正在路过4 年前 3272 评论
MySQL 索引（六）索引优化补充，分⻚查询、多表查询、统计查询
数据库 MySQL 搜索引擎鳄⻥⼉ 1 年前 4875 评论
简单易懂的 MySQL 覆盖索引、前缀索引、索引下推
MySQL_ 沸⽺⽺ _3 年前 2.7k 13 评论
Pandas DataFrame 实战分析：分组、合并、查询、索引与缺失值处理
后端Asthenian 26 天前 72 点赞 评论
MySQL ⾼级进阶：索引优化
后端智多星云1 年前 32611
MySQL | GROUP BY ⼦句使⽤详解
后端 MySQL SQLAndya 4 ⽉前 1651 评论
SQL 查询的执⾏顺序
数据库 MySQLemanjusaka 1 年前 3161 评论
《 MySQL 技术内幕 --InnoDB 存储引擎》笔记 -- 索引篇
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 9/10

MySQL云⾥有个⽪⽪4 年前 76772
MySQL 索引深⼊解析及优化策略
后端仰望星空下的⾃⼰2 年前 2992 评论
深⼊  MySQL 索引：从数据结构到具体使⽤
MySQL 后端LBXX3 年前 1.1k 5 评论
2025/6/4 凌晨 12:06 理解  MySQL 的分组机制： GROUP BY 、 SELECT 、 HAVING 及索引优化理解  MySQL 的分组机制： GR - 掘⾦
https://juejin.cn/post/7487071171194896395 10/10

