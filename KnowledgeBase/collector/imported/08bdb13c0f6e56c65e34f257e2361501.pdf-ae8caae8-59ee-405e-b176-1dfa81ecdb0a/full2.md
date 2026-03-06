# MySQL 性能监控全掌握：关键指标及采集方法

版权：2023-05-08 发布于黑龙江

简介：
数据库中间件监控实战，介绍 MySQL 中哪些指标比较关键以及如何采集这些指标，帮助提早发现问题，提升数据库可用性。

## 整体思路
MySQL 是一个服务，可借用 Google 四个黄金指标（延迟、流量、错误、饱和度）来解决监控问题。大多数指标可通过 `SHOW GLOBAL STATUS`、`SHOW VARIABLES` 获取，复杂分析可借助 `performance_schema` 和 `sys` schema（注意版本和采集成本）。

下面按四类指标逐项说明如何获取及典型判断方式。

### 1.1 延迟
应用程序层面：在上层业务程序对每个 SQL 请求记录耗时，推送到监控系统，监控系统可计算平均延迟、95 分位、99 分位等。但这种埋点有代码侵入性。

MySQL 层面：慢查询统计指标（Counter），可通过：
```
show global status like 'Slow_queries';
```
该指标为单调递增计数，若需统计某时间窗口内的慢查询数量，应对 Counter 做差分计算（如 increase 函数）。

慢查询的判断标准由全局变量 `long_query_time` 控制（默认 10s），可查看：
```
SHOW VARIABLES LIKE 'long_query_time';
```

更细粒度的延迟信息可通过 `performance_schema`（例如 `events_statements_summary_by_digest`），该表捕获查询延迟、错误量、执行次数等。示例（表中时间以皮秒计）：
```
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
FIRST_SEEN: 2016-03-24 14:25:32
LAST_SEEN: 2016-03-24 14:25:55
```

诊断常用 `sys` schema（若可用），例如查 95 分位最慢 SQL：
```
SELECT * FROM sys.statements_with_runtimes_in_95th_percentile;
```
注意：`sys` schema 从 MySQL 5.7.7 开始包含，旧版本需手工安装。

### 1.2 流量
常监控语句执行次数：SELECT、UPDATE、DELETE、INSERT 等。可通过以下命令获取：
```
show global status where Variable_name regexp 'Com_insert|Com_update|Com_delete|Com_select|Questions|Queries';
```
这些是 Counter 型。常用概念：
- `Com_*` 前缀表示各类命令执行次数。
- `Questions` 表示客户端发送给 MySQL 的语句数量（常用作整体吞吐）。
- `Queries` 还包含存储过程内部语句、PREPARE 等，容易与 `Questions` 混淆。

常见统计项：写数量（Com_insert + Com_update + Com_delete）、读数量（Com_select）、语句总量（Questions）。

### 错误
错误可以从客户端埋点采集（有代码侵入性），也可以从 MySQL 本身采集相关错误计数。例如连接相关错误：
```
show global status where Variable_name regexp 'Connection_errors_max_connections|Aborted_connects';
```
示例输出：
```
| Aborted_connects                          | 785546 |
| Connection_errors_max_connections         | 0      |
```
- `Aborted_connects`：连接失败时 +1（不区分原因）。
- `Connection_errors_max_connections`：表示超过最大连接数导致 MySQL 拒绝连接。

查看和调整最大连接数：
```
SHOW VARIABLES LIKE 'max_connections';
```
临时调整（重启后失效）：
```
SET GLOBAL max_connections = 2048;
```
永久修改需在 my.cnf 中添加：
```
max_connections = 2048
```

也可通过 `performance_schema.events_statements_summary_by_digest` 按 schema 聚合错误：
```
SELECT schema_name, SUM(sum_errors) err_count
FROM performance_schema.events_statements_summary_by_digest
WHERE schema_name IS NOT NULL
GROUP BY schema_name;
```
示例：
```
+--------------------+-----------+
| schema_name        | err_count |
+--------------------+-----------+
| employees          | 8         |
| performance_schema | 1         |
| sys                | 3         |
+--------------------+-----------+
```

### 饱和度
首先关注主机级指标：CPU、内存、磁盘 I/O、网络流量。MySQL 自身也有反映饱和度的指标，例如连接数（`Threads_connected`）与最大连接数（`max_connections`）的比值可作为连接使用率。

InnoDB Buffer Pool 相关指标也很重要：
```
show global status like '%buffer%';
```
示例输出（节选）：
```
| Innodb_buffer_pool_pages_data       | 5837        |
| Innodb_buffer_pool_pages_dirty      | 32          |
| Innodb_buffer_pool_pages_free       | 1036        |
| Innodb_buffer_pool_pages_total      | 8191        |
| Innodb_buffer_pool_read_requests    | 8667876784  |
| Innodb_buffer_pool_reads            | 236654      |
| Innodb_buffer_pool_write_requests   | 533520851   |
```
说明：
- `Innodb_buffer_pool_pages_total`：Buffer pool 页总量（page 默认 16KiB，可通过 `innodb_page_size` 查看）。
- `Innodb_buffer_pool_pages_free`：剩余页数。used = total - free，used/total = 使用率。
- `Innodb_buffer_pool_read_requests`：从 Buffer pool 命中的请求总数。
- `Innodb_buffer_pool_reads`：需要穿透到磁盘的数量。

穿透比例 = reads / read_requests。比例越高，说明 Buffer pool 未命中率越高，可能需要增大 Buffer pool。

总结：先用一些全局统计指标（如 Slow_queries）发现问题，再用 `performance_schema`、`sys` 做深度分析。注意 `performance_schema`、`sys` 的采集成本与版本要求。

---

## 采集配置（以 Categraf 为例）
Categraf 针对 MySQL 的采集插件配置位于 `conf/input.mysql/mysql.toml`。示例配置：
```
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
```
关键配置项：
- `address`、`username`、`password`：数据库连接地址和认证信息。
- 建议启用：`extra_status_metrics`、`extra_innodb_metrics`、`gather_slave_status`。
- 建议为监控创建一个只读账号，并统一账号/密码/授权，使配置一致。
- `instances` 是数组，监控多个数据库则配置多个 `[[instances]]`。
- 推荐为实例增加 `labels`（如 `instance`）用于 Dashboard 标识和告警定位。

Categraf 采集 MySQL 时常见两种部署方式：

### 2.1 中心化探测
在一台探针机上部署一个 Categraf，配置多个 `instances` 来采集所有 MySQL 实例。
适用场景：
- MySQL 实例数量较少
- 使用云上 RDS 服务
缺点：不便于自动化新增实例，需要手工更新采集配置。

### 2.2 分布式本地采集（推荐）
在每台部署 MySQL 的机器上本地部署 Categraf，采集 `127.0.0.1:3306`。建议一台宿主机只跑一个 MySQL 实例，且将 InnoDB Buffer pool 设置为较大（例如占物理内存 ~80%）以提升性能。DBA 可在自动化部署工具里加入 Categraf 的部署与配置逻辑，实现“一键监控”。一般用机器名作为指标标识即可。

效果图：可在 Dashboard 中把上述关键指标放入可视化面板（此处省略具体图示）。

---

## 业务指标
MySQL 存储大量业务数据，可通过自定义 SQL 将业务指标上报到监控系统（例如用户数、订单数等）。Categraf 的 MySQL 插件支持自定义查询，示例配置：
```
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
```
说明：
- 在对应的 `[[instances]]` 下增加 `[[instances.queries]]` 来为该实例采集业务指标。
- 返回值中的数值列会作为 metric 上报，字符串列可作为标签。

---

## 总结
- 使用 Google 四个黄金指标（延迟、流量、错误、饱和度）指导 MySQL 的监控与数据采集。
- 常用指标可通过 `SHOW GLOBAL STATUS`、`SHOW VARIABLES` 获取，深度诊断可借助 `performance_schema` 与 `sys` schema。
- 采集器部署推荐在 MySQL 服务主机上本地部署（分布式本地采集），并使用只读监控账号。
- 利用自定义 SQL 可以把业务指标纳入监控体系，提升告警与可观测性。
- 生产环境中 MySQL 很少放容器，Sidecar 模式在容器化场景可考虑，但本文未展开。

---

## FAQ（示例告警 PromQL）
下面是一些常见的告警 PromQL 表达式示例，可根据业务需求调整阈值和时窗：

监控服务器运行状态（Server 不可用或 CPU 使用异常高）：
```
up == 0 or (100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)) > 90
```

监控 MySQL 可用连接数（超过最大连接数比例告警）：
```
mysql_global_status_threads_connected / mysql_global_variables_max_connections * 100 > 80
```

监控 MySQL 存储空间使用率：
```
mysql_info_schema_data_length_bytes / mysql_info_schema_data_free_bytes * 100 > 80
```

提示：请根据具体业务特性和告警级别（信息/警告/紧急）设计更细化的告警策略。

---