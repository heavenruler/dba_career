# TiDB 与 MySQL 在备份容灾体系的衡量对比

作者：TiDB 社区用户  
日期：2024-04-16

如果把数据库的工作建设分为三大体系，从前中后的角度来看，可以笼统一点分为：
- 开发设计体系（前）——考虑产品技术造型、基准测试、最佳实践、开发者使用规范等，使产品对准业务有的放矢。
- 监控优化体系（中）——关注流量、延迟、饱和度、关键指标、查询优化等运维因素，保障产品健康运行。
- 备份恢复体系（后）——关注高可用、业务连续性、灾后恢复，通过额外技术手段保障售后安全。

三大体系可以洞悉产品的覆盖度与成熟度。对于业务和 DBA 而言，开发设计体系和监控优化体系是常做的工作，而备份容灾体系往往需要一次性投入较大精力来制定完整策略。MySQL 的备份容灾体系已较为成熟，下面将对 MySQL 与 TiDB 的备份容灾进行技术对比。

## MySQL 备份体系

MySQL 的备份技术栈包括逻辑备份工具（如 mysqldump、mydumper、dumpling）和物理备份工具（如 XtraBackup）。

- 逻辑备份的定义：从数据库接口层出发，客户端像执行其它 SQL 语句一样访问服务端，输出为 SQL 语句或 CSV 文件。
- 物理备份：直接针对硬盘上的持久化物理文件进行备份，不需要 SQL 解析，因此处理速度快。

mysqldump 是典型的逻辑备份工具，可以指定某个库、某个表或全库备份。进行备份时，若要求一致性，通常会打开 General 日志并启用全局锁，阻止其它 DDL/DML 操作，常用命令为 `FLUSH TABLES WITH READ LOCK`，备份完成后才会解锁。mysqldump 的一致性依赖事务或全局锁（例如 `--single-transaction`）来保证。

mydumper 相对于 mysqldump 备份速度更快，因为 mysqldump 是单线程，而 mydumper 支持多线程并可对输出文件进行压缩。缺点是 mydumper 占用更多资源；恢复时仍需在 MySQL 的逻辑层进行 SQL 解析，恢复速度并不一定有明显优势。

XtraBackup（xtrabackup）是针对 InnoDB 引擎的物理备份工具，常见版本包括 2.4（适用于 MySQL 5.6/5.7）和 8.0（适用于 MySQL 8.0）。XtraBackup 的备份原理大致分三步：

1. 识别并获取目标数据源，备份最近一次 checkpoint 点之后的 redo 日志，对刷到硬盘但未完全进入 InnoDB 的数据进行回放。
2. 拷贝物理文件：分为 IBD 文件（表空间、独立表空间、undo 文件等）与非 IBD 文件。拷贝非 IBD 文件时会加全局锁，防止 DML/DDL 干扰。在 MySQL 8.0.27 之后，对于备份过程中的操作区分更细（允许某些 DDL 而禁止 DML），进一步细化备份一致性的粒度。
3. 当最后一个非 IBD 文件传输完成并且 redo 日志的拷贝结束时，备份完成并自动解锁。

XtraBackup 支持基于全量备份与 redo 日志的增量备份。它通过识别 redo 日志的 LSN（Log Sequence Number）变化来决定需要备份的增量数据。恢复时可以基于全量恢复、增量恢复，或全量恢复加日志回放，能够实现基于时间点的恢复（PITR，Point-In-Time Recovery）。

总体上，MySQL 的物理备份强调与生产数据的协调，使用全局锁、redo 日志监控和文件传输等技术保证备份的一致性与可恢复性，较为谨慎并倾向于更多的安全保障（代价是对生产的更明显影响）。

## TiDB 备份体系

TiDB 支持使用 mysqldump 和 mydumper，但它们只能在逻辑层面对已经持久化的数据进行备份，无法获得全局一致性的快照（因为 TiDB 未实现 MySQL 风格的全局锁）。例如：

- 使用 mysqldump 的 `--single-transaction`：
```bash
root@henley-Inspiron-7447:/tmp# mysqldump -h192.168.10.14 -u root -pGmcc@1234 -P4000 --single-transaction
mysqldump: [Warning] Using a password on the command line interface can be insecure.
mysqldump: Couldn't execute 'ROLLBACK TO SAVEPOINT sp': SAVEPOINT sp does not exist (1305)
```

- mydumper 在 TiDB 上备份时的提示更明确：
```
** (mydumper:6185): CRITICAL **: 16:34:20.943: Couldn't acquire global lock, snapshots will not be consistent:
```

究其根因，TiDB 不支持 `FLUSH TABLES WITH READ LOCK`，而是使用 `@@tidb_snapshot` 来定位快照时间点：
```
tidb> FLUSH TABLES WITH READ LOCK;
ERROR 1105 (HY000): FLUSH TABLES WITH READ LOCK is not supported. Please use @@tidb_snapshot
```

TiDB 的内存管理机制是：写入的增量数据先放入内存，提交成功的数据对应一个唯一时间戳，内存中的数据在适当时机会冻结并合并到基线数据（持久化到磁盘）。TiDB 的物理备份工具 BR（Backup & Restore）的技术原理正是基于时间戳扫描已提交的物理数据文件，主要分三步：

1. 扫描 KV：从 TiKV 所在的 Region 读取备份时间点对应的数据。
2. 生成 SST：将读取的数据转换并保存为 SST 文件（先存在内存/临时目录中）。
3. 上传 SST：把 SST 文件上传到配置的存储路径（如本地文件系统、S3 等）。

下面是一个小测试：在不断写入数据的情况下，对三个不同时间点做全量备份（时间点示例：2024-04-15 10:18:32、10:18:35、10:22:32），备份命令示例：
```bash
tiup br backup full --pd "192.168.153.128:2379" --backupts '2024-04-15 10:18:32' --storage "/tidb/backup/1"
tiup br backup full --pd "192.168.153.128:2379" --backupts '2024-04-15 10:18:32' --storage "/tidb/backup/2"
tiup br backup full --pd "192.168.153.128:2379" --backupts '2024-04-15 10:18:32' --storage "/tidb/backup/3"
tiup br backup full --pd "192.168.153.128:2379" --backupts '2024-04-15 10:18:35' --storage "/tidb/backup/4"
tiup br backup full --pd "192.168.153.128:2379" --backupts '2024-04-15 10:22:32' --storage "/tidb/backup/5"
```

测试结果显示：在持续增加数据的过程中，第一个时间点的三次备份文件大小为 122M；第二个时间点（比第一个晚 3 秒）备份为 138M；第三个（更晚）为 174M。时间越靠后，识别到的数据越多。TiDB 的物理备份过程只从后端扫描物理文件，不需要与前端写入模块协同加锁；而 MySQL 则通常通过加全局锁来阻止前端写入，确保备份一致性。两者相比，MySQL 更谨慎、延迟更高但安全性更强；TiDB 更依赖时间戳快照，减少对前端的影响。

快照的好处是记住某个时间点的数据集合，可以进行该时间点的数据恢复。例如误操作执行了 truncate，可以通过之前的快照恢复该时间点的数据。

示例：对大表执行 truncate，然后仍然可以通过指定时间点备份恢复数据
```sql
mysql> truncate table 表名3;
Query OK, 0 rows affected (55.24 sec)

mysql> truncate table 表名2;
Query OK, 0 rows affected (0.11 sec)

mysql> truncate table 表名1;
Query OK, 0 rows affected (0.13 sec)
```

在 truncate 后仍可以按以前某一时间点做备份：
```bash
root@server128 tidb]# tiup br backup full --pd "192.168.153.128:2379" --backupts '2024-04-15 11:26:30'
Starting component br: /root/.tiup/components/br/v8.0.0/br backup full --pd 192.168.153.128:2379 --backupts
Detail BR log in /tmp/br.log.2024-04-15T11.28.38+0800
Full Backup <------------------------------------------------------------------------------------------------->
Checksum <---------------------------------------------------------------------------------------------------->
[2024/04/15 11:28:48.091 +08:00] [INFO] [collector.go:77] ["Full Backup success summary"] [total-ranges=47]
```

除了内置的快照，TiDB 也支持外部快照（如 LVM）。使用 LVM 快照备份时，需要把 TiDB 的数据盘安装在 LVM 逻辑卷上。示例展示了数据盘挂载与创建 LVM 快照、合并恢复的流程：

df -h 输出示例：
```
[tidb@server128 backup]$ df -h
Filesystem                                   Size  Used Avail Use% Mounted on
/dev/mapper/centos_server153-root            173G  104G   63G  63% /
devtmpfs                                     6.3G     0  6.3G   0% /dev
tmpfs                                        6.3G     0  6.3G   0% /dev/shm
tmpfs                                        6.3G   75M  6.2G   2% /run
tmpfs                                        6.3G     0  6.3G   0% /sys/fs/cgroup
/dev/sda1                                    269M  117M  135M  47% /boot
/dev/mapper/centos_server153-tidb--deploy    4.7G  1.3G  3.2G  29% /tidb/tidb-deploy
/dev/mapper/centos_server153-tidb--data      20G   13G  5.2G  72% /tidb/tidb-data
tmpfs                                        1.3G     0  1.3G   0% /run/user/0
```

创建 LVM 快照：
```bash
lvcreate -L 5G -s -n lv-mysql-snap01 /dev/centos_server153/tidb-data
lvcreate -L 5G -s -n lv-mysql-snap02 /dev/centos_server153/tidb-data

[root@server128 ~]# lvscan
ACTIVE '/dev/centos_server153/swap' [4.00 GiB] inherit
ACTIVE '/dev/centos_server153/root' [<175.71 GiB] inherit
ACTIVE '/dev/centos_server153/tidb-deploy' [4.88 GiB] inherit
ACTIVE Original '/dev/centos_server153/tidb-data' [19.53 GiB] inherit
ACTIVE Snapshot '/dev/centos_server153/lv-mysql-snap01' [5.00 GiB] inherit
ACTIVE Snapshot '/dev/centos_server153/lv-mysql-snap02' [5.00 GiB] inherit
```

若误删数据并卸载数据盘：
```bash
# 删除数据并卸载
rm -rf /tidb/tidb-data/*
umount /tidb/tidb-data/

# 合并并恢复快照
[root@server128 ~]# lvconvert --merge /dev/centos_server153/lv-mysql-snap02
Merging of volume centos_server153/lv-mysql-snap02 started.
centos_server153/tidb-data: Merged: 80.49%
centos_server153/tidb-data: Merged: 100.00%

# 重新挂载
mount /dev/mapper/centos_server153-tidb--data /tidb/tidb-data/
```

## 备份容灾总结

数据库备份恢复有多种方式，可从接入层（逻辑层）、服务层（旁路导入/导出）和物理层三方面考虑。

- MySQL：
  - 接入层备份：mysqldump、mydumper（或 dumpling）。恢复时需进行 SQL 解析，耗时较多；mydumper 备份快但恢复并不总是显著更快。
  - 服务层备份：导出为 CSV 等规范文件，然后通过 LOAD DATA 等旁路导入，避免 SQL 解析开销，导入速度较快且有序。
  - 物理层备份：XtraBackup 能迁移 MySQL 的物理文件，关注已持久化和未持久化数据，通过 redo 回放释放脏页，恢复后数据文件可直接使用。
  - 快照备份：支持 LVM 等外部快照。

- TiDB：
  - 接入层备份：mysqldump、mydumper（需针对 TiDB 做适配）；由于分布式能力，资源潜力大，间接提升了这些工具的使用效果。
  - 服务层备份：Dumpling（导出）与 Lightning（导入），Lightning 绕过接入层直接在服务层导入，通过转换为 KV 形式性能较高。
  - 物理层备份：BR 工具针对 TiKV 进行时间戳扫描，生成 SST 文件；恢复需使用相应工具进行转换和导入。
  - 快照备份：支持 LVM 等外部快照。

对比来看，MySQL 更倾向于在备份时与生产数据进行协同（如加全局锁、元数据锁以保证结构与数据的一致性），而 TiDB 倾向于基于时间戳快照的方式，减少对生产的影响但可能增加存储成本。实际选型应基于业务可用性要求、恢复点与恢复时间目标（RPO/RTO）、以及运维复杂度来做权衡。