# 你真的理解 MySQL 的事务隔离吗？

作者：fliyu（邂逅Go语言） 2023-03-01，广东

提到事务，你很容易想到数据库的四个特性，即 ACID，也被称为事务的原子性、一致性、隔离性和持久性。这些特性确保了事务在数据库中正确执行，并保证数据的完整性和一致性。

- 原子性（Atomicity）：指一个事务是一个不可分割的单位，事务中的所有操作要么全部完成，要么全部不完成。如果事务执行过程中出现错误，事务将被回滚到最初状态，撤销所有更改，保证数据一致性。
- 一致性（Consistency）：指事务的执行结果必须使数据库从一个一致性状态变到另一个一致性状态。在事务执行过程中，数据的完整性约束不能被破坏。
- 隔离性（Isolation）：指在并发环境中，当多个事务同时执行时，每个事务都应该相互隔离、互不干扰，不会出现数据冲突等问题。
- 持久性（Durability）：指事务提交后，对数据的修改是永久性的，不会因为系统故障等原因造成数据丢失。数据库应保证事务所做的修改即使在系统故障时也能永久保存下来。

本文主要讲述其中的隔离性（Isolation）。

## 隔离级别

SQL 标准定义了四种事务隔离级别，从低到高分别是：读未提交（read uncommitted）、读提交（read committed）、可重复读（repeatable read）和串行化（serializable）。隔离级别越高，隔离程度越强，但性能通常越低。

- 读未提交（read uncommitted）：一个事务可以读取另一个未提交事务的数据（脏读）。
- 读提交（read committed）：只能读取到已提交的数据。一个事务提交后，它的更改才会被其他事务看到。
- 可重复读（repeatable read）：一个事务在执行过程中看到的数据总是与该事务开始时看到的数据一致。MySQL 默认隔离级别是可重复读。
- 串行化（serializable）：事务按顺序串行执行，后访问的事务必须等前一个事务执行完成才能继续执行。这是最高隔离级别，同时也是性能最差的。

不同隔离级别会带来不同的并发问题。下表总结了常见的三类问题（脏读、不可重复读、幻读）在各隔离级别下是否可能发生：

| 隔离级别     | 脏读 | 不可重复读 | 幻读 |
|--------------|------|------------|------|
| 读未提交     | 可能 | 可能       | 可能 |
| 读提交       | 不可能 | 可能     | 可能 |
| 可重复读     | 不可能 | 不可能   | 可能 |
| 串行化       | 不可能 | 不可能   | 不可能 |

## 什么是脏读、不可重复读、幻读？

- 脏读：指一个事务读取到了另一个事务已修改但未提交的数据。
- 不可重复读：指在同一事务中，多次读取同一数据，前后读取到的数据不同（例如第一次读到 1，第二次读到 2）。
- 幻读：指一个事务先后读取一个范围的数据，但两次读取到的记录数不同（例如第二次多出或少了一行记录），即同一查询返回了不同数量的行。

## 理解“读提交”和“可重复读”

下面通过一个示例说明读提交（Read Committed）和可重复读（Repeatable Read）的区别。

假设有两个事务 A、B，初始数据 v=1，按以下顺序执行：

1. A: begin;
2. B: begin;
3. A: select v from t;    -- 返回 1
4. B: select v from t;    -- 返回 1
5. B: update t set v = v + 1; -- 将 1 改为 2（但此时 B 未提交）
6. A: select v from t;    -- 返回 V1
7. B: commit;
8. A: select v from t;    -- 返回 V2
9. A: commit;
10. 最后查询 select v from t; -- 返回 V3

- 在读提交（read committed）隔离级别下：A 在步骤 6 看到的 V1 是 1，因为 B 的更新还未提交，只有在 B 提交后（步骤 7），其他事务才能看到 B 的更改。因此步骤 8、10 的值都是 2（V2=V3=2）。
- 在可重复读（repeatable read）隔离级别下：A 在事务开始时就生成了一个快照（snapshot），事务执行期间所有快照读都基于该快照，因此步骤 6 和步骤 8（V1、V2）都为 1，而在 A 提交后或事务外查询（步骤 10）才会看到 2（V3=2）。

总结逻辑区别：
- 在可重复读隔离级别下，只需在事务开始时创建一致性视图（快照），事务内的所有快照读都共享这个视图。
- 在读提交隔离级别下，事务内的每条语句在执行前都会创建一个新的视图（每条语句都看到最新已提交的数据）。

## 事务隔离的实现：MVCC（多版本并发控制）

MVCC 是 MySQL（InnoDB）等数据库实现事务隔离的一种方式。其基本思想是：通过为数据维护多个版本，使每个事务可以看到一个一致性的快照（snapshot），从而避免读写冲突带来的锁等待。

在 InnoDB 中，每行记录后会有两个额外的隐藏值来实现 MVCC：一个记录该行何时被创建（创建者事务 ID），另一个记录该行何时失效或被删除（某个事务的相关信息）。同时，InnoDB 使用 undo log 来保存旧版本的数据，从而可以回溯到历史版本。

MVCC 使用两个重要概念：
- 读取视图（read view）：每个事务的快照，定义了事务能看到哪些版本的数据。
- 版本链（version chain）：用于跟踪每行数据的历史版本，新版本会链接到旧版本，旧版本通过 undo log 可恢复。

读取方式分为两类：
- 快照读（snapshot read）：读取历史版本的数据，默认的 SELECT 语句就是快照读，这能够减少加锁开销。
- 当前读（current read）：读取数据库当前版本的数据（并可能加锁），能看到其他事务已提交的最新数据。插入/更新/删除语句（INSERT、UPDATE、DELETE）以及带锁的 SELECT（如 SELECT ... FOR UPDATE、SELECT ... LOCK IN SHARE MODE）均为当前读。

示例：
```sql
-- 快照读（默认）
SELECT * FROM t WHERE id = 1;

-- 当前读（加锁）
SELECT * FROM t WHERE id = 1 FOR UPDATE;
SELECT * FROM t WHERE id = 1 LOCK IN SHARE MODE;

-- 修改数据也是当前读
UPDATE t SET a = a + 1 WHERE id = 1;
```

## 可重复读下的事务隔离示例

MySQL 默认的隔离级别是可重复读。事务 A 启动时会创建一个视图，之后事务 A 在执行期间，即使其他事务修改了数据，事务 A 看到的数据仍然与事务开始时一致。

注意两种事务启动方式对快照的一些差异：
- 使用 `START TRANSACTION` 或 `BEGIN`：在第一条快照读语句执行完后才会生成该事务的一致性快照（即在执行首个快照读时创建视图）。
- 使用 `START TRANSACTION WITH CONSISTENT SNAPSHOT`：会立即生成一致性快照。

示例创建表和初始数据：
```sql
CREATE TABLE `t` (
  `id` int(11) NOT NULL,
  `a` int(11) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB;

INSERT INTO t(id, a) VALUES (1, 1), (2, 2);
```

下面分别演示两种启动方式的执行顺序（事务 A、B、C）及结果分析。

场景一：使用 `BEGIN`（快照在第一条 SELECT 后创建）

执行顺序（示例）：
1. A: begin;
2. B: begin;
3. C: update t set a = a + 1 where id = 1; -- C 已提交或执行完成前可见与否依赖时序
4. B: update t set a = a + 1 where id = 1;
5. A: select a from t where id = 1; -- 事务 A 的第一次查询
6. B: select a from t where id = 1;
7. B: commit;
8. A: commit;
9. 查询：select a from t where id = 1;

分析：
- 事务 A 第一次查询的值可能是 2，因为 `BEGIN` 在第一条 SELECT 执行完后才得到一致性快照，在该 SELECT 执行前，若事务 C 的 update 已完成并提交，则 A 能看到 C 的更改；而事务 B 的 update 在 A 的首个 SELECT 前若未提交，则 A 看不到 B 的更改。
- 事务 B 的第一次查询是当前读（因为 update 使用当前读），会看到最新提交的数据，包括事务 C 的 update。如果 B 的 select 是快照读，则会被事务 A 的视图覆盖（视具体执行语句而定）。

场景二：使用 `START TRANSACTION WITH CONSISTENT SNAPSHOT`（立即获得快照）

执行顺序（示例）：
1. A: START TRANSACTION WITH CONSISTENT SNAPSHOT;
2. B: START TRANSACTION WITH CONSISTENT SNAPSHOT;
3. C: update t set a = a + 1 where id = 1;
4. B: update t set a = a + 1 where id = 1;
5. A: select a from t where id = 1; -- 事务 A 的第一次查询
6. B: select a from t where id = 1;
7. B: commit;
8. A: commit;
9. 查询：select a from t where id = 1;

分析：
- 事务 A 在步骤 1 就得到了事务的一致性快照，因此在步骤 5 的查询中看到的是快照中的旧值（比如 1），不会看到后续事务 B、C 的更新。只有在 A 提交并结束后，外部查询才会看到最新值。

总结两种启动方式：
- 第一种（BEGIN）：一致性视图在执行第一个快照读语句时创建。
- 第二种（START TRANSACTION WITH CONSISTENT SNAPSHOT）：一致性视图在执行该命令时立即创建。

可重复读的核心是“一致性读”（snapshot read），事务在更新数据时使用当前读（current read）。如果当前读需要对当前记录上锁而该行已被其他事务占用，则需要等待锁释放。

## 事务隔离的底层原理（InnoDB 实现细节）

InnoDB 中每个事务在开始时会从事务系统申请一个唯一递增的事务 ID（transaction id）。每次对数据更新时，都会生成新的数据版本，并将该事务的 transaction id 赋给新版本（一般以 row trx_id 表示）；旧版本会保留，并通过 undo log 来能够回溯到历史版本。

当需要读取旧版本数据以满足某个事务的快照时，InnoDB 会根据 undo log 回滚（roll back）到对应版本，从而实现多版本并发控制（MVCC）。

简要总结 MVCC 的工作方式：
- 写操作生成新版本并写入 undo log 保存旧版本。
- 读操作根据事务的 read view 决定能看到哪些版本的行。
- 快照读使用历史版本，避免加锁；当前读读取最新版本，并可能加锁以保证并发一致性。

## 总结

本文主要讨论了 MySQL 中事务的隔离性相关概念，包括隔离级别、脏读/不可重复读/幻读的区别、读提交 vs 可重复读 的逻辑差异、以及 InnoDB 使用 MVCC 实现事务隔离的基本原理。理解这些概念对日常开发和面试都很有帮助。

多思考、多实践：
- 一百分以内，一分耕耘一分收获；
- 一百分以外，一分耕耘十分收获。