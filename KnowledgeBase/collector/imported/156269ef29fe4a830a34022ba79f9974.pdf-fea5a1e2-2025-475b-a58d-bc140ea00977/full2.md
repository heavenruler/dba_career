# TiFlash 的列式存储引擎：Delta Tree 设计与实现

作者：韦万  
产品技术解读 · 2020-08-06

目录
- 引言
- 整体架构
- Segment 与 2-level LSM 结构
  - Pack
  - Delta Layer
  - Stable Layer
- 存储方式
  - PageStorage
  - DTFile
- 写优化
  - Delta Cache
  - 持续写入能力
- 读优化
  - 减少读放大
  - 读索引（Delta Index）
- Delta Tree vs LSM Tree
- 如何处理事务
- 结语

引言
TiDB 是一款分布式 HTAP 数据库，目前有两种存储节点：TiKV（行式存储，适合 OLTP）和 TiFlash（列式存储，擅长 OLAP）。TiFlash 通过 Raft 协议从 TiKV 实时同步数据，延迟毫秒级，支持实时同步 TiKV 的数据更新与在线 DDL。我们将 TiFlash 作为 Raft Learner 融入 TiDB 的 Raft 体系，上层通过 TiDB 统一查询，使 TiDB 成为真正的 HTAP 数据库。

整体架构
为了在列式存储上支持实时更新，TiFlash 研发了列存引擎 Delta Tree。Delta Tree 借鉴了 B+ Tree 与 LSM Tree 的设计思想：按主键进行 range 分区，分区后的数据块称为 Segment；Segment 内部采用两层结构，分别是 Delta Layer（相当于 L0）和 Stable Layer（相当于 L1）。分区与两层结构的设计能降低复杂度并带来读写性能的平衡。

Segment 与 2-level LSM 结构
Segment
- Segment 的切分粒度通常在 150 万行左右，远超传统 B+ Tree 的 leaf node。单机上 Segment 数量通常在 10 万以内，因此可以把 Segment 的元信息放在内存，简化实现。
- Segment 支持 split、merge。初始状态，一张表只有一个 range 为 [-∞, +∞) 的 Segment。
- Segment 内部采用类似 LSM Tree 的两层结构：Delta Layer 和 Stable Layer。层数越少，写放大越小。默认配置下，理论写放大（不考虑压缩）约为 19 倍；由于列存对压缩友好，实际生产中常见写放大低于 5 倍。

Pack
- Segment 内部的数据管理单位是 Pack，通常一个 Pack 包含 8K 行或更多。
- Pack 的 schema 可能随 DDL 变化而不同。Pack 包含各列数据（一维数组），此外还包含 version 列（事务的 commit_ts，用于 MVCC）和 del_mark 列（布尔类型，表示一行是否被删除）。
- 将数据按 Pack 划分，便于以 Pack 为 IO 单位并做粗糙索引（如 Min-Max），提升 Scan 性能。
- Pack 内部数据按复合字段升序排列，与 TiKV 的数据顺序一致，使用 (PK, version) 排序，以便 TiFlash 无缝接入 TiDB 集群并复用 Region 调度机制。

Delta Layer
- Delta Layer 类似 LSM Tree 的 L0，是 Segment 的增量更新层。最新的数据首先写入 Delta Cache（内存结构），写满后 flush 到磁盘上的 Delta Layer。
- 当 Delta Layer 写满后，会与 Stable Layer 做一次合并（Delta Merge），生成新的 Stable Layer。

Stable Layer
- Stable Layer 相当于 LSM Tree 的 L1，存放绝大部分数据，由只读文件 DTFile 存储。一个 Segment 通常只有一个 DTFile。
- Stable Layer 由 Pack 组成，数据以 (PK, version) 全局有序；Delta Layer 只保证 Pack 内有序，因为写入时不同 Pack 之间可能有 overlap。
- 当 Segment 总数据量超过配置上限，会在 Segment range 中点 split；相邻 Segment 很小则可能 merge。

存储方式
Delta Layer 与 Stable Layer 在磁盘上的存储方式不同：Delta Layer 使用 PageStorage（PS），Stable Layer 使用 DTFile。

PageStorage
- PageStorage 类似对象存储，管理数据块 Page（bytes）。用于存储 Delta Layer 的 Pack 数据及 Segment 元数据。
- PS 支持 Page Get/Insert/Delete/Update，并支持将多个操作合并为一个 WriteBatch 以实现原子写入。Page 存在 PageFile 中，一个 PageFile 可包含多个 Page。
- 内存中维护 PageMap 元数据，用于定位 Page 的 PageFile 与偏移，从而支持随机读取。
- PS 可能有一个或多个 Writable PageFile，写满后变为 Readonly。更新时通过在 Writable PageFile 写入新 Page 并更新内存 PageMap 指向实现所谓的“更新”。
- 背景 GC 线程合并低利用率的 PageFile，回收空间并提升读取效率。
- Delta Layer 的 Pack 会序列化为 Page 存储在 PS 中；PS 支持只读 Page 的一部分数据，以应对只扫描部分列的查询。

DTFile
- DTFile 在文件系统上以文件夹形式存在，文件夹内部采用标准列存格式：每个列对应一个文件。DTFile 是只读并以顺序读取为主，适合用来存储 Stable Layer。
- DTFile 在三种情况下生成：Delta Merge、Segment Split、Segment Merge。
- 选择 DTFile 存 Stable Layer、PS 存 Delta Layer 的原因包括：
  - DTFile 支持列级别 IO 合并，适合 Stable Layer 的读取与生成模式。
  - 将 Delta Layer 用 DTFile 存储会产生大量小文件；PS 可以合并多个 Page，避免小文件问题。
  - PS 支持随机读取，契合 Delta Layer 的读取模式。
  - 写入时，DTFile 需要打开与列数等量的文件，写入多个 Pack 时可以做列级 IO 合并；Delta Layer 常一次只写一个 Pack，用 PS 可把 Pack 的所有列序列化为 Page 一次性写入以减少 IO 次数。

写优化
TiFlash 面向实时 OLAP 场景，需要同时支持高频小量写入（与 TiKV 的更新保持实时同步）和批量导入写入。针对这两类场景做了不同优化。

Delta Cache
- 为缓解高频写入的 IOPS 压力，Delta Tree 在 Delta Layer 设计了内存 cache，称为 Delta Cache。更新先写入 Delta Cache，写满后再 flush 到磁盘。
- 批量写入则直接写入磁盘，无需经过 Delta Cache。
- 为了保证数据安全性，TiFlash 利用 Raft log 作为 WAL：更新先写入 Raft log，等待多数副本确认后再 apply 到状态机（存储引擎）。因此在 flush 之后才更新 raft log applied index，从而避免数据丢失风险。

持续写入能力
- 与 LSM Tree 类似，Delta Tree 通过后台线程持续把 Delta Layer merge 到 Stable Layer（Delta Merge），以控制 Delta Layer 的大小并保持读性能。
- Delta Merge 是写放大的主要来源；写放大取决于 Segment 平均大小与 Delta 层阈值的比值。Delta Merge 频率越高，写放大越大；Delta Layer 比例越小，读性能越好。
- 为了在写入性能与读取性能之间取得平衡，TiFlash 在极端写入高峰时会动态限制写入速度并减小 Delta Merge 频率，降低写放大，避免出现 write stall（写阻塞）。这在一定程度上牺牲了部分读写性能，但改善了整体可用性和业务体验。

读优化
Delta Tree 的设计很多关键点是为了读加速：Segment 划分减少读放大，Segment 内的双层结构支持多种读优化策略。

读取 Scan 的主要耗时分为三部分：
A. 数据本身的读 IO 与解压缩耗时。  
B. 多路归并排序（如使用最小堆）本身的消耗。  
C. 多路归并后把数据 copy 到输出流的耗时。

减少读放大
- TiDB 集群的数据以 Region 为单位管理，Region 是逻辑分块；当 Scan 涉及大量 Region 时会产生读放大。Region 数据分布在越多文件，读放大越大。
- Delta Tree 通过 Segment 分区降低区内数据量和层数，从而减少读放大，优化 A 部分耗时。

读索引（Delta Index）
- 多路归并（B 部分）开销较大。针对重复扫描场景，Delta Tree 引入 Delta Index：第一次 Scan 完成后把多路归并产生的信息保存下来，下一次 Scan 可重复利用这些信息，仅处理增量部分。
- Delta Index 用一棵内存 B+ Tree 实现（作为类似二级索引的结构），叶子节点的 Entry 按 (PK, version) 升序排列。Entry 的初始设计包含 ((PK, version), is_insert, TupleId)。
- 为节省内存，设计进行了优化：
  - 可省略重复存放的 (PK, version)，因为可以通过 TupleId 从原始数据回溯得到。
  - TupleId 在 Stable Layer 中通常是连续递增的。对连续的 N 个 Stable Entry，可用 (TupleId, N) 进行压缩表示。
  - 将 Stable Layer 与 Delta Layer 的 TupleId 区分为 StableId 与 DeltaId，只在 Delta Index 中记录 Delta Layer 的数据并额外记录相邻 Delta Entry 之间插入了多少个 Stable Tuple。
- 最终 Entry 格式为 (is_insert, DeltaId, (StableId, N))。Entry 的总量与 Delta Layer 数据量成正比。通常 Delta Layer 数据占比很小（常在 3% 以内），因此内存开销可接受（例如单节点存放 100 亿数据估算大约需要数 GB 级内存）。
- 有了 Delta Index，Scan 可以快速把 Delta Layer 与 Stable Layer 合并为一个有序流。因为上次结果可以被下一次重复利用，归并的成本摊薄，从而优化了 B 部分耗时。
- 对于 C 部分，Delta Tree 能对连续的 Stable Layer 数据做批量 copy，节省 CPU。相较于传统 LSM Tree，Delta Tree 下层与上层数据量比通常更大，因此批量 copy 的效果更好。

Delta Tree vs LSM Tree
- TiFlash 起初尝试基于 LSM Tree 实现列存引擎，但发现读性能不足并存在其他问题，于是设计了 Delta Tree。
- 在多种数据规模和不同更新 TPS 下的 Scan 耗时对比中，Delta Tree 在大多数场景具有明显优势，这既得益于更好的 Scan 性能，也得益于支持粗糙索引（如 Min-Max）以避免读取无关数据。

如何处理事务
- 开启 TiFlash 副本的 TiDB 集群仍然支持事务，并保证与 TiKV 相同的隔离级别。TiFlash 只实时同步 TiKV 的已提交修改，在事务过程中不提供未提交数据的点查能力，因此避免了列存的弱点。
- Delta Tree 中每条数据都有 version 字段（commit_ts），查询时根据 query_ts 过滤得到符合条件的数据快照（version <= query_ts），实现 MVCC。
- TiDB 使用 Percolator 分布式事务模型，事务过程中需要锁。TiKV 将这些锁持久化到 RocksDB，但 TiFlash 的列存不适合高 TPS、低延迟的 K-V 持久化。TiFlash 的解决方案是将事务中未提交的部分放在内存，仅把已提交的修改写入 Delta Tree。为保障内存中未持久化数据的安全性：
  - 所有数据先落地到 Raft log；重启后可从 Raft log 恢复未持久化部分。
  - 内存状态（包括锁和未提交数据）会定期保存一份副本到磁盘，并推进 Raft log applied index；重启后从磁盘恢复副本到内存。

结语
线上业务系统与分析系统之间长期存在技术鸿沟，核心原因在于分析数据库通常难以实时更新。Delta Tree 列式存储引擎解决了这个问题，使列式存储在保持分析性能的同时支持实时更新。通过引入 TiFlash，TiDB 在同一数据库内集成了行存与列存，简化了实时业务数据分析流程：可以在单条 SQL 中同时使用行存与列存数据，并保证数据严格一致。在 TiDB 中启用 TiFlash 只需一条 SQL：

```sql
ALTER TABLE my_table SET TIFLASH REPLICA 1;
```

参考与延伸阅读
- 论文：“TiDB: A Raft-based HTAP Database”（可检索获取）