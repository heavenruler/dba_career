首页 / 性能运维 -- 借助pstack + strace排查SQL性能问题
性能运维 -- 借助pstack + strace排查SQL性能问题
原创 金仓数据库 2024-03-05 3406
沐雨听风 一、pstack 和 strace
关注
1. pstack 67 45 263K+
文章 粉丝 浏览量
pstack用来跟踪进程栈，这个命令在排查进程问题时非常有用，比如我们发现一个
21 服务一直处于 working 状态（如假死状态，好似死循环），使用这个命令就能轻松 获得了 次点赞
定位问题所在。可以在连续一小段时间内（比如：每秒执行一次，连续10次），多执 9 内容获得 次评论
行几次pstack，若发现代码栈总是停在同一个位置，那个位置就需要重点关注，很 42 获得了 次收藏
可能就是出问题的地方。
TA的专栏 示例
金仓数据库技术专栏 [kingbase@localhost ~]$ pstack 2050
收录 66 篇内容 #0 0x00007f95424d1c53 in __select_nocancel () from /lib64/libc.so.6
#1 0x00000000008cc180 in KesMasterMain () SQL与DB性能 #2 0x00000000004a726c in main ()
收录 45 篇内容
数据库运维 解读顺序从下往上 ，先执行main 函数，然后调用KesMasterMain 然后是 __select
收录 11 篇内容 _nocancel 函数。如果实际生产中出现了应用程序长时间等待的情况，可以通过pst
ack 判断应用程序卡在了哪一步。
但是pstack 只能看到程序执行的函数以及对应的内存地址，并不能显示每步的执行
热门文章 时间。
知识点滴 -- KingbaseES 函数编译执行 2. strace 2023-08-08 24719浏览
知识点滴 -- 函数三种稳定态及其对函数 strace常用来跟踪进程执行时的系统调用和所接收的信号。
调用次数的影响
2023-04-18 22042浏览 在Linux世界，进程不能直接访问硬件设备，当进程需要访问硬件设备(比如读取磁
盘文件，接收网络数据等等)时，必须由用户态模式切换至内核态模式，通过系统调 SQL优化 -- 利用Rownum条件Count Sto
用访问硬件设备。strace可以跟踪到一个进程产生的系统调用，包括参数，返回 p特性优化SQL的一个案例
值，执行消耗的时间。 2023-08-21 9239浏览
SQL优化 -- 针对窗口函数的一个SQL优 示例： 化案例
2023-04-19 8713浏览
strace -o output.txt -T -tt -e trace=all -p 2050
SQL优化 -- 一例 Union All 引发的性能 参数含义： 问题 -o 将结果输出到文件 2023-08-09 7446浏览
-e trace=all 跟踪进程的所有系统调用
-p 进程号

最新文章 -tt 在每行输出的前面显示时间(精确到毫秒)
-T 显示每次系统调用所花费的时间
知识点滴 -- CTE Recursive 如何实现 Or
der Siblings by 功能
[kingbase@localhost ~]$ tail -f output.txt 2025-07-16 17浏览
19:33:39.107104 select(6, [3 4 5], NULL, NULL, {40, 451375}) = 0 (Timeout)
SQL优化 -- 视图内部函数调用引发的性 19:34:19.590769 rt_sigprocmask(SIG_SETMASK, ~[ILL TRAP ABRT BUS FPE SEGV 能问题 19:34:19.590982 open("kingbase.pid", O_RDWR) = 10 <0.000043> 2025-04-30 44浏览 19:34:19.591128 read(10, "2050\n/o", 7) = 7 <0.000028>
SQL优化 -- 如何在一条语句同时返回 Ro 19:34:19.591225 close(10) = 0 <0.000032>
ws and Count 19:34:19.591318 rt_sigprocmask(SIG_SETMASK, [], NULL, 8) = 0 <0.000050>
2025-02-19 97浏览 19:34:19.591690 select(6, [3 4 5], NULL, NULL, {60, 0} <detached ...>
知识点滴 -- old_snapshot_threshold 参
数开启导致索引无法使用案例
这里的read(10, "2050\n/o", 7)、close(10) 都是linux内核层执行的指令，<0.000 2025-01-17 158浏览
032> 这些内容代表的是执行时间。
知识点滴 -- Where子句函数条件执行顺
序
二、排查耗时的步骤 2024-12-19 61浏览
1、确认进程号 目录
可以通过系统视图确认sql对应的pid 一、pstack 和 strace
1. pstack SELECT * FROM sys_stat_activity
2. strace
2、打印进程信息 二、排查耗时的步骤
三、慢 SQL 问题排查步骤 pstack 进程号
1. 测试sql
3、查看strace信息 2. 查询对应pid
3. pstack 分析 32255 进程 strace -o output.txt -T -tt -e trace=all -p 171264
4. strace 分析
4、查看output.txt 并分析执行时间
四、总结
由于这里会出现很细linux系统的函数所以需要借助百度等搜索工具确认函数对应的
操作含义。
三、慢 SQL 问题排查步骤
1. 测试sql
EXPLAIN ANALYZE SELECT * FROM "app_family" af2 WHERE NOT EXISTS (SELECT
Hash Anti Join (cost=78.38..395702.04 rows=4999850 width=33) (actual time=601.025..14615.331
Hash Cond: ((af2.family_id)::text = (af.family_id)::text)
-> Seq Scan on app_family af2 (cost=0.00..332500.00 rows=5000000 width=33)
-> Hash (cost=76.50..76.50 rows=150 width=4) (actual time=2.136..2.136
Buckets: 16384 (originally 1024) Batches: 1 (originally 1) Memory
-> Seq Scan on app_family2 af (cost=0.00..76.50 rows=150 width=4)
Planning Time: 0.466 ms

Execution Time: 14814.652 ms
2. 查询对应pid
SELECT pid,query FROM sys_stat_activity
27097
27096
32251 SHOW search_path
32252 SELECT c.oid,c.*,d.description,pg_catalog.pg_get_viewdef(c.oid,true)
FROM pg_catalog.pg_class c
LEFT OUTER JOIN pg_catalog.pg_description d ON d.objoid=c.oid AND d.objsubid=0
WHERE c.relnamespace=$1 AND c.relkind not in ('i','I','c') AND relname not
32255 "EXPLAIN ANALYZE SELECT * FROM "app_family" af2 WHERE NOT EXISTS
"
536 SELECT pid,query FROM sys_stat_activity
27092
3. pstack 分析 32255 进程
从pstack的分析结果可以看到这个sql的执行过程，但是并不能反馈出慢的步骤。但
是如果在sql 执行过程中 通过pstack 多次查看进程，都显示卡在了同一个函数，那
就很大可能该函数属于慢的问题点。
[kingbase@localhost ~]$ pstack 32255
#0 0x0000000000985fbb in hash_search_with_hash_value ()
#1 0x000000000092209a in BufferTableLookup ()
#2 0x00000000009248fc in ReadBufferCommon ()
#3 0x0000000000925383 in ReadBufExtended ()
#4 0x0000000000516382 in HeapGetPage ()
#5 0x0000000000516a0b in HeapGettupPageMode ()
#6 0x0000000000517b3e in HeapGetNextSlot ()
#7 0x00000000006e7761 in SequenceNext ()
#8 0x00000000006e837e in ExecRowScan ()
#9 0x00000000006aaff3 in ExecutorProcNodeInstr ()
#10 0x00000000006d363a in ExecHJoin ()
#11 0x00000000006aaff3 in ExecutorProcNodeInstr ()
#12 0x00000000006a7f38 in StandardExecRun ()
#13 0x00007f95380ea6e5 in KDBExplainExecutorRun () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/auto_explain.so
#14 0x00007f9535bd3d75 in kbss_ExecutorRun () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/sys_stat_statements.so
#15 0x000000000068ddde in ExplainOnePlan ()
#16 0x000000000068e09f in ExplainOneQueryPlan ()
#17 0x000000000068e6bd in ExplainQuery ()
#18 0x000000000094e4b7 in standard_ProcessUtility ()
#19 0x00007f9537b67813 in SynonymProcUtility () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/synonym.so
#20 0x00007f95378ece31 in PlsqlUtilityCommand () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/plsql.so
#21 0x00007f95376c33fa in ForceViewProcUtil () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/force_view.so
#22 0x00007f95374b636c in flashback_ProcessUtility () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/kdb_flashback.so
#23 0x00007f9535bd706b in kbss_ProcessUtility () from /opt/Kingbase/ES/V9/KESRealPro/V009R001C001B0025/Server/lib/sys_stat_statements.so
#24 0x000000000094b14c in PortalRunUtility ()
#25 0x000000000094c202 in FillPortalStore ()

#26 0x000000000094ccdd in PortalRun ()
#27 0x00000000009473d9 in ExecSimpleQuery ()
#28 0x0000000000949c7a in BackendMain ()
#29 0x00000000004a6683 in ForegroundStartup ()
#30 0x00000000008cc21c in KesMasterMain ()
#31 0x00000000004a726c in main ()
4. strace 分析
从strace 分析可以看到从21:36:07 开始到 21:36:22 进程32255一直进行pread64
操作，先后涉及文件描述符48、49、50。这时候我们借助百度确认一下pread64
的函数的作用
查询后发现pread64 函数是从指定偏移开始读文件。也就是说该sql 从07到22 历时
15s左右都在进行文件的读取操作，涉及48、49、50 三个文件。
收集指令
strace -o output.txt -T -tt -e trace=all -p 32255
[kingbase@localhost ~]$ more output.txt
21:36:01.883491 epoll_wait(3, [{EPOLLIN, {u32=23034888, u64=23034888}}],
21:36:07.195191 recvfrom(10, "Q\0\0\0\222EXPLAIN ANALYZE SELECT * "..., 8192,
21:36:07.195553 lseek(50, 0, SEEK_END) = 166756352 <0.000013>
21:36:07.195627 lseek(52, 0, SEEK_END) = 500768768 <0.000010>
21:36:07.195662 lseek(54, 0, SEEK_END) = 113106944 <0.000010>
21:36:07.195693 lseek(45, 0, SEEK_END) = 614400 <0.000010>
21:36:07.195724 lseek(46, 0, SEEK_END) = 393216 <0.000010>
21:36:07.195755 lseek(47, 0, SEEK_END) = 385024 <0.000010>
21:36:07.195971 lseek(50, 0, SEEK_END) = 166756352 <0.000017>
21:36:07.196088 kill(27091, SIGUSR1) = 0 <0.000024>
21:36:07.196148 pread64(48, "\v\0\0\0\230\375\200\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.202769 pread64(48, "\v\0\0\0\270\233\201\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.202916 pread64(48, "\v\0\0\0H9\202\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.202961 pread64(48, "\v\0\0\0\210\347\202\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.203004 pread64(48, "\v\0\0\0\250\205\203\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.203668 pread64(48, "\v\0\0\0008#\204\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.203764 pread64(48, "\v\0\0\0x\321\204\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.203915 pread64(48, "\v\0\0\0Hg\205\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:07.203959 pread64(48, "\v\0\0\0(\r\206\341\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。
21:36:20.227660 pread64(49, "\r\0\0\0\260^T\241\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:20.227841 pread64(49, "\r\0\0\0\220&U\241\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。
21:36:21.999330 pread64(50, "\r\0\0\0\240\214\203\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999398 pread64(50, "\r\0\0\0xI\204\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999465 pread64(50, "\r\0\0\0\0\370\204\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999532 pread64(50, "\r\0\0\0`\245\205\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999599 pread64(50, "\r\0\0\0\250r\206\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,

21:36:21.999680 pread64(50, "\r\0\0\0H!\207\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999780 pread64(50, "\r\0\0\0\220\316\207\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999857 pread64(50, "\r\0\0\0\300\233\210\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999925 pread64(50, "\r\0\0\0pJ\211\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:21.999992 pread64(50, "\r\0\0\0\220\367\211\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:22.000060 pread64(50, "\r\0\0\0`\304\212\331\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:22.010357 write(2, "\0\0\360\1\377}\0\0f\326@B\17\0\0\0002024-02-03
21:36:22.010538 write(2, "\0\0\360\1\377}\0\0f\326@B\17\0\0\0 = (af.family_id"...,
21:36:22.010588 write(2, "\0\0G\1\377}\0\0t\326@B\17\0\0\0\n\t Bucket"...,
21:36:22.010721 write(2, "\0\0\334\0\377}\0\0t\326@B\17\0\0\0002024-02-03
21:36:22.010776 sendto(9, "\2\0\0\0x\1\0\00018\0\0\3\0\0\0\3\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0"...,
21:36:22.010854 sendto(10, "T\0\0\0#\0\1QUERY PLAN\0\0\0\0\0\0\0\0\0\0\31\377\377\377\377"...,
21:36:22.010952 recvfrom(10, 0xee3000, 8192, 0, NULL, NULL) = -1 EAGAIN (Resource
21:36:22.012577 epoll_wait(3, [{EPOLLIN, {u32=23034888, u64=23034888}}],
21:36:22.042782 recvfrom(10, "B\0\0\0\17\0S_4\0\0\0\0\0\0\0E\0\0\0\t\0\0\0\0\0S\0\0\0\4",
21:36:22.043005 sendto(10, "2\0\0\0\4D\0\0\0\32\0\2\0\0\0\6public\0\0\0\6system"...,
21:36:22.043127 recvfrom(10, 0xee3000, 8192, 0, NULL, NULL) = -1 EAGAIN (Resource
21:36:22.043181 epoll_wait(3, [{EPOLLIN, {u32=23034888, u64=23034888}}],
21:36:22.043508 recvfrom(10, "B\0\0\0\17\0S_5\0\0\0\0\0\0\0E\0\0\0\t\0\0\0\0\0S\0\0\0\4",
21:36:22.043650 sendto(10, "2\0\0\0\4D\0\0\0\31\0\1\0\0\0\17\"$user\", publicC"...,
21:36:22.043735 recvfrom(10, 0xee3000, 8192, 0, NULL, NULL) = -1 EAGAIN (Resource
21:36:22.043774 epoll_wait(3, <detached ...>
通过 lsof 查看32255 处理的文件以及对应fd 就可以确认 本次IO操作涉及的文件。
lsof | grep 32255
。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。
kingbase 32255 kingbase 48u REG 253,0 1073741824 7672114 /opt/Kingbase/ES/V9/data/base/14385/96798
kingbase 32255 kingbase 49u REG 253,0 1073741824 18717 /opt/Kingbase/ES/V9/data/base/14385/96798.1
kingbase 32255 kingbase 50u REG 253,0 166756352 7642968 /opt/Kingbase/ES/V9/data/base/14385/96798.2
。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。。
到了这一步再结合执行计划就可以确认该sql执行过程中是因为seq scan 导致了大
量文件读操作导致sql执行耗时过久。
四、总结
pstack+strace结合的方式可以分析出再一个sql 执行过程中主要耗时的linux系统
操作，从而定位性能问题瓶颈。 但是从上述实验中我们也可以看到通过执行计划可
以实现大部分sql性能问题的定位，所以pstack+strace其实并不适合绝大部分场
景，只有在执行计划信息不足以协助我们判断性能瓶颈时才需要借助pstack+strac
e。
中电科金仓
最后修改时间：2024-12-19 16:44:58
「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」

关注作者 赞赏
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信
息，否则作者和墨天轮有权追究责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contac
t@modb.pro进行举报，并提供相关证据，一经查实，墨天轮将立刻删除相关内容。
文章被以下合辑收录
金仓数据库技术专栏（共66篇）
收藏合辑 金仓数据库技术专栏，介绍金仓数据库性能优化技术、集群技术，以
及SQL优化技术等，致力于打造DBA技术交流、学习空间。
数据库运维（共11篇） 收藏合辑
介绍数据库运维相关技术问题
评论
相关阅读
知识点滴 -- CTE Recursive 如何实现 Order Siblings by 功能
沐雨听风 17次阅读 2025-07-16 17:08:02

