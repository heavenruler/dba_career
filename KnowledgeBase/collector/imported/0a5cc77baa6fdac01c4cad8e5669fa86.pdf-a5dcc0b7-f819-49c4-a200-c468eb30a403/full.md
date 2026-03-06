搞懂Redo Log与Binlog，就搞懂了MySQL数据安全的半壁江山
大黄花鱼 云同学的技术圈 2025年9月7日 08:01 上海 原创
在 MySQL 的世界里，数据安全和主从复制是其赖以生存的基石。但你是否想过，当服务
器突然断电时，那些刚刚提交、还停留在内存中的数据是如何奇迹般地幸存下来的？这一
切的背后，都离不开 MySQL 设计精妙的日志体系。
接下来，我们将深入剖析这个体系中非常有意思的设计： Redo Log 和 Binlog 。
01
MySQL基本架构
简单回顾下MySQL的基本架构。
云同学的技术圈 赞 分享 推荐 写留言
MySQL基本架构图
从图中可以看到，MySQL总体上可以分为 Server 层 和 存储引擎层 两部分。
Server 层
连接器：连接管理、账号认证、获取权限信息
查询缓存：缓存优化，命中缓存则直接返回结果

分析器：SQL语法解析
优化器：SQL优化、选择索引并生成执行计划
执行器：根据执行计划调用存储引擎
存储引擎层
负责数据的存储和提取。
MySQL的存储引擎是插件式的，可以支持 InnoDB、MyISAM、Memory 等。其中，
InnoDB 从 MySQL 5.5.5 版本开始成为了 MySQL 默认存储引擎。
02
MySQL日志两大主角：Redo Log & binlog
1、Redo Log（重做日志）
Redo Log 是 InnoDB 存储引擎特有 的日志。它存在于存储引擎层，是 MySQL 实现崩溃
安全和事务持久性的基石。
（1）职责：保证崩溃安全（crash-safe）
磁盘 I/O 是非常缓慢的。如果每一次数据修改都直接去写磁盘文件，MySQL 的性能
将惨不忍睹。
为了提速，InnoDB 会先修改内存中的缓冲池 （Buffer Pool），然后由后台线程在未
来的某个时刻将这些修改（脏页）异步地通过 fsync 刷回磁盘。
但问题来了：如果脏页还没来得及刷盘，服务器就断电了，内存里的数据不就丢了
吗？
Redo Log 就是为了解决上边的问题而生的。
它完美地实践了 WAL（Write-Ahead Logging, 预写式日志） 的理念：
在数据写入磁盘文件之前，必须先将这次操作的日志写入到日志文件中。
当 InnoDB 修改内存中的数据时，它会立刻生成一条 Redo Log 并确保它在事务提交
(commit) 时落盘。这样，即使脏页没来得及刷盘就发生了崩溃，重启后 InnoDB 也可以通
过读取 Redo Log 的记录，将数据“重做”一遍，从而恢复到崩溃前的状态。
（2）Redo Log特点
内容是物理的
Redo Log 记录的是“对哪个数据页的哪个偏移量做了什么修改”，是一种 物理日志 。这
种记录方式恢复起来极快，因为它不需要经过 SQL 解析等复杂过程。
大小固定，循环写入
Redo Log 文件组的大小是固定的，像一个钟表的表盘一样被循环使用。当写到末尾
时，会回到开头覆盖旧的记录。
引擎层日志
它是 InnoDB 独有的日志，其他存储引擎（如 MyISAM）没有。

Redo Log记录的内容类似：“在表空间 X 的第 Y 个数据页的 Z 偏移量处，写入数据 ‘abc’”。
这种日志是给 InnoDB 自己看的 ， 描述的是物理层面的数据修改。在数据库崩溃后，InnoDB 只需
要像“录像回放”一样，按照 redo log 的记录，把数据页“重做”一遍，就能快速恢复到崩溃前的状
态。 这种操作是幂等的，做多少遍结果都一样，非常高效。
2、Binlog（二进制日志）
Binlog 是 MySQL Server 层的日志，所有存储引擎（InnoDB, MyISAM 等）都可以使
用。
（1）职责：主从复制与时间点恢复
Binlog 的主要职责不是防止崩溃，而是记录所有对数据库进行变更的逻辑操作。
它有两个核心用途：
主从复制 (Replication)
主库将自己的 Binlog 实时地传输给从库，从库接收到后会“回放”Binlog 中的事件，从
而实现与主库的数据同步。
时间点恢复 (Point-in-Time Recovery)
当数据库发生误操作时（比如 delete 删错了表），你可以用一个全量备份恢复到某个时
间点，然后使用 Binlog 回放该时间点之后的所有操作，实现精确的数据恢复。
（2）Binlog特点
内容是逻辑的
Binlog 记录的是一个操作的“逻辑意图”。
主要有两种种格式：
Statement： 记录原始的 SQL 语句；
Row ： 记录每一行数据变更前后的值；
无限大小，追加写入
Binlog 文件会一直追加（append）写入，达到一定大小后会自动滚动到下一个新文
件，不会覆盖旧的记录。
服务层日志
它是 MySQL Server 的功能，与具体存储引擎无关。
Statement 格式
记录原始的 SQL 语句，比如 UPDATE my_table SET name = 'B' WHERE id = 1;。
Row 格式
记录某一行数据从“旧值”变成了“新值”，比如“表 my_table 中，id=1 的行，name 字段从 'A'
变为 'B'”。
binlog日志是给人看的，也是给从库看的， 它描述的是一个操作意图。
3、区别比较

特性 Redo Log Binlog
崩溃安全 主从复制、 核心目的 (Crash Safety) 时间点恢复
服务层 所属层级 存储引擎层 (InnoDB) (Server-level)
偏向物理 日志内容 逻辑（SQL语句或行变更） （数据页变更）
循环写入 追加写入 写入方式 （大小固定） （可滚动）
WAL实现 是（保证持久性的基础） 否
03
执行一条SQL更新，到底发生了什么？
1、两阶段提交 (Two-Phase Commit, 2PC)
两阶段提交 (Two-Phase Commit, 2PC) 是理解MySQL数据更新过程的关键，同时也是
保证主库 crash-safe 和主从数据一致性的重要机制。
我们以一个 UPDATE 语句为例，看看 MySQL 内部是如何通过精妙的 2PC 来协调 Redo
Log 和 Binlog 的。
假设我们要执行：
UPDATE users SET age = 18 WHERE id = 1;
用户发起update；

MySQL 执行器调用 InnoDB 引擎的接口执行数据更新；
写入redo log，标记为prepare (第 1 阶段 - Prepare)：
（1）InnoDB 去 Buffer Pool 中查找 id=1 的数据行，如果不在，就从磁盘加载到
Buffer Pool 中。
（2）InnoDB 在 Buffer Pool 中直接修改 id=1 这行数据的 age 字段为 18，这条数据
所在的数据页现在变成了“ 脏页 ”。
（3）InnoDB 同时会 生成一条对应的 Redo Log ，记录下这个修改。这条 Redo Log
被写入 Redo Log Buffer。
（4）当用户执行 COMMIT 时，InnoDB 会确保将这个事务相关的 Redo Log 刷到磁
盘，并在 Redo Log 中将这个事务的 状态标记为 prepare 。
InnoDB 就告诉执行器：“我已经准备好了，随时可以提交”。
此时，即使 MySQL 崩溃，由于有 Redo Log处于 prepare 状态，数据也能被恢复 （但
恢复时是提交还是回滚，需要看 Binlog 的状态） 。
执行器写 Binlog (第 2 阶段 - Commit 的一部分)：
它会将这个 UPDATE 操作（根据 binlog_format 的设置，可能是 SQL 语句或行变更）
写入 Binlog Cache（内存中的 Binlog 缓冲区）。
然后，执行器将 Binlog Cache 的内容刷到磁盘上的 Binlog 文件中。
Binlog 成功落盘后，执行器会调用 InnoDB 引擎的接口；
Redo log变成commit状态 (第 2 阶段 - Commit 的完成)：
InnoDB 在 Redo Log 中写入一个 commit 标记，表示这个事务已经更新完成。
至此，一个事务才算完整、持久地完成了。MySQL 服务器这时才会返回给客户端“执行
成功”的消息。
2、 “两阶段提交”如何拯救一切？
（1）场景复现
通过之前的介绍，我们可以概括一个事务的提交流程大致是：
用户执行 COMMIT。
InnoDB 准备提交 ：将事务的修改写入 redo log，并标记为 prepare 状态。
MySQL Server 写入 binlog。
InnoDB 完成提交 ：在 redo log 中将事务标记为 commit 状态。
现在，想象一下 崩溃 (crash) 发生在这中间：
场景A：在第 3 步（写 binlog）之前崩溃
状态： Redo log 里有这个事务的记录，但 binlog 里没有。
恢复： MySQL 重启后，InnoDB 发现这个事务没有被 commit，就会回滚它。数据和
binlog 此时是一致的（都没有这个事务）。 数据没丢，一致性也没问题。

场景B：在第 3 步（写 binlog）成功后，第 4 步（InnoDB commit）之前崩溃
状态： Binlog 里已经有了这个事务的记录，但 InnoDB 层面，这个事务还处于 prepare
状态，尚未最终 commit。
恢复（如果没有 2PC 机制）： MySQL 重启后，InnoDB 发现这个事务没有被 commit，
它会怎么办？它会回滚这个事务！
灾难发生： 此时，数据库的数据被回滚了（没有 'B'），但是 binlog 里却记录了数据已经
被改成了 'B'。如果此时有一个从库正在复制，它会接收到 binlog 并执行修改，导致主
从数据不一致！
Binlog 的写入和 InnoDB 的最终提交是两个独立的操作。
在这两个操作之间存在一个危险的“时间窗口”，一旦发生崩溃，就会导致数据和日志的不一致。
（2）2PC 机制内在逻辑
2PC的恢复逻辑是这样的：
MySQL 重启后，InnoDB 会扫描所有处于 prepare 状态的事务。
对于每一个 prepare 状态的事务，InnoDB 不是直接回滚，而是拿着这个事务的唯一标
识（XID）去 binlog 中查找。
决策点：
1⃣️ 如果在 binlog 中能找到这个事务的记录，说明在崩溃前 binlog 已经写入成功了。
为了保证数据和 binlog 的一致性，InnoDB 必须 完成这个事务的提交 （Roll
forward） 。
2⃣️ 如果在 binlog 中找不到这个事务的记录，说明在崩溃前 binlog 还没来得及写。为
了保证一致性，InnoDB 必须 回滚这个事务（Roll back） 。
通过这个机制，MySQL 巧妙地利用 Redo Log 的 prepare 状态作为一个“中间协调点”，
确保了无论在哪个时间点崩溃，InnoDB 数据和 binlog 日志总能恢复到一致的状态。
04
Q & A
Q:
binlog日志也记录了所有的操作，也有位点。为什么binlog 没有
crash_safe的能力？
A:
单独依靠 binlog 无法做到灾难恢复，因为它在两个核心维度上存在致命
缺陷：
一是性能，二是正确性。
致命缺陷一：性能灾难 (用“逻辑”恢复太慢)
Binlog 的恢复方式（理论上）：
MySQL 需要从上一个检查点（checkpoint）开始，重新完整地执行 binlog 中记录的所有
SQL 语句或行变更事件。

这意味着：
SQL 解析： 每一条 UPDATE, INSERT, DELETE 都要重新被 SQL 解析器过一遍。
查询优化： 优化器需要重新为这些 SQL 生成执行计划。
数据查找： 需要重新进行索引扫描、表扫描，找到需要修改的数据行。
加锁与执行： 重新加锁，然后执行修改。
如果崩溃前的一小时内，我们对同一行数据 UPDATE 了 1000 次，那么恢复时，MySQL
就需要真的把这 1000 次 UPDATE 再完整地执行一遍。这个过程极其缓慢，如果业务繁
忙，恢复可能需要几个小时甚至更久，这是生产环境无法接受的。
Redo Log 的恢复方式 (为什么快)：
而Redo log 不关心你执行了什么 SQL，它只记录了物理页的变化。它的恢复语言是：“把
A 数据页的第 X 个字节改成 B”。
这个操作是：
无需 SQL 解析和优化： 直接操作数据页，没有 SQL 层面的开销。
顺序 I/O： Redo log 是顺序写入的，恢复时也是顺序读取，速度极快。
幂等性： 把一个字节改成 'B'，这个操作做一遍和做一百遍，结果都是 'B'。所以恢复过
程非常简单、暴力且高效。
致命缺陷二：正确性灾难 (无法区分“已落盘”和“未落盘”)
这是比性能问题更致命的、正确性层面的问题。Binlog 完全不知道 InnoDB 内部的内存状
态。
背景知识： InnoDB 修改数据时，不是直接写磁盘，而是先修改内存中的缓冲池 (Buffer
Pool) 里的数据页，这些被修改过的页叫做“脏页”。InnoDB 会在后台找合适的时机，将这
些脏页刷回到磁盘文件中。
现在，让我们回到崩溃的瞬间：
内存状态： Buffer Pool 里有大量的脏页。
磁盘状态： 一部分脏页可能已经被刷盘了，另一部分还只存在于内存中。
Binlog 状态： 只要事务提交了，对应的 binlog 就已经记录下来了。
灾难场景1：
假设我们执行了两个事务：
T1: UPDATE users SET age = 18 WHERE id = 1;
T2: UPDATE users SET age = 35 WHERE id = 1;
这两个事务都成功提交了，所以 binlog 里清晰地记录了这两次操作。
在崩溃的瞬间，恰好 T1 对应的那个脏页已经被刷盘了，但是 T2 对应的脏页还在内存里，
没来得及刷盘。
现在，服务器重启，开始用唯一的 binlog 来恢复：
MySQL 读取 binlog，看到了 T1 操作。它会去执行 UPDATE users SET age = 18
WHERE id = 1;。但 id=1 这行数据在磁盘上的 age 已经是 18 了！重复执行可能会导
致未知错误，但就算成功了，也是一次浪费。
MySQL 接着读取 binlog，看到了 T2 操作。它执行 UPDATE users SET age = 35
WHERE id = 1;。这次操作是正确的，因为它把丢失的修改恢复了。
貌似看起来好像问题不大？别急，我们再看下一个场景：

灾难场景2（主键冲突）：
事务 T3: INSERT INTO users (id, name) VALUES (100, 'Dylan'); 成功提交，binlog 已
记录。这个事务对应的脏页也 幸运地被刷盘了 。
现在重启，用 binlog 恢复：
MySQL 读取到 T3 的 binlog，尝试执行 INSERT ... VALUES (100, 'Dylan');。结果会是
什么？ 主键冲突错误！ 因为 id=100 的数据已经真实地存在于磁盘上了。恢复过程会因为
这个错误而中断。
Binlog 是一个MySQL server层的概念，它不知道在崩溃前，在存储引擎层，哪些修改已
经从内存（Buffer Pool）持久化到了磁盘，哪些没有。 强行用 binlog 来恢复，会导致重
复执行已经落盘的操作，引发各种错误（如主键冲突）和数据不一致，最终导致恢复失
败。
云同学的技术圈
专注云原生、中间件、SRE、Devops等领域的技术分享，一起探究系统架构背后的原理与本质。
14篇原创内容
公众号

