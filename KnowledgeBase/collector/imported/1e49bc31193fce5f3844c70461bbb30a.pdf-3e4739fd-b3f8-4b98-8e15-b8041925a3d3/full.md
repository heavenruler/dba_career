MySQL 内存使用情况排查
Cuihulong MySQL从1开始 2025年8月4日 09:25 上海
MySQ使用内存上升90%！在运维过程中50%的几率，会碰到这样的问题。算是比较普
遍的现象。
MySQL内存使用率过高，有诸多原因。普遍的情况是因为使用不当导致的，还有mysql
本身的缺陷的导致的。到底是那方面的问题，那就需要一个一个进行排查。
下面介绍排查思路：
1.参数配置需要确认。是否内存设置合理.
MySQL内存分为全局和线程级：
全局内存（如：innodb_buffer_pool_size，key_buffer_size，innodb_log_buffer
_size）
线程级内存：（如：thread，read，sort，join,tmp 等）只是在需要的时候才分
配，并且在那些操作做完之后就释放)。
线程级内存：线程缓存每个连接到MySQL服务器的线程都需要有自己的缓冲。
默认分配thread_stack（256K,512k)，空闲时这些内存是默认使用，处置之外
网络缓存，还有表缓存等。大致评估会在1M~3M这样的情况。
可通过pmap观察内存变化：while true; do pmap -d 374343 | tail -1; sleep
2; done
MySQL从1开始 赞 分享 推荐 写留言
mysql> SELECT @@query_cache_size,
@@key_buffer_size,
@@innodb_buffer_pool_size ,
@@innodb_log_buffer_size ,
@@tmp_table_size ,
@@read_buffer_size,
@@sort_buffer_size,
@@join_buffer_size ,
@@read_rnd_buffer_size,
@@binlog_cache_size,
@@thread_stack,
( SELECT COUNT (host) FROM information_schema.processlist where command<
> 'Sleep' )\G;
*************************** 1. row ***************************
@@query_cache_size:1048576
@@key_buffer_size:8388608
@@innodb_buffer_pool_size:268435456
@@innodb_log_buffer_size:8388608
@@tmp_table_size:16777216
@@read_buffer_size:131072
@@sort_buffer_size:1048576
@@join_buffer_size:1048576
@@read_rnd_buffer_size:2097152
@@binlog_cache_size:8388608
@@thread_stack:524288

( select count (host) from information_schema.processlist where command<> 'Slee
p' ): 1
备注：query_cache_size 8.0版本已经废弃掉了
2.存储过程&函数&触发器&视图
目前积累的使用经验中， 存储过程&函数&触发器&视图 在MySQL场景下不适合的。性
能又不好，又容易发现内存不释放的问题。所以建议尽量避免。
存储过程&函数
MySQL 5.7
mysql> SELECT db, type , count (*)
FROM mysql.proc
WHERE db not in ( 'mysql' , 'information_schema' , 'performance_schema' , 'sys' )
GROUP BY db, type ;
MySQL 8.0
mysql> SELECT Routine_schema, Routine_type
FROM information_schema.Routines
WHERE Routine_schema not in ( 'mysql' , 'information_schema' , 'performance_schem
a' , 'sys' )
GROUP BY Routine_schema, Routine_type;
视图
mysql> SELECT TABLE_SCHEMA , COUNT (TABLE_NAME)
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA not in ( 'mysql' , 'information_schema' , 'performance_schem
a' , 'sys' )
GROUP BY TABLE_SCHEMA ;
触发器
mysql> SELECT TRIGGER_SCHEMA, count (*)
FROM information_schema.triggers
WHERE TRIGGER_SCHEMA not in ( 'mysql' , 'information_schema' , 'performance_schem
a' , 'sys' )
GROUP BY TRIGGER_SCHEMA;
上面通过mysql配置参数和设计层面检查了是否有可能内存泄露的问题。下
面看看怎样分析实际使用的内存情况。
3.系统库统计查询
总内存使用：
mysql> SELECT
SUM ( CAST ( replace (current_alloc, 'MiB' , '' ) as DECIMAL ( 10 , 2 )) )
FROM sys.memory_global_by_current_bytes
WHERE current_alloc like '%MiB%' ;
分事件统计内存

mysql> SELECT event_name,
SUM ( CAST ( replace (current_alloc, 'MiB' , '' ) as DECIMAL ( 10 , 2 )) )
FROM sys.memory_global_by_current_bytes
WHERE current_alloc like '%MiB%' GROUP BY event_name
ORDER BY SUM ( CAST ( replace (current_alloc, 'MiB' , '' ) as DECIMAL ( 10 , 2 )) ) DESC ;
mysql> SELECT event_name,
sys.format_bytes(CURRENT_NUMBER_OF_BYTES_USED)
FROM performance_schema.memory_summary_global_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 10 ;
账号级别统计
mysql> SELECT user ,event_name,current_number_of_bytes_used/ 1024 / 1024 as MB_CURR
ENTLY_USED
FROM performance_schema.memory_summary_by_account_by_event_name
WHERE host<> "localhost"
ORDER BY current_number_of_bytes_used DESC LIMIT 10 ;
备注：有必要统计用户级别内存，因为很多环境对接了第三方插件，模拟从库，这些插
件容易内存不释放
线程对应sql 语句，内存使用统计
SELECT thread_id,
event_name,
sys.format_bytes(CURRENT_NUMBER_OF_BYTES_USED)
FROM performance_schema.memory_summary_by_thread_by_event_name
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC
LIMIT 20 ;
SELECT m.thread_id tid,
m.user,
esc.DIGEST_TEXT,
m.current_allocated,
m.total_allocated
FROM sys.memory_by_thread_by_current_bytes m,
performance_schema.events_statements_current esc
WHERE m. `thread_id` = esc.THREAD_ID \G
打开所有内存性能监控，会影响性能。注意
#打开
UPDATE performance_schema.setup_instruments SET ENABLED = 'YES' WHERE NAME LIK
E 'memory/%' ;
#关闭
UPDATE performance_schema.setup_instruments SET ENABLED = 'NO' WHERE NAME LIKE 'm
emory/%' ;
#查看使用
SELECT * FROM performance_schema.memory_summary_global_by_event_name
WHERE EVENT_NAME LIKE 'memory/%'
ORDER BY CURRENT_NUMBER_OF_BYTES_USED DESC ;
my.cnf配置文件设置：
[mysqld]
performance-schema-instrument ='memory/%=COUNTED'

最好开启之后重新启动MySQL服务，有助于准确统计。
系统表内存监控信息：
select * from sys.x$memory_by_host_by_current_bytes;
select * from sys.x$memory_by_thread_by_current_bytes;
select * from sys.x$memory_by_user_by_current_bytes;
select * from sys.x$memory_global_by_current_bytes;
select * from sys.x$memory_global_total;
select * from performance_schema.memory_summary_by_account_by_event_name;
select * from performance_schema.memory_summary_by_host_by_event_name;
select * from performance_schema.memory_summary_by_thread_by_event_name;
select * from performance_schema.memory_summary_by_user_by_event_name;
select * from performance_schema.memory_summary_global_by_event_name;
备注：找到对应问题事件或线程后，可以进行排查，解决内存高的问题。
4.系统工具查看内存
1）top命令
显示系统中各个进程的资源占用状况
Shift + m 键 查看内存排名实际使用内存情况，关注RES指标
2）free命令
free -h 命令显示系统内存的使用情况，包括物理内存、交换内存(swap)和内核缓冲区
内存
used 列显示已经被使用的物理内存和交换空间。
buff/cache 列显示被 buffer 和 cache 使用的物理内存大小。
available 列显示还可以被应用程序使用的物理内存大小。
Swap 行(第三行)是交换空间的使用情况。
3）ps命令
mysql相关进程使用内存情况
shell > ps eo user,pid,vsz,rss $(pgrep -f 'mysqld')
USER PID VSZ RSS
root 215945 12960 2356
mysql 217246 1291540 241824
root 221056 12960 2428
mysql 374243 1336924 408752
4）pmap 命令
pmap 是Linux调试及运维一个很好的工具。查看进程的内存映像信息
用法1：执行一段时间 记录数据变化，最少20个记录，下面22837是mysql pid
while true; do pmap -d 22837 | tail -1; sleep 2; done
用法2：linux 命令pmap mysql pid 导出内存 ，下面22837是mysql pid
pmap -X -p 22837 > /tmp/memmysql.txt
RSS 就是这个process 实际占用的物理内存。
Dirty: 脏页的字节数（包括共享和私有的）。

Mapping: 占用内存的文件、或[anon]（分配的内存）、或[stack]（堆栈）。
writeable/private 表示进程所占用的私有地址空间大小，也就是该进程实际使用的内存
大小。
1.首先使用/top/free/ps在系统级确定是否有内存泄露。如有，可以从top输出确定哪一
个process。
2.pmap工具是能帮助确定process是否有memory leak。确定memory leak的原则：
writeable/private (‘pmap –d’输出）如果在做重复的操作过程中一直保持稳定增长，
那么一定有内存泄露。
总结
对于mysql内存泄露来说，
从参数设置和设计上 尽量好合理
需要通过ps库进行排查
linux工具进行进一步确认
官方bug里 memory leak查找，是否存在修复的版本
以上排查里都没有找到原因，可以换下服务器或主从切换观察。也可以进行版本升级
（代价不小）。
如：能提供一个实际环境，也可以一步一步进行调试，抓取内存变化，确定是什么导致
内存泄露的问题。之后提交bug，让官方提供修复。

Pade 6
MySQL 內 存 使 用 情 況 排 查
https﹕//mp﹒weixin﹒qq﹒com/s/7OAD4Pnc4ydwf7AAXxJAhiA
Captured by Fireshot Pro﹕ 11 1 月 2025， 01﹕1l﹕22
https﹕//dgdetfireshot﹒com

