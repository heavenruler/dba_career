SQL优化——我是如何将SQL执⾏性能提升10倍的
本⽂通过记录⼀条 SQL 语句的性能优化过程，介绍 MySQL 中 SQL 语句优化的⼀般思路。
⼀、优化前
1. SQL 语句及其执⾏时⻓
问题 SQL 语句查询需要 6s
⼆、优化思路
1. explain查看执⾏计划
执⾏计划
执⾏计划解读 ( 逐⾏ )
• 存储引擎全量读取了表b(type=ALL) ，预估会读取 8085 条数据 (rows=8085，依赖统计信息，非精确
值 ) ， MySQL 服务器对读取结果进⾏了过滤 (Extra=Using where，where条件b.taxdelaytype = '1') ，
预计过滤后还剩 10%(filtered=10) 。
2025年01⽉17⽇ 19:54 ⼴东原创Triagen Ti 笔记
2025/6/4 凌晨 12:25 SQL 优化 —— 我是如何将 SQL 执⾏性能提升 10 倍的
https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw 1/5

• 存储引擎通过索引读取了表a，对于每个where条件值，可能找到多条符合条件的记录 (type=ref) ，使
⽤的索引为idx_pfi_tc(key=idx_pfi_tc，possible_keys为候选的索引列表，key为通过统计信息计算
后选出的索引 ) ，索引过滤相关的条件列为info.b.ofcode(ref=info.b.ofcode) ，并且使⽤了索引下推[1]
(Extra=Using index condition) 。
• 存储引擎全量读取了表<derived2>，这⾥的<derived2>并非真实表，其代表的是执⾏计划最后⼀⾏查
询出来的临时表 (select_type=DERIVED,id=2) ， MySQL 服务器在执⾏left join的过程中，使⽤了
Block Nested-Loop Join[2](Extra=Using join buffer (Block Nested Loop)) ，并对连接结果进⾏了过
滤 (Extra=Using where，on条件a.tradingcode = c.ofcode) 。
• 存储引擎通过索引idx_period读取表app_cmf_rank_screen(type=ref) ， MySQL 服务器在执⾏left join
的过程中，使⽤了Index Nested-Loop Join[3](Extra没有对连接进⾏说明，就是默认的Index Nested-
Loop Join) ，并对连接结果进⾏了过滤 (Extra=Using where，on条件a.tradingcode =
d.fund_code) 。
• 存储引擎通过索引un_MF_TimeLimit读取表e(type=ref) ， MySQL 服务器在连接后对结果进⾏了过滤
(Extra=Using where，on条件a.SecuID = e.SecuID AND e.startdate = ...) 。
• 存储引擎通过索引un_MF_TimeLimit读取表mf_timelimit(type=ref) ，并且使⽤了覆盖索引[4]
(Extra=Using index，因为索引un_MF_TimeLimit中包含startdate和SecuID) 。
• 存储引擎通过索引idx_ofcode_mgr读取表cmfmbasic(type=ref) ，并且同样使⽤了覆盖索引。
执⾏计划总结
从执⾏计划来看，初步怀疑是因为第三⾏的  Using join buffer (Block Nested Loop)  导致查询
效率低下，于是尝试通过调整join_buffer_size的⼤⼩进⾏优化，然⽽并没有效果，优化有点陷
入僵局了。
2. show warnings查看告警信息
show warnings 查看告警信息
告警信息解读
在执⾏了explain查看执⾏计划命令之后，可以通过show warnings查看相关的告警信息。
show warnings结果的第⼆和第三⾏显⽰，有索引没有被⽤上，通过告警⾥⾯的字段可知是表
app_cmf_rank_screen，⽽与其相关的表是a(pubfund_info)，两者通过条件a.tradingcode =
d.fund_code相关联 .
3. 告警信息确认
2025/6/4 凌晨 12:25 SQL 优化 —— 我是如何将 SQL 执⾏性能提升 10 倍的
https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw 2/5

select table_name,column_name,column_type,character_set_name,collation_name
from information_schema.columns
where table_schema ='info'
and table_name in ('app_cmf_rank_screen','pubfund_info')
and column_name in ('fund_code','tradingcode');
查看表的列属性
结果显⽰，我们两张表关联字段的排序规则确实是不⼀样的，表app_cmf_rank_screen是按
utf8mb4_general_ci排序，表pubfund_info是按utf8mb4_bin排序，所以导致有索引⽆法被使⽤。
三、优化后
两张表的排序规则统⼀为  utf8mb4_bin
语句性能优化到 0.7s
优化后的执⾏计划
2025/6/4 凌晨 12:25 SQL 优化 —— 我是如何将 SQL 执⾏性能提升 10 倍的
https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw 3/5

相比于优化前， SQL 语句执⾏执⾏时⻓从 6s 下降到 0.7s ，性能提升了 10 倍。从执⾏计划来看，表
app_cmf_rank_screen使⽤上了性能更好的主键索引，⼤⼤减少了存储引擎读取表app_cmf_rank_screen的数
据量。
四、总结
1. 表创建的时候，不要⾃⼰指定表或者字段的字符集和排序规则，使⽤数据库默认的全局规则就好。
2. 做 SQL 优化的时候，不⽤急于分析执⾏计划，可以explain后先show warnings查看告警信息，告警信
息⾥⼀般会有优化的思路。
引⽤链接
索引下推 : https://learn.lianglianglee.com/%e4%b8%93%e6%a0%8f/MySQL%e5%ae%9e%e6%88%9845%e8%ae%b2/
05%20%20%e6%b7%b1%e5%85%a5%e6%b5%85%e5%87%ba%e7%b4%a2%e5%bc%95%ef%bc%88%e4%b8%8b%e
f%bc%89.md
Block Nested-Loop Join: https://learn.lianglianglee.com/%e4%b8%93%e6%a0%8f/MySQL%e5%ae%9e%e6%88%984
5%e8%ae%b2/34%20%20%e5%88%b0%e5%ba%95%e5%8f%af%e4%b8%8d%e5%8f%af%e4%bb%a5%e4%bd%bf%e
7%94%a8join%ef%bc%9f.md
Index Nested-Loop Join: https://learn.lianglianglee.com/%e4%b8%93%e6%a0%8f/MySQL%e5%ae%9e%e6%88%984
5%e8%ae%b2/34%20%20%e5%88%b0%e5%ba%95%e5%8f%af%e4%b8%8d%e5%8f%af%e4%bb%a5%e4%bd%bf%e
7%94%a8join%ef%bc%9f.md
覆盖索引 : https://learn.lianglianglee.com/%e4%b8%93%e6%a0%8f/MySQL%e5%ae%9e%e6%88%9845%e8%ae%b2/
05%20%20%e6%b7%b1%e5%85%a5%e6%b5%85%e5%87%ba%e7%b4%a2%e5%bc%95%ef%bc%88%e4%b8%8b%e
f%bc%89.md
[ 1 ]
[ 2 ]
[ 3 ]
[ 4 ]
全⺠学霸
⼩游戏 卡牌 玩游戏
⼴告
请在微信客户端打开
2025/6/4 凌晨 12:25 SQL 优化 —— 我是如何将 SQL 执⾏性能提升 10 倍的
https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw 4/5

Triagen
喜欢作者
SQL性能优化1
MySQL17
2025/6/4 凌晨 12:25 SQL 优化 —— 我是如何将 SQL 执⾏性能提升 10 倍的
https://mp.weixin.qq.com/s/FDRczYdgZ5kMKU64yMB_fw 5/5

