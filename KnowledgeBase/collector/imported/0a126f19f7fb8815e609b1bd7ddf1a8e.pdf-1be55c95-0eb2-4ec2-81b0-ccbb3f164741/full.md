首页 资讯 活动 大会 学习 文档 问答 服务 登录 注册
首页 / MySQL 5.7 半同步复制优缺点、配置及实操记录​
MySQL 5.7 半同步复制优缺点、配置及实操记录​
原创 毛何远 2025-08-14 255
毛何远
关注
​一、核心优点​
文章 粉丝 浏览量
​数据一致性提升​
热门文章 主库提交事务前至少等待一个从库接收Binlog并写入Relay Log，减少主库宕机导致的数据
丢失风险。
MySQL 5.7主从同步功能 ​AFTER SYNC模式​（默认）：主库先同步Binlog到从库再提交事务，一致性更强。
2025-08-06 464浏览 ​性能平衡​
相比全同步复制，仅需等待一个从库ACK，降低延迟，适合高并发场景。 mysql主从同步存在的问题与解决
2025-08-08 259浏览 ​自动降级与高可用​
超时或从库异常时自动切换为异步复制，避免主库阻塞，提升系统可用性。 mysql 历史数据表迁出工具方案
2025-08-06 253浏览
​二、主要问题​ CentOS7修复OpenSSH漏洞升级到Open
SSH 9.8 RPM一键更新包实操过程
2025-08-13 158浏览 ​性能影响​
MySQL 8.1大表加字段会导致数据库长时 主库需等待从库ACK，网络延迟或从库负载高时，事务提交速度下降。
间锁表问题解决 ​超时降级风险​
2025-09-25 139浏览 若所有从库长时间未响应，主库会降级为异步复制，可能导致数据不一致。
​配置复杂度​
在线实训环境入口 需安装插件并调整参数（如超时时间、等待从库数量），生产环境需谨慎测试。
MySQL在线实训环境
​三、具体配置步骤（以主从架构为例）​​ 查看详情
​1. 前提条件​
最新文章 主从复制已配置完成，server-id唯一，Binlog开启。
MySQL版本≥5.7，支持动态加载插件。
MySQL 8.1大表加字段会导致数据库长时 ​2. 安装插件​ 间锁表问题解决
2025-09-25 139浏览 ​主库​：
INSTALL PLUGIN rpl_semi_sync_master SONAME ‘semisync_master.so’; 双主同步一条记录主键冲突处理
2025-09-25 43浏览 SET GLOBAL rpl_semi_sync_master_enabled = 1;
mysql5.7 sql语句慢日志开启及遇到的问 ​从库​： 题
INSTALL PLUGIN rpl_semi_sync_slave SONAME ‘semisync_slave.so’; 2025-08-13 88浏览
SET GLOBAL rpl_semi_sync_slave_enabled = 1;
CentOS7修复OpenSSH漏洞升级到Open 可通过SHOW PLUGINS;验证插件是否加载成功。 SSH 9.8 RPM一键更新包实操过程
2025-08-13 158浏览
​3. 关键参数配置（my.cnf/my.ini）​​
mysql主从同步存在的问题与解决
​主库​ini：semisync_master.dll 2025-08-08 259浏览
[mysqld]
目录

rpl_semi_sync_master_enabled = 1
​一、核心优点​ rpl_semi_sync_master_timeout = 5000 # 超时时间（毫秒，默认10000）
​二、主要问题​ rpl_semi_sync_master_wait_for_slave_count = 1 # 等待从库数量，默认1
rpl_semi_sync_master_wait_point = AFTER_SYNC # 推荐模式：先同步再提交 ​三、具体配置步骤（以主从架构为例）​​
​四、注意事项​ ​从库​ini：
五、my-master配置文件 [mysqld]
六、my-slave配置文件 rpl_semi_sync_slave_enabled = 1
重启MySQL使配置生效。 七、my-master验证
八、my-slave验证 ​4. 验证状态​
​主库​：
SHOW STATUS LIKE ‘Rpl_semi_sync_master_status’; # 应显示’ON’
SHOW STATUS LIKE ‘Rpl_semi_sync_master_clients’; # 显示已连接的从库数量
​从库​：
SHOW STATUS LIKE ‘Rpl_semi_sync_slave_status’; # 应显示’ON’
​四、注意事项​
​参数调优​：
高延迟网络可增大rpl_semi_sync_master_timeout，避免频繁降级。
多从库场景下，rpl_semi_sync_master_wait_for_slave_count可设置为2，进一步提升数
据安全性。
​监控与告警​：
通过SHOW GLOBAL STATUS监控Rpl_semi_sync_master_no_tx（未确认事务数），及时
发现异常。
​与组复制的区别​：
半同步复制仅保证至少一个从库同步，而组复制（Group Replication）需所有节点确认，适
用于强一致性场景
五、my-master配置文件
[mysqld]
port=3311
basedir=D:/mysql_wite_read/3311
datadir=D:/mysql_wite_read/3311/data
server-id=3311
log-bin=mysql-bin-3311
slave_net_timeout = 65
#时区配置
default-time-zone =SYSTEM
lc-messages-dir = D:/mysql_wite_read/mysql-5.7.44-winx64/share
#secure_file_priv = D:/mysql_wite_read/3311/upload
explicit_defaults_for_timestamp = ON
#慢日志配置
slow_query_log = 1
slow_query_log_file =D:/mysql_wite_read/3311/data/mysql-slow.log
long_query_time = 1
log_queries_not_using_indexes = 1
log_output = FILE

log_timestamps=SYSTEM
#错误日志配置
log_error = D:/mysql_wite_read/3311/data/error.log
log_error_verbosity = 3
#插件配置
plugin_dir = D:/mysql_wite_read/mysql-5.7.44-winx64/lib/plugin
#半同步配置
plugin-load = “rpl_semi_sync_master=semisync_master.dll”
rpl_semi_sync_master_enabled = 1
rpl_semi_sync_master_timeout = 5000 # 超时时间，单位毫秒，可根据网络情况调整
rpl_semi_sync_master_wait_for_slave_count = 1 # 等待从库数量，默认 1
rpl_semi_sync_master_wait_point = AFTER_SYNC # 推荐模式
六、my-slave配置文件
[mysqld]
port=3312
basedir=D:/mysql_wite_read/3312
datadir=D:/mysql_wite_read/3312/data
server-id=3312
log-bin=mysql-bin-3312
#时区配置
default-time-zone =SYSTEM
lc-messages-dir = D:/mysql_wite_read/mysql-5.7.44-winx64/share
#secure_file_priv = D:/mysql_wite_read/3311/upload
explicit_defaults_for_timestamp = ON
#慢日志配置
slow_query_log = 1
slow_query_log_file =D:/mysql_wite_read/3312/data/mysql-slow.log
long_query_time = 1
log_queries_not_using_indexes = 1
log_output = FILE
log_timestamps=SYSTEM
#错误日志配置
log_error = D:/mysql_wite_read/3312/data/error.log
log_error_verbosity = 3
#插件配置
plugin_dir = D:/mysql_wite_read/mysql-5.7.44-winx64/lib/plugin
#半同步配置
plugin-load = “rpl_semi_sync_slave=semisync_slave.dll”
rpl_semi_sync_slave_enabled = 1
七、my-master验证

C:\Users\Administrator>D:\mysql_wite_read\mysql-5.7.44-winx64\bin\mysql.exe -u r
oot -p -h 127.0.0.1 -P 3311
Enter password: ****************
Welcome to the MySQL monitor. Commands end with ; or \g.
Your MySQL connection id is 4
Server version: 5.7.44-log MySQL Community Server (GPL)
Copyright © 2000, 2023, Oracle and/or its affiliates.
Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.
Type ‘help;’ or ‘\h’ for help. Type ‘\c’ to clear the current input statement.
mysql> SHOW STATUS LIKE ‘Rpl_semi_sync_master_status’
-> ;
±----------------------------±------+
| Variable_name | Value |
±----------------------------±------+
| Rpl_semi_sync_master_status | ON |
±----------------------------±------+
1 row in set (0.00 sec)
mysql> SHOW STATUS LIKE ‘Rpl_semi_sync_master_clients’;
±-----------------------------±------+
| Variable_name | Value |
±-----------------------------±------+
| Rpl_semi_sync_master_clients | 1 |
±-----------------------------±------+
1 row in set (0.00 sec)
mysql>
八、my-slave验证
C:\Users\Administrator>D:\mysql_wite_read\mysql-5.7.44-winx64\bin\mysql.exe -u r
oot -p -h 127.0.0.1 -P 3312
Enter password: ****************
Welcome to the MySQL monitor. Commands end with ; or \g.
Your MySQL connection id is 4
Server version: 5.7.44-log MySQL Community Server (GPL)
Copyright © 2000, 2023, Oracle and/or its affiliates.
Oracle is a registered trademark of Oracle Corporation and/or its
affiliates. Other names may be trademarks of their respective
owners.
Type ‘help;’ or ‘\h’ for help. Type ‘\c’ to clear the current input statement.
mysql> SHOW STATUS LIKE ‘Rpl_semi_sync_slave_status’;
±---------------------------±------+
| Variable_name | Value |

±---------------------------±------+
| Rpl_semi_sync_slave_status | ON |
±---------------------------±------+
1 row in set (0.00 sec)
mysql>
墨力计划 mysql mysql半同步复制 数据库实操
「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」
关注作者 点赞
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信息，否则作者
和墨天轮有权追究责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contact@modb.pro进行举报，并
提供相关证据，一经查实，墨天轮将立刻删除相关内容。
评论
相关阅读
《MySQL 8.4.6 单机安装手册》
歪比叭啵 1205次阅读 2025-10-14 15:22:50
【文档悬赏令】第1号：数据库新版本的安装实操，欢迎上传赢取奖励！
墨天轮编辑部 818次阅读 2025-10-13 16:19:21
国产数据库时代，不懂业务的 DBA 会被淘汰吗？
芬达 641次阅读 2025-11-03 18:25:23
ACDU周度精选 | 本周数据库圈热点 + 技术干货分享（2025/10/11期）
墨天轮小助手 489次阅读 2025-10-11 14:24:19
MySQL8.0逻辑备份mysqldump全备脚本
Rock Yan 428次阅读 2025-10-21 11:34:25
如期而至！MySQL 9.5.0 创新版本发布
严少安 383次阅读 2025-10-22 00:44:12
ACDU周度精选 | 本周数据库圈热点 + 技术干货分享（2025/10/24期）
墨天轮小助手 342次阅读 2025-10-24 11:08:53
MySQL8.0物理备份Xtrabackup全备脚本
Rock Yan 338次阅读 2025-11-04 18:14:53
9月“墨力原创作者计划”获奖名单公布
墨天轮编辑部 319次阅读 2025-10-14 14:14:39
ACDU周度精选 | 本周数据库圈热点 + 技术干货分享（2025/10/31期）
墨天轮小助手 250次阅读 2025-10-31 15:52:55

