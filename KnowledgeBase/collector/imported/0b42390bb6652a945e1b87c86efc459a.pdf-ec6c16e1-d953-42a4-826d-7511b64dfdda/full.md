我的2023-2024年mysql相关⽂章整理汇总
为了⽅便快速的找到以往⽂章的内容 , 这⾥就做了个汇总 . 感觉是不是能写本书  -_-
每篇⽂章基本上都包含了相关的脚本的 . 有⼏篇其实已经是 2025 年写的了 , 不要在意这些细节 .
连接协议
mysql 连接协议相关的 .
问 : 我们可以使⽤官⽅的驱动包 , 也可以使⽤第三⽅的驱动包 , 为啥还要⾃⼰去解析连接协
议呢 ?
答 : 为了更好的理解 mysql 的运⾏原理 , 还能⾃⼰开发相关⼯具 . 比如 : 旁挂审计 , ⽇志抽取 ( 还
得结合 binlog 解析⼯具 ), 不过这些都已经有⼤佬写过了 .
连接协议
<mysql 连接协议解析 (1)>, 并模拟了⼀个 mysql 服务器 ( 某种程度上可以去 ʼ 骗 ʼ 漏扫的
⼈ ): https://www.modb.pro/db/625127
< 发送 SQL 语句并解析返回结果 >: https://www.modb.pro/db/625133
< ⾃制读写分离中间件 >: https://www.modb.pro/db/625138
< 在 mysql ⾥⾯再连接 mysql>( 恶趣味 ):
https://www.modb.pro/db/625141
< 基于 SSL 的 mysql 连接  ( 含 mysql 流量镜像脚本 )>:
https://www.modb.pro/db/625143
<caching_sha2_password 认证讲解 >:
https://www.modb.pro/db/625146
主从协议
从库连接主库的时候 , 走的数据包有丢丢区别 , 所以分开来看 .
⼤⼤刺猬 2025年02⽉21⽇ 07:00 上海原创 ⼤⼤刺猬
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 1/7

< 主从协议 >: https://www.modb.pro/db/625147
< 主从协议 2 – GTID 解析 >:
https://www.modb.pro/db/1788113344170905600
frm 结构
mysql 5.7 版本还是使⽤的 frm ⽂件来记录表元数据信息 , ⽽市场上使⽤ 5.7(5.x) 的还挺多
的 , 所以我们也就来解析下 frm 的结构 . 官⽅的 mysqlfrm ⼯具或者第三⽅的⼯具 ( 比如
dbsake) 都因为年代久远 , 有丢丢问题 ( 比如精度丢失 , 类型不⽀持等 ). 所以我们就⾃⼰解析
frm 的结构 .
<frm ⽂件解析 >, 这⼀版比较简单粗略 :
https://cloud.tencent.com/developer/article/2409341
<frm2sdi (1) 再探 frm 结构 > 这⼀版就很细致了 , 但是不含 metadata
https://www.modb.pro/db/1880128576226340864
<frm2sdi(3)> 这⾥⾯多了 frm 的 metadata 信息 :
https://www.modb.pro/db/1887686692543410176
sdi 结构
mysql 8.0 使⽤ sdi(Serialized Dictionary Information) 来存储元数据信息 , 并放在了数据
⽂件 (ibd) 中 . sdi page 来记录 sdi 的信息 , 实际上就是⼀个特殊结构的数据⾏ , general
tablespace 情况下 , 就是多⾏数据 ; innodb_file_per_table 情况下 , 就是⼀⾏数据 ( 不考虑
summary). 这⾏数据是压缩了的 , 所以存在溢出⾏ , 得注意下 (issue28)
<MYSQL ⽂件解析  (5) FIL_PAGE_SDI>
最开始讲解的 sdi 比较简单  https://www.modb.pro/db/625502
< 从 ibd ⽂件提取 DDL 和 DML> 后⾯看到官⽹说是压缩的 , 于是直接保留解压  -_-
https://www.modb.pro/db/625500
<mysql.ibd ⽂件解析  (sdi page)>
https://www.modb.pro/db/1836232133276426240
<frm2sdi (2) sdi 内容讲解 >
https://www.modb.pro/db/1881155204905709568
myisam 数据⽂件存储结构
虽然⼤部分⽤户都是使⽤的 Innodb 存储引擎 , 但还是有丢丢使⽤ myisam 的⽤的 , ⽽且 5.7 系
统表也是 myisam 存储引擎的 , 所以我们也稍微看看 myisam 的存储结构吧 .
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 2/7

<myisam MYD ⽂件存储格式 > 我们只看 myd 就够了 , myi 索引就没必要解析
了 . https://www.modb.pro/db/1796359240637566976
innodb 数据⽂件存储结构
本系列的⼤头来了 , ⽬前⼤部分使⽤ Mysql 的都是使⽤的 innodb 存储引擎 , 所以了解 innodb
的数据⽂件 ibd 的结构就非常有⽤了 .
菜⻦ 3 步曲
<MYSQL INNODB ibd ⽂件详解  (1)>
https://cloud.tencent.com/developer/article/2270548
<MYSQL INNODB ibd ⽂件详解  (2) 提取 DDL 和 DML>
https://cloud.tencent.com/developer/article/2272297
<INNODB ibd ⽂件详解  (3) FIL_PAGE_SDI>
https://cloud.tencent.com/developer/article/2272631
初出茅庐
<MYSQL 时间类型在磁盘上的存储结构 >
https://cloud.tencent.com/developer/article/2275562
<mysql 寻找 SDI PAGE> 开始领悟 sdi 结构
https://cloud.tencent.com/developer/article/2340198
渐入佳境
<mysql.ibd ⽂件解析  (sdi page) ( 非 debug 模式下查看隐藏系统表 )>
https://cloud.tencent.com/developer/article/2451792
<mysql 压缩⻚原理和解析 >
https://cloud.tencent.com/developer/article/2452279
<lz4 压缩数据结构并使⽤ Python 解析 >
https://cloud.tencent.com/developer/article/2453114
<mysql 数据加密原理和解析 >
https://cloud.tencent.com/developer/article/2454159
< 浏览器查看 mysql 数据⽂件磁盘结构 >
https://cloud.tencent.com/developer/article/2463909
< 恢复加密的 mysql 表 >
https://cloud.tencent.com/developer/article/2465128
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 3/7

稳中向好
<varchar ⻓度修改时 online DDL 能够使⽤哪种算法 ?>
https://cloud.tencent.com/developer/article/2468760
<decimal 的存储设计 >
https://cloud.tencent.com/developer/article/2472025
<REDUNDANT ⾏格式的数据解析 >
https://cloud.tencent.com/developer/article/2474311
蓄势待发
< 不同 pagesize 下的 xdes 计算⽅法 >
https://cloud.tencent.com/developer/article/2478595
<mysql checksum table 原理深度分析 >
https://cloud.tencent.com/developer/article/2482061
redo/undo (innodb ⽇志⽂件存储结构 )
redo,undo 在运维过程中 , 基本上不会去管它 , 除非 undo log 特别⼤了 …
<MYSQL REDO LOG ⽂件解析 >
https://cloud.tencent.com/developer/article/2264786
<mysql undo ⽂件解析 (1)>
https://cloud.tencent.com/developer/article/2441520
<mysql undo ⽂件解析 (2)>
https://cloud.tencent.com/developer/article/2443036
binlog ⽂件存储结构
市⾯上解析 binlog 的⼯具还是灰常多的 . 但我们掌握 binlog 结构之和 , 可以实现更多的功能 ,
比如⼤事务的统计 ,binlog_cache_size 值的计算参考
< 解析 binlog 中的 gtid (GTID_LOG_EVENT,PREVIOUS_GTIDS_LOG_EVENT)>
https://www.modb.pro/db/1781217154309378048
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 4/7

<binlog 中第⼀个 event FORMAT_DESCRIPTION_EVENT>
https://www.modb.pro/db/1782321141465042944
<[pymysqlbinlog] TABLE_MAP_EVENT>
https://www.modb.pro/db/1782962255633141760
<ROW_EVENT 从 BINLOG 中提取数据 (SQL) & 从 BINLOG 中回滚数据 (SQL)>
https://www.modb.pro/db/1784855323173015552
<QUERY_EVENT & XID_EVENT 解析 Binlog 获取 DDL 和 commit>
https://www.modb.pro/db/1785212851510120448
< 使⽤ pymysqlbinlog 来分析 BINLOG>
https://www.modb.pro/db/1787044504695558144
xfs ⽂件系统结构
啊 , 不是讲 mysql 的吗 , 为啥要看 xfs 的结构啊 . 其实 xfs 结构和 innodb 非常像 . ⽽且对于
drop/truncate 操作 , mysql 层⾯就⽆能为⼒了 , 只能从 fs 层来想办法 . (xfs 的源码非常规范 ,
看起来很舒服 .)
<xfs ⽂件系统浅析  – 恢复 drop 的表 > 恢复原理就是 : rm 的表实际上只是清空了 inode 中记
录的权限 , 其它信息还是保留的 , ⽬录⾥⾯可能会清除 inode 号 , 所以扫描⽬录的效果不如遍
历 Inode tree.
https://cloud.tencent.com/developer/article/2457892
其它
⼀些我觉得有意思的⽂章或者案例
< ⾃制 MYSQL 旁挂审计 >
https://cloud.tencent.com/developer/article/2259748
<MYSQL 命令远程连接 SQLITE3 ( 给 sqlite3 加个⽹络连接功能 )>
https://cloud.tencent.com/developer/article/2261503
<PYTHON ⾃作类 tar ⼯具  实现  数据归档 , 压缩 , 加密功能 >
https://cloud.tencent.com/developer/article/2268572
< 提取 binlog 中的 DDL> 使⽤得还挺多的 …
https://cloud.tencent.com/developer/article/2291860
<mysql 导入数据 , 但存储过程注释没了 > 就是加-c那个
https://cloud.tencent.com/developer/article/2323373
<ERROR 1356 (HY000): View ‘xxxʼ references invalid definer/invoker>
https://cloud.tencent.com/developer/article/2353818
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 5/7

<binlog_cache_size 设置多⼤合适呢 ?>
https://cloud.tencent.com/developer/article/2387420
<tdsql 忘记⾚兔密码怎么办 > 后台是 mysql 也算 mysql 吧 …
https://cloud.tencent.com/developer/article/2406746
< 离谱 ! ⽤ shell 实现 mysql_config_editor 功能 >
https://cloud.tencent.com/developer/article/2394139
<tar 解压进度查看 >
https://cloud.tencent.com/developer/article/2393601
<MySQL 导入数据 , 如何查看进度 >
https://cloud.tencent.com/developer/article/2390430
<mysqldump 导出进度查看脚本 >
https://cloud.tencent.com/developer/article/2425090
<mysql 怎么并发导入数据 >
https://cloud.tencent.com/developer/article/2392211
<load data 导致主从不⼀致 >
https://cloud.tencent.com/developer/article/2416591
<mysql 坏块检查 >
https://cloud.tencent.com/developer/article/2447080
<linux 审计脚本 >
https://cloud.tencent.com/developer/article/2436672
<varchar 字段条件为 0, 却能查询出来数据 ? 不是 BUG, 是特性 !>
https://cloud.tencent.com/developer/article/2433544
<mysql 常⻅连接失败问题汇总 >
https://cloud.tencent.com/developer/article/2465657
<mysql checksum table 原理深度分析 >
https://cloud.tencent.com/developer/article/2482061
<gdb 在线修改 mysql 版本号 >
https://cloud.tencent.com/developer/article/2486647
< 忘记 root 密码时 , 不需要重启也能强制修改了 !>
https://cloud.tencent.com/developer/article/2493715
<mysql 主从延迟案例 ( 有索引但⽆主键 )>
https://cloud.tencent.com/developer/article/2489169
标题叫 < 我的 2023-2024 年 mysql 相关⽂章整理汇总 >, 那么我是谁呢 ?
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 6/7

⽹名 : ⼤⼤刺猬
作者简介 : ⼀名 mysql dba, 分享 python/shell 脚本 , 著有 ibd2sql 等⼯具 .
称号 / 荣誉 : oracle ACE Associate, 墨天轮 MVP
profile: https://ace.oracle.com/apex/ace/profile/ddcw
github : https://github.com/ddcw
腾讯云社区 : https://cloud.tencent.com/developer/user/1130242
墨天轮社区 : https://www.modb.pro/u/17942
公众号 : ⼤⼤刺猬
B 站 : https://space.bilibili.com/448260423
2025/6/4 凌晨 12:56 我的 2023-2024 年 mysql 相关⽂章整理汇总
https://mp.weixin.qq.com/s/QQ52xHZ9-lSCGDfP9aiyCg 7/7

