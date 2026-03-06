会员 众包 新闻 博问 闪存 赞助商 Trae Chat2DB 注册 登录
数据库技术和故事
从今以后，愿你无所畏惧。
博客园 首页 新随笔 联系 管理 订阅 随笔- 403 文章- 36 评论- 28 阅读- 70万
关于MySQL checkpoint
昵称： 海东潮
园龄： 6年11个月
Ⅰ、Checkpoint 粉丝： 62
关注： 2
1.1 checkpoint的作用 +加关注
缩短数据库的恢复时间
< 2025年8月 >
缓冲池不够用时,将脏页刷到磁盘 日 一 二 三 四 五 六
27 28 29 30 31 1 2 重做日志不可用时,刷新脏页 3 4 5 6 7 8 9
10 11 12 13 14 15 16
17 18 19 20 21 22 23
24 25 26 27 28 29 30
31 1 2 3 4 5 6
搜索
常用链接
我的随笔
我的评论 1.2 展开分析
我的参与 page被缓存在bp中,page在bp中和disk中不是时刻保持一致的(page修改一下就刷一次盘是不现实的,是通过checkpoint 最新评论 来玩的)
我的标签
万一宕机,重启的时候disk上那个page需要恢复到原来bp中page的那个版本 更多链接
那问题是,两个page版本不一致咋整？没事,我们做到最终一致就行
我的标签 那我们就说一下这个最终一致是个怎样的过程,通过一个例子来说明：

mysql (208)
linux (54)
oracle (24)
performance (16)
新特性 (15)
memory (14)
复制 (12)
pt (11)
replication (10)
lock (10)
更多
积分与排名
字节旗下的 AI IDE 积分 - 486427
排名 - 1517
随笔分类 (379)
AWS(1)
Cloud(1)
DataArch(3)
EBS(1)
Golang(2)
Goldengate(2) Step1：
一个page读到bp中时,它的lsn（这个鬼东西待会儿仔细说,先理解为一个flag）是 100 ,然后这个page被modify了,它的lsn变成了 130 Linux(59) Step2：
MySQL(222) 另外一个page之前进bp的时候lsn是 50 ,前面那个page被modify之后,它也被修改,它的lsn变成了 140 ,它这个 140 的lsn也写到了 redo
Step3： NewSQL(1) 关键的一步,假设此时lsn为 130 的page被刷到disk上了（什么时候刷也是个学问,这里不说）,而lsn为 140 的那个page还没被刷,磁盘上保存的还是老版本,突然宕机了。
Oracle(44) Step4：
Percona(3) 这时候restart数据库,就会从磁盘上cp的位置( 130 )开始读 redo log ,一直回放到 140 ,这样没被刷到磁盘的那个page就恢复到宕机之前的状态了。
python(1)
Python(3) 划重点：
架构(1) ①这个130,140其实就是字节数,也就是说你对这个页修改产生了10个字节的日志,那么lsn就加10
压力测试(2)
②page原来读进bp的lsn甭管,只管它改变了多少字节就行,所以这个lsn的变化肯定是一个单调递增的过程,其实lsn就是日 运维(27) 志写了多少字节(之前没理解好,以为各个page的lsn是自己玩自己的) 字符编码与存储(6)
Ⅱ、LSN(log sequence number)——日志序列号 随笔档案 (403)
lsn是用来保存checkpoint的,保存现在刷新到磁盘的位置在哪里
2019年2月(16) 这个130,140其实就是字节数,也就是说你对这个页修改产生了10个字节的日志,那么lsn就加10,lsn没有上限,8字节
2019年1月(99) 2.1 lsn存在什么地方？ 2018年12月(153)
每个page有一个LSN,page更新一下LSN就会更新一下,记录在page header中 2018年11月(92)
2018年10月(32) 整个MySQL实例也有一个LSN(这就是checkpoint),记录在第一个重做日志的前2k的块里(就给它用,不会被覆盖)
2018年9月(5)
redo log里有一个LSN 2018年8月(6)
全局lsn位置之前的内容已经刷磁盘上,只要恢复它后面的日志,数据就恢复了
文章分类 (21)
2.2 查看lsn和整个checkpoint流程梳理

Linux(7) 看page中的lsn,page中其实是保存两个lsn的,如下：
MySQL(3)
Oracle(11) (root @172 . 16.0 . 10 ) [(none)]> desc information_schema.INNODB_BUFFER_PAGE_LRU;
+---------------------+---------------------+------+-----+---------+-------+
| Field | Type | Null | Key | Default | Extra |
阅读排行榜 +---------------------+---------------------+------+-----+---------+-------+
| POOL_ID | bigint(21) unsigned | NO | | 0 | |
1. Linux man 命令详细介绍(39700) | LRU_POSITION | bigint( 21 ) unsigned | NO | | 0 | |
| SPACE | bigint(21) unsigned | NO | | 0 | | 2. MySQL 8.0窗口函数(29751)
| PAGE_NUMBER | bigint( 21 ) unsigned | NO | | 0 | |
3. 数据库对比：选择MariaDB还是M | PAGE_TYPE | varchar(64) | YES | | NULL | |
ySQL？(25801) | FLUSH_TYPE | bigint( 21 ) unsigned | NO | | 0 | |
| FIX_COUNT | bigint(21) unsigned | NO | | 0 | | 4. 详细分析MySQL事务日志(redo lo | IS_HASHED | varchar( 3 ) | YES | | NULL | |
g和undo log)(15751) | NEWEST_MODIFICATION | bigint(21) unsigned | NO | | 0 | |
| OLDEST_MODIFICATION | bigint( 21 ) unsigned | NO | | 0 | | 5. MySQL binlog格式解析(10626)
| ACCESS_TIME | bigint(21) unsigned | NO | | 0 | |
6. 关闭服务器节能模式(9999) | TABLE_NAME | varchar( 1024 ) | YES | | NULL | |
7. Linux的Transparent Hugepage与 | INDEX_NAME | varchar(1024) | YES | | NULL | |
| NUMBER_RECORDS | bigint( 21 ) unsigned | NO | | 0 | | 关闭方法(9934) | DATA_SIZE | bigint(21) unsigned | NO | | 0 | |
8. MySQL自增列（AUTO_INCREME | COMPRESSED_SIZE | bigint( 21 ) unsigned | NO | | 0 | |
| COMPRESSED | varchar(3) | YES | | NULL | | NT）相关知识点总结(9760)
| IO_FIX | varchar( 64 ) | YES | | NULL | |
9. 分享一个基于小米 soar 的开源 sq | IS_OLD | varchar(3) | YES | | NULL | |
l 分析与优化的 WEB 图形化工具(911 | FREE_PAGE_CLOCK | bigint( 21 ) unsigned | NO | | 0 | |
+---------------------+---------------------+------+-----+---------+-------+ 4) 20 rows in set (0.00 sec)
10. 如何配置Linux的服务设置为自动
newest_modification 页最新更新完后的lsn 启动或崩溃重新启动后(9048)
oldest_modification 页第一次更新完后的lsn
11. MySQL: OPTIMIZE TABLE: Tabl page刷到磁盘的时候,全局的check_point保存的是oldest(只保存第一次修改时的lsn),而page中的lsn保存的是newest
e does not support optimize, doing
(root@172.16.0.10) [(none)]> show engine innodb status\G recreate + analyze instead(8776) ...
12. 简单实现MySQL数据库的日志审 ---
LOG 计(8446)
---
13. 你的MySQL服务器开启SSL了 Log sequence number 15151135824 当前内存中最新的LSN
吗？SSL在https和MySQL中的原理 Log flushed up to 15151135824 redo 刷到磁盘的LSN
Pages flushed up to 15151135824 最后一个刷到磁盘上的页的最新的LSN（NEWEST_MODIFICATION） 思考(8311) Last checkpoint at 15151135815 最后一个刷到磁盘上的页的第一次被修改时的LSN（OLDEST_MODIFICATION）
14. x86服务器MCE（Machine Chec ...
k Exception）问题(8090)
Log sequence number和Log flushed up这两个LSN可能会不同,运行过程中后者可能会小于 前者,因为 redo 日志也是先在内存中更新,再刷到磁盘的
15. 记一次 MySQL semaphore cras
h 的分析(爱可生)(7517) 最后一个小于前面三个,为什么？
16. Linux atop 监控系统状态(7239)
17. MySQL案例-mysqld got signal 1 脏页会被指向flush list这个就不多赘述了
1(6992) flush list是根据lsn进行组织的,而且还是用一个page第一次放进来的lsn进行组织的,也就是说这个page再次发生更新,它
18. ps命令之排序(6627) 的位置是不会移动的
19. mcelog用法详解(6471) 分析一波： 20. MySQL:关于 unauthenticated u
bp的LRU列表中,一个page,假设LSN进来的时候是100,当前全局LSN也是100,如果这个page变化了,产生了20字节的日 ser(6228)
志,这时候page的lsn变成120,并且通过指针指向flush list中去了,但是这个page立马又被更新产生20字节日志,此时page
评论排行榜 的lsn为140,而此时在flush list中的lsn还是120(这里意思就是page里面保存了两种lsn,一个是第一次修改页的,一个是最
后一次修改页的)
1. MySQL 8.0窗口函数(6) 当这个lsn为120的page被刷到disk上,那么disk上的cp就是120了,但是上面的三个值都是140,是不是很好理解呢,那就是
2. 关于MySQL checkpoint(2) 说,每个page只更新一次,那这四个值就相等了呗,23333！
3. 简单实现MySQL数据库的日志审 为什么这么设计？ 计(2)
为了恢复的时候,保证redo回放的过程的连续性,不会出错 4. 一个能够编写、运行SQL查询并可
视化结果的Web应用：SqlPad(2) page A第一次修改后lsn是120,记录到全局lsn,后面还有个page B被更新,lsn变为140,此时,page A再更新,lsn变为160
5. MySQL 8.0新特性之原子DDL(2) 了。这时候发生宕机,page A被刷到磁盘,page B没刷过去,如果flush list里面记录160的话,发生故障重启时lsn为140的
page B怎么恢复？是不是被跳过去了 6. 【MySQL】sysbench压测服务器
及结果解读(2) 那从120开始恢复,那个页已经是160了,为什么还要恢复？
7. 安装 jemalloc for mysql(2) 数据库会检测,如果page的lsn大于实例的lsn,就不会恢复这个page,跨过去,只将page B从120恢复到140 8. Python PEP-8编码风格指南中文
tips： 版(1)

9. 缓冲池工作原理浅析(1) ①checkpoint不需要实时刷新到磁盘,不是一个页更新了就要更新磁盘上的cp,磁盘上的cp前置一点是没有关系的,大不了
多scan一点redo log,读到不回放就是了,而是由master_thread控制,差不多每秒钟更新一次 10. __细看InnoDB数据落盘 图解 MY
SQL(1) ②回滚问题
推荐排行榜 回滚不是通过redo来回滚的,所有的page前滚到一个位置(恢复完),这些page对应的事务还是活跃的,还没提交,之后这些
事务都会通过undo log来undo回滚,但undo是通过redo来恢复的
1. 详细分析MySQL事务日志(redo lo 比如一个页120-160已经恢复过去了,但是这个事务需要回滚,却又已经刷到磁盘了,没关系,通过undo log往回滚一下就好
g和undo log)(7) 了
2. MySQL 8.0窗口函数(5) 事务活跃列表存放在undo段中,只要事务没提交就在里面,提交后移动到undo的history中,这个历史列表是用来做purge
3. 灰度发布：灰度很简单，发布很复 的,这里面的undo会被慢慢回收 杂&灰度发布（灰度法则）的6点认识
Ⅲ、checkpoint 分类 (2)
4. MySQL: OPTIMIZE TABLE: Tabl Sharp Checkpoint
e does not support optimize, doing 将所有的赃页都刷新回磁盘,刷新时系统hang住,InnoDB关闭时使用
recreate + analyze instead(2) 相关参数：innodb_fast_shutdown={1|0}
5. ORACLE DBA应该掌握的9个免费 Fuzzy Checkpoint 工具(2) 将部分脏页刷新回磁盘,对系统影响较小
innodb_io_capacity来控制,最小限制为100,表示一次最多刷新脏页的能力,与IOPS相关 最新评论 SSD可以设置在4000-8000,SAS最多设置在800多（IOPS在1000左右）
1. Re:简单实现MySQL数据库的日志
Ⅳ、什么时候刷dirty page 审计
以前在master thread线程中(从flush_list中进行刷新) 头一次听说审计
--小菜pjy 现在都在page_cleaner_thread线程中(每一秒,每十秒)
2. Re:ps命令之排序
FLUSH_LRU_LIST 刷新 对我有用
5.5以前需要保证在LRU_LIST尾部要有100个空闲页（可替换的页）,即刷新一部分数据 ,保证有100个空闲页。 --lizhenlzlz
3. Re:一个能够编写、运行SQL查询 由innodb_lru_scan_depth参数来控制,并不只是刷最后一个页,默认探测尾部1024个页（默认）,1024个页中所有脏
并可视化结果的Web应用：SqlPad 页会一起刷掉,该参数是应用到每个Buffer Pool,总数即为该值乘以Buffer Pool的个数,总量超过innodb_io_capacity
@只往前 你装上了吗... 是不合理的,即此参数不得超过innodb_io_capacity/innodb_buffer_pool_instances,ssd的话,可以适当把这个扫描
深度调深一点 --临冬城的狮子
4. Re:MySQL 8.0窗口函数 Async/Sync Flush Checkpoint
老哥，有sql语句吗 重做日志重用
--法外诳图张三
Dirty Page too much 5. Re:MySQL 8.0窗口函数 赃页比例超过bp总量的一定比例,本来是通过page_cleaner_thread来刷,但是脏页太多了,就会强行刷,由 lag,lead写反了 innodb_max_dirty_pages_pct参数控制 --full233
tips： 6. Re:MySQL 8.0窗口函数
你好！，请问基于范围的动态窗口有 ①页只会从flush_list中刷新这个观点是不对的,只有page_cleaner_thread定期问flush_list要脏页,一个一个刷,刷到
什么例子吗，看的不是很明白，我在 innodb_io_capacity的比例值
你们的书上也没有找到例子 ②LRU list中既存在干净的页也存在脏页,假设最后一个页,是脏的,另一个线程需要一个页,free list已经空了,lru会把这个
--下海搬砖 页淘汰给这个线程去使用,这时候也需要刷新这个脏页,默认一下探测1024个page,把脏页刷掉
7. Re:Linux man 命令详细介绍
分类: MySQL 内容有点乱，而且有的介绍明显看着
有问题， 比如 -c 显示使用 cat 命令 标签: mysql , 原理 , checkpoint
的手册信息。直接测试会报错，怎么
好文要顶 关注我 收藏该文 微信分享 可能是cat命令的信息。 建议整理
下，方便看，主要也方便博主自己
海东潮 看！...
粉丝 - 62 关注 - 2 0 0 --findmoon
8. Re:关于MySQL checkpoint +加关注
升级成为会员 跟姜老师讲的差不多
--安纳克里昂 « 上一篇： 缓冲池工作原理浅析
9. Re:Linux内存管理（text、rodat » 下一篇： MySQL重做日志相关
a、data、bss、stack&heap） posted @ 2019-01-07 23:49 海东潮 阅读( 1548 ) 评论( 2 ) 收藏 举报
刷新页面 返回顶部 我在： 2021年 5月 13日 10:28:32 看
登录后才能查看或发表评论，立即 登录 或者 逛逛 博客园首页 过本篇博客！

--努力变胖-HWP 【推荐】飞算科技，让代码飞：欢迎体验 JavaAI 开发助手，参加炫技赛
10. Re:__细看InnoDB数据落盘 图解 【推荐】100%开源！大型工业跨平台软件C++源码提供，建模，组态！
【推荐】AI 的力量，开发者的翅膀：欢迎使用 AI 原生开发工具 TRAE MYSQL
【推荐】2025 HarmonyOS 鸿蒙创新赛正式启动，百万大奖等你挑战 太强啦！！还有一个问题请教。MyS
QL的innodb_flush_method 5.7后是
不是默认采用O_DIRECT？如果是，
那么这么说MySQL数据库就会绕过
【VFS】和【文件系统】，直接对磁盘
进...
--Ethan3306
11. Re:一个能够编写、运行SQL查询
并可视化结果的Web应用：SqlPad
博主又在本地运行过吗，对node不熟
悉，只能docker启动了，但是我还是
想本地运行，官方文档看不太明白。 编辑推荐：
--只往前 · 记一次 C# 平台调用中因非托管 union 类型导致的内存访问越界
· ［EF Core］聊聊“复合”属性 12. Re:MySQL: OPTIMIZE TABLE: T
· 那些被推迟的 C# 14 特性及其背后的故事
able does not support optimize, do · 我最喜欢的 C# 14 新特性
· 程序员究竟要不要写文章 ing recreate + analyze instead
阅读排行： 感谢
· 遭遇疯狂 cc 攻击的一个周末 --一里天空
· C#/.NET/.NET Core技术前沿周刊 | 第 49 期（2025年8.1-8.10）
13. Re:关于MySQL checkpoint · 美丽而脆弱的天体运动：当C#遇见宇宙混沌
· 【EF Core】聊聊“复合”属性 这个篮色的字都不全啊
· GPT‑5 重磅发布 --王庆凡
14. Re:MySQL 8.0新特性之原子DDL
深入解析MySQL 8.0新特性：Crash
Safe DDL：
--龙隆隆
15. Re:MySQL 8.0新特性之原子DDL
深入解析MySQL 8.0新特性：Crash
Safe DDL：
--龙隆隆
16. Re:MySQL 8.0窗口函数
你好，介绍到cume_dist的函数是不
是放错图了呀
--Cles
17. Re:缓冲池工作原理浅析
你这个人真的时有意思，专门抄袭，
无耻下流卑鄙
--91洲际哥
18. Re:【MySQL】sysbench压测服
务器及结果解读
@kun_行者 这人到处抄袭，也不署名
一下...
--91洲际哥
19. Re:MySQL 8.0窗口函数
别名
--sun俊
20. Re:MySQL 8.0窗口函数
你好，谢谢你的分享。 但一个地方不
明白：select * from ( select row_n
umber()over w as row_num, order_i
d,user_no,amount,cr...
--danica_string

博客园 © 2004-2025
浙公网安备 33010602011771号 浙I
CP备2021040463号-3

