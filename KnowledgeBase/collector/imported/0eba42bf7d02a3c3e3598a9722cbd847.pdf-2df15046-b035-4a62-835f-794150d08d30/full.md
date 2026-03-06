首页 资讯 活动 大会 学习 文档 问答 服务 登录 注册
首页 / 从MySQL数据库的角度来看系统page fault（缺页异常）
从MySQL数据库的角度来看系统page fault（缺页异常）
原创 听见风的声音 2025-09-25 220
1 什么是缺页异常 关注
91 44 95K+ MySQL Innodb内存结构图（源自MySQL官网）
文章 粉丝 浏览量
211 获得了 次点赞
55 内容获得 次评论
364 获得了 次收藏
热门文章
Oracle会话超时设置1：在sqlnet.ora和list
ener.ora中设置
2023-02-15 8787浏览
理解model高级语句
2023-03-01 8547浏览
Postgresql 15的安装及简单使用
2023-03-06 4934浏览
oracle 数据库中的行锁和死锁
2023-01-12 4566浏览
Oracle --Oracle 11.2.0.4静默安装
2023-01-17 2348浏览
虚拟地址空间的定义-来自百度百科
最新文章 虚拟地址空间是现代计算机系统中实现内存管理的核心机制，通过为每个进程分配独立的逻
辑地址集合，解决物理内存直接寻址导致的安全隐患和资源冲突问题。该技术采用分段与分
Oracle 数据库又改名了-体验Oracle AI d
页机制实现地址转换，其中分页机制通过固定大小的页面划分和页表映射，既保障进程间的 atabase26AI的极简安装
内存隔离，又支持物理内存与磁盘空间的动态分配。32位系统的虚拟地址空间上限为4GB 2025-10-15 171浏览
32的寻址能力），64位系统理论寻址范围可达2 （基于2 64字节，通过地址翻译单元（MMU）完成 索引空间的使用及回收
虚拟地址到物理地址的转换。 2025-10-09 430浏览
MySQL数据库 Innodb存储引擎的虚拟地址空间就是MySQL内存结构图中左边的In-Memory
使用deepseek快速开发一个Oracle MCP Structures部分，包括缓冲池、log buffer。 server--go语言实现
虚拟地址空间的映射 2025-09-10 163浏览
操作系统将虚拟地址空间内核空间和用户空间两部分，早期的计算机系统内存比较小，不可
从AWR报告开始---一个系统优化数据库 能给所有的虚拟内存分配实际的物理内存，所以操作系统只在实际使用的虚拟内存才分配物 SQL语句的方法
理内存，并且分配后的物理内存，是通过内存映射来管理的，内存映射保存的是虚拟地址空 2025-09-09 591浏览
间的地址和物理内存的映射。
Oracle SQL patch---另外一种不调整SQ 缺页异常（page fault）
L可以更改语句的执行计划的方法 缺页异常示意图（源自网络） 2025-09-03 397浏览

目录
1 什么是缺页异常
2 缺页异常的类型及其与数据库性能的关系
2.1 major page fault
2.2 Innodb缓冲池和major page fault的关系
2.3 minor page fault
2.4 Invalid Page Fault
3 结论
当进程访问它的虚拟地址空间中的page时，如果这个页不能获得有效的数据，就会发生缺页
异常。
2 缺页异常的类型及其与数据库性能的关系
缺页异常的处理（源自网络）
2.1 major page fault
Major Page Fault 指的是当进程访问一个虚拟内存页面时，该页面不在物理内存中，必须从
外部存储设备（如硬盘）加载的情况。因为涉及到磁盘 I/O 操作，Major Page Fault的代价

非常高，常常会导致进程阻塞等待数据加载。
下面是一个缺页异常的例子
mysql> select SEQ,STATE, DURATION ,BLOCK_OPS_IN,BLOCK_OPS_OUT,PAGE_FAULTS_MAJOR,PAGE_FAULTS_MINOR,SWAPS
+ -----+--------------------------------+----------+--------------+---------------+-------------------+-------------------+-------+
| SEQ | STATE | DURATION | BLOCK_OPS_IN | BLOCK_OPS_OUT
+ -----+--------------------------------+----------+--------------+---------------+-------------------+-------------------+-------+
| 2 | starting | 0.005561 | 208 |
| 3 | Executing hook on transaction | 0.000012 | 0 |
| 4 | starting | 0.000008 | 0 |
| 5 | checking permissions | 0.000005 | 0 |
| 6 | Opening tables | 0.000032 | 0 |
| 7 | init | 0.000005 | 0 |
| 8 | System lock | 0.000008 | 0 |
| 9 | optimizing | 0.000005 | 0 |
| 10 | statistics | 0.000014 | 0 |
| 11 | preparing | 0.000012 | 0 |
| 12 | executing | 5.828843 | 1425248 |
| 13 | end | 0.005782 | 504 |
| 14 | query end | 0.007523 | 632 |
| 15 | waiting for handler commit | 0.007799 | 888 |
| 16 | closing tables | 0.007178 | 576 |
| 17 | freeing items | 0.005499 | 240 |
| 18 | cleaning up | 0.005113 | 712 |
+ -----+--------------------------------+----------+--------------+---------------+-------------------+-------------------+-------+
17 rows in set , 1 warning ( 0.00 sec)
上面的profile是语句的第一次执行，需要将数据载入MySQL Innodb的缓冲池，语句的执行
阶段BLOCK_OPS_IN数值很大，这个阶段也发生了major page fault和minor page fault，
minor page fault后面再进行解释，这里看major page fault。
语句执行阶段发生的major page fault也可以从操作系统层面看到，使用pidstat命令可以可
以监控进程的page fault指标
Linux 6.11.0-29-generic (myserver) 09/24/2025 _x86_64_ (4 CPU)
02:16:11 PM UID PID minflt/s majflt/s VSZ RSS %MEM Command
02:16:19 PM 110 1136 0.00 0.00 2407056 438236 47.81 mysqld
02:16:20 PM 110 1136 55.00 23.00 2472592 438492 47.84 mysqld
02:16:21 PM 110 1136 0.00 0.00 2472592 438492 47.84 mysqld
02:16:22 PM 110 1136 0.00 0.00 2472592 438492 47.84 mysqld
02:16:23 PM 110 1136 0.00 0.00 2472592 438492 47.84 mysqld
02:16:24 PM 110 1136 249.00 0.00 2472592 439388 47.94 mysqld
02:16:25 PM 110 1136 0.00 0.00 2472592 439388 47.94 mysqld
发生了major page fault是服务器物理内存不足的征兆，原来应该在内存中的数据被交换到
了磁盘上，即操作系统的交换区内。也有可能是MySQL数据库内存参数配置的过大了，这些
过大的内存配置参数包括Innodb缓冲池大小，读缓冲、排序缓冲、tmp_table_size等。
检查操作系统，通常会发现操作系统层面使用了换页空间

root@myserver:~ # swapon
NAME TYPE SIZE USED PRIO
/swap.img file 4G 270.6M -2
4G的交换区使用了270.6M。用free命令也可以查看
root@myserver:~ # free -h
total used free shared buff/cache available
Mem: 895Mi 724Mi 90Mi 84Ki 209Mi 170Mi
Swap: 4.0Gi 270Mi 3.7Gi
2.2 Innodb缓冲池和major page fault的关系
InnoDB缓冲池是MySQL内部的内存区域，用于缓存数据和索引页。
操作系统的Major Page Fault是指当进程访问的虚拟内存页面不在物理内存中，需要从磁盘
（交换区或文件）加载时发生。
当InnoDB缓冲池不足时，MySQL无法在缓冲池中找到所需的数据页，因此需要从磁盘上的
表空间文件中读取数据页。这个磁盘读取操作是由MySQL发起的，并且是通过文件系统调用
（如read）来完成的。
但是，这里需要区分两种情况：
a) MySQL从磁盘读取数据到缓冲池：这个过程是MySQL主动发起的I/O操作，并不直接等同
于操作系统的Major Page Fault。
b) 操作系统的Major Page Fault是发生在虚拟内存管理层面的，当进程（这里是MySQL）
访问的内存地址所对应的物理页面不在内存中时，由操作系统触发。
那么，InnoDB缓冲池不足会导致Major Page Fault吗？可能间接导致，但不是直接原因。
数据库缓冲池不足是缓冲池设置过小，本来应该再内存中的数据被刷到了磁盘上，在访问时
需要再次读入到数据库缓冲区。Major Page Fault是物理内存不足，导致原来在物理内存中
内存页被换出到操作系统的换页空间上，如果是数据库缓冲区的数据被换到了磁盘上，这时
数据库缓冲区的内存区域包含了物理内存和换页空间，数据仍然是在数据库缓冲区内。
这时，查看SQL的profile，不会看到BLOCK_OPS_IN操作。反之，如果是数据库缓冲区不
足，看到的是BLOCK_OPS_IN操作，不会是major page fault。
2.3 minor page fault
也称为 soft page fault，指需要访问的内存不在虚拟地址空间，但是在物理内存中，需要M
MU建立物理内存和虚拟地址空间的映射关系即可。有两种情况下会发生minor page fault，
一是要访问的数据不再物理内存中，需要读入缓冲区，另外一种情况是访问的数据已经再缓
冲区内，但没和现在的进程或者线程使用的虚拟空间进行连接。先验证一下后面这种情况，
另开一个会话，运行同样的SQL语句，看一下语句的profile

mysql> show profile PAGE FAULTS for query 1 ;
+ --------------------------------+----------+-------------------+-------------------+
| Status | Duration | Page_faults_major | Page_faults_minor
+ --------------------------------+----------+-------------------+-------------------+
| starting | 0.000090 | 0 |
| Executing hook on transaction | 0.000007 | 0 |
| starting | 0.000012 | 0 |
| checking permissions | 0.000008 | 0 |
| Opening tables | 0.000043 | 0 |
| init | 0.000009 | 0 |
| System lock | 0.000012 | 0 |
| optimizing | 0.000008 | 0 |
| statistics | 0.000023 | 0 |
| preparing | 0.000020 | 0 |
| executing | 0.151010 | 0 |
| end | 0.000014 | 0 |
| query end | 0.000005 | 0 |
| waiting for handler commit | 0.000008 | 0 |
| closing tables | 0.000008 | 0 |
| freeing items | 0.000040 | 0 |
| cleaning up | 0.000005 | 0 |
+ --------------------------------+----------+-------------------+-------------------+
17 rows in set , 1 warning ( 0.00 sec)
再次运行语句，再看profile，就没有换页失效的情况了
mysql> show profile page faults for query 2 ;
+ --------------------------------+----------+-------------------+-------------------+
| Status | Duration | Page_faults_major | Page_faults_minor
+ --------------------------------+----------+-------------------+-------------------+
| starting | 0.000068 | 0 |
| Executing hook on transaction | 0.000004 | 0 |
| starting | 0.000007 | 0 |
| checking permissions | 0.000005 | 0 |
| Opening tables | 0.000026 | 0 |
| init | 0.000005 | 0 |
| System lock | 0.000007 | 0 |
| optimizing | 0.000004 | 0 |
| statistics | 0.000013 | 0 |
| preparing | 0.000011 | 0 |
| executing | 0.171669 | 0 |
| end | 0.000014 | 0 |
| query end | 0.000005 | 0 |
| waiting for handler commit | 0.000008 | 0 |
| closing tables | 0.000008 | 0 |
| freeing items | 0.000040 | 0 |
| cleaning up | 0.000009 | 0 |
+ --------------------------------+----------+-------------------+-------------------+
17 rows in set , 1 warning ( 0.00 sec)
minor page fault是内存连接操作，速度很快，通常不会影响数据库的性能。
2.4 Invalid Page Fault
Invalid Page Fault 翻译为无效缺页错误，比如进程访问的内存地址越界访问，又比如对空
指针解引用内核就会报segment fault错误中断进程直接挂掉。

发生了这这种无效页的错误通常是程序的bug或者是数据的错误。
3 结论
如果语句的执行过程中发生了major page fault，则要考虑到是物理内存不足的原因。当
然，也有可能是数据库的内存设置过大，导致不必要的换页。
如果发生的是BLOCK_OPS_IN，则是数据库缓冲池过小，需要扩大数据库缓冲池大小。
墨力计划 mysql性能优化
最后修改时间：2025-09-25 09:51:39
「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」
关注作者 点赞
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信息，否则作者
和墨天轮有权追究责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contact@modb.pro进行举报，并
提供相关证据，一经查实，墨天轮将立刻删除相关内容。
评论

