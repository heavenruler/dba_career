# 6 MySQL 底层解析——缓存：InnoDB Buffer Pool（包括连接、解析、缓存、引擎、存储等）

作者：天涯泪小武

版权声明：本文为博主原创文章，遵循 CC 4.0 BY-SA 版权协议，转载请附上原文出处链接和本声明。

前面几篇主要学习存储，在磁盘上的存储结构、内部格式等。本文聚焦内存，对 InnoDB 来说最关键的就是 InnoDB Buffer Pool（缓冲池）。内存读写与磁盘读写速度相差甚远。数据库的数据最终落到磁盘，为了达到快速读写，必须依靠缓存技术。InnoDB 的缓存区就是 Buffer Pool：读取数据时先在缓存中查看是否存在相应的数据页（page），不存在才去磁盘检索，检索到后缓存到 pool 中。插入、修改、删除也是先操作缓存中的数据，之后再以一定频率更新到磁盘上。控制刷盘的机制叫做 Checkpoint（检查点）。

## InnoDB Buffer Pool 内部结构

MySQL 安装后默认 Buffer Pool 大小是 128M，可以通过 `show variables like 'innodb_buffer_pool%';` 查看。通过 `show global status like '%innodb_buffer_pool_pages%';` 可以查看已被占用和空闲的页数。

理论上，如果把 Buffer Pool 设置得足够大，能装下所有要访问的数据，那么所有请求都走内存，性能最佳。官方建议把 Buffer Pool 设置为物理内存的 50%–75%。在 MySQL 5.7.5 之后，可以在不重启 MySQL 的情况下动态修改 Buffer Pool 大小；若设置超过 1G，建议调整 `innodb_buffer_pool_instances=N`，将 pool 分成 N 个实例，按照 page 的 hash 映射到不同实例，有助于减少多线程并发读取同一个 pool 时的锁竞争。

注意：文中所示的左右两块内存结构，有两块不在 Buffer Pool 内，是另外一块内存，但大部分内存通常属于 Buffer Pool。

## 缓冲区 LRU 淘汰算法

当 pool 大小不足，满了之后会根据 LRU（最近最少使用）算法淘汰页面。最频繁使用的页在 LRU 列表前端，最少使用的页在尾端，淘汰首先释放尾端的页。

InnoDB 的 LRU 与普通 LRU 略有不同：引入了 midpoint（中点）概念。新读取到的页并不是直接放到 LRU 列表头部，而是放到 midpoint 位置。该位置大概在 LRU 列表的 5/8 处，由参数 `innodb_old_blocks_pct` 控制（默认值例如 37，表示新读取的页插入到尾端 37% 的位置）。midpoint 之后为 old 列表，之前为 new 列表，new 列表的页代表更活跃的数据。

不直接将新页放到头部的原因是：某些扫描操作会访问大量页，这些页可能只在当前查询中有用，之后很少访问，不应被当成长期热点。将新页先放到 midpoint，相当于“预热”。还有参数 `innodb_old_blocks_time` 表示页读取到 midpoint 后需要等待多久才会被加入到 LRU 列表的热端。

可以通过 `show engine innodb status;` 查看一些统计信息：
- Database pages：LRU 列表中页的数量
- pages made young：LRU 列表中页移动到前端的次数
- Buffer pool hit rate：缓冲池命中率（100% 理想，低于 95% 可能需要关注是否全表扫描污染 LRU 列表）

## Pool 的主要空间

读缓存对性能影响更大（多数数据库读多写少）。读缓存主要包含索引页和数据页。如果要读取的数据不在 pool 中，则从磁盘读入，读到的新页通常放到 pool 的 3/8 位置，后续再决定是否放到 LRU 列表头部。最小单位是页（innodb 默认 16KB），哪怕只读一条记录也会加载整个页。如果是顺序读，下一条记录很可能就在同一个页中，从而命中缓存。

## 插入缓冲（Insert Buffer）

Insert Buffer 是 Buffer Pool 的一部分，用来缓存 insert 操作对二级索引（非聚簇索引）的修改。直接每次把插入写入 B+Tree 的二级索引会导致大量随机读取，尤其当存在多个二级索引时，插入会变慢。Insert Buffer 用于合并这些对同一页的操作，减少随机 IO。

使用 Insert Buffer 的前提：
1. 索引是二级索引（secondary index）
2. 索引不是 UNIQUE（非唯一索引）

注意：索引不能是 UNIQUE，因为插入缓冲时不会去查询索引页判断唯一性；如果查询了，就会产生随机读取，违背引入缓冲的目的。Insert Buffer 在写密集时会占用较多内存，默认最大可占用 1/2 的 Buffer Pool 空间，可通过相关参数控制（文中提到的 IBUF_POOL_SIZE_PER_MAX_SIZE 等）。

## 变更缓冲（Change Buffer）

新版 InnoDB 引入了 Change Buffer，功能类似 Insert Buffer，但不仅限于 insert，还对 update、delete 也进行缓冲。也就是说，所有 DML 操作（插入、更新、删除）都会先进入缓冲区做逻辑合并，之后再落地。可以通过参数 `innodb_change_buffering` 配置缓冲哪些类型的操作，可选值有 `inserts`、`deletes`、`purges`、`changes`、`all`、`none`。默认通常是所有操作都入 buffer。另有参数控制 Change Buffer 使用的最大内存比例（例如值 25 表示最多使用 1/4 的缓冲池空间）。

## Insert Buffer 原理

Insert Buffer 的数据结构是一棵 B+Tree（全局一棵），负责对所有表的二级索引进行插入缓存。在磁盘上，这棵树存放在共享表空间（通常为 ibdata1）。如果尝试用独立表空间（.ibd 文件）恢复表时出现 CHECK TABLE 错误，可能是因为该表的二级索引的数据还在 Insert Buffer 中没有刷新到表空间。可用 `REPAIR TABLE` 重建表上的所有二级索引。

Insert Buffer 在叶子节点里存放要刷到二级索引的信息：至少包括哪个表、哪个页面（page）或页面偏移（pageNo）以及要插入或修改的数据。内节点存放的是 search key（用于定位目标表和页）。

流程简述：
- 发起插入或修改时，判断目标二级索引页是否已在 Buffer Pool 中。
- 如果在 Buffer Pool 中，直接修改缓存中的页。
- 如果不在，则构造 search key 和要插入的数据，将记录插入到 Insert Buffer 的叶子节点中（缓冲起来）。

## 何时 Merge Insert Buffer

Insert Buffer 的数据会在以下情况下被合并（merge）到真正的二级索引中：
1. 二级索引页被读取到 Buffer Pool 时（即该页后来被访问到）
2. Insert Buffer 已无可用空间，需要刷出以腾出空间
3. Master Thread（后台主线程）定期将缓冲中的项刷入磁盘（有周期性的合并任务）

第一种情况直观：原本之所以写入 Insert Buffer，是因为目标索引页不在 pool 中；若后续该页被加载入 pool，则可顺便把缓冲的修改合并过去。第二种情况是资源约束触发刷出。第三种情况是 InnoDB 的后台合并机制。

## Checkpoint（redo log 与刷盘）

当数据页在 Buffer Pool 中被修改后，该页成为脏页（buffer 中的数据比磁盘新）。数据库需要按照一定规则将脏页刷写回磁盘。如果每次页发生变化就马上刷入磁盘，开销会非常大；同时若未刷入就发生宕机，脏页数据会丢失。

为保证可靠性，事务数据库通常采用 write-ahead log（WAL）策略：在事务提交时，先写重做日志（redo log），再修改页。发生故障时，通过 redo log 恢复数据。InnoDB 的增删改查流程大致如下：
- 增删改时先顺序写入 redo log（顺序写磁盘）
- 修改 Buffer Pool 中的页（若页不在 pool，则插入 Insert Buffer）
- 后台线程按照规则将缓冲中的数据刷入磁盘进行持久化
- 故障发生后通过 redo log 恢复

Checkpoint 的作用主要是将缓冲池中的脏页写回磁盘，保证 redo log 能够循环使用并限制其大小。Checkpoint 会决定每次刷多少、从哪里刷脏页、何时刷。触发 Checkpoint 的情况包括：
- 数据库关闭时，将所有脏页刷新到磁盘
- Master Thread 周期性（每秒或每 10 秒等）异步刷新一定比例的脏页到磁盘
- LRU 列表空闲页不足时，需要刷新部分来自 LRU 列表的脏页
- redo log 空间不足时，需要强制刷新脏页以保证 redo log 环形重用
- Buffer Pool 空间不足时，脏页太多需要刷新

## “两次写”（Double Write）

InnoDB 的 double write 是一个用于保证数据页可靠性的机制。其设计巧妙：在写数据页到磁盘之前，先将一批页顺序写入一个 doublewrite 区域（在共享表空间中），然后再把这些页写到各自的表空间位置。若写入过程中发生崩溃，可以根据 doublewrite 区域恢复部分页，避免页碎片或部分写入导致的数据损坏。这里不展开详细实现，感兴趣者可进一步查阅 InnoDB doublewrite 的实现细节。

---

到此，InnoDB 的 Buffer Pool、Insert Buffer/Change Buffer、LRU 策略、Checkpoint 与 redo log 等核心缓存与刷盘机制的基本原理已大致清晰。想深入了解的可以结合源码或官方文档、专门书籍进一步阅读。

命令参考示例：
- 查看 Buffer Pool 变量：`show variables like 'innodb_buffer_pool%';`
- 查看 Buffer Pool 页面状态：`show global status like '%innodb_buffer_pool_pages%';`
- 查看 InnoDB 引擎状态：`show engine innodb status;`