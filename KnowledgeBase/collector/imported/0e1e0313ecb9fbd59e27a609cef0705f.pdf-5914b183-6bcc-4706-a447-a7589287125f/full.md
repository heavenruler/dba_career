青石路
MySQL的默认隔离级别为什么是RR，而不是RC java工程师
榜上有名
青石路 2024-10-08 358 阅读10分钟 专栏： MySQL 65 67k 193
文章 阅读 粉丝
复制 重新生成 智能总结 关注 私信
文章主要探讨了 MySQL 的默认隔离级别为何是 RR 而非 RC。先回顾了关系型数据库隔离级别和 binlog 格式，包
括 STATEMENT、ROW、MIXED 三种格式及其特点。接着从不同方面分析，指出为规避早期版本主从复制的 目录 收起
bug，RR 被设为默认隔离级别并沿用至今。还说明了不同隔离级别和 binlog 格式组合下主从复制的情况。
开心一刻
关联问题: RR 有何特性 binlog 如何优化 RC 缺点在哪 基础回顾
binlog 格式
STATEMENT
ROW
开心一刻 MIXED
优缺点对比
默认隔离级别 今天和朋友们去K歌，看着这群年轻人一个个唱的贼嗨，不禁感慨道：年轻真好啊！
想到自己年轻的时候，那也是拿着麦克风不放的人 总结
现在的我没那激情了，只喜欢坐在角落里，默默的听着他们唱，就连旁边的妹子都劝我说：大哥别摸了，唱
首歌吧
相关推荐
从CPU100%高危故障到稳定在10%：一个月的优化之旅，成功上线！
1.3k阅读 · 14点赞
面试官 ：你好 ，对 JVM 垃圾回收参数有没有深入的理解 ？
12k阅读 · 52点赞
【Redis干货】这个Redis的坑你肯定没踩过!
725阅读 · 8点赞
高性能必杀技：Java中的池化技术
670阅读 · 5点赞
基础回顾
这样设计系统，能拿下大厂的Offer吗？
479阅读 · 19点赞
我们一起来回顾下八股文
面试官：关系型数据库的隔离级别有哪些 精选内容
你： （Read Uncommited 简称 RU）、读已提交（Read Commited 简称 RC）、可重复度 读未提交 如何开发一个 Spring Boot Starter：以定时任务 Starter 为例及常见踩坑点
（Repeatable Read 简称 RR）、串行化（Serializable） Asthenia0412 · 84阅读 · 0点赞
【验证码逆向专栏】最新某验四代动态参数逆向详解 面试官：主流关系型数据库的默认隔离级别是什么
K哥爬虫 · 33阅读 · 1点赞
你：MySQL 的默认隔离级别是可重复度，其他的如 Oracle、SQL Server、PostgreSQL、DB2 默认隔离级 virt-host-validate 异常项处理
别是读已提交 bobz965 · 20阅读 · 1点赞
鸿蒙轻内核A核源码分析系列六 MMU协处理器（2）
面试官：MySQL 的默认隔离级别为什么是 ，而不是 RR RC 别说我什么都不会 · 16阅读 · 0点赞
OpenHarmony（鸿蒙南向开发）——轻量系统内核（LiteOS-M）【LMS调测】 你：呃...，这个...，昂昂昂昂昂，这个没去研究过
塞尔维亚大汉 · 32阅读 · 0点赞
面试官：那你回去等通知吧
找对属于你的技术圈子 MySQL 5.5 才用 InnoDB 代替 MyISAM 作为 MySQL 的默认存储引擎，而事务才有隔离级别一说，
回复「进群」加入官方微信群 MyISAM 本就不支持事务，所以谈 MySQL 的隔离级别都是基于 MySQL 5.5 及其之后的版本
binlog 格式
在回答问题
MySQL 的默认隔离级别为什么 是 ，而不是 RR RC
之前，我们需要先了解下 MySQL 的 binlog
binlog 全称 ，即 ，有时候也称 ，记录了对 MySQL 数据库执行了更改的 binary log 二进制日志 归档日志
所有操作，包括表结构变更（CREATE、ALTER、DROP TABLE…）、表数据修改（INSERT、UPDATE、
DELETE...），但不包括 SELECT 和 SHOW 这类操作，因为这类操作对数据本身并没有修改；若更改操作并
未导致数据库变化，那么该操作也会写入 binlog，例如
sql 代码解读 复制代码
create table tbl_t1(name varchar ( 32 ));
insert into tbl_t1 values ( 'zhangsan' );
update tbl_t1 set name = 'lisi' where name = '123' ;
show master status\G;
show binlog events in 'mysql-bin.000002' \G;

此时的： 并未引起数据库的变化，但还是被 update tbl_t1 set name = 'lisi' where name = '123';
记录到了 binlog 中
binlog 的格式有三种： 、 、 ，一开始只有 STATEMENT，后面慢慢衍生出了 STATEMENT ROW MIXED
ROW、MIXED；MySQL 5.1.5 之前 binlog 的格式只有 STATEMENT，5.1.5 开始支持 ROW，从 5.1.8 版本开
始支持 MIXED；MySQL 5.7.7 之前，binlog 的默认格式都是 STATEMENT，在 5.7.7 及更高版本中，
binlog_format 的默认值才是 ROW；三种格式的 binlog 各长什么样，它们有什么区别，各有什么优劣，我
们往下看
STATEMENT
从 MySQL 第一个版本，到 8.0.x，STATEMENT 一直坚挺在 binlog 的格式中，只是从 5.7.7 开始，它退居幕
后，头把交椅给了 ROW
binglog 与我们开发中的代码日志是不一样的，它包含两类文件
索引文件
文件名.index，记录了哪些日志文件正在被使用，内容如下
日志文件
文件名.00000*
记录了对 MySQL 数据库执行了更改的所有操作
因为 binlog 的日志文件是二进制文件，不能用文本编辑器直接打开，需要用特定的工具来打开，MySQL 提
供了 来帮助我们查看日志文件内容，其可选参数很多，具体可用 mysqlbinlog
sql 代码解读 复制代码
mysqlbinlog.exe --help
查看，我们可以使用如下命令
sql 代码解读 复制代码
mysqlbinlog.exe .. / data / mysql - bin .000004
查看日志文件内容

可以看到，对数据库表的操作
sql 代码解读 复制代码
insert tbl_t1 values ( 'aaa' ),( 'bbb' );
update tbl_t1 set name = 'a1' where name = 'aaa' ;
delete from tbl_t1 where name = 'bbb' ;
都是以明文形式的 SQL 记录在日志文件中
ROW
MySQL 5.7.7 及之后版本，binlog 的默认格式是 ROW，我们基于 5.7.30 版本，来看下 ROW 格式 binlog 内
容是怎样的；先产生数据库更改操作
sql 代码解读 复制代码
create table tbl_row(
name varchar ( 32 ),
age int
);
insert into tbl_row values ( 'qq' , 23 ),( 'ww' , 24 );
update tbl_row set age = 18 where name = 'aa' ;
update tbl_row set age = 18 where name = 'qq' ;
delete from tbl_row where name = 'aa' ;
delete from tbl_row where name = 'ww' ;
master 当前正在写入的 binlog 文件： ，position 从 到 ，我们看下日志文 mysql-bin.000002 2885 3929
件中是怎么记录的，执行
sql 代码解读 复制代码
mysqlbinlog.exe --start-position=2885 --stop-position=3929 ../data/mysql-bin.000002
可以看到，表结构变更操作以明文形式的 SQL 记录在日志文件中（与 STATEMENT 一样），但表数据变更的
操作却是以一坨一坨的密文形式记录在日志文件中，不便于我们阅读，庆幸的是，mysqlbinlog 提供参数 -v
或 -vv 来解密查看，执行
sql 代码解读 复制代码
mysqlbinlog.exe --base64-output=decode-rows -v --start-position=2885 --stop-position=3929 ../data/mysql-bin.000002
INSERT 没什么好注意的，每一列都插入对应的值

sql 代码解读 复制代码
insert into tbl_row values ( 'qq' , 23 ),( 'ww' , 24 );
对应
### INSERT INTO `my_project`.`tbl_row`
### SET
### @1 = 'qq'
### @2 = 23
### INSERT INTO `my_project`.`tbl_row`
### SET
### @1 = 'ww'
### @2 = 24
UPDATE 就有需要注意的了，虽然我们修改列只有一列，条件列也只有一列，但是日志中记录的却是：修改
列是全部列，条件列也是全部列，并且列值是具体的值，而没有 NOW()、UUID() 这样的函数
sql 代码解读 复制代码
update tbl_row set age = 18 where name = 'qq' ;
对应
### UPDATE `my_project`.`tbl_row`
### WHERE
### @1 = 'qq'
### @2 = 23
### SET
### @1 = 'qq'
### @2 = 18
表没有明确的指定主键，满足更新条件的记录也只有一条，大家可以去试试这种情况
明确指定主键且满足更新条件的记录有多条的情况
看看 binlog 日志是怎么记录的
DELETE 与 UPDATE 一样，虽说条件列只有一个，但日志中记录的确实全部列
sql 代码解读 复制代码
delete from tbl_row where name = 'ww' ;
对应
### DELETE FROM `my_project`.`tbl_row`
### WHERE
### @1 = 'ww'
### @2 = 24
相较 STATEMENT，ROW 显得更复杂，内容多很多
MIXED
字面意思：混合，那它混合谁？ 还能混合谁？只能混合 STATEMENT 和 ROW
大多数情况下，是以 STATEMENT 格式记录 binlog 日志（因为 MySQL 默认隔离级别是 RR，而又很少有人
去修改默认隔离级别），当隔离级别为 RC 模式的时候，则修改为 ROW 模式记录；有些特殊场景，也是以
ROW 格式来记录的，就不区分 RR 和 RC 了（摘自： 关于binary log那些事——认真码了好长一篇 ）
当然还有一个 ，说白了就是，只有具体的值才最可靠，其他依赖于上下文、环境的函数、系统变量 NOW()
都不可靠，因为它们会因上下文、环境而变化
这个就不去展示具体的日志内容了，有兴趣的小伙伴自行去跑结果
优缺点对比
三种格式都已介绍完毕，相信大家对它们各自的特点、优缺点已经有一定的了解了，我给大家总结下

MIXED 的愿景（结合 STATEMENT 和 ROW 两者的优点，产生一个完美的格式）是好的，但事与愿违，它
还是会有一些问题；相比于准确性而言，性能优先级会低一些（随着技术的发展，硬件性能已不再是不可接
受的瓶颈），所以推荐使用 格式 ROW
默认隔离级别
从上面 binlog 格式的内容来看，似乎与默认隔离级别 RR 没有半毛钱关系，我只能说你们先莫急，慢慢往下
看
RC 隔离级别，binlog 格式是 STATEMENT 时，各版 MySQL 执行表数据修改操作
表引擎肯定得是 InnoDB，我们分别看下 、 、 、 MySQl5.0.96 MySQL5.1.30 MySQL5.5.8
执行表数据更改操作的情况 MySQL5.7.30
MySQl5.0.96 可以正常执行
MySQL5.1.30 执行报错，提示
sql 代码解读 复制代码
ERROR 1598 (HY000): Binary logging not possible. Message: Transaction level 'READ-COMMITTED' in
MySQL5.5.8、MySQL5.7.30 执行报错，都提示
sql 代码解读 复制代码
ERROR 1665 (HY000): Cannot execute statement: impossible to write to binary log since BINLOG_FORMAT
也就是说，MySQL5.1.30及之后，RC 隔离级别的 InnoDB 对 binlog_format 是有限制的，不能是
STATEMENT，否则表数据无法进行修改
不同 session 的操作记录在 binlog 中的记录顺序
我们用两个 session 来执行更新操作，看下不同 session 的操作记录在 binlog 中的记录顺序有什么决
定
可以看到
sql 代码解读 复制代码
update tbl_rr_test set age = 20 where id = 1 ;
先执行，后 commit，而
sql 代码解读 复制代码
update tbl_rr_test set age = 21 where id = 2 ;
后执行，先 commit，日志中记录的是

先commit的记录在前面，后commit的记录在后面，与执行时间点无关
就单个 session 来说，好理解，执行顺序就是记录顺序；多个 session 之间的话，先 commit 的先记录
主库对数据库的更改是按执行时间的先后顺序进行的，而 binlog 却是按 commit 的先后顺序记录的，
理论上来说就会出现 MySQL Bug23051 中的示例问题
默认隔离级别（RR）与 binlog 关系
MySQL Bug23051 里面有说到，MySQL 5.1 的早期版本，隔离级别是 RC、binlog 格式是 STATEMENT
时，InnoDB 的主从复制是有 bug 的（5.1.21 中修复），而 5.0.x 是没问题的，我们在 5.0.96 上跑下
Bug23051 中的例子
可以看到，5.0.96 下的 InnoDB，在 RC 级别，binlog_format=STATEMENT 时
sql 代码解读 复制代码
UPDATE t1 SET a = 11 where b = 2 ;
的事务未提交，则
sql 代码解读 复制代码
UPDATE t1 SET b = 2 where b = 1 ;
的事务会被阻塞，那么从库复制的时候，数据是没问题的
所以，综合前面的来看，从 MySQL5.0 开始，InnoDB 在 RC 级别，binlog_format=STATEMENT 时主
从复制是没有 bug 的（5.0没问题，5.1.21之前的5.1.x有问题，但官方不提供下载了，5.1.21及之后的版
本不支持 RC 隔离级别下设置 binlog 为 STATEMENT）
那么 binlog 与 默认级别 RR 的关系就清楚了，就是 【原创】互联网项目中mysql应该选什么事务隔离
级别 中的一段话
那Mysql在5.0这个版本以前，binlog只支持STATEMENT这种格式！而这种格式在读已提交
(Read Commited)这个隔离级别下主从复制是有bug的，因此Mysql将可重复读(Repeatable
Read)作为默认的隔离级别！
也就是说，在 MySQL5.0之前，将 RR 作为默认隔离级别，是为了规避大部分主从复制的bug（具体什
么bug，可详看 Bug23051 中的案例，或者 【原创】互联网项目中mysql应该选什么事务隔离级别 中的
案例），然后一直被沿用了下来而已；为什么不是规避全部的主从复制 bug，因为在 RR 隔离级别、
binlog_format=STATEMENT 下，使用系统函数（ 、 等）时，还是会导致主从数据不 NOW() UUID()
一致
总结
binlog 格式
目前主流的 MySQL 版本中，binlog 格式有 3 种：STATEMENT、ROW、MIXED，从数据准确性考虑，
推荐使用 ROW 格式
binlog 默认格式
MySQL 5.1.5 之前只支持 STATEMENT 格式的 binlog，5.1.5 开始支持 binlog_format=ROW，MySQL
5.7.7 之前，binlog 的默认格式都是 STATEMENT，在 5.7.7 及更高版本中，binlog_format 的默认值才
是 ROW
binlog 用途
主要包括：主从复制、数据恢复、审计
主从复制 bug（InnoDB 引擎）
MySQL 5.1.30及之后，InnoDB 下，开启 RC 隔离级别的话是不能启用 binlog_format=STATEMENT的
RC、RR 隔离级别，binlog_format=MIXED，主从复制仍会有数据不一致的问题（受系统函数影响）

RR 隔离级别，binlog_format=STATEMENT，主从复制仍会有数据不一致的问题（受系统函数影响）
binlog_format=ROW，不管是 RC 隔离级别，还是 RR 隔离级别，主从复制不会有数据不一致的问题
MySQL 的默认隔离级别为什么是 RR，而不是 RC
为了规避 MySQL5.0 以前版本的主从复制问题，然后一直被沿用了下来而已
标签： MySQL
本文收录于以下专栏
MySQL 专栏目录
订阅 MySQL
· 0 订阅 4 篇文章
神奇的 SQL 之 JOIN，以MySQL为例来探讨下它的执行过程是怎样的（下） 上一篇
评论 0
登录 / 注册 即可发布评论！
0 / 1000 发送
暂无评论数据
为你推荐
糟了，数据库崩了，又好像没崩
程序员wayn 1年前 2.0k 16 2 MySQL 数据库
(第一回合)回龙观大叔狂磕mysql｜小册免费学
小宇渣渣渣 3年前 729 7 评论 MySQL
面试官：事务隔离级别和锁有什么关系（上）｜ 8月更文挑战
切图老司机 3年前 512 9 评论 数据库 程序员
神奇的 SQL 之 Index Condition Pushdown，这可是个好优化
青石路 5月前 327 11 6 SQL MySQL 后端
神奇的 SQL ，同时实现小计与合计，你们会如何实现
青石路 4月前 1.6k 15 7 SQL
牛马日记起源-Mysql数据库
牛马日记 1年前 556 7 1 后端
[Mysql] 聊聊MVCC与Buffer Pool缓存机制
抢老婆酸奶的小肥仔 1年前 616 3 评论 后端 MySQL 数据库
一个 MVCC 和面试官大战30回合
yes的练级攻略 3年前 1.2k 10 1 MySQL
查询SQL的执行流程
木子雷 4年前 4.9k 43 9 MySQL 面试
MySQL的binlog有啥用？谁写的？在哪里？怎么配置？
熬夜不加班 4年前 1.3k 3 评论 MySQL
不会InooDB底层和事务特性原理还想手撕面试官？
学徒630 1年前 478 7 评论 后端 数据库 Java
(第三回合)回龙观大叔狂磕mysql｜小册免费学
小宇渣渣渣 3年前 296 3 1 MySQL
一文搞懂MySQL体系架构！！
冰_河 3年前 7.5k 22 3 MySQL
全方位解析 MySQL 及相关面试题一（收藏点赞系列）
coderxdh 3年前 355 点赞 评论 MySQL

神奇的SQL，你真的知道 ON 和 WHERE 之间的区别吗
青石路 5月前 2.1k 24 15 SQL MySQL 后端

