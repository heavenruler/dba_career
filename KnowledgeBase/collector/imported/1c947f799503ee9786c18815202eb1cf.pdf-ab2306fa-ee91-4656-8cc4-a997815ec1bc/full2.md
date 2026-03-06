# 面试官最爱问的 MySQL 日志问题：3 大日志工作原理图解

作者：lz6132（熵减后端），原创，2025-07-19

MySQL 中常被问到的三种日志是 binlog、redo log 和 undo log。它们各自的作用是什么？三者之间有什么联系？为便于理解，下面从执行一条 UPDATE 语句的全过程来说明。

## 执行一条 UPDATE 语句的过程（概览）

当客户端发起数据更新请求时，MySQL 的处理大致分为两层：Server 层和存储引擎层（以 InnoDB 为例）。主要流程如下。

### Server 层处理

1. 获取连接：先由连接器处理连接，进行用户名、密码和权限验证，验证成功后返回连接给客户端。
2. 解析与优化：客户端提交 SQL。若是查询语句（5.7 及以前版本有查询缓存）会检查查询缓存。然后 SQL 交由解析器进行词法分析和语法分析，优化器生成执行计划（例如决定使用索引或全表扫描）。
3. 执行器：根据执行计划调用存储引擎 API 执行操作。同时，所有 DDL/DML 操作（SELECT 除外）会写入 binlog cache，最终写入 binlog。binlog 是逻辑日志，采用追加写，保留完整日志，用于主从同步和数据恢复。写入 binlog 时先写入内存中的 binlog cache（提高速度），刷盘时机包括事务提交时必定刷盘、cache 满时触发等。注意：写入 binlog cache 是由 Server 层完成的，与存储引擎无关，这是必须的步骤。

### 存储引擎（InnoDB）层处理

InnoDB 有自己的缓存机制（buffer pool），用于缓存磁盘数据页以减少磁盘 I/O。更新数据时主要步骤：

1. 在修改数据前，将修改前的数据（用于回滚的内容）记录到 buffer pool 对应的 undo log 页面（随后会刷盘到 undo log 文件）。undo log 的作用是支持事务回滚（保证原子性）并支持 MVCC。
2. 修改 buffer pool 中的数据页，产生脏页（dirty page）。
3. 将变更写入 redo log buffer（随后会刷盘到 redo log）。redo log 是保证数据一致性和事务持久性的核心组件，在崩溃恢复时通过重放 redo log 恢复数据。redo log 是循环顺序写的物理日志，写性能高。与此同时，把 undo log 的相关记录也写到 redo log buffer 中，以便在提交时触发 undo log 的刷盘（undo log 刷盘既可由 redo log 提交触发，也有后台异步线程负责）。
4. 提交事务时，触发 redo log 的两阶段提交机制，确保 redo log 和 binlog 刷盘，保证一致性。只要 binlog 刷盘成功，数据就不会丢失。
5. 后台异步线程会将 redo log buffer 的内容写入磁盘。

## redo log 两阶段提交

InnoDB 为了保证 redo log 与 binlog 的一致性，采用两阶段提交（这里指 redo log 与 binlog 的配合流程）：

1. Prepare 阶段：在修改数据并准备提交时，事务先将变更写入 redo log，并将日志状态标记为 prepare。此步骤确保事务的修改已被记录，但事务尚未对外可见。
2. 提交阶段：MySQL 将 binlog cache 的内容同步刷盘到 binlog。binlog 刷盘成功后，会把 redo log 设置为 commit 状态并异步刷盘，同时触发 undo log 的刷盘。这样就确保 binlog 与 redo log 的顺序性和持久性。

## 重要配置：innodb_flush_log_at_trx_commit

该参数控制 InnoDB 在事务提交时 redo log 的刷盘行为，三个常见取值：

- =0：日志每秒批量刷盘（性能最高，但宕机时可能丢失最多 1 秒的数据）。
- =1（默认）：每次事务提交时强制刷盘（最安全，但性能最低）。
- =2：日志写入操作系统缓存（OS cache），由操作系统负责异步刷盘；只要操作系统不崩溃，数据不会丢失。

选择哪个值应根据对性能和数据安全性的权衡来决定。

## 三大日志的作用小结

- Binlog（逻辑日志）：用于主从复制和基于日志的恢复，记录 SQL 语句或行级变化的逻辑信息，通常位于 Server 层的 binlog cache，事务提交时刷盘保存。
- Redo log（物理日志）：InnoDB 的循环顺序写物理日志，记录数据页的物理修改，用于崩溃恢复（通过重放 redo log），保证事务持久性与一致性。
- Undo log：保存数据修改的前镜像，用于事务回滚和实现 MVCC（多版本并发控制）。

通过对一条 UPDATE 语句从 Server 层到 InnoDB 层的完整处理流程，可以清楚地看到三者在事务处理、数据持久化与恢复机制中的分工与协作。

作者提示：个人观点，仅供参考。欢迎指正与交流。