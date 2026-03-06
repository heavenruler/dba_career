超爱吃士力架
从MySQL索引下推看性能优化：减少回表，提升查询 东汉末年去搬砖
作者榜No.12 人气作者
效率 60 17k 181
文章 阅读 粉丝
超爱吃士力架 2024-11-30 834 阅读7分钟 专栏： MySQL篇
关注 私信
复制 重新生成 智能总结
目录 收起
文章主要介绍了 MySQL 索引下推技术，包括其定义、作用（减少回表操作提高查询效率）、适用情况（联合索引
等）、开启关闭方式、使用案例、性能对比、扫描过程和使用条件等，最后鼓励交流学习和分享。
索引下推
实战 关联问题: ICP适用于哪些引擎 如何确定ICP效果 怎样设置ICP默认
1.1 使用前后对比
1.2 ICP的开启/关闭
1.3ICP使用案例
接着上篇 索引优化全攻略：提升排序、GROUP BY与分页性能 今天我们学习索引下推 1.4开启和关闭ICP的性能对比
1.5 使用前后的扫描过程
索引下推 1.6 ICP的使用条件
交流学习
索引下推（Index Condition Pushdown，简称 ICP）是一种提高查询效率、减少回表操作的技术。它允许
MySQL 在使用联合索引查找数据时，将部分查询条件“下推”到存储引擎层进行过滤。这样可以减少从表中 相关推荐
读取的数据行，降低 I/O 操作的开销，从而提高查询性能。需要注意的是，索引下推仅适用于联合索引，且
它通过将本应由服务器层处理的操作交给存储引擎来执行，从而实现性能优化。 什么是分布式追踪？它是如何工作的？
1.2k阅读 · 19点赞
通俗一点就是通过二级索引査到主键id后回表完再进行where条件过滤 改为 =>二级索引査到数据后直接
【Java面试经典】说说Runnable与Callable的区别 where过滤一遍再进行回表来减少回表的次数
112阅读 · 1点赞
[译]如何设计分布式锁
实战 67阅读 · 2点赞
面试：MySQL优化--索引、SQL
159阅读 · 5点赞 1.1 使用前后对比
反向 Debug 了解一下？揭秘 Java DEBUG 的基本原理
Index Condition Pushdown( ICP )是MySQL 5.6中新特性，是一种在存储引擎层使用索引过滤数据的一种优 504阅读 · 5点赞
化方式。
精选内容 如果没有ICP，存储引擎会遍历索引以定位基表中的行，并将它们返回给MySQL服务器，由MySQL服务
器评估 后面的条件是否保留行。 WHERE
Discourse PostgreSQL 15 升级
启用ICP后，如果部分 条件可以仅使用索引中的列进行筛选，则MySQL服务器会把这部分 WHERE WHERE honeymoose · 27阅读 · 0点赞
条件放到存储引擎筛选。然后，存储引擎通过使用索引条目来筛选数据，并且只有在满足这一条件时才 Laravel11 博客1--使用Laravel Jetstream | 多用户和管理员登录
从表中读取行。 一个人的程序 · 37阅读 · 0点赞
Apache Kafka 消息清理之道 好处: ICP可以减少存储引擎必须访问基表的次数和MySQL服务器必须访问存储引擎的次数。
AutoMQ · 27阅读 · 0点赞
但是，ICP的 取决于在存储引擎内通过 掉的数据的比例。 加速效果 ICP筛选
必知必会之数据库规约
小杨404 · 48阅读 · 1点赞 30多款 IntelliJ IDEA 必备插件：让你笑着提升开发效率!
拒绝繁忙！免费使用 deepseek-r1:671B 参数满血模型
例子： 程序猿DD · 1.6k阅读 · 12点赞
key 有索引
找对属于你的技术圈子 EXPLAIN SELECT *FROM s WHERE key>'z'AND key LIKE '%a';
回复「进群」加入官方微信群

这里条件like '%a' 其实可以在索引里面，算出来哪些符合条件。。。。过滤出符合条件的，再回表。这
样回表的数据可以减少很多。还有一个好处，没有索引下推，就需要把数据都回表查出来，，这些数
据可能在不同的页当中，又会产生IO
条件下推，下推到下一个条件符不符合。
1.2 ICP的开启/关闭
默认情况下启用索引条件下推。可以通过设置系统变量 控 optimizer_switch
制: index_condition_pushdown
ini 代码解读 复制代码
#关闭索引下推
SET optimizer_switch = 'index_condition_pushdown=off ' ;
#打开索引下推
SET optimizer_switch = 'index_condition_pushdown=on ' ;
当使用索引条件下推时， 语句输出结果中Extra列内容显示为 。 EXPLAIN Using index condition
1.3ICP使用案例
建表
sql 代码解读 复制代码
CREATE TABLE `people` (
`id` INT NOT NULL AUTO_INCREMENT,
`zipcode` VARCHAR ( 20 ) COLLATE utf8_bin DEFAULT NULL ,
`firstname` varchar ( 20 ) COLLATE utf8_bin DEFAULT NULL ,
`lastname` varchar ( 20 ) COLLATE utf8_bin DEFAULT NULL ,
`address` varchar ( 50 ) COLLATE utf8_bin DEFAULT NULL ,
PRIMARY KEY ( `id`),
KEY `zip_last_first`( `zipcode` , `lastname`, `firstname`)
)ENGINE = InnoDB AUTO_INCREMENT = 5 DEFAULT CHARSET = utf8mb3 COLLATE = utf8_bin;
插入数据
sql 代码解读 复制代码
INSERT INTO `people` VALUES
( '1' , '000001' , '三' , '张' , '北京市' ),
( '2' , '000002 ' , '四' , '李' , '南京市' ),
( '3' , '000003' , '五' , '王' , '上海市' ),
( '4 ' , '000001' , '六' , '赵' , '天津市' );
为该表定义联合索引zip_last_first (zipcode，lastname，firstname)。如果我们知道了一个人的邮编，但是
不确定这个人的姓氏，我们可以进行如下检索:
sql 代码解读 复制代码
SELECT * FROM people
WHERE zipcode = '000001'
AND lastname LIKE '%张%'
AND address LIKE '%北京市%' ;
执行查看SQL的查询计划，Extra中显示了 ，这表示使用了索引下推。另外， Using index condition
表示条件中包含需要过滤的非索引列的数据，即address LIKE '%北京市%'这个条件并不是索 Usingwhere
引列，需要在服务端过滤掉。
1.4开启和关闭ICP的性能对比
创建存储过程，主要目的就是插入很多000001的数据，这样查询的时候为了在存储引擎层做过滤，减少
IO，也为了减少缓冲池（缓存数据页，没有IO）的作用。
sql 代码解读 复制代码
DELIMITER / /
CREATE PROCEDURE insert_people( max_num INT )
BEGIN
DECLARE i INT DEFAULT 0 ;
SET autocommit = 0 ;
REPEAT
SET i = i + 1 ;
INSERT INTo people ( zipcode, firstname , lastname , address ) VALUES ( '000001' , '六' , '赵' , '天津市'
UNTIL i = max_num
END REPEAT;
COMMIT ;
END / /
DELIMITER ;

调用存储过程
scss 代码解读 复制代码
call insert_people ( 1000000 );
首先打开 。 profiling
sql 代码解读 复制代码
#查看
mysql > show variables like 'profiling%' ;
+ ------------------------+-------+
| Variable_name | Value |
+ ------------------------+-------+
| profiling | OFF |
| profiling_history_size | 15 |
+ ------------------------+-------+
ini 代码解读 复制代码
set profiling = 1 ;
执行SQL语句，此时默认打开索引下推。
sql 代码解读 复制代码
SELECT * FROM people WHERE zipcode = '000001' AND lastname LIKE '%张%' ;
再次执行sQL语句，不使用索引下推
sql 代码解读 复制代码
SELECT /*+ no_icp (people) */ * FROM people WHERE zipcode = '000001' AND lastname LIKE '%张%' ;
查看当前会话所产生的所有profiles
ini 代码解读 复制代码
show profiles\G ;
结果如下。
多次测试效率对比来看，使用ICP优化的查询效率会好一些。这里建议多存储一些数据效果更明显。
1.5 使用前后的扫描过程
在不使用ICP索引扫描的过程：

storage层：只将满足index key条件的索引记录对应的整行记录取出，返回给server层
server 层：对返回的数据，使用后面的where条件过滤，直至返回最后一行。
使用ICP扫描的过程： storage层： 首先将index key条件满足的索引记录区间确定，然后在索引上使用index
filter进行过滤。将满足的index filter条件的索引记录才去回表取出整行记录返回server层。不满足index
filter条件的索引记录丢弃，不回 表、也不会返回server层。 server 层： 对返回的数据，使用table filter条
件做最后的过滤。

使用前后的成本差别 使用前，存储层多返回了需要被index filter过滤掉的整行记录 使用ICP后，直接就去掉
了不满足index filter条件的记录，省去了他们回表和传递到server层的成本。 ICP的 加速效果 取决于在存储
引擎内通过 ICP筛选 掉的数据的比例。
1.6 ICP的使用条件
如果表访问的类型为range、ref、eq_ref和ref_or_null可以使用ICP
ICP可以用于 和 表，包括分区表 和 表 InnoDB MyISAM InnoDB MyISAM
对于 表， 仅用于二级索引。ICP的目标是减少全行读取次数，从而减少I/o操作。 InnoDB ICP
当SQL使用覆盖索引时，不支持ICP。因为这种情况下使用ICP不会减少I/O。
索引覆盖不能使用，一个原因是，索引覆盖，不需要回表。。ICP作用是减小回表，ICP需要回表
相关子查询的条件不能使用ICP
交流学习
最后，如果这篇文章对你有所启发，请帮忙转发给更多的朋友，让更多人受益！如果你有任何疑问或想法，
欢迎随时留言与我讨论，我们一起学习、共同进步。别忘了关注我，我将持续分享更多有趣且实用的技术文
章，期待与你的交流！
标签： 后端 MySQL Java 话题： 每天一个知识点
本文收录于以下专栏
MySQL篇 专栏目录
订阅 学习过程中的笔记
· 5 订阅 18 篇文章
索引优化全攻略：提升排序、GROUP BY与分页性能 高手都在用的数据库优化套路，你掌握了吗？ 上一篇 下一篇

评论 6
登录 / 注册 即可发布评论！
0 / 1000 发送
最热 最新
超级爽朗的郑 可控核聚变高级研发专家 @成都可控核聚变研究院
这里描述有点问题：on是开启，off是关闭
1月前 点赞 1
超爱吃士力架 : 好的，谢谢 作者
1月前 点赞 回复
醯大年年
2月前 点赞 评论
嗨肥肠煎蛋
好
2月前 点赞 评论
查看全部 6 条评论
为你推荐
你真的了解索引吗（下）？|mysql 系列（7）
小汪哥写代码 3年前 400 2 评论 MySQL 后端
MySQL高级进阶：索引优化
智多星云 1年前 311 1 1 后端
MySQL索引优化策略
Serena 11月前 329 4 2 后端 数据库 MySQL
MySQL索引下推
爱码士1024 8月前 205 1 评论 MySQL
MySql底层索引与数据优化【下篇】
小小de海绵 3年前 4.3k 14 5 MySQL
MySQL 索引深入解析及优化策略
仰望星空下的自己 1年前 232 2 评论 后端
Mysql索引的简单优化一
Caixr 3年前 251 点赞 评论 数据库
关于MySQL索引知识与小妙招 — 学到了！
牧小农 4年前 228 2 评论 数据库
Mysql进阶之索引优化
孤居自傲 1年前 1.4k 7 1 后端 Java
MySQL索引
李昂的数字之旅 1年前 188 1 评论 MySQL
图解MySQL索引下推
程序员大彬 2年前 1.6k 10 评论 后端 MySQL
MySQL 索引优化实践
心城以北 3年前 1.4k 36 评论 后端 MySQL
MySQL索引常见问题
终有救赎 1年前 697 10 4 后端 面试 数据库
MySQL进阶学习（二）----索引
鸦鸦世界第一爱吃蛙 1年前 1.4k 6 评论 MySQL SQL
MySQL查询优化必备
原来是咔咔 3年前 884 12 评论 MySQL

