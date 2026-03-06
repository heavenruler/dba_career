# 搞懂 Redo Log 与 Binlog，就搞懂了 MySQL 数据安全的半壁江山

作者：大黄花鱼（云同学的技术圈）

在 MySQL 的世界里，数据安全和主从复制是其赖以生存的基石。但你是否想过，当服务器突然断电时，那些刚刚提交、还停留在内存中的数据是如何奇迹般地幸存下来的？这一切的背后，都离不开 MySQL 设计精妙的日志体系。接下来，我们将深入剖析这个体系中非常有意思的两位主角：Redo Log 和 Binlog。

## 01 MySQL 基本架构

图：MySQL 基本架构图

从整体上看，MySQL 可以分为 Server 层和存储引擎层两部分。

- Server 层
  - 连接器：连接管理、账号认证、权限获取
  - 查询缓存：缓存优化，命中则直接返回结果（注：不同版本中行为有差异）
  - 分析器：SQL 语法解析
  - 优化器：SQL 优化、选择索引并生成执行计划
  - 执行器：根据执行计划调用存储引擎
- 存储引擎层
  - 负责数据的存储和提取。存储引擎是插件式的，可选 InnoDB、MyISAM、Memory 等。其中 InnoDB 自 MySQL 5.5.5 起成为默认存储引擎。

## 02 MySQL 日志两大主角：Redo Log & Binlog

### 1. Redo Log（重做日志）

Redo Log 是 InnoDB 存储引擎特有的日志，存在于存储引擎层，是 MySQL 实现崩溃安全和事务持久性的基石。

职责：保证崩溃安全（crash-safe）  
磁盘 I/O 非常慢。为了提速，InnoDB 先修改内存中的缓冲池（Buffer Pool），后台线程在未来某个时刻将这些脏页异步地通过 fsync 刷回磁盘。若脏页尚未刷盘就发生断电，内存中的修改将丢失。Redo Log 采用 WAL（Write-Ahead Logging，预写式日志）理念：在数据页写入磁盘之前，必须先把这次操作的日志写入日志文件。当 InnoDB 修改内存中的数据时，会立即生成一条 Redo Log，并确保在事务提交（commit）时落盘。这样，即使脏页没来得及刷盘就崩溃，重启后 InnoDB 可以通过读取 Redo Log 的记录将数据“重做”一遍，恢复到崩溃前的状态。

Redo Log 特点
- 内容是物理的：记录“对哪个数据页的哪个偏移量做了什么修改”，属于物理日志，恢复时无需 SQL 解析，速度快。
- 大小固定，循环写入：Redo Log 文件组大小固定，像表盘一样循环使用，写到末尾回到开头覆盖旧记录。
- 引擎层日志：InnoDB 独有，其他存储引擎（如 MyISAM）没有。

Redo Log 的记录示例（伪）：“在表空间 X 的第 Y 个数据页的 Z 偏移量处，写入数据 'abc'”。这些日志是给 InnoDB 自己看的，描述物理层面的数据修改。崩溃后，InnoDB 可以像“录像回放”一样，按照 Redo Log 把数据页重做一遍，操作是幂等的，效率高。

### 2. Binlog（二进制日志）

Binlog 是 MySQL Server 层的日志，所有存储引擎（InnoDB、MyISAM 等）都可以使用。

职责：主从复制与时间点恢复  
Binlog 记录所有对数据库进行变更的逻辑操作，两个核心用途是：
- 主从复制（Replication）：主库将自己的 Binlog 实时传给从库，从库回放 Binlog 中的事件以实现数据同步。
- 时间点恢复（Point-in-Time Recovery）：在误操作后，可先用全量备份恢复到某个时间点，再用 Binlog 回放该时间点之后的操作，实现精确恢复。

Binlog 特点
- 内容是逻辑的：记录操作的“逻辑意图”。
  - Statement：记录原始 SQL 语句；
  - Row：记录每一行数据变更前后的值。
- 无限大小，追加写入：Binlog 文件一直追加写入，达到一定大小后滚动到新文件，不会覆盖旧记录。
- 服务层日志：属于 MySQL Server 层，与具体存储引擎无关。

Statement 示例：UPDATE my_table SET name = 'B' WHERE id = 1;  
Row 示例：记录 "表 my_table 中 id=1 的行，name 字段从 'A' 变为 'B'"。Binlog 是给人和从库看的，描述的是操作意图。

### 3. 区别比较

| 特性 | Redo Log | Binlog |
|---|---:|---:|
| 主要职责 | 崩溃安全（Crash Safety） | 主从复制、时间点恢复 |
| 所属层级 | 存储引擎层（InnoDB） | 服务层（Server-level） |
| 日志内容 | 物理（数据页变更） | 逻辑（SQL 语句或行变更） |
| 写入方式 | 循环写入（大小固定） | 追加写入（可滚动，保留历史） |
| 是否实现 WAL | 是（保证持久性的基础） | 否 |

## 03 执行一条 SQL 更新，到底发生了什么？

### 1. 两阶段提交（Two-Phase Commit, 2PC）

理解 MySQL 的数据更新过程，关键在于两阶段提交（2PC）。2PC 保证主库 crash-safe 和主从数据一致性。下面以一个 UPDATE 语句为例，演示 Redo Log 与 Binlog 如何被协调。

假设执行：
```sql
UPDATE users SET age = 18 WHERE id = 1;
```

执行流程（简化）：
1. 用户发起 UPDATE。
2. MySQL 执行器调用 InnoDB 引擎接口执行数据更新。
3. 写入 Redo Log，标记为 prepare（第 1 阶段 - Prepare）：
   - InnoDB 去 Buffer Pool 查找 id=1 的数据行，若不在则从磁盘加载。
   - 在 Buffer Pool 中直接修改该行，相关数据页变为脏页。
   - 生成对应的 Redo Log，并写入 Redo Log Buffer。
   - 当用户执行 COMMIT 时，InnoDB 确保将事务相关的 Redo Log 刷到磁盘，并在 Redo Log 中将事务标记为 prepare。此时 InnoDB 告诉执行器“我已准备就绪，可以提交”。
   - 即使 MySQL 崩溃，由于 Redo Log 有 prepare 状态，数据可以被恢复（但恢复时是否提交需要看 Binlog 的状态）。
4. 执行器写 Binlog（第 2 阶段 - Commit 的一部分）：
   - 将 UPDATE 操作（取决于 binlog_format）写入 Binlog Cache。
   - 将 Binlog Cache 刷到磁盘上的 Binlog 文件。
   - Binlog 成功落盘后，执行器调用 InnoDB 接口继续下一步。
5. Redo Log 变成 commit 状态（第 2 阶段 - Commit 完成）：
   - InnoDB 在 Redo Log 中写入 commit 标记，表示事务已完成。
   - 到此，事务才算完整、持久地完成，MySQL 向客户端返回成功。

这个流程其实就是 MySQL 内部的一种简化的两阶段提交：先让存储引擎准备（prepare），然后写服务端的 Binlog，最后让存储引擎完成 commit。

### 2. 两阶段提交如何保障一致性？

概括事务提交流程：
1. 用户执行 COMMIT。
2. InnoDB 准备提交：将修改写入 Redo Log，并标记为 prepare 状态。
3. MySQL Server 写入 Binlog。
4. InnoDB 完成提交：在 Redo Log 中将事务标记为 commit。

现在考虑崩溃发生在不同时间点的影响：

场景 A：在第 3 步（写 Binlog）之前崩溃  
- 状态：Redo Log 有事务记录，但 Binlog 没有。  
- 恢复：重启后 InnoDB 发现该事务未被 commit，会回滚它。数据和 Binlog 都一致（都没有该事务）。

场景 B：在第 3 步成功之后，第 4 步（InnoDB commit）之前崩溃  
- 状态：Binlog 已记录事务，但 InnoDB 仍处于 prepare，尚未最终 commit。  
- 如果没有 2PC：重启后 InnoDB 会回滚该事务，导致数据库数据与 Binlog 不一致。从库若基于 Binlog 执行该事务，会产生主从不一致问题。

2PC 的恢复逻辑：
- MySQL 重启后，InnoDB 扫描所有处于 prepare 状态的事务。对于每个 prepare 状态的事务，InnoDB 用事务唯一标识（XID）去 Binlog 中查找：
  - 若在 Binlog 中能找到该事务记录，说明 Binlog 已写入，InnoDB 必须完成该事务的提交（roll forward），以保证数据和 Binlog 一致。
  - 若在 Binlog 中找不到该事务记录，说明 Binlog 未写入，InnoDB 必须回滚该事务（roll back）。
通过这个机制，InnoDB 使用 Redo Log 的 prepare 状态作为一个“中间协调点”，确保无论何时崩溃，InnoDB 数据和 Binlog 日志都能恢复到一致的状态。

## 04 Q & A

Q: Binlog 也记录了所有操作，并且有位点（position）。为什么 Binlog 没有 crash-safe 的能力？  
A: 单独依靠 Binlog 无法做到灾难恢复，主要因为两个致命缺陷：性能和正确性。

致命缺陷一：性能灾难（用“逻辑”恢复太慢）  
- Binlog 的恢复（理论上）需要从上一个检查点开始，逐条重新执行 Binlog 里的 SQL 或行变更事件。每条操作都要经过 SQL 解析、优化器生成执行计划、索引扫描/表扫描、加锁与执行。如果崩溃前对同一行做了大量更新，恢复时必须把这些更新完整地再执行一遍，极其缓慢，可能需要数小时，这在生产环境不可接受。
- Redo Log 的恢复则记录物理页的变化，恢复操作是“把 A 数据页的第 X 个字节改成 B”。无需 SQL 解析，采用顺序 I/O，且操作幂等（做多少遍都是同样结果），速度非常快。

致命缺陷二：正确性灾难（无法区分“已落盘”和“未落盘”）  
- Binlog 不知道 InnoDB 内部 Buffer Pool 的持久化状态。InnoDB 修改数据先写 Buffer Pool（脏页），后台在合适时机刷回磁盘。崩溃瞬间，部分脏页可能已刷盘、部分尚在内存。
- 举例说明：
  - 场景 1（顺序更新）：T1: UPDATE users SET age = 18 WHERE id = 1; T2: UPDATE users SET age = 35 WHERE id = 1; 两个事务都提交并写入 Binlog，但在崩溃时 T1 的脏页已刷盘、T2 的脏页尚在内存。用 Binlog 恢复会先执行 T1（磁盘上已是 18，重复执行可能无害但浪费），再执行 T2（恢复成功）。
  - 场景 2（主键冲突）：T3: INSERT INTO users (id, name) VALUES (100, 'Dylan'); T3 已提交并写入 Binlog，且脏页已刷盘。重启时，用 Binlog 恢复会再次执行 INSERT，导致主键冲突错误，恢复过程可能中断。
- 结论：Binlog 作为 Server 层日志，不知道哪些修改已从内存持久化到磁盘、哪些未持久化。强行仅用 Binlog 恢复会导致重复执行已经落盘的操作，从而引发错误（如主键冲突）和数据不一致，最终使恢复失败。

（结束）

关于作者：云同学的技术圈，专注云原生、中间件、SRE、DevOps 等领域的技术分享。