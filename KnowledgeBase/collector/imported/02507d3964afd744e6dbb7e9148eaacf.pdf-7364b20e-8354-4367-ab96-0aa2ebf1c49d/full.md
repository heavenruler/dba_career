MySQL内存使⽤率⾼问题排查
本⽂为墨天轮数据库管理服务团队原创内容，如需转载请联系⼩墨（VX：modb666）并注明来源。
作者：蔡璐
墨天轮数据库管理服务团队技术顾问
⼗年数据库技术顾问经验，所服务的⾏业包括银⾏、消费、政企、电信运营商、制造业等；个⼈专项数
据库领域：MySQL，PostgreSQL、openGauss，擅⻓数据库架构设计、容灾解决⽅案及数据库的⽇常
管理、疑难故障诊断、性能优化、迁移升级改造等。
⼀、问题现象
问题实例 mysql 进程实际内存使⽤率过⾼
⼆、问题排查
2.1 参数检查
蔡璐 2025年02⽉26⽇ 15:00 湖北原创 墨天轮
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 1/10

mysql 版本  ： 8.0.39 ，慢⽇志没有开启， innodb_buffer_pool_size 12G （机器内存 62G ，相
对配置较低），临时⽂件在 /tmp ⽬录下
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 2/10

2.2 检查内存使⽤
SELECT @@key_buffer_size,
@@innodb_buffer_pool_size ,
@@innodb_log_buffer_size ,
@@tmp_table_size ,
@@read_buffer_size,
@@sort_buffer_size,
@@join_buffer_size ,
@@read_rnd_buffer_size,
@@binlog_cache_size,
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 3/10

@@thread_stack,
(SELECT COUNT(host) FROM  information_schema.processlist where command<>
2.3 存储过程、函数、视图
-- 存储过程、函数
SELECT  Routine_schema, Routine_type
FROM information_schema.Routines
WHERE  Routine_schema not in ('mysql','information_schema','performance_schema
GROUP BY Routine_schema, Routine_type;
-- 视图
SELECT  TABLE_SCHEMA , COUNT(TABLE_NAME)
FROM information_schema.VIEWS
WHERE TABLE_SCHEMA not in ('mysql','information_schema','performance_schema',
GROUP BY TABLE_SCHEMA ;
-- 触发器
SELECT TRIGGER_SCHEMA, count(*)
FROM information_schema.triggers
WHERE  TRIGGER_SCHEMA not in ('mysql','information_schema','performance_schema
GROUP BY TRIGGER_SCHEMA;
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 4/10

2.4 排查实际占⽤
1 、总内存使⽤
SELECT
SUM(CAST(replace(current_alloc,'MiB','')  as DECIMAL(10, 2))  )
FROM sys.memory_global_by_current_bytes
WHERE current_alloc like '%MiB%';
2 、分事件统计内存
SELECT event_name,
SUM(CAST(replace(current_alloc,'MiB','')  as DECIMAL(10, 2))  )
FROM sys.memory_global_by_current_bytes
WHERE current_alloc like '%MiB%' GROUP BY event_name
ORDER BY SUM(CAST(replace(current_alloc,'MiB','')  as DECIMAL(10, 2))  )
mysql> SELECT event_name,
sys.format_bytes(CURRENT_NUMBER_OF_BYTES_USED)
FROM performance_schema.memory_summary_global_by_event_name
ORDER BY  CURRENT_NUMBER_OF_BYTES_USED DESC
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 5/10

LIMIT 10;
3 、账号级别统计
sELECT user,event_name,current_number_of_bytes_used/1024/1024 as MB_CURRENTLY_
FROM performance_schema.memory_summary_by_account_by_event_name
WHERE host<>"localhost"
ORDER BY  current_number_of_bytes_used DESC LIMIT 10;
2.4 操作系统排查
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 6/10

1 、 top shift+m
2 、 ps 命令  mysql 相关进程使⽤内存情况
ps eo user,pid,vsz,rss $(pgrep -f 'mysqld')
3 、 pmap 命令
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 7/10

while true; do pmap -d 3020273 | tail -1; sleep 2; done
pmap -X -p 3020273 > /tmp/memmysql.txt
RSS 就是这个 process 实际占⽤的物理内存。
Dirty: 脏⻚的字节数（包括共享和私有的）。
Mapping: 占⽤内存的⽂件、或 [anon] （分配的内存）、或 [stack] （堆栈）。
writeable/private 表⽰进程所占⽤的私有地址空间⼤⼩，也就是该进程实际使⽤的内存⼤⼩。
（ 1 ）⾸先使⽤ /top/free/ps 在系统级确定是否有内存泄露。如有，可以从 top 输出确定哪⼀个
process 。
（ 2 ） pmap ⼯具是能帮助确定 process 是否有 memory leak 。确定 memory leak 的原则：
writeable/private (‘pmap –dʼ 输出）如果在做重复的操作过程中⼀直保持稳定增⻓，那么⼀定
有内存泄露。
4 、检查⼤⻚配置
三、解决⽅案
1 ）临时关闭：
echo never >> /sys/kernel/mm/transparent_hugepage/enabled
echo never >> /sys/kernel/mm/transparent_hugepage/defrag
2 ）永久关闭，下⼀次重启后⽣效：
在  /etc/rc.local ⽂件中加入如下内容：
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 8/10

阅读原⽂
#!/bin/sh
#
# This script will be executed *after* all the other init scripts.
# You can put your own initialization stuff in here if you don't
# want to do the full Sys V style init stuff.
touch /var/lock/subsys/local
if test -f /sys/kernel/mm/transparent_hugepage/enabled; then
echo never > /sys/kernel/mm/transparent_hugepage/enabled
fi
if test -f /sys/kernel/mm/transparent_hugepage/defrag; then
echo never > /sys/kernel/mm/transparent_hugepage/defrag
THE END
墨天轮从乐知乐享的数据库技术社区蓄势出发，全⾯升级，提供多类型数据库管理服务。墨天轮数据
库管理服务旨在为⽤户构建信赖可托付的数据库环境，并为数据库⼚商提供中立的⽣态⽀持。
服务官⽹：https://www.modb.pro/service
点击进入作者个⼈主⻚
MySQL 67
数据库677
技术分享 | 墨天轮数据库服务团队82
MariaDB 2
MySQL · ⽬录
上⼀篇
您希望仅记录对数据库对象和数据在 MySQL
系统上所做的更改。以下哪个⽇志默认会做…
下⼀篇
MySQL DDL后执⾏计划乱了？
2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 9/10

2025/6/4 凌晨 12:58 MySQL 内存使⽤率⾼问题排查
https://mp.weixin.qq.com/s/YBY5T34M6xWq24lS8vKZlQ 10/10

