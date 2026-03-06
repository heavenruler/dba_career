大模型 产品 解决方案 文档与社区 权益中心 定价 云市场 合作伙伴 支持与服务 了解阿里云 备案 控制台 登录 注册
开发者社区 首页 探索云世界 问产品 动手实践 官方博客 考认证 TIANCHI大赛 活动广场 下载 个人 积分 发布
热门文章 最新文章 开发者社区 数据库 文章 正文
MySQL性能监控全掌握，快来get关键指标及采集方法！ 美团面试：MySQL为什么 不用 Docker部署？ 91
【深入了解MySQL】优化查询性能与数据库设计 45 版权 2023-05-08 1670 发布于黑龙江
的深度总结 详解MySQL字符集和Collation 61
docker pull mysql:8.0.26提示Error response 74 本文涉及的产品
from daemon: Get “https://registry- 数据库连接工具连接mysql提示：“Host 29 1.docker.io/v2/“: EOF错误 云数据库 RDS MySQL，集群系列 2核4GB RDS MySQL Serverless 基础系列，0.5-2RCU RDS MySQL Serverless 高可用系列，价值2615元额度，1个月 ‘172.23.0.1‘ is not allowed to connect to this MySQL底层概述—1.InnoDB内存结构 143 MySQL server“ 推荐场景： 推荐场景： 搭建个人博客 学生管理系统数据库设计
MySQL底层概述—2.InnoDB磁盘结构 144 搭建个人博客
立即试用 立即试用 立即试用
相关课程 更多
简介： 数据库中间件监控实战，MySQL中哪些指标比较关键以及如何采集这些指标了。帮助提早发现问题，提升数据库可用性。
MySQL企业常见架构与调优经验分享
云数据库MySQL版快速上手教程
数据库中间件监控实战，MySQL中哪些指标比较关键以及如何采集这些指标了。帮助提早发现问题，提升数据库可用性。
阿里云云原生数据仓库AnalyticDB MySQL版 使用教程
MySQL实战进阶
数据库及SQL/MySQL基础
1 整体思路 云数据库MySQL快速入门
监控哪类指标？ 相关电子书 更多 AI
助 理 如何采集数据？ javaedge 2659文章 1问答 目录 +关注 0 0 0 0 MongoDB在性能监控领域的应用
第10讲监控方法论如何落地？ 构建微服务下的性能监控
微服务架构的应用性能监控 这些就可以在MySQL中应用起来。MySQL是个服务，所以可借用Google四个黄金指标解决问题：
相关实验场景 更多
1.1 延迟 MySQL引擎及架构优化
基于EBS部署高性能的MySQL服务 应用程序会向MySQL发起SELECT、UPDATE等操作，处理这些请求花费多久很关键，甚至还想知道具体是哪个SQL最慢，这样就可以有针对性地调优。
使用CloudLens采集RDS日志并进行审计分析 1.1.1 采集延迟数据
在客户端埋点 AnalyticDB MySQL游戏行业数据分析实践
上层业务程序在请求MySQL的时候，记录每个SQL请求耗时，把这些数据统一推给监控系统，监控系统就可以计算出平均延迟、95分位、99分位的延迟数据了。要埋点，对
函数计算X RDS PostgreSQL，基于LLM大语言模型构建AI知识库 业务代码有侵入性。
AnalyticDB MySQL海量数据秒级分析体验 Slow queries
MySQL提供慢查询数量的统计指标，通过如下命令拿到：
推荐镜像 更多 show global status like 'Slow_queries';
+---------------+-------+
| Variable_name | Value | mysql
+---------------+-------+
mariadb | Slow_queries | 107 |
+---------------+-------+ postgresql
1 row in set (0.000 sec)
这指标是Counter型，即单调递增，若想知道最近1min有多少慢查询，需要使用increase函数做二次计算。
下一篇
慢查询标准
PAI Model Gallery 支持云上一键部署 DeepSeek-V3、 全局变量long_query_time，默认10s，可调整。每当查询时间超过 long_query_time 指定时间，Slow_queries 就会 +1。
DeepSeek-R1 系列模型
获取 long_query_time 值：
SHOW VARIABLES LIKE 'long_query_time';
+-----------------+-----------+
| Variable_name | Value |
+-----------------+-----------+
| long_query_time | 10.000000 |
+-----------------+-----------+
通过 performance schema、sys schema 拿到统计数据。若performance schema的 events_statements_summary_by_digest 表，该表捕获很多关键信息，如延迟、错误
量、查询量。
如下案例，SQL执行2次，平均执行时间325ms，表里的时间度量指标都是以皮秒为单位：
*************************** 1. row ***************************
SCHEMA_NAME: employees
DIGEST: 0c6318da9de53353a3a1bacea70b4fce
DIGEST_TEXT: SELECT * FROM `employees` WHERE `emp_no` > ?
COUNT_STAR: 2
SUM_TIMER_WAIT: 650358383000
MIN_TIMER_WAIT: 292045159000
AVG_TIMER_WAIT: 325179191000
MAX_TIMER_WAIT: 358313224000
SUM_LOCK_TIME: 520000000
SUM_ERRORS: 0

SUM_WARNINGS: 0
SUM_ROWS_AFFECTED: 0
SUM_ROWS_SENT: 520048
SUM_ROWS_EXAMINED: 520048
...
SUM_NO_INDEX_USED: 0
SUM_NO_GOOD_INDEX_USED: 0
FIRST_SEEN: 2016-03-24 14:25:32
LAST_SEEN: 2016-03-24 14:25:55
针对即时查询、诊断问题，还可使用 sys schema。sys schema提供一种组织良好、易读的指标查询方式，查询更简单。如下方法找到最慢的SQL。这个数据在
statements_with_runtimes_in_95th_percentile 表中。
SELECT * FROM sys.statements_with_runtimes_in_95th_percentile;
更多例子查看 sys schema 文档。不过要注意的是，MySQL 5.7.7开始才包含sys schema，5.6 版本开始可手工安装。
1.2 流量
最熟的就是统计 SELECT、UPDATE、DELETE、INSERT 等语句执行数量。若流量太高，超过硬件承载能力，显然需监控、扩容。这些类型指标在 MySQL 全局变量中都能拿
到：
show global status where Variable_name regexp 'Com_insert|Com_update|Com_delete|Com_select|Questions|Queries';
+-------------------------+-----------+
| Variable_name | Value |
+-------------------------+-----------+
| Com_delete | 2091033 |
| Com_delete_multi | 0 |
| Com_insert | 8837007 |
| Com_insert_select | 0 |
| Com_select | 226099709 |
| Com_update | 24218879 |
| Com_update_multi | 0 |
| Empty_queries | 25455182 |
| Qcache_queries_in_cache | 0 |
| Queries | 704921835 |
| Questions | 461095549 |
| Slow_queries | 107 |
+-------------------------+-----------+
这些指标都是 Counter 型。Com_ 是 Command 的前缀，即各类命令的执行次数。 整体吞吐量主要是看 Questions 指标，但Questions 很容易和它上面的Queries混淆。从
例子里我们可以明显看出 Questions 的数量比 Queries 少。Questions 表示客户端发给 MySQL 的语句数量，而Queries还会包含在存储过程中执行的语句，以及 PREPARE
这种准备语句，所以监控整体吞吐一般是看 Questions。
流量方面的指标，一般我们会统计写数量（Com_insert + Com_update + Com_delete）、读数量（Com_select）、语句总量（Questions）。
错误
错误量这类指标有多个应用场景，比如客户端连接 MySQL 失败了，或者语句发给 MySQL，执行的时候失败了，都需要有失败计数。典型的采集手段有两种。
在客户端采集、埋点，不管MySQL问题 or 网络问题或中间负载均衡问题或DNS解析问题，只要连接失败，都能发现。但有代码侵入性。
从 MySQL 采集相关错误，如连接错误通过 Aborted_connects、Connection_errors_max_connections拿
show global status where Variable_name regexp 'Connection_errors_max_connections|Aborted_connects';
+-----------------------------------+--------+
| Variable_name | Value |
+-----------------------------------+--------+
| Aborted_connects | 785546 |
| Connection_errors_max_connections | 0 |
+-----------------------------------+--------+
只要连接失败，不管啥原因，Aborted_connects 都 +1，而更常用的是 Connection_errors_max_connections ，表示超过了最大连接数，所以 MySQL 拒绝连接。MySQL默
认最大连接数151，在现在这样硬件条件下，实在太小，因此出现这种情况的频率较高，要多关注，及时发现。
SHOW VARIABLES LIKE 'max_connections';
+-----------------+-------+
| Variable_name | Value |
+-----------------+-------+
| max_connections | 151 |
+-----------------+-------+
可通过如下命令调整最大连接数：
SET GLOBAL max_connections = 2048;
虽可通过命令临时调整最大连接数，但一旦重启话就失效。为永久修改该配置，需调整 my.cnf 加一行：
max_connections = 2048
events_statements_summary_by_digest 表也能拿到错误数量。
SELECT schema_name
, SUM(sum_errors) err_count
FROM performance_schema.events_statements_summary_by_digest
WHERE schema_name IS NOT NULL
GROUP BY schema_name;
+--------------------+-----------+
| schema_name | err_count |
+--------------------+-----------+
| employees | 8 |
| performance_schema | 1 |
| sys | 3 |
+--------------------+-----------+

饱和度
MySQL用什么指标反映资源有多“满”？先关注 MySQL 所在机器 CPU、内存、硬盘I/O、网络流量这些基础指标。
MySQL本身也有一些指标反映饱和度，如连接数，当前连接数（Threads_connected）除以最大连接数（max_connections）可得 连接数使用率，需重点监控的饱和度指
标。
InnoDB Buffer pool 相关指标：
Buffer pool 的使用率
Buffer pool 的内存命中率
Buffer pool内存专门用来缓存 Table、Index 相关数据，提升查询性能。
查看Buffer pool相关指标：
MariaDB [(none)]> show global status like '%buffer%';
+---------------------------------------+--------------------------------------------------+
| Variable_name | Value |
+---------------------------------------+--------------------------------------------------+
| Innodb_buffer_pool_dump_status | |
| Innodb_buffer_pool_load_status | Buffer pool(s) load completed at 220825 11:11:13 |
| Innodb_buffer_pool_resize_status | |
| Innodb_buffer_pool_load_incomplete | OFF |
| Innodb_buffer_pool_pages_data | 5837 |
| Innodb_buffer_pool_bytes_data | 95633408 |
| Innodb_buffer_pool_pages_dirty | 32 |
| Innodb_buffer_pool_bytes_dirty | 524288 |
| Innodb_buffer_pool_pages_flushed | 134640371 |
| Innodb_buffer_pool_pages_free | 1036 |
| Innodb_buffer_pool_pages_misc | 1318 |
| Innodb_buffer_pool_pages_total | 8191 |
| Innodb_buffer_pool_read_ahead_rnd | 0 |
| Innodb_buffer_pool_read_ahead | 93316 |
| Innodb_buffer_pool_read_ahead_evicted | 203 |
| Innodb_buffer_pool_read_requests | 8667876784 |
| Innodb_buffer_pool_reads | 236654 |
| Innodb_buffer_pool_wait_free | 5 |
| Innodb_buffer_pool_write_requests | 533520851 |
+---------------------------------------+--------------------------------------------------+
Innodb_buffer_pool_pages_total ：InnoDB Buffer pool 页总量，页（page）是 Buffer pool 的一个分配单位，默认page size=16KiB，可通过 show variables like
"innodb_page_size"看。
Innodb_buffer_pool_pages_free ：剩余页数量，通过 total 和 free 可得 used，used/total=使用率。使用率高不是说有问题，因为InnoDB有 LRU 缓存清理机制，只要响应
够快，高使用率也不是问题。
Innodb_buffer_pool_read_requests 和 Innodb_buffer_pool_reads ：read_requests 表示向 Buffer pool 发起的查询总量，若Buffer pool缓存了相关数据直接返回，没有就
得穿透内存去查询硬盘。
有多少请求满足不了，需查硬盘？得看 Innodb_buffer_pool_reads 指标统计数量。
reads指标 / read_requests = 穿透比例
比例越高，性能越差，可调整 Buffer pool 大小解决。
根据 Google 四个黄金指标方法论，梳理 MySQL 相关指标，这些指标大多可通过 global status 和 variables 拿到。performance schema、sys schema 相对难搞：
sys schema 需要较高版本才能支持
这两个 schema 的数据不太适合放到 metrics 库
常见做法通过一些偏全局统计指标，如Slow_queries，先发现问题，再通过这俩 schema 的数据分析细节。
不同的采集器采集的指标，命名方式会有差别，不过大同小异，关键理解思路、原理。
利用 Categraf 配置采集，演示整个过程。
2 采集配置
Categraf 针对 MySQL 的采集插件配置，在 conf/input.mysql/mysql.toml 里。我准备了一个配置样例，你可以参考。
[[instances]]
address = "127.0.0.1:3306"
username = "root"
password = "1234"
extra_status_metrics = true
extra_innodb_metrics = true
gather_processlist_processes_by_state = false
gather_processlist_processes_by_user = false
gather_schema_size = false
gather_table_size = false
gather_system_table_size = false
gather_slave_status = true
# # timeout
# timeout_seconds = 3
# labels = { instance="n9e-dev-mysql" }
最关键的配置是 数据库连接地址和认证信息，具体采集哪些由一堆开关控制。建议把
extra_status_metrics
extra_innodb_metrics
gather_slave_status
置true，其他都不太需采集。labels推荐加instance标签，给这数据库取表意性更强名称，收到告警消息可一眼知道是哪个数据库问题。instances部分是数组，若要监控多个
数据库，就配置多个 instances。

Categraf作为采集探针，采集 MySQL 时，有两种方案：
2.1 中心化探测
找一台机器作为探针机器，部署一个单独 Categraf，只采集 MySQL 相关指标，同时采集所有的 MySQL 实例，即这个 Categraf 的 mysql.toml 中有很多 instances 配置段。
2.1.1 适用
MySQL 实例数量较少
云上 RDS 服务
相对不太方便做自动化，如新建一个MySQL，还需要到这个探针机器里配置相关的采集规则，麻烦。
2.2 分布式本地采集（推荐）
把 Categraf 部署到部署 MySQL 的那台机器上，让 Categraf 采集 127.0.0.1:3306 实例。
MySQL服务建议不要混部，一台宿主机就部署一个 MySQL，InnoDB Buffer pool设置大些，80%物理内存，性能杠杠。
DBA 管理 MySQL经常创建集群，通常沉淀一些自动化工具，在自动化工具里把部署 Categraf、配置 Categraf 的 mysql.toml 的逻辑都加上，一键搞定。监控只需读权限，
建议为监控系统创建一个单独的数据库账号，统一账号、统一密码、统一授权，这样 mysql.toml 配置也一致。
采用这种部署方式一般就用机器名做标识，不太需单独instance标签。Categraf 内置一个 夜莺监控大盘，大盘变量使用机器名来做过滤。如用Grafana，去 Grafana 官网搜
Dashboard，大同小异。刚提到的那些关键指标最好都放Dashboard。
效果图：

3 业务指标
MySQL指标采集核心原理：连上MySQL执行一些 SQL，查询性能数据。
Categraf 内置一些查询 SQL，能否自定义SQL查询一些业务指标？如查询一下业务系统的用户量，把用户量作为指标上报到监控系统。可使用 Categraf 的 MySQL 采集插件
实现，查看 mysql.toml 里的默认配置：
[[instances.queries]]
# 作为 metric name 的前缀
mesurement = "users"
# 查询返回的结果，可能有多列是数值，指定哪些列作为指标上报
metric_fields = [ "total" ]
# 查询返回的结果，可能有多列是字符串，指定哪些列作为标签上报
label_fields = [ "service" ]
# 指定某一列的内容作为 metric name 的后缀
field_to_append = ""
# 语句执行超时时间
timeout = "3s"
# 查询语句，连续三个单引号，和Python的三个单引号语义类似，里边内容就不用转义
request = '''
select 'n9e' as service, count(*) as total from n9e_v5.users
'''
自定义SQL的配置，想查询哪个数据库实例，就在对应 [[instances]] 下面增加 [[instances.queries]] 。
MySQL 相关的监控实践，包括性能监控和业务监控，核心就是上面我们说的这些内容，下面我们做一个总结。
4 总结
Google 四个黄金指标方法论指导MySQL 监控数据采集，从延迟、流量、错误、饱和度分别讲解了具体指标是什么及如何获取。
采集器部署还有一种就是容器环境 Sidecar 模式。因为生产环境里 MySQL 一般很少放容器，所以没提。

由于 MySQL 存储很多业务数据，是业务指标重要来源，通过自定义 SQL可以获取很多业务指标，推荐试用这种监控方式。
5 FAQ
MySQL的监控大盘已给出，一些关键指标也点出，告警规则怎么配置？常见的告警 PromQL 哪些？
对于MySQL监控大盘中的关键指标，我们可以根据业务需求设置相应的告警规则。一些常见的告警PromQL表达式如下：
监控服务器运行状态：如果服务器停止响应或CPU使用率超过阈值，则发出告警。
up == 0 or (100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 90
监控MySQL数据库性能：例如，监听可用连接数是否已达到最大连接数并进行告警。
mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100 > 80
监控MySQL数据库存储空间：配置阈值，并在使用率超过预设值后触发告警。
mysql_info_schema_data_length_bytes / mysql_info_schema_data_free_bytes * 100 > 80
除以上这些例子外，还可以根据具体业务情况自定义更多的告警规则。提示：为了实现更精细化的告警，建议对不同种类的监控数据，针对不同的告警级别进行区分，制定
更加明确的告警策略。
文章标签： 云数据库 RDS MySQL 版 容器 SQL 关系型数据库 监控 MySQL RDS 中间件 数据库 缓存 存储
关键词： 云数据库 RDS MySQL 版get 云数据库 RDS MySQL 版方法 云数据库 RDS MySQL 版指标 云数据库 RDS MySQL 版采集 性能监控方法
相关实践学习
如何快速连接云数据库RDS MySQL 全面了解阿里云能为你做什么
本场景介绍如何通过阿里云数据管理服务DMS快速连接云数 阿里云在全球各地部署高效节能的绿色数据中心，利用清洁
据库RDS MySQL，然后进行数据表的CRUD操作。 计算为万物互联的新世界提供源源不断的能源动力，目前开
服的区域包括中国（华北、华东、华南、香港）、新加坡、美
评论
登录 后可评论

相关文章
yuanzhengme | 6月前 | 关系型数据库 MySQL 索引
MySQL的全文索引查询方法
【8月更文挑战第26天】MySQL的全文索引查询方法
84 0 0
游客r2tgrg3ez7yzc | 22天前 | 关系型数据库 MySQL Docker
docker pull mysql:8.0.26提示Error response from daemon: Get “https://registry-1.docker.io/v2/“: EOF错误
docker pull mysql:8.0.26提示Error response from daemon: Get “https://registry-1.docker.io/v2/“: EOF错误
176 9 9
互联网课堂 | 2月前 | SQL 关系型数据库 MySQL
深入解析MySQL的EXPLAIN：指标详解与索引优化
MySQL 中的 `EXPLAIN` 语句用于分析和优化 SQL 查询，帮助你了解查询优化器的执行计划。本文详细介绍了 `EXPLAIN` 输出的各项指标，如 `id`、`select_type`、`table`、`type`、`key` 等，并提供了如何利用这些指标优化索引结构和
326 9 10
小Tomkk | 4月前 | 存储 关系型数据库 MySQL
环比、环比增长率、同比、同比增长率 ，占比，Mysql 8.0 实例（最简单的方法之一)（sample database classicmodels _No.2 ）
环比、环比增长率、同比、同比增长率 ，占比，Mysql 8.0 实例（最简单的方法之一)（sample database classicmodels _No.2 ）
221 1 1
sunrr | 4月前 | 存储 关系型数据库 MySQL
提高MySQL查询性能的方法有很多
提高MySQL查询性能的方法有很多
326 7 7
蓝易云 | 2月前 | SQL 存储 关系型数据库
MySQL/SqlServer跨服务器增删改查（CRUD）的一种方法
通过上述方法，MySQL和SQL Server均能够实现跨服务器的增删改查操作。MySQL通过联邦存储引擎提供了直接的跨服务器表访问，而SQL Server通过链接服务器和分布式查询实现了灵活的跨服务器数据操作。这些技术为分布式数据库管理提供了强大的支持，能够满足复杂的数据操作需求。
98 12 12
小王老师呀 | 6月前 | 存储 关系型数据库 MySQL
mysql数据库查询时用到的分页方法有哪些
【8月更文挑战第16天】在MySQL中，实现分页的主要方法包括：1）使用`LIMIT`子句，简单直接但随页数增加性能下降；2）通过子查询优化`LIMIT`分页，提高大页码时的查询效率；3）利用存储过程封装分页逻辑，便于复用但需额外维护；4）借助MySQL变量实现，可能提供更好的性能但实现较复杂。这些方法各有优缺点，可根据实际需求选择适用方案。
620 2 2
蓝易云 | 2月前 | 存储 缓存 关系型数据库
MySQL的count()方法慢
MySQL的 `COUNT()`方法在处理大数据量时可能会变慢，主要原因包括数据量大、缺乏合适的索引、InnoDB引擎的设计以及复杂的查询条件。通过创建合适的索引、使用覆盖索引、缓存机制、分区表和预计算等优化方案，可以显著提高
740 12 12
栈江湖 | 2月前 | SQL 关系型数据库 MySQL
数据库灾难应对：MySQL误删除数据的救赎之道，技巧get起来！之binlog
《数据库灾难应对：MySQL误删除数据的救赎之道，技巧get起来！之binlog》介绍了如何利用MySQL的二进制日志（Binlog）恢复误删除的数据。主要内容包括： 1. **启用二进制日志**：在`my.cnf`中配置`log-bin`并重启MySQL服务。
112 2 2
2G冲浪词条 | 3月前 | 关系型数据库 MySQL
Mysql 中日期比较大小的方法有哪些？
在 MySQL 中，可以通过多种方法比较日期的大小，包括使用比较运算符、NOW() 函数、DATEDIFF 函数和 DATE 函数。这些方法可以帮助你筛选出特定日期范围内的记录，确保日期格式一致以避免错误。
115 1 1
为什么选择阿里云 产品和定价 解决方案 文档与社区 权益中心 支持与服务 关注阿里云
什么是云计算 全部产品 技术解决方案 文档 免费试用 基础服务 关注阿里云公众号或下载阿里云APP，关注云资
讯，随时随地运维管控云服务 全球基础设施 免费试用 开发者社区 高校计划 企业增值服务
技术领先 产品动态 天池大赛 企业扶持计划 迁云服务
稳定可靠 产品定价 培训与认证 推荐返现计划 官网公告
安全合规 价格计算器 健康看板
联系我们：4008013260 分析师报告 云上成本管理 信任中心
法律声明 Cookies政策 廉正举报 安全举报 联系我们 加入我们
阿里巴巴集团 淘宝网 天猫 全球速卖通 阿里巴巴国际交易市场 1688 阿里妈妈 飞猪 阿里云计算 AliOS 万网 高德 UC 友盟 优酷 钉钉 支付宝 达摩院 淘宝海外 阿里云盘 饿了么
© 2009-2025 Aliyun.com 版权所有 增值电信业务经营许可证： 浙B2-20080101 域名注册服务机构许可： 浙D3-20210002
浙公网安备 33010602009975号 浙B2-20080101-4

Padge 8
MySQL 性 腕 岩 控 全 掌 握 ， 怏 來 get 夾 毽 指 柩 及 釆 集 方 法 ! ﹣ 阿 里 云 午 及 者 社 巴
https﹕//developeraliyun﹒com/article/1207546
鑾 ﹣ 鸞 浙 公 网 安 吟 33010602009975 周 ﹍ 浙 B2﹣20080101﹣4
Captured by FireSshot Pro﹕ 14 2 月 2025， 14﹕58﹕56
https﹕//dgdetfireshot﹒com

