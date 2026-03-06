# MySQL 5.7 半同步复制优缺点、配置及实操记录

作者：毛何远  
日期：2025-08-14

## 一、核心优点
- 数据一致性提升  
  主库提交事务前至少等待一个从库接收 Binlog 并写入 Relay Log，减少主库宕机导致的数据丢失风险。MySQL 5.7 的 AFTER_SYNC 模式（默认）表示主库先同步 Binlog 到从库再提交事务，一致性更强。

- 性能平衡  
  与全同步复制相比，仅需等待一个从库 ACK，降低延迟，适合高并发场景。

- 自动降级与高可用  
  超时或从库异常时会自动切换为异步复制，避免主库长时间阻塞，提升系统可用性。

## 二、主要问题
- 性能影响  
  主库需等待从库 ACK，网络延迟或从库负载高时，事务提交速度会下降。

- 超时降级风险  
  若所有从库长时间未响应，主库会降级为异步复制，可能导致数据不一致。

- 配置复杂度  
  需安装插件并调整参数（如超时时间、等待从库数量），生产环境需谨慎测试。

## 三、具体配置步骤（以主从架构为例）

### 1. 前提条件
- 主从复制已配置完成，server-id 唯一，Binlog 已开启。  
- MySQL 版本 ≥ 5.7，支持动态加载插件。

### 2. 安装插件
在主库执行：
```sql
INSTALL PLUGIN rpl_semi_sync_master SONAME 'semisync_master.so';
SET GLOBAL rpl_semi_sync_master_enabled = 1;
```

在从库执行：
```sql
INSTALL PLUGIN rpl_semi_sync_slave SONAME 'semisync_slave.so';
SET GLOBAL rpl_semi_sync_slave_enabled = 1;
```

通过 `SHOW PLUGINS;` 验证插件是否加载成功。

### 3. 关键参数配置（my.cnf / my.ini）
建议在配置文件中持久化以下参数，并重启 MySQL 使配置生效。

主库（master）相关配置项示例：
```ini
[mysqld]
rpl_semi_sync_master_enabled = 1
rpl_semi_sync_master_timeout = 5000              # 超时时间（毫秒，默认10000）
rpl_semi_sync_master_wait_for_slave_count = 1    # 等待从库数量，默认 1
rpl_semi_sync_master_wait_point = AFTER_SYNC     # 推荐模式：先同步再提交
```

从库（slave）相关配置项示例：
```ini
[mysqld]
rpl_semi_sync_slave_enabled = 1
```

注意：在 Windows 下的 my.ini 示例中可能需要指定 `plugin_dir` 并使用 `plugin-load` 加载 DLL（示例见下）。

### 4. 验证状态
在主库上：
```sql
SHOW STATUS LIKE 'Rpl_semi_sync_master_status';
SHOW STATUS LIKE 'Rpl_semi_sync_master_clients';
```
示例输出：
```
| Rpl_semi_sync_master_status  | ON |
| Rpl_semi_sync_master_clients | 1  |
```

在从库上：
```sql
SHOW STATUS LIKE 'Rpl_semi_sync_slave_status';
```
示例输出：
```
| Rpl_semi_sync_slave_status | ON |
```

## 四、注意事项

- 参数调优  
  根据网络延迟调整 `rpl_semi_sync_master_timeout`，以避免频繁降级。在多从库场景下，可将 `rpl_semi_sync_master_wait_for_slave_count` 设置为 2 或更高，以提升数据安全性，但会带来额外延迟。

- 监控与告警  
  使用 `SHOW GLOBAL STATUS` 监控 `Rpl_semi_sync_master_no_tx`（未确认事务数），及时发现异常或退化情况。

- 与组复制的区别  
  半同步复制仅保证至少一个从库同步；组复制（Group Replication）则需要所有节点确认，适用于需要强一致性的场景。

## 五、my-master 配置文件示例（Windows）
```ini
[mysqld]
port=3311
basedir=D:/mysql_wite_read/3311
datadir=D:/mysql_wite_read/3311/data
server-id=3311
log-bin=mysql-bin-3311
slave_net_timeout=65
default-time-zone=SYSTEM
lc-messages-dir=D:/mysql_wite_read/mysql-5.7.44-winx64/share
explicit_defaults_for_timestamp=ON

slow_query_log=1
slow_query_log_file=D:/mysql_wite_read/3311/data/mysql-slow.log
long_query_time=1
log_queries_not_using_indexes=1
log_output=FILE
log_timestamps=SYSTEM

log_error=D:/mysql_wite_read/3311/data/error.log
log_error_verbosity=3

plugin_dir=D:/mysql_wite_read/mysql-5.7.44-winx64/lib/plugin
plugin-load="rpl_semi_sync_master=semisync_master.dll"
rpl_semi_sync_master_enabled=1
rpl_semi_sync_master_timeout=5000
rpl_semi_sync_master_wait_for_slave_count=1
rpl_semi_sync_master_wait_point=AFTER_SYNC
```

## 六、my-slave 配置文件示例（Windows）
```ini
[mysqld]
port=3312
basedir=D:/mysql_wite_read/3312
datadir=D:/mysql_wite_read/3312/data
server-id=3312
log-bin=mysql-bin-3312
default-time-zone=SYSTEM
lc-messages-dir=D:/mysql_wite_read/mysql-5.7.44-winx64/share
explicit_defaults_for_timestamp=ON

slow_query_log=1
slow_query_log_file=D:/mysql_wite_read/3312/data/mysql-slow.log
long_query_time=1
log_queries_not_using_indexes=1
log_output=FILE
log_timestamps=SYSTEM

log_error=D:/mysql_wite_read/3312/data/error.log
log_error_verbosity=3

plugin_dir=D:/mysql_wite_read/mysql-5.7.44-winx64/lib/plugin
plugin-load="rpl_semi_sync_slave=semisync_slave.dll"
rpl_semi_sync_slave_enabled=1
```

## 七、示例：客户端连接与验证（Windows）
在主库（3311）上连接并验证：
```bash
D:\mysql_wite_read\mysql-5.7.44-winx64\bin\mysql.exe -u root -p -h 127.0.0.1 -P 3311
# 然后在 mysql 提示符下执行：
SHOW STATUS LIKE 'Rpl_semi_sync_master_status';
SHOW STATUS LIKE 'Rpl_semi_sync_master_clients';
```

在从库（3312）上连接并验证：
```bash
D:\mysql_wite_read\mysql-5.7.44-winx64\bin\mysql.exe -u root -p -h 127.0.0.1 -P 3312
# 然后在 mysql 提示符下执行：
SHOW STATUS LIKE 'Rpl_semi_sync_slave_status';
```

---

如果需要，我可以提供：
- 生产环境下的优化建议（监控指标、告警规则）；
- 基于多从库的容灾配置建议与故障演练步骤。