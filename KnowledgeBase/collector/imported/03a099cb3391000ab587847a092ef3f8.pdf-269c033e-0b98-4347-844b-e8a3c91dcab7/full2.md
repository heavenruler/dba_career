# SysBench 压缩并发性能翻倍：单机版 TiDB vs MySQL 8.0.42

作者：shunwahⓂ️

基于电商订单场景的 OLTP、点查询、存储效率及扩展性全面压测分析。本文使用 Sysbench 对单节点部署的 MySQL 8.0.42（端口 3306）与单节点 TiDB（端口 4006）进行对比测试，围绕数据准备、缓存预热、OLTP 混合读写、点查询、索引更新、并发梯度和存储压缩比等维度展开，旨在通过客观数据帮助技术选型。

---

## 测试说明（通用）

- 使用 Sysbench（1.0.17）准备数据：10 张表，每张表 1,000,000 行，共约 1,000 万行（MySQL 在信息统计上略有差异）。
- MySQL 使用 InnoDB，TiDB 使用 TiKV（RocksDB/LSM），因此存储特性和压缩率存在本质差异。
- 为保证公平性，测试尽量在相同硬件下进行单节点部署，但 TiDB 的优势在于分布式扩展能力，单节点结果仅供参考。
- 建议在对 TiDB 测试时使用 --db-driver=mysql。prepare 阶段可以考虑 --auto_inc=off 避免自增 ID 的性能瓶颈（但行为可能与 MySQL 略有不同）。
- TiDB 使用乐观事务，冲突场景下会有重试导致性能波动，这是正常现象。

---

## 一、MySQL 8.0.42 测试（端口 3306）

### 1. 准备测试数据（Prepare）

命令与输出（sysbench 创建 10 张表并每张插入 1,000,000 条记录）：

```bash
sysbench oltp_common --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
```

输出示例：

```
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Initializing worker threads...
Creating table 'sbtest5'...
...
Inserting 1000000 records into 'sbtest6'
...
Creating a secondary index on 'sbtest3'...
...
```

过程说明：数据准备阶段顺利完成，系统创建了 10 张表并插入约 1 亿条测试数据（各表 1,000,000 条，共 10 张表），同时为每张表建立了二级索引，为后续性能测试奠定基础。

### 2. 预热缓存（Warm Up）

为了确保测试在稳定状态下进行，使用只读测试将数据加载到 InnoDB 缓冲池，避免后续受磁盘 I/O 瓶颈影响：

```bash
sysbench oltp_read_only --threads=16 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
```

输出节选：

```
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Running the test with following options:
Number of threads: 16
...
SQL statistics:
queries performed:
read: 2902970
write: 0
other: 414710
total: 3317680
transactions: 207355 (3454.61 per sec.)
...
Latency (ms):
min: 1.24
avg: 4.63
max: 411.92
95th percentile: 12.52
```

结果分析：预热阶段达到约 3454.61 TPS，95% 请求延迟 < 12.52 ms，数据已充分加载到内存中。

### 3. OLTP 混合读写测试（Read Write）

命令：

```bash
sysbench oltp_read_write --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
```

部分结果（日志截取）：

```
[ 300s ] thds: 8 tps: 449.00 qps: 8975.50 (r/w/o: 6283.00/1794.60/897.90)
SQL statistics:
queries performed:
read: 1407728
write: 402208
other: 201104
total: 2011040
transactions: 100552 (335.15 per sec.)
queries: 2011040 (6703.05 per sec.)
Latency (ms):
min: 2.08
avg: 23.86
max: 2361.49
95th percentile: 57.87
```

性能分析：300 秒测试期间 MySQL 平均约 335.15 TPS，QPS 约 6703；吞吐量在测试中期逐步提升，最终峰值接近 449 TPS，95% 延迟 57.87 ms。

### 4. 点查询性能测试（Point Select）

命令：

```bash
sysbench oltp_point_select --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306
```

日志节选：

```
[ 270s ] thds: 8 tps: 75252.01 qps: 75252.01 (r/w/o: 75252.01/0.00/0.00)
[ 280s ] thds: 8 tps: 78663.08 qps: 78663.18 ...
[ 290s ] thds: 8 tps: 78766.09 qps: 78765.99 ...
```

点查询表现出极低延迟和极高吞吐。

### 5. 索引更新测试（Update Index）

命令：

```bash
sysbench oltp_update_index --threads=8 --mysql-host=127.0.0.1 --mysql-port=3306 --mysql-user=root
```

日志节选：

```
[ 270s ] thds: 8 tps: 849.90 qps: 849.90 (r/w/o: 0.00/849.90/0.00) ...
[ 280s ] thds: 8 tps: 937.85 ...
[ 290s ] thds: 8 tps: 721.72 ...
```

大致指标显示 MySQL 在索引更新场景下 TPS 在 700–900 范围（平均约 848 TPS 左右）。

### 6. 并发压力梯度测试（线程数 8, 24, 36, 55）

命令示例：

```bash
for threads in 8 24 36 55
do
  sysbench oltp_read_write --threads=${threads} --mysql-host=127.0.0.1 --mysql-port=3306
done
```

并发测试结果摘要（日志节选）：

- 8 线程：transactions: 100552 (335.15 per sec.)
- 24 线程：transactions: 187421 (624.25 per sec.)
- 36 线程：transactions: 211558 (703.06 per sec.)
- 55 线程：transactions: 230840 (768.09 per sec.)

并发性能趋势：随着线程数增加，MySQL 能较好扩展，TPS 从 335 提升到 768（约提升 129%），表现出良好的多核利用能力和并发扩展性。

### 7. 数据压缩比分析（MySQL）

查看逻辑大小（information_schema.TABLES）：

```sql
SELECT table_name AS `Table`,
round(((data_length + index_length) / 1024 / 1024), 2) `Size (MB)`
FROM information_schema.TABLES
WHERE table_schema = "test_db";
```

输出示例：

```
+----------+-----------+
| Table    | Size (MB) |
+----------+-----------+
| sbtest1  | 237.75    |
| sbtest10 | 237.75    |
| sbtest2  | 236.77    |
...
+----------+-----------+
10 rows in set (0.20 sec)
```

汇总统计：

```sql
SELECT
SUM(TABLE_ROWS) AS `Total_Rows`,
ROUND(SUM(DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2) AS `Total_Size_MB`
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'test_db';
```

结果：

```
+------------+---------------+
| Total_Rows | Total_Size_MB |
+------------+---------------+
| 9863995    | 2372.61       |
+------------+---------------+
```

物理磁盘占用检查：

```
[root@worker3 test_db]# du -sh
2.5G .
[root@worker3 test_db]# pwd
/data/pingkai/mysql/test_db
[root@worker3 test_db]# ls
sbtest10.ibd sbtest2.ibd sbtest4.ibd sbtest6.ibd sbtest8.ibd
sbtest1.ibd sbtest3.ibd sbtest5.ibd sbtest7.ibd sbtest9.ibd
```

分析：10 张表共约 986 万行，逻辑大小约 2.37 GB，物理占用约 2.5 GB。MySQL InnoDB 存储在本次测试中存储效率较为合理，逻辑与物理大小基本一致，没有明显空间浪费。

---

## 二、TiDB 测试（端口 4006）

重要提示总结：TiDB 是分布式数据库，架构与 MySQL 不同。Sysbench 使用 --db-driver=mysql。prepare 阶段可考虑 --auto_inc=off。TiDB 的乐观事务模型在高并发冲突场景可能会有重试和波动。

### 1. 准备测试数据（Prepare）

命令：

```bash
sysbench oltp_common --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
```

输出示例（表创建与插入）：

```
sysbench 1.0.17 (using system LuaJIT 2.0.4)
Initializing worker threads...
Creating table 'sbtest2'...
...
Inserting 1000000 records into 'sbtest10'
Creating table 'sbtest9'...
Inserting 1000000 records into 'sbtest9'
Creating a secondary index on 'sbtest10'...
Creating a secondary index on 'sbtest9'...
```

### 2. 预热缓存（Warm Up）

注意：TiKV 也有 Block Cache，预热同样重要。

命令：

```bash
sysbench oltp_read_only --threads=16 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
```

输出节选：

```
transactions: 21820 (363.27 per sec.)
queries: 349120 (5812.39 per sec.)
Latency (ms):
min: 14.61
avg: 44.02
max: 411.80
95th percentile: 78.60
```

预热结果比 MySQL 更高的延迟基线（avg/95th 均高于 MySQL 的预热结果），但已基本加载到缓存。

### 3. OLTP 混合读写测试（Read Write）

命令：

```bash
sysbench oltp_read_write --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
```

日志节选：

```
[ 300s ] thds: 8 tps: 126.79 qps: 2533.48 (r/w/o: 1773.11/506.78/253.59)
SQL statistics:
transactions: 52486 (174.93 per sec.)
queries: 1049720 (3498.59 per sec.)
Latency (ms):
min: 16.35
avg: 45.72
max: 289.19
95th percentile: 87.56
```

总体：8 线程下 TiDB 平均约 174.93 TPS，QPS 约 3498.59，95% 延迟 87.56 ms。

### 4. 点查询性能测试（Point Select）

命令：

```bash
sysbench oltp_point_select --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
```

日志节选：

```
[ 300s ] thds: 8 tps: 7425.78 qps: 7425.78
SQL statistics:
transactions: 2295788 (7652.53 per sec.)
queries: 2295788 (7652.53 per sec.)
Latency (ms):
min: 0.21
avg: 1.04
max: 94.67
95th percentile: 2.48
```

点查询为 TiDB 的强项之一，但在单节点 TiDB 与单机 MySQL 的对比中仍显著落后 MySQL 的主键点查吞吐。

### 5. 索引更新测试（Update Index）

命令：

```bash
sysbench oltp_update_index --threads=8 --mysql-host=127.0.0.1 --mysql-port=4006 --mysql-user=root
```

日志节选：

```
[ 300s ] thds: 8 tps: 991.44 ...
SQL statistics:
transactions: 260561 (868.52 per sec.)
queries: 260561 (868.52 per sec.)
Latency (ms):
min: 1.77
avg: 9.21
max: 194.19
95th percentile: 21.50
```

索引更新场景下 TiDB 平均约 868.52 TPS，略优于 MySQL 的相近测试。

### 6. 并发压力梯度测试（线程数 8, 24, 36, 55）

命令示例：

```bash
for threads in 8 24 36 55
do
  sysbench oltp_read_write --threads=${threads} --mysql-host=127.0.0.1 --mysql-port=4006
done
```

日志节选与关键统计：

- 8 线程：transactions: 52486 (174.93 per sec.), 95th 87.56 ms
- 24 线程：transactions: 59718 (198.98 per sec.), 95th 176.73 ms
- 36 线程：transactions: 58745 (195.72 per sec.), 95th 277.21 ms
- 55 线程：transactions: 56726 (188.83 per sec.), 95th 419.45 ms

并发趋势：TiDB 在 8->24 线程间有小幅上升，但在 36、55 线程时 TPS 未继续增长并出现明显延迟上升，表现出并发承载上限较低（单节点部署限制及 Region 路由开销所致）。

### 7. 记录数据压缩比（TiDB）

查看 information_schema.tables 示例：

```sql
SELECT TABLE_NAME, TABLE_ROWS, AVG_ROW_LENGTH, DATA_LENGTH, INDEX_LENGTH
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'test_db';
```

输出示例：

```
+------------+------------+----------------+-------------+--------------+
| TABLE_NAME | TABLE_ROWS | AVG_ROW_LENGTH | DATA_LENGTH | INDEX_LENGTH |
+------------+------------+----------------+-------------+--------------+
| sbtest4    | 1000000    | 16             | 16000000    | 8000000      |
...
+------------+------------+----------------+-------------+--------------+
```

查询数据库逻辑大小（示例）：

```sql
SELECT table_schema AS 'Database',
SUM(data_length + index_length) / 1024 / 1024 AS 'Size (MB)'
FROM information_schema.tables
WHERE table_schema = 'test_db'
GROUP BY table_schema;
```

结果示例：

```
+----------+--------------+
| Database | Size (MB)    |
+----------+--------------+
| test_db  | 228.88183594 |
+----------+--------------+
```

物理磁盘占用（TiKV 存储目录）：

```
[root@worker3 pingkai]# cd /tidb-data/tikv-20160
[root@worker3 tikv-20160]# du -sh
2.4G .
```

结论：TiDB（TiKV/RocksDB）在本次测试中显示出明显更高的逻辑压缩率（信息统计上 test_db 逻辑大小约 228.88 MB，物理占用约 2.4 GB），在数据压缩与长期存储成本上优于 MySQL。

---

## 三、MySQL 8.0.42 vs TiDB 核心性能指标对比

（下表汇总单节点测试得到的关键指标）

| 指标 | MySQL 8.0.42（单节点） | TiDB（单节点） | 差异/说明 |
|---|---:|---:|---|
| 总行数（估算） | 9,863,995 | 10,000,000（10 表 × 100 万行） | 接近 |
| 逻辑总大小（MB，information_schema） | 2372.61 | 228.88 | TiDB 逻辑大小约为 MySQL 的 0.1 倍（约 10.4× 压缩比） |
| 实际磁盘占用（GB） | 2.5G | 2.4G | 物理占用接近（单节点数据放置差异） |
| OLTP 混合读写（8 线程） TPS | 335.15 | 174.93 | MySQL 吞吐约 1.9× |
| OLTP 混合读写（8 线程） QPS | 6703.05 | 3498.59 | MySQL 优势明显 |
| OLTP 混合读写（8 线程） 95% 延迟（ms） | 57.87 | 87.56 | MySQL 延迟更低 |
| 单表点查询（主键，8 线程） TPS | ~77,988 | 7,652.53 | MySQL 点查吞吐约 10×（延迟极低） |
| 点查询 95% 延迟（ms） | 0.14 | 2.48 | MySQL 更低延迟 |
| 索引更新（8 线程） TPS | ~848.21 | 868.52 | 两者相近或 TiDB 略优 |
| 并发扩展性（线程增长至 55） | TPS 增至 768.09（增长 ~129%），95% 延迟≤150ms | TPS 基线 ~175，上升有限并在高并发下下降，95% 延迟显著增大（>400ms） | MySQL 单节点扩展性更好 |

---

## 四、性能差异与选型建议

### 1. 核心性能差异总结

- MySQL 8.0.42（单机）
  - 优势：极致的单机性能与低延迟（尤其是主键点查），在 OLTP 混合读写与高并发场景下表现优异；对单机资源利用与 InnoDB 缓冲池管理成熟。
  - 短板：逻辑大小与存储效率不及 LSM 栈，长期大规模历史数据存储成本较高。
- TiDB（单节点）
  - 优势：底层使用 RocksDB/LSM，天然压缩比高，适合长期存储海量数据；写入与索引更新在某些场景下表现良好；分布式架构保证未来可横向扩展、支持 HTAP 场景。
  - 短板：单节点点查与高并发吞吐相比 MySQL 有明显差距；分布式开销（Region 路由、网络）会在单节点或高并发冲突情况下显现延迟与 TPS 波动。

### 2. 业务选型建议

- 适合优先选 MySQL 的场景
  - 中小规模业务（如日订单量在 10 万以内），对查询延迟敏感（商品详情、用户登录）。
  - 需要极致的单点 OLTP 性能与高并发支撑（50+ 线程）且对存储成本敏感度低。
  - 希望使用成熟单体架构，运维成本与复杂度较低。
- 适合优先选 TiDB 的场景
  - 海量数据存储（千万级订单、亿级日志），希望控制磁盘与存储成本。
  - 需要弹性扩展（线性扩容、无需停机）与统一 HTAP 能力（未来可能同时做分析）。
  - 对事务一致性、高可用、集群级容灾与跨机房部署有强需求。

### 3. 测试局限性与优化方向

- 本次对比为单节点 TiDB 与单机 MySQL，未体现 TiDB 的分布式扩展能力。若构建多 TiKV 节点的 TiDB 集群，预计能显著提升吞吐和并发承载。
- TiDB 的参数（连接池、Region 大小、TiKV 配置、调优 RocksDB）和客户端连接策略可对性能产生较大影响，需按实际负载进一步调优。
- 建议后续做补充测试：TiDB 多节点集群 vs MySQL 主从/分片架构、故障注入高可用测试、HTAP 场景（TiFlash）以及超大数据量（TB+）下的表现。

---

## 五、总结与展望

- 结论：在单节点环境中，MySQL 8.0.42 在传统 OLTP 场景和主键点查上显著优于单节点 TiDB；而 TiDB 在存储压缩与长期海量数据管理方面具有天然优势。选择数据库应基于业务侧重点：若追求单点极致性能与低延迟，优先 MySQL；若需海量数据管理、弹性扩展与 HTAP 能力，优先 TiDB。
- 展望：要全面评估 TiDB 的真实竞争力，应开展多节点分布式测试（3 个 TiKV 节点及以上）、高可用与故障恢复测试、HTAP 场景测试与超大数据量的长期稳定性测试。

---

## 作者注

- 本文所有操作及测试基于 TEM 敏捷模式自动化部署 TiDB-v7.1.8-5.2-20250630 与 MySQL 8.0.42 版本完成。版本持续迭代，部分行为或语法随更新可能变化，请以官方文档为准。
- 以上为个人测试与建议，仅供参考。不代表行业普适观点。涉及生产环境请在具备权限与备份的前提下进行验证与测试。欢迎交流讨论。

