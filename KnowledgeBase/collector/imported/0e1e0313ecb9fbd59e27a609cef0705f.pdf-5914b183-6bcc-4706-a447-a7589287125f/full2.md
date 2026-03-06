# MySQL 的默认隔离级别为什么是 RR，而不是 RC

作者：青石路  2024-10-08

本文主要探讨 MySQL 的默认隔离级别为何是 Repeatable Read（RR）而不是 Read Committed（RC）。首先回顾关系型数据库的隔离级别和 MySQL 的 binlog 格式（STATEMENT、ROW、MIXED）及其特点，然后从不同方面分析，说明 MySQL 早期为规避主从复制的 bug 将 RR 设为默认隔离级别的原因，并说明不同隔离级别与 binlog 格式组合下的主从复制情况。

## 基础回顾

关系型数据库常见的隔离级别有：
- Read Uncommitted（RU）
- Read Committed（RC）
- Repeatable Read（RR）
- Serializable（串行化）

MySQL 从 5.5 开始将 InnoDB 作为默认存储引擎，事务与隔离级别的讨论都是基于 InnoDB。

## binlog 格式

binlog（binary log，二进制日志）记录了对 MySQL 数据库的更改操作，包括表结构变更（CREATE、ALTER、DROP 等）和表数据修改（INSERT、UPDATE、DELETE 等），但不包括 SELECT、SHOW 等只读操作。即便某次 DML 操作没有实际改动数据（例如 WHERE 条件不满足），这类语句通常也会被记录到 binlog 中。

MySQL 支持三种 binlog 格式：STATEMENT、ROW、MIXED。
- 早期只有 STATEMENT（直到 5.1.5 之前）。
- 5.1.5 开始支持 ROW，5.1.8 开始支持 MIXED。
- 在 MySQL 5.7.7 之前，默认是 STATEMENT；从 5.7.7 起，默认改为 ROW。

下面分别说明三种格式的特点与差异。

### STATEMENT

STATEMENT 格式记录执行的 SQL 语句文本。binlog 文件由索引文件（*.index，记录哪些日志文件在使用）和日志文件（mysql-bin.00000*）组成，日志是二进制的，可用 mysqlbinlog 查看：

```bash
mysqlbinlog.exe --help
mysqlbinlog.exe ../data/mysql-bin.000004
```

在 STATEMENT 模式下，诸如 INSERT、UPDATE、DELETE 等操作以明文 SQL 形式记录在日志中。

### ROW

ROW 格式记录的是行级数据变更（具体的列值），表结构变更仍以 SQL 形式记录。以 MySQL 5.7.30 为例：

```sql
create table tbl_row(
  name varchar(32),
  age int
);
insert into tbl_row values ('qq', 23), ('ww', 24);
update tbl_row set age = 18 where name = 'aa';
update tbl_row set age = 18 where name = 'qq';
delete from tbl_row where name = 'aa';
delete from tbl_row where name = 'ww';
```

使用 mysqlbinlog 查看 ROW 格式时，普通模式下数据部分是以二进制/编码形式记录，需要加参数解码：

```bash
mysqlbinlog.exe --base64-output=decode-rows -v --start-position=2885 --stop-position=3929 ../data/mysql-bin.000002
```

输出示例（简化）：

- INSERT 会列出每列的具体值：
  ```
  INSERT INTO `my_project`.`tbl_row`
  SET
  @1 = 'qq'
  @2 = 23
  INSERT INTO `my_project`.`tbl_row`
  SET
  @1 = 'ww'
  @2 = 24
  ```

- UPDATE 会记录更新前的完整行和更新后的完整行（即使只修改了一列也记录所有列的值）：
  ```
  UPDATE `my_project`.`tbl_row`
  WHERE
  @1 = 'qq'
  @2 = 23
  SET
  @1 = 'qq'
  @2 = 18
  ```

- DELETE 同样记录被删除行的完整列值：
  ```
  DELETE FROM `my_project`.`tbl_row`
  WHERE
  @1 = 'ww'
  @2 = 24
  ```

与 STATEMENT 相比，ROW 的记录更详细、更准确，但日志体积可能更大。

### MIXED

MIXED 模式是 STATEMENT 与 ROW 的混合：在大多数情况下以 STATEMENT 记录，但在一些对复制安全性不确定或依赖上下文的语句时自动改用 ROW。通常当隔离级别为 RC 或遇到某些不安全的语句（例如使用 NOW()、UUID() 等依赖上下文的函数）时，会使用 ROW 记录。

MIXED 的目标是兼顾性能与正确性，但在某些场景下仍有问题。综合考虑数据准确性，推荐使用 ROW。

## 优缺点对比（简要）

- STATEMENT：记录语句文本，日志体积小，易读，但在某些语句与并发场景下可能导致主从不一致。
- ROW：记录具体行变更，准确性高，适合复制一致性和数据恢复，但日志体积较大。
- MIXED：权衡两者，自动切换；效果依赖实现细节，仍可能被系统函数等影响。

总体推荐：若以数据准确性为主，优先使用 ROW。

## 默认隔离级别 与 binlog 的关系

看似隔离级别与 binlog 格式无直接关系，但历史原因导致二者有关联。

在 MySQL 5.1 的早期版本中，如果将隔离级别设为 RC 且 binlog_format 为 STATEMENT，InnoDB 的主从复制存在 bug（参见 Bug23051，5.1.21 中修复）。在 MySQL 5.0.x 中该问题不存在，因此从历史兼容性与复制稳定性考虑，MySQL 在早期选择将默认隔离级别设为 RR，以规避在仅支持 STATEMENT 的环境下出现的主从复制问题。

具体行为示例：
- 在一些版本中，如果在 InnoDB 下把隔离级别设为 RC 并同时将 binlog_format 设置为 STATEMENT，执行数据修改会报错（MySQL 5.1.30 及之后版本对这种组合有限制，不允许这样配置），错误类似：
  ```
  ERROR 1598 (HY000): Binary logging not possible. Message: Transaction level 'READ-COMMITTED' ...
  ```
  或
  ```
  ERROR 1665 (HY000): Cannot execute statement: impossible to write to binary log since BINLOG_FORMAT ...
  ```

也就是说，从 MySQL 5.1.30 开始，InnoDB 在 RC 隔离级别下不允许 binlog_format=STATEMENT，因为这会导致不安全的复制行为或直接被拒绝执行。

## 不同 session 的操作在 binlog 中的记录顺序

binlog 的记录顺序是按事务提交（commit）的顺序，而非按语句开始执行的时间顺序。举例：

Session A:
```sql
update tbl_rr_test set age = 20 where id = 1;
-- later commit
```

Session B:
```sql
update tbl_rr_test set age = 21 where id = 2;
-- earlier commit
```

即使 Session A 的 SQL 先于 Session B 执行，但如果 Session B 先提交，binlog 中先记录的是 Session B 的事务。多个 session 间的 binlog 顺序以 commit 时间为准。这一特性在特定条件下可能导致主从间数据不一致（见 Bug23051 的示例）。

## 默认隔离级别（RR）与 binlog 的历史原因

总结历史原因：在 MySQL 5.0 之前，binlog 只支持 STATEMENT 格式。在 STATEMENT + RC 的组合下，早期的 InnoDB 在主从复制时会产生不一致的 bug（如 Bug23051）。为了规避大量主从复制问题，MySQL 将默认隔离级别设为 Repeatable Read（RR）。此策略自那以后沿用下来，直至 binlog 格式与复制行为逐步改进（例如引入 ROW、MIXED，以及在新版中默认采用 ROW）。

需要注意的是，即使在 RR + STATEMENT 的组合下，使用像 NOW()、UUID() 这类依赖上下文或环境的函数仍然可能导致主从不一致；因此，ROW 是更可靠的选择。

## 总结

- binlog 格式主要有三种：STATEMENT、ROW、MIXED。为保证数据准确性，推荐使用 ROW。
- binlog 格式的演进：5.1.5 开始支持 ROW，5.1.8 开始支持 MIXED；5.7.7 之前默认是 STATEMENT，5.7.7 及更高版本默认是 ROW。
- binlog 的主要用途包括主从复制、数据恢复和审计。
- 关于主从复制的已知问题（针对 InnoDB）：
  - 在 MySQL 5.1.30 及之后版本，若使用 RC 隔离级别，不允许使用 binlog_format=STATEMENT。
  - RC/RR + binlog_format=MIXED 时，主从复制仍可能因系统函数等导致不一致。
  - RR + binlog_format=STATEMENT 在某些情况下仍会受到系统函数影响而出现不一致。
  - binlog_format=ROW 无论 RC 还是 RR，主从复制一般不会有数据不一致的问题。
- MySQL 默认隔离级别为 RR（而不是 RC）的主要原因是为了规避早期版本（尤其是仅支持 STATEMENT 的版本）中与 RC 组合时产生的主从复制 bug，因而一路沿用至今。

标签：MySQL