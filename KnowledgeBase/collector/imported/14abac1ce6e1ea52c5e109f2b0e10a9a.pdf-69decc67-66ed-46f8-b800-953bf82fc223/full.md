MySQL查询优化的三种处理阶段：Index Key、Index Filter 和
Table Filter
二师兄 师兄奇谈 2025年9月28日 20:36 北京 原创
在 MySQL 中，索引主要用于优化查询。在 MySQL 查询优化中涉及到三种处理阶段： 师兄奇谈 Index Ke 赞 分享 推荐 写留言
、 和 。 y Index Filter Table Filter
它们描述的是数据库在使用索引时，查询条件的匹配和过滤发生的过程，这个分类的背景通常出现
在讨论索引下推（Index Condition Pushdown, ICP）时。
关于索引下推可参考我们前面写的这篇文章：《 什么是MySQL的索引下推技术？ 》
以下是对这三种索引处理阶段的详细说明：
1. Index Key
定义：索引键 (Index Key) 是指索引的关键列，即索引中存储的字段值。索引键是用来帮助定位数
据行的，查询通常首先使用索引键来筛选匹配最基础条件的记录。
使用场景 ：
当查询条件和索引的定义一致时，例如：
SELECT * FROM employees WHERE employee_id = 123 ;
如果 有索引，数据库可以通过索引键快速找到符合条件的记录。 employee_id
特性 ：

这是索引的基本功能，通过索引键直接定位满足条件的记录。
索引键检索的是精确匹配或者范围扫描的记录。
查询执行流程 ：
通过索引键快速定位对应的记录集合。
2. Index Filter
定义：索引过滤 (Index Filter) 是对索引存储的数据进行进一步过滤，用于实现更复杂的查询条
件，而无需先通过索引定位所有数据然后回表。索引过滤是在存储引擎层完成的， 是索引下推优化
的关键部分 。
使用场景 ：
查询条件涉及多个字段，但不是全部字段都能通过索引键直接定位。例如：
SELECT * FROM employees WHERE employee_id > 100 AND salary < 50000 ;
假设有索引 ： (employee_id, salary)
数据库通过 定位部分范围的记录； employee_id > 100
然后在存储层通过 进一步过滤索引中的记录，而不是直接将所有匹配 salary < 50000 emp
的记录返回到 Server 层。 loyee_id > 100
特性 ：
索引过滤是对索引本身存储的数据进行字段值筛选，而不是直接访问表。
索引下推优化后，在存储引擎层完成这部分过滤，提高了查询效率。
查询执行流程 ：
基于索引键定位候选记录。
在存储层进一步筛选索引中的记录，减少上层（Server Layer）需要处理的数据量。
3. Table Filter
定义：表过滤 (Table Filter) 是指数据库通过回表查询数据后，再对返回的表中数据进行过滤。这
通常是针对查询条件中涉及的 非索引列 ，或者索引本身无法过滤的情况。
使用场景 ：
查询条件涉及非索引字段，例如：
SELECT * FROM employees WHERE employee_id > 100 AND department = 'Engineering' ;
假设只有索引 ： (employee_id)
数据库通过索引范围查询 ； employee_id > 100
获取记录后，需要回表读取 列，并在 Server 层过滤 department department = 'Enginee
的条件。 ring'
特性 ：
表过滤发生在 Server 层（服务层），需要通过索引定位记录后，回表查询原始记录再进行过
滤。

如果查询条件中非索引列过多，或者数据量较大，表过滤会带来性能开销。
查询执行流程 ：
基于索引键定位候选记录。
回表查询原始数据。
在 Server 层对数据进行过滤，符合条件的记录才会返回给用户。
三类过滤物理过程
Index Key 初始阶段，通过索引键快速定位候选记录。
Index Filter 在存储引擎层上对候选记录进行进一步过滤，减少需要回表的记录数。
Table Filter 如果查询涉及非索引列或更复杂的过滤条件，需要回表查询，并在服务器层最终
过滤。
索引下推重要点
MySQL 5.6 之前，一旦记录在索引 Key 查找到，所有复杂条件的过滤都在 Server 层完成
（包括非下推的 Index Filter 和 Table Filter）。
MySQL 5.6 开始支持索引下推 (ICP)，将部分过滤逻辑 (Index Filter) 下推到存储引擎层，并
在回表查询之前完成过滤，显著减少了回表次数和 Server 层的压力。
示例
假设有一个包含索引 的表，查询如下： (employee_id, salary)
SELECT * FROM employees WHERE employee_id > 100 AND salary < 50000 AND department = 'Engineering'
Index Key : 索引通过 进行范围扫描，获取候选记录。 employee_id > 100
Index Filter（索引下推实现） : 在存储层进一步通过 过滤出满足条件的记 salary < 50000
录，减少回表的次数。
Table Filter : 回表查询后，对 的条件进行过滤，最终返回结 department = 'Engineering'
果。
小结
索引下推利用了 Index Filter 在存储层完成过滤的能力，减少了回表次数和 Server 层处理数据的
压力，从而优化了查询性能。在实际使用索引时，通过合理的覆盖索引设计，可进一步减少回表，
提高效率。
全文完，感谢阅读，如果喜欢请三连。
近期精选文章 ：
MySQL中的数据去重，该用DISTINCT还是GROUP BY？
MySQL的两种分页方式：Offset/Limit分页和游标分页
为什么MySQL索引不生效？来看看这8个原因
什么是MySQL的索引下推技术？
学习中的飞轮效应：如何快速学习一门知识？

▲ ”师兄奇谈 “：职场&生活&自我提升
个人书籍： 《Spring Boot技术内幕》&& 《Drools 8规则引擎》
微信号：541075754
师兄奇谈
一个专注职场、职业成长、团队管理以及自我成长的公众号。笔者为：《SpringBoot技术内幕》、《Drools
647篇原创内容
公众号
作者新书—— 《Drools 8规则引擎》：

MySQL · 目录
上一篇 下一篇
MySQL中的数据去重，该用DISTINCT还是 MySQL之进阶：一篇文章搞懂MySQL索引之
GROUP BY？ B+树

