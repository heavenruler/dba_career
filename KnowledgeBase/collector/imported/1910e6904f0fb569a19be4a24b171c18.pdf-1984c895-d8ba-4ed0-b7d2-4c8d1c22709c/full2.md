# MySQL 中的 InnoDB Buffer Pool

作者: jchen104

本文深入探讨 MySQL 的 InnoDB Buffer Pool，包括其内部结构、插入缓冲与变更缓冲的作用、数据合并的规则以及 redo log 的重要性。通过对缓冲池的淘汰算法和状态查看的分析，帮助理解如何优化数据库性能并确保数据一致性。

前言
在之前的文章《MySQL 内存相关知识介绍》中，我们对 MySQL 的内存有了初步了解，文末提到了 InnoDB Buffer Pool。本文将更深入地介绍它，以及与之相关的插入缓冲（insert buffer）与变更缓冲（change buffer）。

目录
- 一、InnoDB Buffer Pool 的内部结构
- 二、插入缓冲（insert buffer）与变更缓冲（change buffer）
- 三、数据合并（merge buffer）
  - 写回规则
  - redo log
- 四、补充
  - 淘汰算法
  - 状态查看

## 一、InnoDB Buffer Pool 的内部结构

InnoDB Buffer Pool 的组成包括数据页（data pages）、索引页（index pages）、插入/变更缓冲、锁信息及其它管理结构。类似操作系统的分页机制，MySQL 以页（page）为单位读写数据：当发生缺页时，从磁盘读取对应的数据页并将整个页加载到内存（基于局部性原理，相邻数据也很可能会被访问），从而减少磁盘随机读，提高读取性能。

查看 Buffer Pool 大小：
```sql
show variables like 'innodb_buffer_pool_size';
```

查看 Buffer Pool 中页的使用情况：
```sql
show global status like '%innodb_buffer_pool_pages%';
```

常见状态项说明：
- Innodb_buffer_pool_pages_data：缓冲池中包含数据的页数，包括脏页（单位：page）。
- Innodb_buffer_pool_pages_dirty：缓冲池中脏页数（单位：page）。
- Innodb_buffer_pool_pages_flushed：刷新页请求的次数（单位：page）。
- Innodb_buffer_pool_pages_free：剩余空闲页数（单位：page）。
- Innodb_buffer_pool_pages_misc：被用于管理用途或 hash index 而不能用于普通数据页的页数（单位：page）。
- Innodb_buffer_pool_pages_total：缓冲池页总数（单位：page）。

在数据库专用服务器上，通常建议将 InnoDB Buffer Pool 设置为系统内存的 70%–80%。设置过小会影响性能，设置过大可能导致操作系统 swap，从而同样影响性能。

## 二、插入缓冲（insert buffer）与变更缓冲（change buffer）

MySQL 的索引基于 B+ 树结构。对于 B+ 树，每次更新叶子节点可能涉及扩容、校验、寻址等多步操作，因此频繁插入会带来大量 I/O。对于主键索引（聚簇索引），插入通常是顺序的，影响较小；但对二级索引（非聚簇索引），每次插入都需要维护这些 B+ 树，可能导致随机读取。二级索引越多，插入越慢。

为减少这种随机 I/O，MySQL 引入了 insert buffer：当要修改的二级索引页不在缓冲池中时，不立即载入索引页进行修改，而是把修改记录先写入 insert buffer（即 change buffer 的一部分），并在合适时机合并到索引页。这样可以聚合多个操作，减少磁盘随机读写，提高性能。

change buffer 是对 insert buffer 的扩展，不仅插入（insert）会被缓存，update、delete 对二级索引的修改也可以缓存。也就是说，对所有 DML 操作的二级索引修改，若索引页不在内存中，都会先进入变更缓冲，再按规则写回到索引页。

可以查看并设置 change buffer 的模式（all、insert、none）：
```sql
show variables like 'Innodb_change_buffering';
```

查看 change buffer 最大占比（表示 change buffer 最多能占用 Buffer Pool 的百分比）：
```sql
show variables like 'Innodb_change_buffer_max_size';
```

## 三、数据合并（Merge buffer）

虽然变更缓冲能减少即时的磁盘 I/O，但最终这些改动需要写回到索引页并持久化到磁盘。下面是写回与合并的主要规则与机制。

### 写回规则
1. insert buffer 已无可用空间时，会触发合并和写回。
2. 当某个二级索引页被读取到内存中时，如果该索引页在 change buffer 中有对应的改动，MySQL 会把这些改动从 change buffer 中取出并合并入索引页（注意：此时合并是发生在内存中的，把变更写到索引页的内存拷贝，而索引页写到磁盘是更晚的事情）。
3. 后台线程定期将 change buffer 中的数据写回磁盘。MySQL 有专门的后台（master）线程处理定期合并与写回，防止内存中未合并的改动无限增长。

### redo log
由于 Buffer Pool 中的页可能是脏页（内存与磁盘不一致），为保证事务的持久性与崩溃恢复，MySQL 使用 redo log 记录对数据页的修改过程。事务进行时，会先顺序写入 redo log，然后才在内存中修改数据页（或变更缓冲）。当脏页最终写回磁盘后，相应的 redo log 可以被重用或覆盖。

如果服务器宕机，尚未写回磁盘的内存改动会丢失，但可通过 redo log 恢复。这保证了即使缓冲池中的数据未持久化，数据一致性仍能被维护。

## 四、补充

### 1. 淘汰算法
操作系统中常用 LRU（Least Recently Used）算法进行页面替换。InnoDB Buffer Pool 也采用类似的机制，但有一些差异：从磁盘读取的新页并不会直接放到 LRU 队首，而是放在一个称为 midpoint 的位置，该位置由参数 innodb_old_blocks_pct 控制，默认值使新页放置在距尾端约 37% 的位置。midpoint 之后的区域被视为 old 列表，之前为 new 列表，简单理解 new 列表的页更活跃。

之所以不把新载入的页直接放在头部，是避免偶发访问把非热点页推到队首，从而污染真正的活跃页。

控制 midpoint 的参数：
```sql
show variables like 'Innodb_old_blocks_pct';
```

还有一个参数控制页读取到 midpoint 后，需要等待多久（毫秒）才会被加入到 LRU 的头部：
```sql
show variables like 'Innodb_old_blocks_time';
```

### 2. 状态查看
可以使用以下命令查看 InnoDB 的运行状态与缓冲池的使用、命中情况：
```sql
show engine innodb status\G
```
在输出中，有些字段特别有用：
- Pages made young：有多少页从 old 区移动到 new 区（表明页变为“年轻”）。
- Pages made not young：由于 innodb_old_blocks_time 的设置导致页没有从 old 区移到 new 区的次数。
- Buffer pool hit rate（通过相关状态项计算）：表示缓冲池命中率，通常不应低于 95%；如果低于 95%，需要检查是否有全表扫描或其他导致 LRU 污染的操作。

备注：常用的与 Buffer Pool 相关的重要系统变量包括 innodb_buffer_pool_size、innodb_buffer_pool_instances、innodb_buffer_pool_chunk_size 等。这些参数影响 Buffer Pool 的大小、分片与调整策略，根据具体业务负载与内存大小进行配置与优化。

结束语
本文为学习总结，可能有不完善之处，欢迎指正与补充。