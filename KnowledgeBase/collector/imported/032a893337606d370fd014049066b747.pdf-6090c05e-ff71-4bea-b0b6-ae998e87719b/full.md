InnoDB圣经：30个图 硬核解读 InnoDB 内存架构 和 磁盘架构 （
万字 长文 ）
45岁老架构师尼恩 技术自由圈 2025年8月21日 17:31 湖北 原创
FSAC未来超级架构师
架构师总动员
实现架构转型，再无中年危机
技术自由圈
疯狂创客圈（技术自由架构圈）：一个 技术狂人、技术大神、高性能 发烧友 圈子。圈内一大波顶级高手、架构师、发烧友已经实现技术自由；另外一大波卷王，正在狠狠卷，奔向技术自由
333篇原创内容
公众号
尼恩说在前面
在40岁老架构师 尼恩的 读者交流群 (50+)中，最近有小伙伴拿到了一线互联网企业如得物、阿里、滴滴、极
兔、有赞、希音、百度、网易、美团、蚂蚁、得物的面试资格，遇到很多很重要的相关面试题：
InnoDB 内存结构 和 磁盘 结构， 你理解吗？
什么是 Doublewrite Buffer ？InnoDB是如何实现 Doublewrite Buffer 的？
比较undo log、redo log和bin log的作用和区别？
最近有小伙伴在面 腾讯，问到了mysql InnoDB 存储引擎 相关的面试题。 小伙伴 没有系统的去梳理和总
结，所以支支吾吾的说了几句，面试官不满意，面试挂了。
所以，尼恩给大家做一下系统化、体系化的梳理，使得大家内力猛增，可以充分展示一下大家雄厚的 “技术肌
技术自由圈 赞 分享 推荐 写留言 肉”， 让面试官爱到 “不能自已、口水直流” ，然后实现”offer直提”。
当然，这道面试题，以及参考答案，也会收入咱们的 《尼恩Java面试宝典PDF》V175版本，供后面的小伙伴
参考，提升大家的 3高 架构、设计、开发水平。
《尼恩 架构笔记》《尼恩高并发三部曲》《尼恩Java面试宝典》的PDF，请到文末公号【技术自由圈】获取
本文作者：
第一作者 老架构师 肖恩（肖恩 是尼恩团队 高级架构师，负责写此文的第一稿，初稿 ）
第二作者 老架构师 尼恩 （ 45岁老架构师， 负责 提升此文的 技术高度，让大家有一种 俯视 技
术、俯瞰技术、 技术自由 的感觉 ）
一、InnoDB 存储引擎
1、MySQL体系和InnoDB存储引擎
MySQL的体系结构是分层设计的，包括Server层和 Engin层。
1. 服务层(Server层) ：处理连接、查询解析、优化、内置函数
2. 存储引擎层(Engin层) ：负责数据存储/检索（可插拔）
Engin层 是可以拔插设计， 可以 选择不同的 存储引擎。
InnoDB 属于 Engin层 ，是默认的 存储引擎， 负责 "最终数据存储与管理"的核心组件。
MySQL整体架构：

各层作用 ：
连接层：处理客户端接入（如TCP连接），验证密码，管理连接池。
服务层：负责SQL的解析、优化（比如选最优索引）、缓存，以及执行存储过程等。
存储引擎层：这是MySQL的"数据管家"，通过统一接口与服务层交互。InnoDB是其中功能最完善
的（支持事务、行锁等），直接对接磁盘文件。
文件系统层：最终存储数据的物理文件（如 .ibd 数据文件、日志文件等）。
关键点 ：可拔插架构中，有一套规范的I/O操作接口，InnoDB通过标准接口嵌入MySQL，处理所有数据I/O操作
2、Inno DB总体架构
InnoDB 存储引擎目前也是应用最广泛的存储引擎。 从 MySQL 5.5 版本开始作为表的默认存储引擎。
InnoDB 存储引擎 最早由 Innobase Oy 公司开发（属第三方存储引擎）。
InnoDB 存储引擎 是第一个完整支持 ACID 事务的 MySQL 存储引擎，特点是行锁设计、支持 MVCC、支持外
键、提供一致性非锁定读，非常适合 OLTP 场景的应用使用。
InnoDB 存储引擎架构包含内存结构和磁盘结构两大部分

MySQL 8.0 版本，总体架构图如下：
MySQL 5.5 版本，总体架构图如下：
3、Inno DB数据读写流程

关键步骤：
1）读路径 ：优先检查缓冲池，未命中时从.ibd(也就是各种表空间)加载
2）写路径 ：
先写redo log（顺序I/O）
异步写入数据文件（随机I/O）
SHOW ENGINE INNODB STATUS\G -- 查看刷脏进度
3）崩溃恢复 ：通过redo log重做未落盘操作
二、InnoDB内存架构
InnoDB的内存就像"高速缓存区"，减少磁盘IO，提升速度。
主要组件如下：

核心组件 ：
(1) Buffer Pool 数据热区枢纽 ：
预分配连续内存缓存数据页，通过LRU算法管理热数据，将随机I/O转为内存操作。
(2) Log Buffer ： 写操作高速通道
暂存事务中的redo日志， 控制刷盘策略，平衡性能与安全。 innodb_flush_log_at_trx_commit
(3) Change Buffer ： 非聚簇索引加速器
缓存非唯一索引的DML操作（INSERT/UPDATE/DELETE），后台异步合并到磁盘索引结构。
(4) 自适应哈希索引 智能路径优化器 ：
自动检测高频等值查询路径，在内存中构建哈希索引，突破B+树检索深度限制。
(5) undo 日志缓冲：
InnoDB 内存中临时存放 undo 日志的区域 ，用于事务回滚和多版本控制，最终会刷新到磁盘的 Undo 表空
间。
2.1、Buffer Pool
2.1.1 什么是 Buffer Pool？
简单说，Buffer Pool 是 InnoDB 存储引擎里一块 内存区域 ，专门用来缓存表数据和索引数据。
就像我们平时把常用的文件放在桌面方便拿取，MySQL 也会把频繁访问的数据存到 Buffer Pool 里，避免每次
都去读写磁盘（磁盘速度比内存慢太多），以此提高查询效率。
它是 InnoDB 性能的“核心加速器”，大部分时候，我们查数据、改数据，都是和 Buffer Pool 打交道，而不是
直接操作磁盘。
Buffer Pool缓存磁盘数据页（16KB/页）。
通过减少磁盘 I/O 提升性能，使用 LRU 算法 + 冷热分离 管理数据页。
2.1.2 数据读取流程
```
SELECT * FROM table WHERE id=1; -- 直接返回内存数据
关键步骤说明：

缓存命中 （哈希表检索）：直接返回内存数据
缓存未命中 ：
从 获取空闲页 free_list
若空 → 触发 LRU 淘汰冷区尾部页
若为脏页 → 异步刷盘
从磁盘加载数据到空闲页
2.1.3 冷热数据迁移机制
冷热数据迁移是 MySQL 的 内存优化策略 ，通过将 Buffer Pool 中的内存页分为热区（高频访问）和冷区（低
频访问），从而实现：
保护热点数据 ：高频访问页不被异常挤出
隔离临时访问 ：全表扫描等操作不污染热区
智能淘汰 ：优先释放低频使用的内存
1）LRU冷热分区结构
位置 特征 流动规则
热区头部 最近高频访问页 持续访问则保留
冷区头部 新加载页/降级页 二次访问可升热区
冷区尾部 待淘汰页 内存不足时立即释放
关键控制参数
-- 冷区占比 (默认37%)
SET GLOBAL innodb_old_blocks_pct = 37;
-- 冷区页停留最短时间 (默认1000ms)
SET GLOBAL innodb_old_blocks_time = 1000;
2）基本流程

3）冷热区规则 ：
首次加载：插入 冷区头部
二次访问：移至 热区头部
冷→热迁移条件 ：
第二次访问该数据页
距首次加载时间 > innodb_old_blocks_time
访问间隔需超过过滤阈值
热→冷降级条件 ：
连续未访问时间 > 热区保护期
热区空间不足时尾部页降级
访问频率跌出热区保持阈值
4）淘汰规则 ：
if page in lru_cold and not recently_used: # 冷区尾部
evict_page(page)
elif page in lru_hot and not accessed_in_time: # 热区未访问
move_to_cold_head(page) # 降级至冷区
5）案例分析
场景： 10GB全表扫描

SELECT * FROM 10GB_table; -- 数千万页级扫描
保护机制：
(1) 所有新页插入冷区头部
(2) 1秒内连续访问不触发升温
(3) 扫描结束自动从冷区尾部淘汰
(4) 热区100%不受影响
6）与传统LRU对比优势
机制 传统LRU MySQL冷热迁移
新页插入位置 直接放头部 冷区头部
全表扫描影响 立即污染热点区 完全隔离在冷区
淘汰策略 纯按访问时间 冷区优先+频率加权
二次机会 无 热区降级页回冷区头部
本质价值 ：通过物理隔离和延时升温机制，解决了传统LRU算法的“缓存污染”问题，使有限的Buffer Pool空
间始终服务于真正的热点数据。
2.1.4 脏页刷盘机制
什么是 “脏页”？
当我们修改数据时，先改 Buffer Pool 里的缓存（内存），这时候缓存和磁盘数据就不一致了，这部分缓存叫
“脏页”。
脏页怎么来的？
事务修改数据时，InnoDB 会先从磁盘加载目标数据页到 Buffer Pool（如果不在内存中），修改内存页后，
会：
(1) 标记该页为“脏页”（dirty page）；
(2) 记录修改操作到 Redo Log（保证崩溃后能恢复）；
(3) 不立即写回磁盘（磁盘 IO 太慢，影响性能）。
脏页刷盘用到mysql的checkpoint机制。
Checkpoint机制
什么是checkpoint机制呢？
InnoDB改数据先在内存瞎折腾（Buffer Pool），不立马写到磁盘——怕慢。
但这么搞有俩问题：
万一崩了，内存里的改动丢了咋办？
Redo Log 总不能无限存吧？
Checkpoint 就是来解决这俩问题的。

说白了，它就是个「标记点」，告诉系统：“在我这时间点之前，所有内存里改了还没写到磁盘的脏页，都已经
安全落地了”。
checkpoint标记点以后的修改，崩溃恢复交给redo log处理
Checkpoint的核心作用：
缩短恢复时间 ：崩溃恢复时只需要从最近的checkpoint开始重做日志
脏页刷盘 ：定期清理缓冲池中的脏页
日志空间回收 ：标记哪些redo log可以被覆盖重用
Checkpoint 有哪几种？啥时候会触发（也就是啥时候进行脏页刷盘）？
1）Sharp Checkpoint（彻底型）
就一种情况会触发： 数据库正常关闭（shutdown） 。
这时候会把所有脏页全刷到磁盘，Checkpoint 直接怼到 Redo Log 的末尾。下次启动不用恢复，因为啥都落
盘了。简单粗暴，但耗时——生产库大的话，关一次可能等半天。
2）Fuzzy Checkpoint（模糊型）
数据库正常运行时用的，不刷所有脏页，只挑一部分刷，避免阻塞业务。细分为 4 种：
Master Thread Checkpoint ：
主线程自己偷偷干的，每秒或每 10 秒（默认1S）刷一点脏页（数量很少），不影响性能。比如每秒刷 10 个
页，慢悠悠的。
FLUSH_LRU_LIST Checkpoint ：
Buffer Pool 有个 LRU 链表（最近最少用），淘汰旧页时，发现是脏页，就得先刷盘再扔。不然扔了就丢数据
了。
Async/Sync Flush Checkpoint ：
这是急活儿！Redo Log 快写满时（write pos 快追上 Checkpoint 了），必须赶紧刷脏页推进 Checkpoint，给
新日志腾地方。
要是还剩点空间，异步刷（不卡事务）；
要是快满了，同步刷（卡着新事务，直到腾出新空间）。
Dirty Page too much Checkpoint ：
当脏页占 Buffer Pool 的比例超过 innodb_max_dirty_pages_pct （默认 75%），就触发刷盘，把比例压
下去。避免脏页太多，万一崩了恢复慢。

Page 10
InnoDB 圣 炵 ﹕ 30 人 囧 硬 核 解 逵 InnoDB 內 存 架 构 和 磁 盆 架 构 ( 万 字 長 文 ﹚
https﹕//mp﹒weixin﹒qq﹒com/s/cTo35wu9PBkRRrrm5QU﹣sQ
核 心 流 程 囧
胜 火 生 命 周 期 ﹕
主
加 入 Flush List
主
迸 入 胜 血 阯 列
ˍ
﹢
触 冷 刷 盪
棄 查 触 岑 繳 沓 池 港 ~ 吟 台 空 兩
﹛﹔ˍˍ
弓 嶔 推 迸 LSN LRU 淘 汰 刷 盅 萸 別 減 心 峰 值
主
森 迅 加 干 冶 血
Captured by Fireshot Pro﹕ 11 1 月 2025， 00﹕46﹕30
https﹕//dgdetfireshot﹒com

2.1.5 性能调优实战
关键配置参数
参数 说明 推荐值
总内存大小 物理内存的50%-80% innodb_buffer_pool_size
冷区内存占比 默认37% innodb_old_blocks_pct
每次扫描深度 默认1024 innodb_lru_scan_depth
预热技巧 （重启后加载）：
SELECT pg.space_id, pg.page_no
FROM information_schema.innodb_buffer_page AS pg;
监控命令 ：
SHOW ENGINE INNODB STATUS;
-- Buffer Pool命中率 = (1 - disk_reads / logical_reads) * 100%
核心价值 ：将随机磁盘 I/O 转换为内存访问，加速高频数据操作。理解冷热分离与异步刷盘机制是调优关
键。
2.2、Change Buffer
2.2.1 什么是 Change Buffer
简单说，Change Buffer 是 InnoDB 里一块 专门缓存非唯一二级索引修改 的内存区域。
作用：当你改数据时，如果要改的索引页不在内存里（Buffer Pool），不用立刻去磁盘找这个页，先把修改记
在 Change Buffer 里，等以后有机会再一起处理。
打个比方： 这就像 网购时，快递员不会每到一个包裹就立刻送上门，而是攒一批顺路送——减少跑腿次数，效
率自然高。

为什么 Change Buffer 能提升性能？
核心是 减少磁盘 IO ：
对非唯一二级索引的高频修改（比如批量插入），不用每次都读磁盘页，先在内存里“记账”；
合并时一次性处理多个修改，把零散的磁盘操作变成集中操作。
反过来想：如果没有 Change Buffer，每插一条数据就要读一次磁盘索引页（如果不在内存），1000条就是
1000次磁盘IO，慢得让人着急。
Change Buffer本质定位： Change Buffer（写缓冲）是 InnoDB 加速 非唯一二级索引变更 的杀手锏。
Change Buffer核心价值： 将索引更新由随机写转为顺序写，解决二级索引写入瓶颈。
不是所有索引修改都能用Change Buffer，有两个前提：
(1) 必须是二级索引（非主键索引）；
(2) 这个索引不是唯一的（因为唯一索引要检查唯一性，必须访问磁盘页确认，绕不开）。
像普通的 、 、 操作，只要符合上面两个条件，就可能用到 Change Buffer。 INSERT UPDATE DELETE
Change Buffer 运作全流程：
2.2.2 合并触发场景
存在 Change Buffer 里的修改，终究要写到磁盘的索引页上，这个过程叫“合并”（merge）
-- 手动强制合并命令
ALTER TABLE tbl_name FORCE CHANGE BUFFER MERGE;
2.2.3 性能调优实战
关键控制参数

-- 最大内存占比 (默认25%)
SET GLOBAL innodb_change_buffer_max_size=30;
-- 合并操作类型配置
SET GLOBAL innodb_change_buffering='all'; -- 支持insert/delete/purge
状态监控命令
SHOW ENGINE INNODB STATUS\G
---BUFFER POOL AND MEMORY
Ibuf: size 7549, free list len 3980, seg size 11530,
merged operations:
insert 5934234, delete mark 387703, delete 7392
与传统方案对比
特性 无Change Buffer Change Buffer启用
二级索引更新 每次触发磁盘随机写 批量顺序写
索引页不在内存时 先读磁盘 → 更新 → 写回 内存记录 → 延迟合并
写性能 100TPS 10000+ TPS
适用场景 唯一索引更新 非唯一索引批量写入
设计哲学 ：
用内存换磁盘随机I/O，牺牲数据落地实时性换取吞吐量跃升。
在账单记录、时序数据场景可带来10倍+写入性能提升，但对交易核心表需谨慎评估数据一致性要求。
2.2.4 Change Buffer 总结
Change Buffer 就是 InnoDB 为非唯一二级索引修改设计的“内存暂存区”：
(1) 先把修改记在内存，避免频繁访问磁盘；
(2) 等合适的时机（比如查询该索引时）再批量合并到磁盘；
(3) 核心价值：把零散的磁盘操作变成集中操作，大幅提升写性能。
理解它，就能更好地优化那些带非唯一二级索引的表的写入性能了。
2.3、Log Buffer
2.3.1 什么是Log Buffer
Log Buffer（日志缓冲区）是 InnoDB 的 事务日志高速通道 ，在内存中缓冲 redo log 数据，通过 批量合并写盘
机制 将随机I/O转化为顺序I/O，实现事务提交的瞬时响应。
简单说，Log Buffer 就是 InnoDB 存 redo log 的一块 内存缓冲区 。redo log 是保证数据安全的关键（比如断
电时恢复数据），但直接写磁盘太慢，所以先放内存里攒一攒，凑够一批再写磁盘，这就是 Log Buffer 的作
用。
打个比方：就像你写日记，不会写一个字就立刻存档，而是写满一页再存——减少存档次数，效率更高。
基本流程图：

当你执行增删改操作时，redo log 的产生和存储流程是这样的：
比如你连续执行10条 ，InnoDB 不会每条都写磁盘，而是先把这10条的 redo log 都放 Log Buffer 里， UPDATE
等满足条件了再一次性刷到磁盘，大大减少磁盘 IO 次数。
什么时候会把 Log Buffer 刷到磁盘？
性能影 触发条件 刷盘模式 数据安全性 响
事务提交同步 innodb_flush_log_at_trx_comm
最高（ACID） 高延迟 刷 it=1
每秒后台异步 中等（OS崩溃丢数 innodb_flush_log_at_trx_comm
低延迟 刷 据） it=2
Buffer使用率 > 75% 强制刷盘 防溢出 可控
周期影 Checkpoint推进 连带刷盘 保证恢复点 响
Checkpoint的执行是InnoDB存储引擎的核心机制，其触发基于四大条件：
时间周期 ‌：秒级/分钟级定时触发
空间阈值 ‌：日志空间 >75% 或脏页比例 >阈值
事件驱动 ‌：关闭、备份等特殊操作
负载压力 ‌：高并发写入时的自适应触发
Checkpoint执行时完成的关键工作：
确定最小安全LSN位置
批量刷新Redo日志到磁盘
按顺序写入脏数据页
原子更新检查点元数据
回收日志和数据页资源
2.3.2 性能调优实战
关键控制参数
-- 缓冲区大小 (默认16MB，建议1-4GB)
SET GLOBAL innodb_log_buffer_size = 268435456; -- 256MB
-- 刷盘策略 (1=全持久化, 2=高性能模式)
SET GLOBAL innodb_flush_log_at_trx_commit = 2;
-- 刷盘间隔 (默认1秒)
SET GLOBAL innodb_flush_log_at_timeout = 2;
状态监控命令：

SHOW ENGINE INNODB STATUS\G
LOG
Log sequence number 182701152 // 当前LSN
Log flushed up to 182701152 // 刷盘LSN
Pages flushed up to 182701152 // 页刷盘LSN
Last checkpoint at 182701092 // 检查点LSN
系统崩溃恢复逻辑：
2.3.3 Log Buffer 总结
核心是 减少磁盘 IO 次数 ：
内存写速度比磁盘快1000倍以上，先放内存能让事务执行更快；
批量刷盘把多次小 IO 变成一次大 IO，效率更高。
但记住：Log Buffer 只是“暂存”，最终还是要刷到磁盘才能保证数据安全，这就是为什么有各种刷盘策略的平
衡。
(1) 先存内存，减少磁盘 IO，让事务跑得更快；
(2) 靠定时、满了、事务提交这三个时机刷到磁盘，兼顾性能和安全；
(3) 大小和刷盘策略可以调，根据业务的“速度需求”和“安全需求”平衡。
理解它，就能更好地配置 MySQL，在数据安全和写入性能之间找到合适的平衡点。
2.4、Adaptive Hash Index(自适应哈希索引)
2.4.1 什么是自适应哈希索引（AHI）？
自适应哈希索引（AHI）是 InnoDB 的 动态索引加速器 ，自动将高频访问的 B+树 路径转换为哈希索引。
自适应哈希索引（AHI） 核心目标： 将索引检索复杂度从 O(log n) 降至 O(1) ，针对热点数据查询实现毫秒级
响应。
简单说，AHI 是 InnoDB 自己偷偷搞的“加速工具”——它会盯着那些被频繁查询的索引，悄悄在内存里建哈希
索引，帮你把某些查询速度提得更快。
哈希索引的特点是“等值查询贼快”（比如 WHERE id = 123 ），但维护起来麻烦，还不适合范围查询（比
如 WHERE id > 100 ）。

InnoDB 就想出个招：不麻烦人手动建，自己观察哪些查询频繁，符合哈希索引的脾气，就自动建，这就是“自
适应”的意思。
1）运作流程：
不是随便什么查询都会触发 AHI，得满足几个条件：
必须是 等值查询 （比如 ）； =、IN、<=>
同一索引页（B+树里的一个叶子节点）被频繁访问，且查询模式固定（比如总是查 WHERE col
）； = ?
访问次数达到阈值（InnoDB 内部判断，不用我们管）。
举个例子：一张表有索引 ，如果经常执行 这类查 idx_name SELECT * FROM t WHERE name = '张三'
询，InnoDB 发现这个索引页被反复查，就会给这个页建个 AHI。
比如你第一次查 name = '张三' ，没 AHI，走 B+树查；查多了，InnoDB 建了 AHI，下次再查，直接通过哈
希值定位到数据，不用再遍历 B+树的层级，速度能快好几倍。
2）AHI 会自动“清理”吗？
会的。InnoDB 不只是建，还会盯着 AHI 的使用情况：
如果某个 AHI 建完后很少被用到，会自动删掉，腾内存；
当索引结构变化（比如删数据、改索引），对应的 AHI 也会跟着更新或删除，不用手动维护。
这也是“自适应”的体现——只留有用的，没用的自动清。
3）AHI 适合什么场景？
最适合“大量等值查询”的场景，比如：
电商商品详情页（频繁查 ）； WHERE goods_id = ?
用户中心（频繁查 ）。 WHERE user_id = ?
这些场景下，AHI 能把查询从“遍历 B+树”变成“哈希直接定位”，性能提升明显。
但如果是 范围查询多 （比如 ），AHI 几乎没用，因为哈希索引不支持范围查找，这时甚 WHERE price > 100
至可能浪费内存。
4）AHI 总结：
AHI 就是 InnoDB 自带的“智能加速插件”：
(1) 自动观察频繁的等值查询，悄悄建哈希索引；
(2) 加速查询时直接定位数据，跳过 B+树遍历；
(3) 没用的 AHI 自动删，不麻烦人维护；
(4) 适合等值查询多的场景，范围查询多可以关掉。
理解它，就能更好地判断要不要留着这个“加速工具”，让数据库跑更快。

2.4.2 性能调优实战
适用场景：
场景类型 加速效果 典型案例
主键点查询 8-10倍 用户ID查询
短连接查询 5-7倍 微服务API请求
排序索引访问 3-5倍 分页顺序查询
大范围扫描 无提升 全表扫描
控制参数：
-- 全局开关 (默认ON)
SET GLOBAL innodb_adaptive_hash_index = OFF;
-- 分区数设置 (默认8，解决锁竞争)
SET GLOBAL innodb_adaptive_hash_index_parts = 16;
-- 实时状态监控
SHOW GLOBAL STATUS LIKE 'Innodb_ahi%';
输出关键指标：
+-----------------------------------+-------+
| Variable_name | Value |
+-----------------------------------+-------+
| Innodb_ahi_searches | 38245 | # AHI查询次数
| Innodb_ahi_inserts | 1298 | # AHI新增条目
| Innodb_ahi_contention | 83 | # 哈希冲突次数
+-----------------------------------+-------+
与B+树索引对比：
维度 B+Tree AHI
索引类型 持久化结构 内存临时结构
构建方式 显示创建 自动按需生成
检索复杂度 O(log n) O(1)
适用操作 范围/精确/排序 仅精确查询
内存占用 固定 动态增长(最大BPOOL 1/32)
更新代价 中 高(需重建)
最佳场景 通用业务 超高频点查询
核心价值 ：对热点主键查询实现零层检索（直接内存定位），在交易系统核心表（如订单号查询）可提升10
倍吞吐量。但高并发写入场景可能因重建开销导致20%性能下降，需通过
innodb_adaptive_hash_index_parts 缓解锁冲突。
三、InnoDB 磁盘架构

核心组件：
(1) Redo Log（重做日志）
崩溃恢复的保险丝 ：顺序记录所有物理数据变更，实例崩溃时通过重放保证ACID持久性，物理文件为
ib_logfile0/1 的循环写入。
(2) Undo Log（回滚日志）
：存储数据修改前的原始镜像，支撑事务回滚和MVCC多版本读，MySQL 8.0后独立存储在 事务回滚的时光机
等专用表空间。 undo_001
(3) 系统表空间（System Tablespace）
引擎核心仓库 ：默认存储数据字典、双写缓冲、Change Buffer等元数据，主文件 ibdata1 持续增长且不可收
缩。
(4) 独立表空间（File-Per-Table Tablespace）
表专属数据容器 ：每个InnoDB表独立的 .ibd 文件存储表数据+索引，通过 innodb_file_per_table=ON 启
用，支持空间回收。
(5) 通用表空间（General Tablespace）
多表共享存储池 ：用户创建的跨表存储空间（ CREATE TABLESPACE ），可将多个表集中存储于自定义 .ibd 文
件中。
(6) 撤销表空间（Undo Tablespaces）
回滚日志专用住宅 ：MySQL 8.0+默认将undo log从系统表空间剥离，存储在独立的 undo_001/002 文件，避
免ibdata1膨胀。
(7) 临时表空间（Temporary Tablespaces）
瞬时数据沙盒 ：存储临时表及排序操作的磁盘中间数据，主文件 ibtmp1 随服务启动动态创建，重启自动清
理。
3.1、Redo Log
Redo Log（重做日志）是 InnoDB 的 崩溃恢复核心组件 ，采用物理逻辑日志结构，在事务提交前确保操作可恢
复。
核心价值： 将随机数据写入转化为顺序日志写入 ，实现ACID中的持久性（Durability）。
Redo Log是InnoDB存储引擎特有的物理日志 ，记录数据页的物理修改（如表空间号、页号、偏移量、修改
值），而非逻辑SQL语句（bin log是逻辑日志，存储的是逻辑sql）
3.1.1 WAL机制
Redo Log基于Write-Ahead Logging（WAL）机制，即“先写日志，后写磁盘”。事务提交时，先将修改记录写
入Redo Log Buffer并刷盘，再异步将内存中的脏页写入磁盘。
这一机制通过顺序写（日志）替代随机写（数据页），显著降低IO开销。

即使事务提交后脏页未落盘，Redo Log的存在仍能保证数据可恢复，从而提升性能并保障持久性。
redo log 和 undo log 配合起来的作用就是：
事务提交前崩溃，通过 undo log 回滚事务
事务提交后崩溃，通过 redo log 恢复事务
3.1.2 循环写入
Redo Log File 是 循环写入 的，由多个日志文件组成文件组（如4个1GB文件），类似“环形跑道”：
write pos ：当前日志写入位置（不断向后移动）。
checkpoint ：当前要覆盖的位置（需先将此位置前的脏页写入磁盘，才能推进）。
当 追上 时，数据库会先触发 checkpoint 机制（刷脏页到磁盘），再推 write pos checkpoint
进 ，避免日志被覆盖前数据丢失。 checkpoint

write pos：当前记录写到的位置，或者说 当前redo log文件写到了哪个位置
checkpoint：当前要擦除的位置，或者说 目前redo log文件哪些记录可以被覆盖
这两个指针把整个环形划成了几部分
write pos - checkpoint：待写入的部分
checkpoint - write pos：还未刷入磁盘的记录
3.1.3 刷盘策略
先说明下redo log的三层存储架构：
(1) 粉色，是InnoDB的一项很重要的内存结构(In-Memory Structure)，日志缓冲区(Log Buffer)，这一
层，是MySQL应用程序用户态；
(2) 黄色，是操作系统的缓冲区(OS cache)，这一层，是OS内核态；
(3) 蓝色，是落盘的日志文件；
Redo Log是怎么刷盘的？
第一步： 事务提交的时候，会写入Log Buffer，这里调用的是MySQL自己的函数WriteRedoLog；
第二步： 只有当MySQL发起系统调用写文件write时，Log Buffer里的数据，才会写到OS cache。注意，
MySQL系统调用完write之后，就认为文件已经写完，如果不flush，什么时候落盘，是操作系统决定的；
第三歩： 由操作系统（当然，MySQL也可以主动flush）将OS cache里的数据，最终fsync到磁盘上；
能够控制事务提交时，刷redo log的策略。目前有三种策略：
策略一：最佳性能(innodb_flush_log_at_trx_commit=0)
每隔一秒，才将Log Buffer中的数据批量write入OS cache，同时MySQL主动fsync。

这种策略，如果数据库崩溃，有一秒的数据丢失。
策略二：强一致(innodb_flush_log_at_trx_commit=1)
每次事务提交，都将Log Buffer中的数据write入OS cache，同时MySQL主动fsync。
这种策略，是InnoDB的默认配置，为的是保证事务ACID特性。
策略三：折衷(innodb_flush_log_at_trx_commit=2)
每次事务提交，都将Log Buffer中的数据write入OS cache；
操作系统决定刷盘时机（默认每秒一次 ） fsync
MySQL 后台线程每秒也会主动触发一次 ‌，确保日志落盘 fsync
这种策略，如果操作系统崩溃，可能有一秒的数据丢失
策略三，如果操作系统崩溃，最多有一秒的数据丢失。因为OS也会fsync，MySQL主动fsync的周期是一秒，
所以最多丢一秒数据。
策略三，磁盘IO次数不确定，因为操作系统的fsync频率并不是MySQL能控制的。
不同策略平衡了可靠性与性能，适用于不同业务场景（如金融系统选1，高并发场景选2或0）
3.2、Undo Log
Undo Log（回滚日志）是 InnoDB 事务原子性的基石 ，记录事务修改前的数据镜像。核心职责：
(1) 事务回滚：恢复到修改前状态
(2) MVCC多版本：实现非锁定一致性读
(3) 崩溃恢复：与Redo Log协同保证数据完整性
3.2.1 事务回滚（原子性）‌
在undo log日志中记录事务中的反向操作
事务进行insert操作，undo log记录delete操作
事务进行delete操作，undo log记录insert操作
事务进行update操作（value1 改为value2 ），undolog记录update操作（value2 改为value1 ）
开启事务后，对表中某条记录进行修改（将该记录字段值由value1 ——> value2 ——> value3 ），如果从整个
修改过程中出现异常，事务就会回滚，字段的值就回到最初的起点（值为value1 ）
trx_id代表事务id，记录了这一系列事务操作是基于哪个事务；
roll_pointer代表回滚指针，就是当要发生rollback回滚操作时，就通过roll_pointer进行回滚，这
个链表称为版本链。构建多版本链，支持精确回滚到特定版本

3.2.2 Undo Log MVCC支持（隔离性）‌
Undo Log 为 MVCC 提供多版本数据快照，实现非阻塞读与隔离性。
版本链复用‌：每个事务通过 trx_id 和 roll_pointer 访问对应版本数据，避免读写冲突
ReadView 机制‌：结合隐藏字段（如 DB_TRX_ID）和 Undo Log 版本链，决定事务可见的数据版
本
隔离级别适配‌：支持可重复读（RR）和读已提交（RC）等隔离级别，减少锁竞争
MVCC 能让读写不冲突，全靠 Undo Log 形成的“版本链”。举个例子：
事务 1 改了 id=1 的数据（name 从 'a' 变 'b'），生成一条 Update Undo Log（记着 name='a'）；
事务 2 同时读 id=1，它的 Read View 会判断“事务 1 没提交，不能看新值”，就顺着版本链找
Undo Log 里的老版本（name='a'）；
直到事务 1 提交，且没有事务再引用这个老版本，Purge 线程才会删掉这条 Undo Log。
MVCC和事务的隔离性，请参见尼恩团队另外一篇重要文章：
MVCC学习圣经：一文穿透MySQL MVCC，吊打面试官
3.2.3 内存优化机制
Undo Log 通过内存缓存和异步清理优化性能
Buffer Pool 缓存‌：Undo 页缓存在内存中，加速回滚和 MVCC 访问
Redo Log 保护‌：Undo 页的修改会记录到 Redo Log，确保崩溃后仍可恢复
异步清理‌：事务提交后，Purge 线程回收不再需要的 Undo 页，减少内存占用
3.3、bin log
3.3.1 什么是bin log日志
Binlog（Binary Log） 是 MySQL 的核心日志机制，它不属于Inno DB组件，属于MySQL 服务层，这里简单介
绍下
Binlog（Binary Log） 是 MySQL 的核心日志机制，记录所有对数据库的 DDL 和 DML 变更操作（如增删改表
结构、数据），但不包括查询语句（如 SELECT ）。其核心作用是实现 数据恢复 和 主从复制一致性。
redo log 和bin log的区别：
redo log（重做日志）让InnoDB存储引擎拥有了崩溃恢复能力。
binlog（归档日志）保证了MySQL集群架构的数据一致性。

通过一张图比较下二者区别
特性 Bin Log Redo Log
‌归属‌ MySQL Server 层 InnoDB 存储引擎
‌日志类型‌ 逻辑日志（SQL 或行变更） 物理日志（数据页修改）
‌写入方式‌ 追加写入（文件无限增长） 循环写入（固定大小）
‌持久化时机‌ 事务提交时 事务提交时（强制刷盘）
‌主要用途‌ 主从复制、时间点恢复 崩溃恢复、事务持久性
‌存储引擎依赖‌ 与存储引擎无关 仅 InnoDB
bin log日志格式
STATEMENT：记录 SQL 语句，日志量小但存在主从不一致风险（比如使用 ）。 NOW()
ROW：记录行级变更（旧值/新值），数据一致性高但日志量大。
MIXED：默认模式，自动切换 STATEMENT 和 ROW，平衡性能与一致性。
3.3.2 bin log日志刷盘参数
刷盘时机： 事务提交时，日志先写入内存缓存（ ），再根据 参数决定是否持久 binlog_cache sync_binlog
化到磁盘。
参数配置：
sync_binlog=0 ：依赖系统刷盘，性能高但数据易丢失。
sync_binlog=1 ：每次提交立即刷盘，最安全但性能损耗大。
sync_binlog=N ：累积 N 个事务后刷盘，折中方案。
这样，InnoDB 通过三大日志机制构建完整事务系统：
3.4、MySQL表空间
MySQL表空间是InnoDB存储引擎管理数据的 核心物理容器 ，分为五大类型：
(1) 系统表空间（ibdata1）
存储引擎元数据、双写缓冲区和Change Buffer（MySQL 5.7默认），通过 配置， innodb_data_file_path
无法自动收缩
(2) 独立表空间（.ibd）
启用 后，每个表独占文件存放 数据+索引 ，支持 回收空间 innodb_file_per_table=ON OPTIMIZE TABLE
(3) 通用表空间
用户用 CREATE TABLESPACE 创建，多个表共享.ibd文件，适合管理大量小表
(4) 撤销表空间（undo_*.ibd）

MySQL 8.0+将UNDO日志从ibdata1剥离，默认2个文件动态循环写入，避免历史事务阻塞
(5) 临时表空间（ibtmp1）
存储临时表/排序数据，服务重启自动重建， 控制大小 innodb_temp_data_file_path
版本演进 ：
5.6前：所有数据塞进ibdata1（易暴涨）
5.7+：独立表空间成为默认
8.0：UNDO日志独立，彻底解决ibdata1膨胀
3.4.1 表空间结构
表空间又由段 (segment)、区 ( extent)、页 (page) 组成，页是 InnoDB 磁盘管理的最小单位。
page 则是表空间数据存储的基本单位，innodb 将表文件（xxx.ibd）按 page 切分，依类型不同，page 内容
也有所区别，最为常见的是存储数据库表的行记录。
表空间下一级称为 segment。segment 与数据库中的索引相映射。
Innodb 引擎内，每个索引对应两个 segment： 管理叶子节点的 segment 和管理非叶子节点 segment。

创建索引中很关键的步骤便是分配 segment，Innodb 内部使用 INODE 来描述 segment。
segment 的下一级是 extent，extent 代表一组连续的 page，默认为 64 个 page，大小 1MB。
InnoDB 存储引擎的逻辑存储结构大致如下图2 所示。
在我们执行 sql 时，不论是查询还是修改，mysql 总会把数据从磁盘读取内内存中，而且在读取数据时，不会
单独加在一条数据，而是直接加载数据所在的数据页到内存中。
表空间本质上就是一个存放各种页的页面池。
「page页」是 InnoDB 管理存储空间的基本单位，也是内存和磁盘交互的基本单位。
也就是说，哪怕你需要 1 字节的数据，InnoDB 也会读取整个页的数据，
InnoDB 有很多类型的页，它们的用处也各不相同。
比如：有存放 undo 日志的页、有存放 INODE 信息的页、有存放 Change Buffer 信息的页、存放用户记录数
据的页（索引页）等等。
InnoDB 默认的页大小是 16KB，在初始化表空间之前可以在配置文件中进行配置，一旦数据库初始化完成就不
可再变更了。
SHOW VARIABLES LIKE 'innodb_page_size'
InnoDB引擎Row，Page具体结构参考 腾讯mysql 连环炮：索引、慢查询、深分页优化、sql优化、并发事
务问题、隔离级别、日志
3.4.2 系统表空间
简单说，系统表空间是 InnoDB 存储引擎的“大总管”——一块集中存放关键信息的磁盘空间，默认对应文
件 ibdata1 （在数据目录下）。它不像普通表那样只存自己的数据，而是管着一堆 InnoDB 运行必需的“核心资
产”，是数据库启动和运行的基础。
系统表空间里到底存了啥？
数据字典 ：相当于数据库的“户口本”，记录了所有表的结构（表名、字段、类型、索引信息等）。
InnoDB 启动时必须读它，否则不知道有哪些表，没法干活。这部分是硬要求，必须存在系统表空

间里，挪不走。
Undo 日志 ：8.0以下版本的Undo Log存储在系统表空间，事务的“后悔药”。比如你执
行 UPDATE 改了数据，Undo 日志就会记着“之前的值是啥”，如果事务回滚（ ROLLBACK ），就靠
它恢复原状。默认情况下，Undo 日志也存在系统表空间里。
双写缓冲区（Doublewrite Buffer） ：防止数据“写坏”的保险。InnoDB 刷脏页到磁盘时，不会直
接写数据文件，而是先写到双写缓冲区（相当于一个临时备份），确认写完了再同步到数据文件。
如果中途断电，数据文件没写完整，下次启动可以从双写缓冲区恢复，避免数据损坏。这部分也固
定在系统表空间。
Change Buffer ：之前讲过的“非唯一二级索引修改暂存区”，默认也存在系统表空间（它本质是一
块特殊的内存区域，但会定期刷到磁盘，磁盘上的部分就存在这里）。
用户表数据/索引（可选） ：如果创建表时没开“独立表空间”
（ innodb_file_per_table=OFF ），那么表的数据和索引会直接存在系统表空间里，和上面这
些核心内容混在一起。
系统表空间架构演进

组件 5.7及更早 8.0+
数据字典 ibdata1 mysql.ibd
Undo Log ibdata1 undo_001/002
用户表数据 可选共享 独立.ibd文件
Change Buffer ibdata1 ibdata1
双写缓冲区 ibdata1 #ib_16384_0.dblwr
临时表空间 ibtmp1 #innodb_temp
怎么配置系统表空间？
主要靠 （或 ）里的参数控制： my.cnf my.ini
(1) 指定文件路径和大小：
```ini
[mysqld]
innodb_data_file_path = ibdata1:12M:autoextend # 默认配置：ibdata1，初始12M，自动增长
# 也可以指定多个文件，比如：
# innodb_data_file_path = ibdata1:50M;ibdata2:50M:autoextend # 两个文件，ibdata2满了自动涨
(2) 是否用独立表空间存用户表：
```ini
[mysqld]
innodb_file_per_table = ON # 开独立表空间（默认值），用户表数据存在单独的 .ibd 文件，不占系统表空间
建议一直开着 ，这样用户表数据存在独立的 文件里（比如 ）， innodb_file_per_table=ON .ibd t1.ibd
删表时 会被删掉，不会让 越来越大。 .ibd ibdata1
3.4.3 独立表空间
简单说，独立表空间就是让每张表的“数据和索引”单独存成一个文件（比如 t1.ibd ），不和系统表空间
（ ibdata1 ）混在一起。就像每个家庭有自己独立的户口本，不用都塞在一个大本子里，管理起来方便多了。
MySQL 5.6 之后，这个功能默认是打开的（ innodb_file_per_table=ON ），现在基本都是这么用。
独立表空间（File-Per-Table）是 InnoDB 的 表级存储革命 ，每个用户表拥有专属的.ibd文件，实现物理存储的
完全隔离。核心价值：
(1) 空间自治：表级空间管理
(2) 性能隔离：IO操作分散
(3) 运维灵活：单表备份/迁移
3.4.4 通用表空间
通用表空间（General Tablespaces）是 InnoDB 的 高级存储容器 ，允许将多个表聚合存储在共享的物理文件
中，突破"一个表=一个文件"的限制，实现存储级别的灵活整合。
核心架构

关键操作命令
-- 在数据目录下创建一个叫 的通用表空间，文件是 app_data.ibd app_data
CREATE TABLESPACE app_data
ADD DATAFILE 'app_data.ibd'
ENGINE=InnoDB;
-- 也可以指定绝对路径（比如放另一个磁盘）
CREATE TABLESPACE log_data
ADD DATAFILE '/data/mysql/logs/log_data.ibd' -- 自定义路径
ENGINE=InnoDB;
-- 新建表时直接放进 app_data 表空间
CREATE TABLE user (
id int PRIMARY KEY,
name varchar(50)
) TABLESPACE app_data; -- 关键：指定表空间
-- 把已有的独立表空间的表（t_order）移到 app_data 里
ALTER TABLE t_order TABLESPACE app_data;
SELECT
table_name,
tablespace_name
FROM
information_schema.tables
WHERE
table_schema = '你的库名';
-- 先把表移走（比如移回独立表空间）
ALTER TABLE user TABLESPACE = innodb_file_per_table; -- 独立表空间的特殊名称
-- 或者直接删表
DROP TABLE t_order;
-- 再删表空间
DROP TABLESPACE app_data;

架构精髓 ：通用表空间如同数据库的"多功能集装箱"，通过物理聚合打破存储孤岛。特别适用于：
SaaS系统（万级小表合并存储）
时序数据（冷热分级归档）
敏感数据（统一加密管理）
黄金法则：当单个实例超过500个表时，通用表空间可显著降低文件系统压力！
3.4.5 撤销表空间
简单说，撤销表空间就是专门存 Undo 日志的“独立仓库”。Undo 日志是事务的“后悔药”——比如你执
行 UPDATE 改了数据，它会记下“改之前的值是啥”，万一事务回滚（ ROLLBACK ），就靠它恢复原状。
撤销表空间（Undo Tablespaces）是 MySQL 8.0+ 的 事务时光机 ，独立存储 UNDO 日志，实现：
(1) 原子性保障：事务回滚能力
(2) MVCC 支持：多版本并发控制
(3) 空间自治：独立回收机制
MySQL 8.0 默认创建 2 个 Undo 表空间文件（ undo_001 和 undo_002 ），每个初始大小为 16MB，通过参
数 innodb_undo_tablespaces 可调整数量（范围 2-127），每个文件初始 16MB，支持自动扩展和截断回
收。
Undo 表空间的逻辑层级管理是咋样的？
回滚段（Rollback Segments） ：每个 Undo 表空间包含 128 个回滚段
（由 innodb_rollback_segments 控制），每个回滚段管理 1024 个 Undo 段（Undo Segments）。
Undo 页与日志记录 ：Undo 段由多个 16KB 的页组成，按事务类型分为 Insert Undo 段（仅用于回滚）和
Update Undo 段（用于 MVCC），前者事务提交后立即释放，后者需等待无活跃读视图时清除。
通过多 Undo 表空间与回滚段的分区设计，理论上支持高达数万级并发事务（例如：128 表空间 × 128 回滚段
× 1024 Undo 段）。
如下图所示。
关键说明 ：
每个 Undo 表空间包含 128 个回滚段

每个回滚段管理 1024 个 Undo 段 （按事务类型分类）
Undo 段由 16KB 页 组成，存储具体日志记录
说说 Undo Log 与 MVCC 的协作机制？
Undo Log 与 MVCC 的协作机制如下图所示：
运作原理 ：
事务修改前将旧数据写入 Undo Log
读事务通过 Read View 判断可见性
多版本数据通过 Undo Log 链回溯访问
系统表空间与 Undo 表空间存储有啥区别？
特性 Undo 表空间 系统表空间（历史方案）
存储内 数据字典、双写缓冲、Undo Log 等混合内 仅 Undo Log 容 容
空间管 支持自动截断，避免文件膨胀 无法自动回收，需手动调整或重建 理
性能影 减少 I/O 竞争，提升并发处理能 高频事务易导致文件过大，性能下降 响 力
版本支 MySQL 5.7+ 默认方案 MySQL 5.6 及更早版本 持
3.4.6 临时表空间
临时表空间（Temporary Tablespaces）是 MySQL 的 高速暂存区 ，专为临时数据处理设计，存储：
(1) 用户创建的临时表（CREATE TEMPORARY TABLE）
(2) 优化器生成的内部临时表（排序/分组等）
(3) 在线DDL操作的中间数据
核心架构

MySQL版本 临时表空间方案
≤5.7 共享ibtmp1文件
8.0+ 全局ibtmp1 + 会话级独立文件
InnoDB 临时表空间分为 会话临时表空间 和 全局临时表空间 ，分别承担不同角色：
会话临时表空间（Session Temporary Tablespaces）
用途： 存储用户显式创建的临时表（CREATE TEMPORARY TABLE）以及优化器生成的内部临时
表（如排序、分组操作） 。
生命周期 ：会话断开时自动截断并释放回池，文件扩展名为 ，默认位于 目 .ibt #innodb_temp
录。
分配机制 ：首次需要创建磁盘临时表时，从预分配的池中分配（默认池包含 10 个表空间文件），
每个会话最多分配 2 个表空间（用户临时表与优化器内部临时表各一）。
全局临时表空间（Global Temporary Tablespace） ：
用途 ：存储用户临时表的回滚段（Rollback Segments），支持事务回滚操作。
文件配置 ：默认文件名为 ibtmp1 ，初始大小 12MB，支持自动扩展，由参
数 innodb_temp_data_file_path 控制路径与属性。
回收机制 ：服务器重启时自动删除并重建，意外崩溃时需手动清理。
Temporary Tablespaces 物理结构
图示说明 ：
全局临时表空间 ： 存储用户临时表的回滚段 ibtmp1
会话临时表空间 ： 目录下预分配 10 个 文件池（默认配置） #innodb_temp .ibt
每个会话最多激活 2 个临时表空间（用户临时表 + 优化器内部临时表）。

会话级临时表空间生命周期
关键点 ：
(1) 首次需要磁盘临时表时从池中分配
(2) 会话断开连接后立即归还空间
(3) 文件物理保留但内容截断（类似内存池机制）
临时表空间使用查询流程
前面说过临时表空间可 存储用户显式创建的临时表（CREATE TEMPORARY TABLE）以及优化器生成的内部
临时表（如排序、分组操作） 。
那它的查询过程是怎样的呢？
3.5 Doublewrite Buffer
简单说，Doublewrite Buffer 是 InnoDB 防止数据“写坏”的一道保险。
当 InnoDB 把内存里的脏页（改过但没刷到磁盘的数据）写到磁盘时，不是直接写到数据文件（.ibd），而是先
写一份到 Doublewrite Buffer，确认安全后再同步过去。
这就像你保存重要文档时，先存到U盘一份，再存到电脑硬盘——万一存硬盘时突然断电，至少U盘里还有备
份，不会丢数据。
双写缓冲（Doublewrite Buffer）是 InnoDB 的 数据安全卫士 ，通过"先写副本再写正本"的两段式写入机制，
解决 部分页写入（Partial Page Write） 问题，确保数据页崩溃恢复的完整性。
核心工作流程图
3.5.1 为什么写数据需要Double write Buffer
MySQL程序是跑在Linux操作系统上的，理所当然要跟操作系统交互，

一般来说，MySQL中一页数据是16kb，操作系统一个页是 4kb，所以，mysql page 刷到磁盘，要写4个文件
系统里的页。
如图所示：
需要注意的是，这个操作并非原子操作，比如我操作系统写到第二个页的时候，Linux 机器断电了，这时候就
会出现partial page write（部分页写入） 问题了, 造成”页数据损坏“。
并且, 这种”页数据损坏“靠 redo 日志是无法修复的 。
Redo log 中记录的是对页的局部修改操作，而不是页面的全量记录。 换句话说，Redo log记录的是修改前后
的差异，而不是整个数据页的内容。
如果发生 partial page write（部分页写入）问题时，出现问题的页面的全量记录，这里包括哪些没有被 Redo
log记录 未修改过的数据，此时重做日志(Redo Log)无能为力。
Doublewrite Buffer 的出现就是为了解决上面的这种情况。
虽然名字带了 Buffer，但实际上 Doublewrite Buffer 是 内存+磁盘 的结构。
Doublewrite Buffer 是一种特殊文件 flush 技术，带给 InnoDB 存储引擎的是数据页的可靠性。
它的作用是，在把页写到磁盘数据文件之前， InnoDB 先把它们写到一个叫 doublewrite buffer（双写缓冲
区）的共享表空间内，在写 doublewrite buffer 完成后，InnoDB 才会把页写到数据文件的适当的位置。
如果在写页的过程中发生意外崩溃，InnoDB 在稍后的恢复过程中在 doublewrite buffer 中找到完好的 page
副本用于恢复。
3.5.2 Doublewrite Buffer原理
Doublewrite Buffer 采用 内存+磁盘双层结构 ，关键组件如下：
内存结构

容量固定为 128 个页（2MB） ，每个页 16KB。
数据页刷盘前，通过 拷贝至内存 Doublewrite Buffer。 memcpy
磁盘结构
位于系统表空间（ ibdata ），分为 2 个区（extent1/extent2） ，共 2MB。
数据以 顺序写 方式写入，避免随机 I/O 开销。
工作流程如下图所示：
如上图所示，当有数据修改且页数据要刷盘时：
(1) 第一步：记录 Redo log。
(2) 第二步：脏页从 Buffer Pool 拷贝至内存中的 Doublewrite Buffer。
(3) 第三步：Doublewrite Buffer 的内存里的数据页，会 fsync 刷到 Doublewrite Buffer 的磁盘上，分两
次写入磁盘共享表空间中(连续存储，顺序写，性能很高)，每次写 1MB；
(4) 第四步：Doublewrite Buffer 的内存里的数据页，再刷到数据磁盘存储 .ibd 文件上（离散写）；
时序图如下：
崩溃恢复
如果第三步前，发生了崩溃，可以通过第一步记录的 Redo log 来恢复。
如果第三步完成后发生了崩溃， InnoDB 存储引擎可以从共享表空间中的 Double write 中找到该页的一个副
本，将其复制到独立表空间文件，再应用 Redo log 恢复。
在正常的情况下，MySQL 写数据页时，会写两遍到磁盘上，第一遍是写到 doublewrite buffer，第二遍是写
到真正的数据文件中， 这就是“Doublewrite”的由来。
Doublewrite Buffer 通过 两次写 机制，在内存和磁盘间构建冗余副本，成为 InnoDB 保障数据完整性的基
石。

其架构设计平衡了性能与可靠性，尤其在高并发或异常宕机场景下表现突出。
3.5.3 Doublewrite Buffer相关参数
以下是一些与Doublewrite Buffer相关的参数及其含义：
innodb_doublewrite ： 这个参数用于启用或禁用双写缓冲区。设置为1时启用，设置为0时禁
用， 默认值为1。
： 这个参数定义了多少个双写文件被使用。默认值为2，有效范 innodb_doublewrite_files
围从2到127。
innodb_doublewrite_dir ： 这个参数指定了存储双写缓冲文件的目录的路径。默认为空字符
串，表示将文件存储在数据目录中。
: 这个参数定义了每次批处理操作写入的字节数。默认值 innodb_doublewrite_batch_size
为0，表示InnoDB会选择最佳的批量大小。
innodb_doublewrite_pages ：这个参数定义了每个双写文件包含多少页面。默认值为128。
3.5.4 Doublewrite Buffer和redo log
在MySQL的InnoDB存储引擎中，Redo log和Doublewrite Buffer共同工作以确保数据的持久性和恢复能力。
(1) 首先wal架构：
当有一个DML（如INSERT、UPDATE）操作发生时， InnoDB会首先将这个操作写入redo log（内存）。这些日
志被称为未检查点（uncheckpointed）的redo日志。
(2) 然后，在修改内存中相应的数据页之后，需要将这些更改记录在磁盘上。
但是直接把这些修改的页写到其真正的位置可能会因发生故障导致页部分更新，从而导致数据不一致。
因此，InnoDB的做法是先将这些修改的页按顺序写入doublewrite buffer。
这就是为什么叫做 "doublewrite" —— 数据实际上被写了两次，先在doublewrite buffer，然后在它们真正的
位置。
(3) 一旦这些页被安全地写入doublewrite buffer，它们就可以按原始的顺序写回到文件系统中。
即使这个过程在写回数据时发生故障，我们仍然可以从doublewrite buffer中恢复数据。
(4) 最后，当事务提交时，相关联的redo log会被写入磁盘。
这样即使系统崩溃，redo log也可以用来重播（replay）事务并恢复数据库。
在系统恢复期间，InnoDB会检查doublewrite buffer，并尝试从中恢复损坏的数据页。
如果doublewrite buffer中的数据是完整的，那么InnoDB就会用doublewrite buffer中的数据来更新损坏的
页。
否则，如果doublewrite buffer中的数据不完整，InnoDB也有可能丢弃buffer内容，重新执行那条redo log以
尝试恢复数据。
所以，Redo log和Doublewrite Buffer的协作可以确保数据的完整性和持久性。如果在写入过程中发生故障，
我们可以从doublewrite buffer中恢复数据，并通过redo log来进行事务的重播。
3.5.5 Doublewrite Buffer 总结
Doublewrite Buffer是InnoDB的一个重要特性，用于保证MySQL数据的可靠性和一致性。
它的实现原理是通过将要写入磁盘的数据先写入到Doublewrite Buffer中的内存缓存区域，然后再写入到磁盘
的两个不同位置，来避免由于磁盘损坏等因素导致数据丢失或不一致的问题。
总的来说，Doublewrite Buffer对于改善数据库性能和数据完整性起着至关重要的作用。尽管其引入了一些开
销，但在大多数情况下，这些成本都被其提供的安全性和可靠性所抵消。
说在最后：有问题找老架构取经‍
按照此文的套路去回答，一定会 吊打面试官，让面试官爱到 “不能自已、口水直流” ，然后实现”offer直提”。

在面试之前，建议大家系统化的刷一波 5000页《 尼恩Java面试宝典PDF 》，里边有大量的大厂真题、面试
难题、架构难题。
很多小伙伴刷完后， 吊打面试官， 大厂横着走。
在刷题过程中，如果有啥问题，大家可以来 找 40岁老架构师尼恩交流。
另外，如果没有面试机会， 可以找尼恩来改简历、做帮扶。
前段时间，尼恩 刚辅导一个 外包+二本小伙 进 美团 ： 一步登天 进了顶奢大厂（ 美团） ， 26
岁小2本 逆天改命
跟着 尼恩 狠狠卷，实现 “offer自由” ， 逆天改命 很容易的 。
惊天大逆袭： 通过 Java+AI 实现弯道超车， 完成转架构
会 AI的程序员，工资暴涨50%！
极速上岸： 被裁 后， 8天 拿下 京东，狠涨 一倍 年薪48W， 小伙伴 就是
做对了一件事
外包+二本 可以进 美团： 26岁小2本 一步登天， 进了顶奢大厂（ 美团） ， 太爽了
暴涨 150%，4年 CRUD 一步登天， 进 ‘宇宙厂’， 26 岁 小伙 6个月 大逆袭
Java+Al 大逆袭1 ： 34岁无路可走，一个月翻盘，拿 3个架构offer，靠 Java+Al 逆天改命！！！
java+AI 大逆袭2 ： ：3年 程序媛 被裁， 25W-》40W 上岸， 逆涨60%。 Java+AI 太神了， 架构小
白 2个月逆天改命
Java+AI逆袭 ： 36岁/失业7个月/彻底绝望 。狠卷 3个月 Java+AI ，终于逆风翻盘，顺利 上岸
Java+AI逆袭 ： 闲了一年，41岁/失业12个月/彻底绝望 。狠卷 2个月 Java+AI ，终于逆风翻盘
冲大厂 案例： 全网顶尖、高薪案例， 进大厂拿高薪， 实现薪酬腾飞、人生逆袭
涨一倍：从30万 涨 60万，3年经验小伙 冲大厂成功，逆天了 ！！！
阿里+美团offer： 25岁 屡战屡败 绝望至极。找尼恩转架构升级，1个月拿到阿里+美团offer，逆天改命
年薪 50W
阿里offer： 6年一本 不想 混小厂了。狠卷1年 拿到 得物 + 阿里 offer ， 彻底上岸 ，逆天改命
大龄逆袭的案例： 大龄被裁，快速上岸的，远离没有 offer 的焦虑、恐慌
47岁超级大龄， 被裁员后 找尼恩辅导收 2个offer，一个40多W。 35岁之后，只要 技术
好，还是有饭吃，关键是找对方向，找对路子
大龄不难：39岁/15年老码农，15天时间40W上岸，管一个team，不用去 铁人三项了！

草根逆袭， 100W 年薪 天花板 案例。 他们 如何 实现薪酬腾飞、人生逆袭？
专科生 100年薪 ：35岁专科 草根逆袭，2线城市年薪100W 逆天改命， 从 超低起点 塔基（8W）--》
塔腰-》塔尖（100W）
年薪100W的底层逻辑： 大厂被裁，他们两个，如何实现年薪百万？
年薪100W ： 40 岁小伙，被裁6个月，猛卷3月，100W逆袭 ，秘诀：升级首席架构/总
架构
最新的100W案例：环境太糟，如何升 P8级，年入100W？
职业救助站
实现职业转型，极速上岸
关注 职业救助站 公众号，获取每天职业干货
助您实现 职业转型、职业升级、极速上岸
---------------------------------
技术自由圈
实现架构转型，再无中年危机
关注 技术自由圈 公众号，获取每天技术千货
一起成为牛逼的 未来超级架构师
几十篇架构笔记、5000页面试宝典、20个技术圣经
请加尼恩个人微信 免费拿走
暗号 领电子书 ，请在 公众号后台 发送消息：
在看 赞 如有收获，请点击底部的" "和" "，谢谢

