# 我的 2023–2024 年 MySQL 相关文章整理汇总

为了方便快速地找到以往文章的内容，这里做了个汇总。感觉是不是能写本书 -_-  
每篇文章基本上都包含了相关的脚本。有几篇其实已经是 2025 年写的了，不要在意这些细节。

## 连接协议

问：我们可以使用官方的驱动包，也可以使用第三方的驱动包，为什么还要自己去解析连接协议呢？  
答：为了更好地理解 MySQL 的运行原理，还能自己开发相关工具。比如：旁挂审计、日志抽取（还得结合 binlog 解析工具），不过这些都已经有大佬写过了。

- MySQL 连接协议解析 (1)，并模拟了一个 MySQL 服务器（某种程度上可以去“骗”漏洞扫描的人）：https://www.modb.pro/db/625127  
- 发送 SQL 语句并解析返回结果：https://www.modb.pro/db/625133  
- 自制读写分离中间件：https://www.modb.pro/db/625138  
- 在 MySQL 里面再连接 MySQL（恶趣味）：https://www.modb.pro/db/625141  
- 基于 SSL 的 MySQL 连接（含 MySQL 流量镜像脚本）：https://www.modb.pro/db/625143  
- caching_sha2_password 认证讲解：https://www.modb.pro/db/625146

## 主从协议

从库连接主库时，走的数据包有些区别，所以单独整理。

- 主从协议：https://www.modb.pro/db/625147  
- 主从协议 2 – GTID 解析：https://www.modb.pro/db/1788113344170905600

## frm 结构

MySQL 5.7 版本仍使用 frm 文件来记录表的元数据信息，市场上仍有大量 5.7（5.x）实例在使用，因此解析 frm 结构很有价值。官方的 mysqlfrm 工具或第三方工具（比如 dbsake）因年代久远存在一些问题（如精度丢失、类型不支持等），所以自己实现了解析。

- frm 文件解析（较简单粗略）：https://cloud.tencent.com/developer/article/2409341  
- frm2sdi (1) 再探 frm 结构（较细致，但不含 metadata）：https://www.modb.pro/db/1880128576226340864  
- frm2sdi (3) 包含 frm 的 metadata 信息：https://www.modb.pro/db/1887686692543410176

## sdi 结构

MySQL 8.0 使用 SDI（Serialized Dictionary Information）来存储元数据信息，并放在数据文件（.ibd）中。SDI page 用来记录 SDI 的信息，实际上就是一个特殊结构的数据行：在 general tablespace 下就是多行数据；在 innodb_file_per_table 情况下通常是一行数据（不考虑 summary）。这行数据是压缩的，因此存在溢出行，需要注意（见 issue28）。

- MYSQL 文件解析 (5) FIL_PAGE_SDI（最开始讲解的 SDI 比较简单）：https://www.modb.pro/db/625502  
- 从 ibd 文件提取 DDL 和 DML（后面看到官网说是压缩的，于是直接保留解压）：https://www.modb.pro/db/625500  
- mysql.ibd 文件解析（sdi page）：https://www.modb.pro/db/1836232133276426240  
- frm2sdi (2) SDI 内容讲解：https://www.modb.pro/db/1881155204905709568

## MyISAM 数据文件存储结构

虽然大部分用户使用 InnoDB 存储引擎，但仍有少量使用 MyISAM 的场景，且 5.7 的系统表也是 MyISAM 存储引擎，因此简单查看 MyISAM 的存储结构也是有必要的。

- MyISAM MYD 文件存储格式（只看 MYD 即可，MYI 索引可不解析）：https://www.modb.pro/db/1796359240637566976

## InnoDB 数据文件存储结构

这是本系列的重点；目前大部分使用 MySQL 的用户都使用 InnoDB 存储引擎，了解 InnoDB 的数据文件（.ibd）结构非常有用。

- MYSQL INNODB ibd 文件详解 (1)：https://cloud.tencent.com/developer/article/2270548  
- MYSQL INNODB ibd 文件详解 (2) 提取 DDL 和 DML：https://cloud.tencent.com/developer/article/2272297  
- INNODB ibd 文件详解 (3) FIL_PAGE_SDI：https://cloud.tencent.com/developer/article/2272631

进阶与专题整理：
- MYSQL 时间类型在磁盘上的存储结构：https://cloud.tencent.com/developer/article/2275562  
- mysql 寻找 SDI PAGE：https://cloud.tencent.com/developer/article/2340198  
- mysql.ibd 文件解析（sdi page）（非 debug 模式下查看隐藏系统表）：https://cloud.tencent.com/developer/article/2451792  
- mysql 压缩页原理和解析：https://cloud.tencent.com/developer/article/2452279  
- lz4 压缩数据结构并使用 Python 解析：https://cloud.tencent.com/developer/article/2453114  
- mysql 数据加密原理和解析：https://cloud.tencent.com/developer/article/2454159  
- 浏览器查看 mysql 数据文件磁盘结构：https://cloud.tencent.com/developer/article/2463909  
- 恢复加密的 mysql 表：https://cloud.tencent.com/developer/article/2465128

结构优化与深入：
- varchar 长度修改时 online DDL 能够使用哪种算法？：https://cloud.tencent.com/developer/article/2468760  
- decimal 的存储设计：https://cloud.tencent.com/developer/article/2472025  
- REDUNDANT 行格式的数据解析：https://cloud.tencent.com/developer/article/2474311  
- 不同 pagesize 下的 xdes 计算方法：https://cloud.tencent.com/developer/article/2478595  
- mysql checksum table 原理深度分析：https://cloud.tencent.com/developer/article/2482061

## redo / undo（InnoDB 日志文件存储结构）

redo、undo 在日常运维过程中一般不需要频繁处理，除非 undo log 特别大：

- MYSQL REDO LOG 文件解析：https://cloud.tencent.com/developer/article/2264786  
- mysql undo 文件解析 (1)：https://cloud.tencent.com/developer/article/2441520  
- mysql undo 文件解析 (2)：https://cloud.tencent.com/developer/article/2443036

## binlog 文件存储结构

市面上解析 binlog 的工具很多，但掌握 binlog 结构可以实现更多功能，比如大事务统计、binlog_cache_size 值的计算参考等。

- 解析 binlog 中的 GTID（GTID_LOG_EVENT、PREVIOUS_GTIDS_LOG_EVENT）：https://www.modb.pro/db/1781217154309378048  
- binlog 中第一个 event FORMAT_DESCRIPTION_EVENT：https://www.modb.pro/db/1782321141465042944  
- [pymysqlbinlog] TABLE_MAP_EVENT：https://www.modb.pro/db/1782962255633141760  
- ROW_EVENT：从 binlog 中提取数据（SQL） & 从 binlog 中回滚数据（SQL）：https://www.modb.pro/db/1784855323173015552  
- QUERY_EVENT & XID_EVENT 解析：从 binlog 获取 DDL 和 commit：https://www.modb.pro/db/1785212851510120448  
- 使用 pymysqlbinlog 来分析 binlog：https://www.modb.pro/db/1787044504695558144

## XFS 文件系统结构

虽然主题是 MySQL，但 XFS 的结构与 InnoDB 非常相似。对于 drop/truncate 操作，MySQL 层面无能为力，必须从文件系统层面想办法恢复。XFS 源码规范、易读，适合学习。

- XFS 文件系统浅析 – 恢复 drop 的表（恢复原理：rm 实际上只是清空 inode 中记录的权限，其他信息仍保留；目录里可能会清除 inode 号，所以扫描目录不如遍历 Inode tree）：https://cloud.tencent.com/developer/article/2457892

## 其它

一些有意思的文章或案例：

- 自制 MySQL 旁挂审计：https://cloud.tencent.com/developer/article/2259748  
- MySQL 命令远程连接 SQLite3（给 sqlite3 加个网络连接功能）：https://cloud.tencent.com/developer/article/2261503  
- Python 自作类 tar 工具：实现数据归档、压缩、加密功能：https://cloud.tencent.com/developer/article/2268572  
- 提取 binlog 中的 DDL（常用）：https://cloud.tencent.com/developer/article/2291860  
- MySQL 导入数据，但存储过程注释没了（导入时加 -c 参数）：https://cloud.tencent.com/developer/article/2323373  
- ERROR 1356 (HY000): View ‘xxx’ references invalid definer/invoker：https://cloud.tencent.com/developer/article/2353818  
- binlog_cache_size 设置多大合适？：https://cloud.tencent.com/developer/article/2387420  
- tdsql 忘记赤兔密码怎么办（后台是 MySQL）：https://cloud.tencent.com/developer/article/2406746  
- 离谱！用 shell 实现 mysql_config_editor 功能：https://cloud.tencent.com/developer/article/2394139  
- tar 解压进度查看：https://cloud.tencent.com/developer/article/2393601  
- MySQL 导入数据，如何查看进度：https://cloud.tencent.com/developer/article/2390430  
- mysqldump 导出进度查看脚本：https://cloud.tencent.com/developer/article/2425090  
- MySQL 怎么并发导入数据：https://cloud.tencent.com/developer/article/2392211  
- load data 导致主从不一致：https://cloud.tencent.com/developer/article/2416591  
- MySQL 坏块检查：https://cloud.tencent.com/developer/article/2447080  
- Linux 审计脚本：https://cloud.tencent.com/developer/article/2436672  
- varchar 字段条件为 0，却能查询出来数据？不是 BUG，是特性！：https://cloud.tencent.com/developer/article/2433544  
- MySQL 常见连接失败问题汇总：https://cloud.tencent.com/developer/article/2465657  
- gdb 在线修改 MySQL 版本号：https://cloud.tencent.com/developer/article/2486647  
- 忘记 root 密码时，不需要重启也能强制修改了！：https://cloud.tencent.com/developer/article/2493715  
- MySQL 主从延迟案例（有索引但无主键）：https://cloud.tencent.com/developer/article/2489169

---

作者信息：

- 网名：大大刺猬  
- 作者简介：一名 MySQL DBA，分享 Python/Shell 脚本，著有 ibd2sql 等工具。  
- 称号 / 荣誉：Oracle ACE Associate、墨天轮 MVP  
- profile: https://ace.oracle.com/apex/ace/profile/ddcw  
- GitHub: https://github.com/ddcw  
- 腾讯云社区: https://cloud.tencent.com/developer/user/1130242  
- 墨天轮社区: https://www.modb.pro/u/17942  
- 公众号：大大刺猬  
- B 站：https://space.bilibili.com/448260423