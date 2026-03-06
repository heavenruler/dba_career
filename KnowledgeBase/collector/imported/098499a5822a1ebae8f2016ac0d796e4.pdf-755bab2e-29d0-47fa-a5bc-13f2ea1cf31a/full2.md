# 关于 MySQL checkpoint
作者：海东潮

## I. Checkpoint 的作用
Checkpoint 的主要作用是缩短数据库的恢复时间。缓冲池（buffer pool）中的页面（page）与磁盘上的页面不是时刻一致的：当页面被修改后不会马上刷到磁盘，而是由 checkpoint、flush 机制、以及重做日志（redo log）共同保证故障恢复时的数据一致性。

举例说明 checkpoint / LSN 的作用：

步骤：
1. 一个 page 被读到 buffer pool 时，它的 LSN（标记修改位置的数值，下面会详细说明）是 100。这个 page 被修改后，它的 LSN 变成 130。
2. 另一个 page 之前进 buffer pool 时 LSN 是 50。前面那个 page 被修改之后，它也被修改，它的 LSN 变成 140，同时这个 140 的 LSN 写入了 redo log。
3. 关键一步，假设 LSN 为 130 的 page 被刷到磁盘（什么时候刷也是个学问，这里不细述），而 LSN 为 140 的 page 还没刷，磁盘上保存的还是老版本。此时发生宕机。
4. 重启时，数据库会从磁盘上保存的 checkpoint 位置（例如 130）开始读 redo log，一直回放到 140，这样没被刷到磁盘的那个 page 就能恢复到宕机前的状态。

要点总结：
- LSN 实际上以字节数为单位（即你对页的修改产生了多少字节的日志，LSN 就加多少）。LSN 是单调递增的，通常用 8 字节保存。
- 每个 page 的 LSN 记录与 redo log 的 LSN 配合，保证 redo 回放时可以把磁盘上的页面恢复到 buffer pool 的版本。
- checkpoint 不需要实时更新到磁盘；一般由后台线程（master_thread 或 page_cleaner_thread）周期性更新。checkpoint 稍微“滞后”一点没关系，只会多回放一点 redo log。

回滚（undo）方面：
- 回滚不是通过 redo 完成的；恢复阶段先把页面“前滚”到某个位置（通过 redo），事务尚未提交的操作仍然活跃，这些事务通过 undo log 进行回滚，undo 的内容在需要时也会被 redo 恢复并最终被 purge 回收。

## II. LSN（Log Sequence Number）——日志序列号
LSN 用来描述日志的位置，并用于保存 checkpoint，表示当前已刷新到磁盘的位置。

- 每个 page 在 header 中有 LSN（实际 InnoDB 中页里会保存两个 LSN 字段：NEWEST_MODIFICATION 和 OLDEST_MODIFICATION）。
  - NEWEST_MODIFICATION：页最近一次修改完成后的 LSN（最新修改）。
  - OLDEST_MODIFICATION：页第一次被修改时的 LSN（第一次修改时记录的值）。
- 整个 MySQL 实例也有一个全局的 checkpoint LSN（记录在 redo log 的第一个 2K 块里，用来保存 checkpoint，不会被覆盖）。
- redo log 里也保存 LSN 信息。

示例：查看 INNODB_BUFFER_PAGE_LRU 表结构（用于说明页里保存的字段）：
```
[root@172.16.0.10] [(none)]> desc information_schema.INNODB_BUFFER_PAGE_LRU;
+---------------------+---------------------+------+-----+---------+-------+
| Field               | Type                | Null | Key | Default | Extra |
+---------------------+---------------------+------+-----+---------+-------+
| POOL_ID             | bigint(21) unsigned | NO   |     | 0       |       |
| LRU_POSITION        | bigint(21) unsigned | NO   |     | 0       |       |
| SPACE               | bigint(21) unsigned | NO   |     | 0       |       |
| PAGE_NUMBER         | bigint(21) unsigned | NO   |     | 0       |       |
| PAGE_TYPE           | varchar(64)         | YES  |     | NULL    |       |
| FLUSH_TYPE          | bigint(21) unsigned | NO   |     | 0       |       |
| FIX_COUNT           | bigint(21) unsigned | NO   |     | 0       |       |
| IS_HASHED           | varchar(3)          | YES  |     | NULL    |       |
| NEWEST_MODIFICATION | bigint(21) unsigned | NO   |     | 0       |       |
| OLDEST_MODIFICATION | bigint(21) unsigned | NO   |     | 0       |       |
| ACCESS_TIME         | bigint(21) unsigned | NO   |     | 0       |       |
| TABLE_NAME          | varchar(1024)       | YES  |     | NULL    |       |
| INDEX_NAME          | varchar(1024)       | YES  |     | NULL    |       |
| NUMBER_RECORDS      | bigint(21) unsigned | NO   |     | 0       |       |
| DATA_SIZE           | bigint(21) unsigned | NO   |     | 0       |       |
| COMPRESSED_SIZE     | bigint(21) unsigned | NO   |     | 0       |       |
| COMPRESSED          | varchar(3)          | YES  |     | NULL    |       |
| IO_FIX              | varchar(64)         | YES  |     | NULL    |       |
| IS_OLD              | varchar(3)          | YES  |     | NULL    |       |
| FREE_PAGE_CLOCK     | bigint(21) unsigned | NO   |     | 0       |       |
+---------------------+---------------------+------+-----+---------+-------+
```

从 `SHOW ENGINE INNODB STATUS` 中常见的 LSN 信息示例及含义：
```
Log sequence number 15151135824      -- 当前内存中最新的 LSN
Log flushed up to 15151135824        -- redo 已经刷到磁盘的 LSN（redo file）
Pages flushed up to 15151135824      -- 最后一个刷到磁盘上的页的 NEWEST_MODIFICATION
Last checkpoint at 15151135815       -- 最后一个刷到磁盘上的页的 OLDEST_MODIFICATION（checkpoint 位置）
```
注意：
- “Log sequence number”和“Log flushed up to”两个 LSN 可能不同：redo log 的写入也是先写入内存再刷到磁盘的，运行过程中“Log sequence number”通常 >= “Log flushed up to”。
- flush list（刷页列表）是根据页第一次被修改时的 LSN（即 OLDEST_MODIFICATION）来组织的：当一个页第一次进入 flush list 时会记录该页的第一次修改的 LSN，后续该页再被修改不会改变它在 flush list 中的位置。这是为了保证在刷页与恢复时 redo 的连续性。

示例分析（flush list 与恢复）：
- Page A 第一次修改后 LSN 是 120（写入全局 LSN）；后续 Page B 被更新到 140；接着 Page A 再更新到 160。此时如果发生宕机，而 flush list 中记录的是 Page A 的第一次修改 LSN（120），当从 checkpoint（120）开始恢复时，数据库会检测页的 LSN。如果磁盘上 Page 的 LSN 小于实例的 LSN，会回放 redo；如果 page 的 LSN 大于实例的 LSN，数据库会跳过该页的恢复（因为该页已经是更新的版本）。
- 设计如此是为了保证 redo 的连续性，不会漏回放需要的日志区间。

有关 checkpoint 的一些重要点：
- checkpoint 不需要实时刷到磁盘，通常由后台线程（master_thread 或 page_cleaner_thread）大约每秒更新一次 checkpoint。
- 回滚的处理不是通过 redo 来完成的：恢复后活跃事务使用 undo log 回滚，undo 也会被适时回放和回收。
- page 的 NEWEST_MODIFICATION 与 OLDEST_MODIFICATION 两个字段一起配合 checkpoint 与 flush list 的管理。

## III. Checkpoint 分类
- Sharp Checkpoint
  - 将所有脏页都刷新回磁盘，通常会导致系统在刷新期间短暂挂起（hang）。InnoDB 在关闭时会使用这种方式（例如 innodb_fast_shutdown=0 时会尽量将脏页刷回）。
- Fuzzy Checkpoint
  - 将部分脏页刷新回磁盘，对系统影响较小。Fuzzy checkpoint 是 InnoDB 常用的方式，checkpoint 可以略微滞后，恢复时只需回放多一点的 redo。
- Async/Sync Flush Checkpoint（异步/同步刷盘）
  - 与 redo log 重用等存在关联，涉及刷盘策略与线程模型的选择。

相关参数：
- innodb_fast_shutdown = {1|0}：控制关闭时是否使用快速关闭（0 表示不快速，尽量刷干净）。
- innodb_io_capacity：控制后台每秒最多刷新的页能力，最小值为 100，通常与 IOPS 相关。SSD 可设高一些（例如 4000-8000），SAS 磁盘可设较低（例如 800），具体应依据硬件实际 IOPS 调整。
- innodb_max_dirty_pages_pct：当脏页比例超过该阈值时，会强制刷页，避免脏页过多导致问题。

## IV. 什么时候刷 dirty page（脏页刷写）
- 早期（5.5 以前）主要由 master_thread 在 flush_list 中进行刷新。现在更多由 page_cleaner_thread 负责（page cleaner 会周期性从 flush_list 拉取脏页并刷写）。
- 刷新的扫描深度由 innodb_lru_scan_depth 控制：默认每个 buffer pool 探测 1024 个尾部页面，探测到的脏页会被一起刷掉。总量 = innodb_lru_scan_depth * buffer_pool_instances。注意不要把该值设得超过 innodb_io_capacity / innodb_buffer_pool_instances，否则不合理。
- 当系统需要回收空闲页时（free list 为空且要分配页），LRU 会把尾部（可能为脏页）的页面淘汰给需要使用的线程，这时也需要刷新这些脏页。
- page_cleaner_thread 定期向 flush_list 要脏页并执行刷写；但并不是只有 flush_list 的页面会被刷，LRU 探测也会触发刷写。

常见问题与技巧：
- flush_list 的组织是按页第一次进入时的 LSN（OLDEST_MODIFICATION），因此 page 多次更新不会更改在 flush_list 的位置。
- checkpoint 不需要与每次页面更新完全同步，允许略微滞后以减少 I/O 压力。
- 恢复过程中，如果磁盘上 page 的 LSN 大于实例的 LSN，则不会对该页进行恢复（跳过）；恢复会保证 redo 回放的连续性。
- 关于参数设置：innodb_io_capacity、innodb_lru_scan_depth、innodb_max_dirty_pages_pct 等需要根据硬件（SSD/SAS）和负载进行调优。

小结（tips）：
- LSN 是以字节数计的单调递增数，用来定位 redo 日志和页面修改位置。
- 每个页保存 NEWEST_MODIFICATION（最新修改）和 OLDEST_MODIFICATION（第一次修改）两个 LSN，用于 flush list 的组织和 checkpoint。
- Checkpoint 通过保存一个实例级别的 LSN，配合 redo log 的回放，保证故障恢复时数据一致性。
- 合理配置 innodb_io_capacity、innodb_lru_scan_depth、innodb_max_dirty_pages_pct 可以平衡 I/O 与恢复时间。
- page_cleaner_thread 现在是刷脏页的主力线程，但在内存压力或 free list 空时，LRU 探测也会触发强制刷写。

（完）