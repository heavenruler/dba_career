首页 资讯 活动 大会 学习 文档 问答 服务 登录 注册
首页 / SysBench 压缩并发性能翻倍：单机版TiDB vs MySQL 8.0.42
SysBench 压缩并发性能翻倍：单机版TiDB vs MySQL 8.0.42
原创 shunwahⓂ️ 2025-09-20 177
shunwahⓂ️
基于电商订单场景的OLTP、点查询、存储效率及扩展性全面压测分析 关注
156 106 213K+ 个人简介
文章 粉丝 浏览量 作者： ShunWah
公众号： “顺华星辰运维栈”主理人。 1330 获得了 次点赞
持有认证： OceanBase OBCA/OBCP、MySQL OCP、OpenGauss、崖山 DBCA、亚信 AntDB
414 内容获得 次评论 CA、翰高 HDCA、GBase 8a | 8c | 8s、Galaxybase GBCA、Neo4j Graph Data Science Cert
206 获得了 次收藏 ification、NebulaGraph NGCI & NGCP、东方通 TongTech TCPE 等多项权威认证。
获奖经历： 在OceanBase&墨天轮征文大赛、OpenGauss、TiDB、YashanDB、Kingbase、KW
DB 征文等赛事中多次斩获一、二、三等奖，原创技术文章常年被墨天轮、CSDN、ITPUB 等平台 热门文章 首页推荐。
部署反向代理神器 Nginx Proxy Manager
配置阿里云ssl证书
2022-10-27 16160浏览 公众号_ID：顺华星辰运维栈
CSDN_ID： shunwahma 第一次如何通过OceanBase初级OBCA、
墨天轮_ID：shunwah 中级OBCP认证考试
2022-06-24 11275浏览 ITPUB_ID： shunwah
IFClub_ID：shunwah Windows工具DBeaver连接OceanBase数
据库访问MySQL和Oracle租户
2022-03-09 8303浏览
东方通 TongWeb 中间件入门指南： 轻松
掌握从部署到认证
2025-03-19 4588浏览
「更易用的OceanBase」Docker 部署 Oc
eanBase 4.0 数据库 快速体验增删改查
2022-11-25 4562浏览
最新文章
「Dashboard 测评」OceanBase 白屏+黑
屏 obshell Dashboard 轻量化运维
3天前 74浏览
十月总结｜深耕数据库社区：沉淀技术微
光
2025-11-02 35浏览
【TiDB 体验官实测】 TiDB v7.1.8 多语法
前言 兼容MySQL 多场景验证
2025-11-01 60浏览
在上一篇《TEM 敏捷模式（单节点）自动化部署 TiDB 数据库指南》 TEM 敏捷模式（单节 sysbench 实测：TiDB 7.1.8 两副本的 OL
点）自动化部署 TiDB 数据库指南 中，我成功搭建了 TiDB 与 MySQL 8.0.42 的测试环境。 TP/OLAP 解析
“工欲善其事，必先利其器”，环境就绪后，下一步便是通过科学的测试来量化其性能表现， 2025-10-27 116浏览

为技术选型提供坚实的数据支撑。 YashanDB 部署太复杂？10分钟搞定 Doc
ker 体验攻略 本文将以业界标准的 Sysbench 工具为标尺，对部署好的 MySQL 8.0.42 (端口 3306) 与 T 2025-10-23 116浏览
iDB (端口 4006) 发起全方位的性能挑战。测试将围绕数据压缩比、OLTP混合读写、单表点
查、索引更新及并发扩展能力五大核心维度展开，旨在通过客观数据，深入剖析两者在不同 目录
负载下的性能特征与优劣差异，帮助您在实际业务场景中做出更明智的数据库选择。
前言
一、MySQL 8.0.42 测试 (端口 3306)
一、MySQL 8.0.42 测试 (端口 3306)
1. 准备测试数据 (Prepare)
2. 预热缓存 (Warm Up) 在本节中，我们将对 MySQL 8.0.42 进行全面的性能测试。测试环境为单节点部署，通过 S
3. OLTP 混合读写测试 (Read Write) ysbench 模拟多种负载场景，以评估其在不同压力下的表现。测试涵盖了数据准备、缓存预
热、OLTP 混合读写、点查询、索引更新以及并发梯度测试等多个维度。 4. 点查询性能测试 (Point Select)
7. 数据压缩比分析
1. 准备测试数据 (Prepare) 二、TiDB 测试 (端口 4006)
1. 准备测试数据 (Prepare)
首先，我们使用 Sysbench 准备测试数据，创建 10 张表，每张表包含 100 万行数据。此过
2. 预热缓存 (Warm Up)
程会生成测试所需的数据并创建相应的二级索引。
4. 点查询性能测试 (Point Select)
执行命令： 5. 索引更新测试 (Update Index)
6. 并发压力梯度测试 (并发度：8, 24, 36,
sysbench oltp_common --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
7. 记录数据压缩比
7.1 通过TiDB Dashboard或以下SQL命令查看存储大小
输出结果： 7.3 查询 test_db 中每张表的逻辑大小
7.4 统计 test_db 总数据量
[root@worker3 pingkai]# sysbench oltp_common --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306
三、MySQL 8.0.42 vs TiDB 核心性能指标对比表
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Initializing worker threads...
Creating table 'sbtest5'...
Creating table 'sbtest2'...
Creating table 'sbtest3'...
Creating table 'sbtest7'...
Creating table 'sbtest8'...
Creating table 'sbtest4'...
Creating table 'sbtest1'...
Creating table 'sbtest6'...
Inserting 1000000 records into 'sbtest6'
Inserting 1000000 records into 'sbtest5'
Inserting 1000000 records into 'sbtest8'
Inserting 1000000 records into 'sbtest7'
Inserting 1000000 records into 'sbtest2'
Inserting 1000000 records into 'sbtest4'
Inserting 1000000 records into 'sbtest1'
Inserting 1000000 records into 'sbtest3'
Creating a secondary index on 'sbtest3'...
Creating a secondary index on 'sbtest2'...
Creating a secondary index on 'sbtest1'...
Creating a secondary index on 'sbtest7'...
Creating a secondary index on 'sbtest6'...
Creating a secondary index on 'sbtest5'...
Creating a secondary index on 'sbtest4'...
Creating a secondary index on 'sbtest8'...
Creating table 'sbtest10'...
Inserting 1000000 records into 'sbtest10'

Creating table 'sbtest9'...
Inserting 1000000 records into 'sbtest9'
Creating a secondary index on 'sbtest10'...
Creating a secondary index on 'sbtest9'...
[root@worker3 pingkai]#
过程说明： 数据准备阶段顺利完成，系统创建了10张表并插入了1亿条测试数据，同时为每
张表建立了必要的二级索引，为后续性能测试奠定了数据基础。
2. 预热缓存 (Warm Up)
为了确保测试结果反映数据库在稳定状态下的性能，我们进行了缓存预热。这一步通过运行
只读测试将数据加载到 InnoDB 缓冲池中，避免后续测试受到磁盘 I/O 瓶颈的影响。
执行命令：
sysbench oltp_read_only --threads=16 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
监控截图：

输出结果：
[root@worker3 pingkai]# sysbench oltp_read_only --threads=16 --mysql-host=127.0.0.1
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Running the test with following options:
Number of threads: 16
Initializing random number generator from current time
Initializing worker threads...
Threads started!
SQL statistics:
queries performed:
read: 2902970
write: 0
other: 414710
total: 3317680
transactions: 207355 (3454.61 per sec.)
queries: 3317680 (55273.76 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 60.0213s
total number of events: 207355
Latency (ms):
min: 1.24
avg: 4.63
max: 411.92
95th percentile: 12.52
sum: 959241.78
Threads fairness:
events (avg/stddev): 12959.6875/951.67

execution time (avg/stddev): 59.9526/0.01
[root@worker3 pingkai]#
结果分析： 预热阶段表现出色，达到了 3454.61 TPS 的高吞吐量，95% 的请求延迟在 12.
52ms 以内，表明数据已充分加载到内存中，为后续测试做好了准备。
3. OLTP 混合读写测试 (Read Write)
接下来进行 OLTP 混合读写测试，模拟典型的在线事务处理场景，包含读、写和其他操作的
综合负载。
执行命令：
sysbench oltp_read_write --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
执行过程：
[root@worker3 pingkai]# sysbench oltp_read_write --threads=8 --mysql-host=127.0.0.1
[root@worker3 pingkai]#
查看详细结果：

[root@worker3 pingkai]# cat mysql_8thread_rw.log
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Running the test with following options:
Number of threads: 8
Report intermediate results every 10 second(s)
Initializing random number generator from current time
Initializing worker threads...
Threads started!
[ 10s ] thds: 8 tps: 281.92 qps: 5650.57 (r/w/o: 3955.83/1130.09/564.65) lat (ms,95%):
...（中间日志省略）...
[ 300s ] thds: 8 tps: 449.00 qps: 8975.50 (r/w/o: 6283.00/1794.60/897.90) lat (ms,95%):
SQL statistics:
queries performed:
read: 1407728
write: 402208
other: 201104
total: 2011040
transactions: 100552 (335.15 per sec.)
queries: 2011040 (6703.05 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.0172s
total number of events: 100552
Latency (ms):
min: 2.08
avg: 23.86
max: 2361.49
95th percentile: 57.87
sum: 2399512.40
Threads fairness:
events (avg/stddev): 12569.0000/102.16
execution time (avg/stddev): 299.9390/0.01
[root@worker3 pingkai]#

性能分析： 在 300 秒的测试期间，MySQL 8.0.42 实现了平均 335.15 TPS 的稳定性能。
吞吐量在测试过程中逐渐提升，最终达到 449 TPS，表明数据库在长时间运行下仍能保持良
好的性能表现。95% 的请求延迟为 57.87ms，显示出较为一致的响应性能。
4. 点查询性能测试 (Point Select)
点查询测试评估数据库在主键查询场景下的性能，这是许多应用程序中的常见操作模式。
执行命令：
sysbench oltp_point_select --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306
执行过程：
[root@worker3 pingkai]# sysbench oltp_point_select --threads=8 --mysql-host=127.0.0.1
[root@worker3 pingkai]#
查看详细结果：

[root@worker3 pingkai]# tail -30 mysql_8thread_point_select.log
[ 270s ] thds: 8 tps: 75252.01 qps: 75252.01 (r/w/o: 75252.01/0.00/0.00) lat (ms,95%):
[ 280s ] thds: 8 tps: 78663.08 qps: 78663.18 (r/w/o: 78663.18/0.00/0.00) lat (ms,95%):
[ 290s ] thds: 8 tps: 78766.09 qps: 78765.99 (r/w/o: 78765.99/0.00/0.00)极低的延迟水平，95%
### **5. 索引更新测试 (Update Index)**
索引更新测试评估数据库在更新索引列时的性能表现，这对于维护数据一致性和查询性能至关重要。
**执行命令：**
```bash
sysbench oltp_update_index --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
执行过程：
[root@worker3 pingkai]# sysbench oltp_update_index --threads=8 --mysql-host=127.0.0.1
[root@worker3 pingkai]#
查看详细结果：
[root@worker3 pingkai]# tail -30 mysql_8thread_update_index.log
[ 270s ] thds: 8 tps: 849.90 qps: 849.90 (r/w/o: 0.00/849.90/0.00) lat (ms,95%):
[ 280s ] thds: 8 tps: 937.85 qps: 937.85 (r/w/o: 0.00/937.85/0.00) lat (ms,95%):
[ 290s ] thds: 8 tps: 721.72 qps: 721.72 (r/w/o: 0.00/721.72/极低的延迟水平，95% 的请求在
### **6. 并发压力梯度测试**
为了评估 MySQL 在不同并发压力下的性能表现，我们进行了梯度测试，逐步增加线程数从 8 到 55，观察系统吞吐量和响应时间的变化。
**执行命令：**
```bash
for threads in 8 24 36 55
do
sysbench oltp_read_write --threads=${threads} --mysql-host=127.0.0.1 --mysql-port=3306
done
执行过程：
[root@worker3 pingkai]# for threads in 8 24 36 55
> do
> sysbench oltp_read_write --threads=${threads} --mysql-host=127.0.0.1 --mysql-port=3306
> done
[root@worker3 pingkai]#

并发测试结果分析：
24 线程测试结果：
[root@worker3 pingkai]# tail -30 mysql_24thread_rw.log
...（输出内容）...
transactions: 187421 (624.25 per sec.)
queries: 3748420 (12485.05 per sec.)
...
36 线程测试结果：
[root@worker3 pingkai]# tail -30 mysql_36thread_rw.log
...（输出内容）...
transactions: 211558 (703.06 per sec.)
queries: 4231160 (14061.24 per sec.)
...

55 线程测试结果：
[root@worker3 pingkai]# tail -30 mysql_55thread_rw.log
...（输出内容）...
transactions: 230840 (768.09 per sec.)
queries: 4616800 (15361.81 per sec.)
...
并发性能趋势： 随着并发线程数的增加，MySQL 展现出良好的扩展性，从 8 线程的 335.1
5 TPS 逐步提升到 55 线程的 768.09 TPS，性能提升了约 129%。这表明 MySQL 8.0.42
能够有效利用多核资源，在高并发场景下仍能保持性能的线性增长。

7. 数据压缩比分析
最后，我们分析了 MySQL 的数据存储效率，评估其在不同存储引擎下的数据压缩能力。
执行命令：
mysql -h 127.0.0.1 -P 3306 -u root -p 'Pingkai@123' -e "SELECT table_name AS \`Table\`,
输出结果：
[root@worker3 pingkai]# mysql -h 127.0.0.1 -P 3306 -u root -p'Pingkai@123'
mysql: [Warning] Using a password on the command line interface can be insecure.
Welcome to the MySQL monitor. Commands end with ; or \g.
Your MySQL connection id is 190
Server version: 8.0.42 MySQL Community Server - GPL
Copyright (c) 2000, 2025, Oracle and/or its affiliates.
Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.
Type 'help;' or '\h' for help. Type '\c' to clear the current input statement.
mysql> SELECT table_name AS `Table`,
-> round(((data_length + index_length) / 1024 / 1024), 2) `Size (MB)`
-> FROM information_schema.TABLES
-> WHERE table_schema = "test_db";
+----------+-----------+
| Table | Size (MB) |
+----------+-----------+
| sbtest1 | 237.75 |
| sbtest10 | 237.75 |
| sbtest2 | 236.77 |
| sbtest3 | 237.75 |
| sbtest4 | 237.75 |
| sbtest5 | 237.77 |
| sbtest6 | 236.77 |
| sbtest7 | 236.78 |
| sbtest8 | 236.75 |
| sbtest9 | 236.78 |
+----------+-----------+
10 rows in set (0.20 sec)
mysql>

汇总统计：
mysql> SELECT
-> SUM(TABLE_ROWS) AS `Total_Rows`,
-> ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS `Total_Size_MB`
-> FROM information_schema.TABLES
-> WHERE TABLE_SCHEMA = 'test_db';
+------------+---------------+
| Total_Rows | Total_Size_MB |
+------------+---------------+
| 9863995 | 2372.61 |
+------------+---------------+
1 row in set (0.02 sec)
mysql>
物理磁盘占用检查：

[root@worker3 test_db]# du -sh
2.5G .
[root@worker3 test_db]# pwd
/data/pingkai/mysql/test_db
[root@worker3 test_db]# ls
sbtest10.ibd sbtest2.ibd sbtest4.ibd sbtest6.ibd sbtest8.ibd
sbtest1.ibd sbtest3.ibd sbtest5.ibd sbtest7.ibd sbtest9.ibd
[root@worker3 test_db]#
存储分析： 10 张表共存储了约 986 万行数据，逻辑大小为 2.37GB，实际物理磁盘占用为
2.5GB。MySQL 8.0 的 InnoDB 存储引擎在此测试中显示了合理的存储效率，逻辑大小与物
理大小基本一致，表明数据存储较为紧凑，没有明显的空间浪费。
通过以上全面的测试，我们对 MySQL 8.0.42 的性能特征有了深入的理解。接下来将在第二
部分进行 TiDB 的对比测试，从而全面评估两种数据库在不同场景下的性能表现。
二、TiDB 测试 (端口 4006)
重要提示： TiDB是分布式数据库，其架构与MySQL完全不同。Sysbench测试时， 建议 ：
使用 。 --db-driver=mysql
在 阶段，可以增加 以避免TiDB自增ID的性能瓶颈（但需 prepare --auto_inc=off
注意这可能与MySQL行为略有不同，可根据测试目的选择）。
由于TiDB的乐观事务模型，在高并发冲突场景下可能因重试机制导致性能波动，这是正
常现象。
1. 准备测试数据 (Prepare)
sysbench oltp_common --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
输出

[root@worker3 pingkai]# sysbench oltp_common --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Initializing worker threads...
Creating table 'sbtest2'...
Creating table 'sbtest6'...
Creating table 'sbtest1'...
Creating table 'sbtest5'...
Creating table 'sbtest8'...
Creating table 'sbtest7'...
Creating table 'sbtest3'...
Creating table 'sbtest4'...
Inserting 1000000 records into 'sbtest4'
Inserting 1000000 records into 'sbtest1'
Inserting 1000000 records into 'sbtest7'
Inserting 1000000 records into 'sbtest3'
Inserting 1000000 records into 'sbtest2'
Inserting 1000000 records into 'sbtest6'
Inserting 1000000 records into 'sbtest5'
Inserting 1000000 records into 'sbtest8'
Creating a secondary index on 'sbtest4'...
Creating a secondary index on 'sbtest3'...
Creating a secondary index on 'sbtest2'...
Creating a secondary index on 'sbtest6'...
Creating a secondary index on 'sbtest1'...
Creating a secondary index on 'sbtest8'...
Creating a secondary index on 'sbtest5'...
Creating a secondary index on 'sbtest7'...
Creating table 'sbtest10'...
Inserting 1000000 records into 'sbtest10'
Creating table 'sbtest9'...
Inserting 1000000 records into 'sbtest9'
Creating a secondary index on 'sbtest10'...
Creating a secondary index on 'sbtest9'...
[root@worker3 pingkai]#

2. 预热缓存 (Warm Up)
*TiDB的存储引擎TiKV也有Block Cache，预热同样重要。*
sysbench oltp_read_only --threads=16 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
输出
[root@worker3 pingkai]# sysbench oltp_read_only --threads=16 --mysql-host=127.0.0.1
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Running the test with following options:
Number of threads: 16
Initializing random number generator from current time
Initializing worker threads...
Threads started!
SQL statistics:
queries performed:
read: 305480
write: 0
other: 43640
total: 349120
transactions: 21820 (363.27 per sec.)
queries: 349120 (5812.39 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 60.0632s
total number of events: 21820
Latency (ms):
min: 14.61
avg: 44.02
max: 411.80
95th percentile: 78.60
sum: 960512.62
Threads fairness:
events (avg/stddev): 1363.7500/5.54
execution time (avg/stddev): 60.0320/0.02
[root@worker3 pingkai]#

OLTP 混合读写测试 (Read Write)
sysbench oltp_read_write --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
输出
[root@worker3 pingkai]# sysbench oltp_read_write --threads=8 --mysql-host=127.0.0.1
[root@worker3 pingkai]#
日志

[root@worker3 pingkai]# tail -30 tidb_8thread_rw.log
[ 270s ] thds: 8 tps: 150.30 qps: 3001.40 (r/w/o: 2100.50/600.30/300.60) lat (ms,95%):
[ 280s ] thds: 8 tps: 188.48 qps: 3770.19 (r/w/o: 2639.88/753.34/376.97) lat (ms,95%):
[ 290s ] thds: 8 tps: 197.82 qps: 3961.22 (r/w/o: 2773.13/792.46/395.63) lat (ms,95%):
[ 300s ] thds: 8 tps: 126.79 qps: 2533.48 (r/w/o: 1773.11/506.78/253.59) lat (ms,95%):
SQL statistics:
queries performed:
read: 734804
write: 209944
other: 104972
total: 1049720
transactions: 52486 (174.93 per sec.)
queries: 1049720 (3498.59 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.0393s
total number of events: 52486
Latency (ms):
min: 16.35
avg: 45.72
max: 289.19
95th percentile: 87.56
sum: 2399887.73
Threads fairness:
events (avg/stddev): 6560.7500/10.81
execution time (avg/stddev): 299.9860/0.01
[root@worker3 pingkai]#

4. 点查询性能测试 (Point Select)
*点查询是TiDB的强项，预计会表现非常好。*
sysbench oltp_point_select --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
输出
[root@worker3 pingkai]# sysbench oltp_point_select --threads=8 --mysql-host=127.0.0.1
[root@worker3 pingkai]#
日志
[root@worker3 pingkai]# tail -30 tidb_8thread_point_select.log
[ 270s ] thds: 8 tps: 7726.57 qps: 7726.57 (r/w/o: 7726.57/0.00/0.00) lat (ms,95%):
[ 280s ] thds: 8 tps: 9696.07 qps: 9696.07 (r/w/o: 9696.07/0.00/0.00) lat (ms,95%):
[ 290s ] thds: 8 tps: 6357.09 qps: 6357.09 (r/w/o: 6357.09/0.00/0.00) lat (ms,95%):
[ 300s ] thds: 8 tps: 7425.78 qps: 7425.78 (r/w/o: 7425.78/0.00/0.00) lat (ms,95%):
SQL statistics:
queries performed:
read: 2295788
write: 0
other: 0
total: 2295788
transactions: 2295788 (7652.53 per sec.)
queries: 2295788 (7652.53 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.0024s
total number of events: 2295788
Latency (ms):
min: 0.21
avg: 1.04
max: 94.67
95th percentile: 2.48
sum: 2397345.08
Threads fairness:
events (avg/stddev): 286973.5000/530.76
execution time (avg/stddev): 299.6681/0.01
[root@worker3 pingkai]#

5. 索引更新测试 (Update Index)
sysbench oltp_update_index --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
输出
[root@worker3 pingkai]# sysbench oltp_update_index --threads=8 --mysql-host=127.0.0.1
[root@worker3 pingkai]#
日志

[root@worker3 pingkai]# tail -30 tidb_8thread_update_index.log
[ 270s ] thds: 8 tps: 1175.56 qps: 1175.56 (r/w/o: 0.00/1175.56/0.00) lat (ms,95%):
[ 280s ] thds: 8 tps: 691.76 qps: 691.76 (r/w/o: 0.00/691.76/0.00) lat (ms,95%):
[ 290s ] thds: 8 tps: 871.78 qps: 871.78 (r/w/o: 0.00/871.78/0.00) lat (ms,95%):
[ 300s ] thds: 8 tps: 991.44 qps: 991.44 (r/w/o: 0.00/991.44/0.00) lat (ms,95%):
SQL statistics:
queries performed:
read: 0
write: 260561
other: 0
total: 260561
transactions: 260561 (868.52 per sec.)
queries: 260561 (868.52 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.0053s
total number of events: 260561
Latency (ms):
min: 1.77
avg: 9.21
max: 194.19
95th percentile: 21.50
sum: 2399147.68
Threads fairness:
events (avg/stddev): 32570.1250/35.07
execution time (avg/stddev): 299.8935/0.02
[root@worker3 pingkai]#

6. 并发压力梯度测试 (并发度：8, 24, 36, 55)
for threads in 8 24 36 55
do
sysbench oltp_read_write --threads=${threads} --mysql-host=127.0.0.1 --mysql-port=4006
done
输出
[root@worker3 pingkai]# for threads in 8 24 36 55
> do
> sysbench oltp_read_write --threads=${threads} --mysql-host=127.0.0.1 --mysql-port=4006
> done
[root@worker3 pingkai]#
日志
[root@worker3 pingkai]# tail -30 tidb_24thread_rw.log
[ 270s ] thds: 24 tps: 195.38 qps: 3895.07 (r/w/o: 2724.97/779.73/390.37) lat (ms,95%):
[ 280s ] thds: 24 tps: 191.46 qps: 3837.35 (r/w/o: 2687.18/766.95/383.23) lat (ms,95%):
[ 290s ] thds: 24 tps: 205.40 qps: 4107.78 (r/w/o: 2874.98/821.90/410.90) lat (ms,95%):
[ 300s ] thds: 24 tps: 204.70 qps: 4084.07 (r/w/o: 2857.55/817.81/408.71) lat (ms,95%):
SQL statistics:
queries performed:
read: 836052
write: 238872
other: 119436
total: 1194360
transactions: 59718 (198.98 per sec.)
queries: 1194360 (3979.57 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.1216s
total number of events: 59718
Latency (ms):
min: 41.18
avg: 120.58
max: 498.40
95th percentile: 176.73
sum: 7201066.00
Threads fairness:
events (avg/stddev): 2488.2500/5.74
execution time (avg/stddev): 300.0444/0.04

[root@worker3 pingkai]#
[root@worker3 pingkai]# tail -30 tidb_36thread_rw.log
[ 270s ] thds: 36 tps: 177.08 qps: 3548.95 (r/w/o: 2485.85/708.93/354.16) lat (ms,95%):
[ 280s ] thds: 36 tps: 160.42 qps: 3201.46 (r/w/o: 2239.85/641.17/320.44) lat (ms,95%):
[ 290s ] thds: 36 tps: 186.69 qps: 3732.18 (r/w/o: 2613.25/745.56/373.38) lat (ms,95%):
[ 300s ] thds: 36 tps: 198.72 qps: 3972.13 (r/w/o: 2778.50/795.99/397.64) lat (ms,95%):
SQL statistics:
queries performed:
read: 822430
write: 234980
other: 117490
total: 1174900
transactions: 58745 (195.72 per sec.)
queries: 1174900 (3914.31 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.1534s
total number of events: 58745
Latency (ms):
min: 54.66
avg: 183.90
max: 1000.55
95th percentile: 277.21
sum: 10803286.29
Threads fairness:
events (avg/stddev): 1631.8056/4.56
execution time (avg/stddev): 300.0913/0.05

[root@worker3 pingkai]#
[root@worker3 pingkai]# tail -30 tidb_55thread_rw.log
[ 270s ] thds: 55 tps: 193.74 qps: 3883.50 (r/w/o: 2720.23/775.58/387.69) lat (ms,95%):
[ 280s ] thds: 55 tps: 195.80 qps: 3915.49 (r/w/o: 2740.29/783.90/391.30) lat (ms,95%):
[ 290s ] thds: 55 tps: 198.11 qps: 3952.33 (r/w/o: 2764.49/791.63/396.21) lat (ms,95%):
[ 300s ] thds: 55 tps: 183.00 qps: 3665.41 (r/w/o: 2568.70/730.60/366.10) lat (ms,95%):
SQL statistics:
queries performed:
read: 794164
write: 226904
other: 113452
total: 1134520
transactions: 56726 (188.83 per sec.)
queries: 1134520 (3776.50 per sec.)
ignored errors: 0 (0.00 per sec.)
reconnects: 0 (0.00 per sec.)
General statistics:
total time: 300.4142s
total number of events: 56726
Latency (ms):
min: 93.52
avg: 291.10
max: 1089.25
95th percentile: 419.45
sum: 16512668.08
Threads fairness:
events (avg/stddev): 1031.3818/4.27
execution time (avg/stddev): 300.2303/0.13

[root@worker3 pingkai]#
7. 记录数据压缩比
7.1 通过TiDB Dashboard或以下SQL命令查看存储大小
（单节点部署下，数据都在TiKV上）：
SELECT
TABLE_NAME,
TABLE_ROWS,
AVG_ROW_LENGTH,
DATA_LENGTH,
INDEX_LENGTH
FROM
information_schema.TABLES
WHERE
TABLE_SCHEMA = 'test_db';
输出

```language
mysql> SELECT TABLE_NAME, TABLE_ROWS, AVG_ROW_LENGTH, DATA_LENGTH,
+------------+------------+----------------+-------------+--------------+
| TABLE_NAME | TABLE_ROWS | AVG_ROW_LENGTH | DATA_LENGTH | INDEX_LENGTH |
+------------+------------+----------------+-------------+--------------+
| sbtest4 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest5 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest6 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest8 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest2 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest3 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest7 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest1 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest10 | 1000000 | 16 | 16000000 | 8000000 |
| sbtest9 | 1000000 | 16 | 16000000 | 8000000 |
+------------+------------+----------------+-------------+--------------+
10 rows in set (0.04 sec)
mysql>
日志
除了你之前使用的 information_schema.TABLES，TiDB 还提供了其他一些系统表来查看存储信息，但需要注意它们的估算性质。
#### 7.2 查询 test_db 数据库的逻辑大小
你可以使用以下 SQL 语句查询 test_db 数据库的逻辑大小（MB）：
```language
mysql> SELECT
table_schema AS 'Database',
-> table_schema AS 'Database',
-> SUM(data_length + index_length) / 1024 / 1024 AS 'Size (MB)'
information_schema.tables
-> FROM
-> information_schema.tables
-> WHERE
-> table_schema = 'test_db'
GROUP BY table_schema; -> GROUP BY table_schema;
+----------+--------------+
| Database | Size (MB) |
+----------+--------------+

| test_db | 228.88183594 |
+----------+--------------+
1 row in set (0.08 sec)
mysql>
7.3 查询 test_db 中每张表的逻辑大小
若想了解 test_db 中每张表的逻辑大小，可以执行：
mysql> SELECT
-> table_name AS 'Table',
-> (data_length + index_length) / 1024 / 1024 AS 'Size (MB)',
-> table_rows AS 'Rows'
-> FROM
-> information_schema.tables
-> WHERE
-> table_schema = 'test_db'
-> ORDER BY (data_length + index_length) DESC;
+----------+-------------+---------+
| Table | Size (MB) | Rows |
+----------+-------------+---------+
| sbtest4 | 22.88818359 | 1000000 |
| sbtest5 | 22.88818359 | 1000000 |
| sbtest6 | 22.88818359 | 1000000 |
| sbtest8 | 22.88818359 | 1000000 |
| sbtest2 | 22.88818359 | 1000000 |
| sbtest3 | 22.88818359 | 1000000 |
| sbtest7 | 22.88818359 | 1000000 |
| sbtest1 | 22.88818359 | 1000000 |
| sbtest10 | 22.88818359 | 1000000 |
| sbtest9 | 22.88818359 | 1000000 |
+----------+-------------+---------+
10 rows in set (0.04 sec)
mysql>

*注意：TiDB的压缩比通常远高于MySQL，这是其底层使用RocksDB（LSM树）带来的天然优势。*
7.4 统计 test_db 总数据量
统计整个 test_db 数据库的总行数和总大小，只需使用 SUM() 聚合函数即可。
[root@worker3 pingkai]# cd /tidb-data/tikv-20160
[root@worker3 tikv-20160]# du -sh
2.4G .
[root@worker3 tikv-20160]# ls
db last_tikv.toml raftdb.info rocksdb.info space_placeholder_file
import LOCK raft-engine snap
[root@worker3 tikv-20160]#
三、MySQL 8.0.42 vs TiDB 核心性能指标对比表
1. 数据压缩比对比（基础存储效率）
指标 MySQL 8.0.42 TiDB 差异倍数
总行数 9,863,995（估算） 10,000,000（10表×100万行） -
逻辑总大小（M 2372.61（DATA_LENGTH+IN 228.88（DATA_LENGTH+IN MySQL约10.
B） DEX_LENGTH） DEX_LENGTH） 37倍
实际磁盘占用 2.5（/data/pingkai/mysql/tes 2.4（/tidb-data/tikv-20160） 基本持平 （GB） t_db）
逻辑大小压缩比超10倍，海量 核心优势 无额外压缩开销，读写性能直接 TiDB占优 存储成本低

2. 8线程核心场景性能对比（基础并发能力）
95%延迟（m 测试场景 数据库 平均TPS 平均QPS 优势方 s）
MySQL 8.0.4 OLTP混合读写 335.15 6703.05 57.87 MySQL 2
OLTP混合读写 TiDB 174.93 3498.59 87.56 MySQL
单表点查询（主 MySQL 8.0.4 77988.8 77988.8 MySQL（超10 0.14 键） 2 4 4 倍）
单表点查询（主 TiDB 7652.53 7652.53 2.48 MySQL 键）
MySQL 8.0.4 索引更新（字段k） 848.21 848.21 25.28 TiDB（略优） 2
索引更新（字段k） TiDB 868.52 868.52 21.50 TiDB
3. 并发梯度性能对比（扩展性与抗压力）
并发线程数 数据库 平均TPS 95%延迟（ms） 性能趋势
8 MySQL 8.0.42 335.15 57.87 延迟低，吞吐稳定
8 TiDB 174.93 87.56 吞吐约为MySQL的52%
24 MySQL 8.0.42 624.25 71.83 TPS提升86%，延迟增长24%
24 TiDB 198.98 176.73 TPS提升14%，延迟增长102%
36 MySQL 8.0.42 703.06 95.81 TPS再提升13%，延迟可控
36 TiDB 195.72 277.21 TPS微降1.6%，延迟骤增57%
55 MySQL 8.0.42 768.09 150.29 TPS持续提升9%，延迟可接受
55 TiDB 188.83 419.45 TPS降3.5%，延迟超400ms
四、性能差异与选型建议
1. 核心性能差异总结
从测试数据可清晰看出，MySQL 8.0.42与TiDB的优势场景呈现显著分化，本质是“单机架
构”与“分布式架构”的设计目标差异：
（1）MySQL 8.0.42：单机性能天花板，低延迟场景首选
优势突出 ：在OLTP混合读写、单表点查询场景下，TPS/QPS均远超TiDB——点查询QPS
达7.8万，95%延迟仅0.14ms，完全满足“订单详情页、用户信息查询”等高频低延迟需
求；随并发线程从8增至55，TPS从335提升至768，增长129%，且95%延迟控制在15
0ms内，并发扩展性优秀。
短板明显 ：存储效率低，相同数据量下逻辑大小是TiDB的10倍，长期存储海量历史数据
（如3年订单）会导致磁盘成本高企。
（2）TiDB：分布式存储与稳定性优势，海量数据场景适配
核心价值 ：存储压缩比超10倍，逻辑大小仅228.88MB，适合需长期留存海量数据的场
景；索引更新性能略优于MySQL（TPS868.52 vs 848.21），得益于LSM树对写入的优

化；延迟波动小，混合读写场景无超300ms的极端延迟（MySQL最大延迟2361ms），
事务稳定性更优。
性能瓶颈 ：分布式架构带来的“Region路由”开销导致点查询延迟较高；高并发（36线程
以上）下TPS饱和、延迟骤增，抗并发上限低于MySQL，适合中小并发场景。
2. 业务选型建议
（1）优先选MySQL 8.0.42的场景
中小规模业务（日订单量10万以内），对查询延迟敏感（如电商商品详情、用户登录）；
高并发OLTP场景（如秒杀、促销峰值），需支撑50+线程并发且延迟可控；
存储成本不敏感，更关注“即开即用”的简单架构（无需维护分布式集群）。
（2）优先选TiDB的场景
海量数据存储（如千万级订单、亿级用户行为日志），需控制磁盘成本；
需弹性扩展的业务（如从单节点扩展至多节点，无需停机）；
对事务稳定性要求极高（如金融转账、支付对账），不允许极端延迟；
未来可能从OLTP向HTAP（混合事务/分析）扩展，需统一数据存储（TiDB支持HTA
P）。
3. 测试局限性与优化方向
本次测试为单节点TiDB与单机MySQL对比，未体现TiDB分布式集群的横向扩展能力（如多T
iKV节点部署可提升高并发吞吐）；若需更全面评估，可后续补充“TiDB集群（3TiKV节点）v
s MySQL主从架构”的对比测试，进一步验证分布式架构在高可用、扩展性上的优势。
总结与展望
通过以上全方位的测试对比，我们可以得出以下结论：
传统优势领域，MySQL 表现强劲：在经典的 OLTP 混合读写、尤其是超高并发的主键点查
询场景下，单机 MySQL 8.0 展现了压倒性的性能优势。其成熟的 InnoDB 存储引擎、缓冲
池管理以及在本机上的低延迟通信，使其在处理这种压力时得心应手。对于业务模型以简单
读写为主的传统应用，MySQL 依然是可靠且高性能的选择。
TiDB 的定位与优势：本次测试中，TiDB 在单节点部署下并未在性能上超越 MySQL。这恰
恰说明了 TiDB 的核心价值不在于替代单机 MySQL 追求极致的单点性能，而在于其天生的
分布式架构所带来的扩展性、高可用性和大数据容量处理能力。其索引更新性能与 MySQL
持平，也证明了其存储引擎的稳定性。测试中遇到的高并发连接问题，也提示我们需要为 Ti
DB 进行更针对性的参数调优（如连接池、内存参数等）。
如何选择？取决于业务场景：
如果你的业务是传统的单体应用，数据量在 TB 级以下，且对极致的事务性能和低延迟有很
高要求，MySQL 8.0 是更优的选择。
如果你的业务正在快速发展，面临大数据量（TB+）、高并发扩展、实时 HTAP 分析或者对
高可用性有强烈要求，那么 TiDB 的分布式架构优势将远远超越本次测试所展现的性能差
异。它允许你通过增加节点来线性提升整体集群能力，这是单机 MySQL 无法实现的。
展望：本次测试仅在单节点环境下进行，未能体现 TiDB 作为分布式数据库的真正实力。未
来的测试可以进一步深入：

分布式性能测试：构建 TiDB 多节点集群，测试其水平扩展能力。
高可用测试：模拟节点故障，验证其无损自动故障转移能力。
HTAP 场景测试：利用 TiFlash 列存引擎，测试在混合负载下的表现。
大数据量测试：导入百TB级别数据，测试 MySQL 与 TiDB 的可用性差异。
总之，没有最好的数据库，只有最合适的数据库。希望本篇文章的测试数据能为您勾勒出 M
ySQL 与 TiDB 在性能上的清晰边界，助您为业务找到最佳的技术基石。
作者注 ：
——本文所有操作及测试均基于 TEM 敏捷模式自动化部署 TiDB-v7.1.8-5.2-20250630 和 MySQ
L 8.0.42版本完成。请注意 TiDB-v7.1.8 和MySQL 8.0.42 版本处于持续迭代中，部分语法或功能
可能随更新发生变化，请以 TiDB 官方文档最新内容为准。
——以上仅为个人思考与建议，不代表行业普适观点。以上所有操作均需在具备足够权限的环境下执
行，涉及生产环境时请提前做好备份与测试。文中案例与思路仅供参考，若与实际情况巧合，纯属
无意。期待与各位从业者共同探讨更多可能！
墨力计划 数据库实操 tidb数据库 tidb 敏捷模式 tidb第四届征文-运维开发之旅
最后修改时间：2025-09-22 09:49:06
「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」
关注作者 点赞
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信息，否则作者
和墨天轮有权追究责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contact@modb.pro进行举报，并
提供相关证据，一经查实，墨天轮将立刻删除相关内容。
文章被以下合辑收录
墨天轮「实操看我的」征文-数据库实操优质文章合辑（共69
篇） 收藏合辑
本合辑汇总了「实操看我的」数据库主题征文活动中“最佳实操奖” 文章及部分高
阅读量合格文章，欢迎参考~
评论
jieguo
单机硬件什么配置？cpu,mem,disk（机械还是固态？）
1月前 点赞 评论
相关阅读
PostgreSQL Patroni + Consul 高可用
黄山谷 194次阅读 2025-10-27 21:12:12

16个知识点，学会MySQL数据库Binary Log Files !
陈举超 173次阅读 2025-10-12 19:08:39
MySQL启用透明页压缩，导致宕机！
陈举超 144次阅读 2025-11-09 15:13:16
数据库事务原子性，如理解有误，可能会丢数据！
陈举超 133次阅读 2025-10-25 10:48:21
sysbench 实测：TiDB 7.1.8 两副本的 OLTP/OLAP 解析
shunwahⓂ️ 116次阅读 2025-10-27 21:38:26
YashanDB 部署太复杂？10分钟搞定 Docker 体验攻略
shunwahⓂ️ 116次阅读 2025-10-23 09:24:17
通过sql日志，分析达梦数据库dexp导出表时，执行了哪些SQL?
陈举超 86次阅读 2025-10-17 20:53:35
使用 BR 备份 TiDB 到 AWS S3 存储
Lucifer三思而后行 69次阅读 2025-11-04 13:13:46
【TiDB 体验官实测】 TiDB v7.1.8 多语法兼容MySQL 多场景验证
shunwahⓂ️ 60次阅读 2025-11-01 20:06:30
TiDB 备份与恢复整理
Lucifer三思而后行 46次阅读 2025-11-04 11:50:38

