# MySQL InnoDB MONITOR 性能监控

作者: Cuihulong（MySQL从1开始）

MySQL 中碰到问题时，排查故障必不可少的是解读 InnoDB 内部状态（SHOW ENGINE INNODB STATUS）。InnoDB 监视器提供的信息包括：事务、死锁、信号量、IO、自适应哈希、缓冲池等的当前状态。一般 DBA 通过 SQL 命令行在需要时获得标准 InnoDB Monitor 输出到客户端程序中。

默认情况下，InnoDB 提供的是自动循环捕获并覆盖原有信息的方式，因此事故发生后常常无法获取当时的现场信息。InnoDB 内部状态对性能调优非常有用。InnoDB 也可将监视器输出以日志方式记录：当 InnoDB 监视器开启时，大约每 15 秒会将输出写入错误日志或指定的状态文件。

## 1. 启动跟踪

日志输出相关的系统变量有两项，分别用于开启标准 InnoDB Monitor 和 InnoDB Lock Monitor：

```sql
SHOW VARIABLES LIKE '%innodb_status%';
```

示例输出：

```
+----------------------------+-------+
| Variable_name              | Value |
+----------------------------+-------+
| innodb_status_output       | ON    |
| innodb_status_output_locks | OFF   |
+----------------------------+-------+
```

备注：开启/关闭 InnoDB 监视器需要 PROCESS 权限。

可以使用如下命令切换：

```sql
SET GLOBAL innodb_status_output = ON;
SET GLOBAL innodb_status_output_locks = ON;  -- 若需要开启 Lock Monitor
```

### Lock monitor 差异

如果启用 Lock Monitor，就会在输出中包含额外的锁信息。这样可以提供更多操作层面的数据信息，便于准确定位对应的数据操作。

### 文件输出

在不开启 innodb_status_output 参数的情况下，可以通过启动时指定 `innodb-status-file` 选项来启用标准 InnoDB Monitor 输出并将其写入状态文件。当使用此选项时，datadir 下会生成一个名为 `innodb_status` 的文件（带 PID），InnoDB 大约每 15 秒向其写入一次输出。

注意：
- 正常关闭数据库时该文件会自动删除；异常关闭时不会删除。
- 该参数非动态，可在 my.cnf 中添加以启用：

```ini
[mysqld]
innodb_status_file=1
```

或通过启动参数：

```
mysqld --defaults-file=/etc/my8.0.cnf --innodb-status-file=on --user=mysql
```

### 自定义脚本

作为 15 秒周期输出监控的替代方案（15 秒间隔对生产可能太频繁并影响性能），可以通过执行 `SHOW ENGINE INNODB STATUS` 语句并配合脚本与 crontab 定期抓取监控输出，例如每 10 分钟一次。

示例脚本（保存为 innodb_status.sh）：

```bash
#!/bin/bash
################################
# crontab 示例:
# */10 * * * * sh /root/innodb_status.sh
################################

source /etc/profile
HOSTNAME="127.0.0.1"
PORT="3380"
USERNAME="root"
PASSWORD="123456"
SOCK="/opt/data8.0/mysql/mysql.sock"

mysql_innodbstatus(){
  AWR_PATH="/opt/data8.0/logs/$1"
  if [ ! -d "$AWR_PATH" ] ; then
    mkdir -p "$AWR_PATH"
  fi
  FINENAME="$AWR_PATH/$(date +mysql_awr_%Y-%m-%d).log"
  if [ ! -f "$FINENAME" ] ; then
    touch -p "$FINENAME"
  fi

  now=$(date +"%Y-%m-%d %H:%M:%S")
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> "$FINENAME"
  echo "innodb engine" >> "$FINENAME"
  echo "+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++" >> "$FINENAME"

  mysql --user="${USERNAME}" --password="${PASSWORD}" --socket="${SOCK}" -A -e "show engine innodb status\G" >> "$FINENAME"

  # delete files older than 10 days
  find "$AWR_PATH" -type f -mtime +10 | xargs rm -f
}

mysql_innodbstatus 3380
```

## 2. 指标说明

InnoDB 监控目前的主要关注点包括信号量（semaphore）、事务（transaction）、死锁、外键及相关锁等问题。InnoDB 状态输出中包含许多有用的指标用于定位性能瓶颈与并发问题。可参考相关文章了解指标含义和分析方法（示例参考资料）:

https://www.modb.pro/db/80471

## 3. InnoDB Monitor 会自动打开的情况

InnoDB 在以下情况下会暂时启用标准 InnoDB Monitor 输出（自动触发）：

- 长时间的 semaphore wait（信号量等待）
- InnoDB 无法在缓冲池中找到空闲的块
- 超过 67% 的缓冲池被脏页或自适应哈希索引占用

当自动触发时，InnoDB 会把当前状态写入错误日志（或状态文件），以便诊断相关问题。

## 4. 总结

- 建议仅在真正需要时启用监视器，否则关键的瞬时信息可能已被覆盖或刷新掉。对于负载较低的 MySQL 实例，可考虑长期开启；对于生产高负载实例，建议采用定期脚本抓取方式并控制频率。
- InnoDB 监视输出会带来一定的性能开销：经 sysbench 多次测试，通常性能损耗约 0.2% ~ 3%。目前尚无证据表明会导致数据库完全不可用，但仍需谨慎启用。
- 日志刷新为大约每 15 秒一次，但状态收集与输出也需时间，因此两次日志写入并非严格的 15 秒间隔。
- 若监视器输出指向错误日志，错误日志会迅速增大，应定期使用 FLUSH ERROR LOGS 或其他日志轮转方式进行切割。
- 将输出定向到单独的状态文件（innodb-status-file）也会带来大文件问题，且频率可能过高。若可提供控制输出频率的参数并支持不自动删除历史文件，会更为友好。