相关推荐
MySQL | GROUP BY子句使用详解 后端出路在何方
InnoDB 索引与 Online DDL 的结合：业务不中断的优
96阅读 · 1点赞 破写代码的
JVM类加载器(附面试题)
化秘诀 79 15k 62
关注 48阅读 · 0点赞 文章 阅读 粉丝
深入理解 RedisConnectionFactory：Spring Data Redis 的核心组件 后端出路在何方 2025-01-14 79 阅读9分钟 专栏： MySQL 关注 私信
140阅读 · 3点赞
复制 重新生成 智能总结 Spring中FactoryBean接口详解
74阅读 · 2点赞
文章主要介绍了 InnoDB 中添加索引是否锁表及 Online DDL 技术。添加索引是否锁表取决于索引类型和操作方 一文带你了解什么是servlet
式，普通和唯一索引通常用行级锁，全文索引等可能用表级锁。Online DDL 能减少锁表影响，提升并发性能，支持 82阅读 · 3点赞
部分操作，使用时要注意选择合适操作和时机，并监控进度。文中还通过案例和流程图进行了详细说明。
精选内容 关联问题: Online DDL适用场景？ 添加索引如何选时机？ 普通索引有何优势？
RocketMQ实战—8.营销系统业务和方案介绍
东阳马生架构 · 30阅读 · 0点赞
TP6开发单页应用 Nginx的一些配置
InnoDB加索引是否会锁表 南雨北斗 · 33阅读 · 1点赞
Java | RESTful 接口规范
在InnoDB存储引擎中，给表添加索引是一个常见的操作，但是否会锁表取决于 索引的类型 和 操作的方式 。 Andya · 45阅读 · 1点赞
为了便于理解，我们可以将关键点拆解如下： Go 语言如何玩转 RESTful API 服务
烛阴 · 86阅读 · 0点赞
1. 普通索引和唯一索引 Spring AOP之EnableAspectJAutoProxy原理
程序员侠客行 · 70阅读 · 0点赞 是否锁表？
添加普通索引或唯一索引时，InnoDB会使用 行级锁 ，具体来说：
表中的其他行仍然可以被访问和修改。
这意味着不会完全锁住整个表，其他事务可以继续进行。
为什么用行级锁？
因为这些索引的创建过程能够逐步扫描数据行并更新索引，避免阻塞整个表的操作。
2. 全文索引或分区表的索引
是否锁表？
当添加 全文索引 或涉及某些 分区表索引 的操作时，InnoDB可能会使用 表级锁 ：
表级锁会完全锁住表，阻止其他事务的访问或修改。
这可能导致并发性能下降，因此需要慎重操作。
为什么锁表？
这些索引操作往往涉及更复杂的逻辑，无法逐行处理数据，因此需要锁住整个表以保证数据的一致性。
3. 锁的类型对性能的影响
如果是 行级锁 ，影响较小，因为大部分操作可以并行进行。
如果是 表级锁 ，影响较大，因为会阻止对表的其他操作，这在高并发场景下需要特别注意。
4. 如何避免性能问题
了解索引特性 ：在添加索引前，需要确认索引的类型（普通索引、唯一索引、全文索引等）。
选择合适的时机 ：尽量选择业务低峰期操作，以减少对数据库性能的影响。
备份数据 ：在执行可能会锁表的索引操作时，提前备份数据以防止意外。
InnoDB在添加索引时是否会锁表，取决于索引的类型和具体操作方法。普通索引和唯一索引通常不会锁

表，而全文索引或某些分区操作可能会锁表。了解这些细节有助于数据库管理员合理规划操作，避免对性能
造成重大影响。
流程图思维导图
以下是关于InnoDB加索引锁表的逻辑流程图，为了帮助理解不同索引类型对锁的影响。
通过这个思维导图，可以快速判断添加索引时是否会锁表，从而更好地规划索引操作。
在介绍了不同索引类型对锁表的影响后，我们再来讨论 InnoDB 引擎中非常重要的 Online DDL（在线DDL）
技术 。这是 MySQL 数据库优化的一项关键功能，能够帮助在不锁表的情况下执行部分数据定义语言
（DDL）操作，从而降低对高并发业务系统的性能影响。
详细解读 InnoDB Online DDL 技术
1. 什么是Online DDL？
Online DDL 是 InnoDB 提供的一个功能，允许我们在执行一些涉及表结构的操作（如添加索引、修改列
等）时，尽可能减少对表数据的锁定。
通过降低锁的粒度（使用行级锁代替表级锁）以及优化锁的持续时间，Online DDL 技术可以让 DDL 操
作与其他事务并行运行。
2. Online DDL的特点和优势
减少锁定范围：
Online DDL 主要使用行级锁，减少了对表的完全锁定。它允许其他事务继续访问表中的数据，避免业务
暂停。
并发性能提升：
Online DDL 特别适合需要持续高并发读写操作的大型数据库系统，例如电商或社交平台。在这些环境
中，完全锁表可能会对业务造成严重影响，而 Online DDL 可以将这种影响降到最低。
灵活性：
Online DDL 支持在后台执行某些DDL操作，同时允许用户对表中的数据进行 SELECT、INSERT、
UPDATE 等操作。
3. Online DDL 支持的操作类型
并非所有 DDL 操作都支持 Online DDL。以下是常见的支持和不支持的情况：

支持操作 是否会锁表 说明
添加普通索引 不会完全锁表 只在部分阶段使用行级锁，允许数据读写。
添加唯一索引 不会完全锁表 和普通索引类似，行级锁影响较小。
修改列类型 不会完全锁表 如果操作不涉及数据重新组织，则不会锁表。
重命名表 不会完全锁表 此操作几乎瞬时完成，对表无显著锁定影响。
添加或删除列 可能部分锁表 某些操作需要重新组织存储结构，可能使用临时表。
不支持或有限支持的操作 是否会锁表 说明
添加全文索引 会锁表 全文索引需要对全文数据进行扫描和组织，无法完全在线执行。
添加分区 会锁表 涉及复杂表结构重组，必须锁表进行。
表分区的变更 会锁表 涉及全表数据的重新布局，需谨慎操作。
4. Online DDL 的工作机制
Online DDL 的实现涉及多个优化点，使得操作对运行中的系统影响最小化：
元数据锁（Metadata Lock, MDL）：
对表的元数据进行短暂加锁，确保表定义的修改操作是安全的。
后台线程执行任务：
DDL 操作会在后台线程中运行，主线程不会阻塞，用户可以继续操作表中的数据。
行级锁：
对于索引操作，使用行级锁逐行更新索引内容，而不是整表锁定。
分阶段操作：
Online DDL 将操作分为多个阶段，例如准备阶段、执行阶段、清理阶段等，只有部分阶段需要短暂锁定
表。
5. 如何高效使用Online DDL？
在实际使用中，充分利用 Online DDL 技术可以帮助数据库管理员更高效地完成索引和表结构的变更操作，
以下是一些实用建议：
选择支持"Online DDL"的操作：
尽量避免选择需要表级锁的操作，例如添加全文索引或分区表操作。
选择业务低峰期执行：
即使是支持 Online DDL 的操作，在高并发下仍可能会占用资源，应尽量选择业务低峰期执行。
监控执行过程：
使用 MySQL 的 或 命令，可以监控 DDL 操作的进度和对 performance_schema SHOW PROCESSLIST
系统的影响。
InnoDB 的 Online DDL 技术通过减少锁表的范围和持续时间，让我们可以在不显著影响业务的情况下完成部
分表结构修改。尽管如此，了解哪些操作支持这一技术仍然很重要，对于支持较差的操作（如添加全文索
引），我们依然需要考虑其对性能的影响并选择合适的执行时机。
关于 InnoDB 添加索引和 Online DDL 技术的完整思维逻辑：
通过这个导图，我们可以快速理解在添加索引时不同技术的使用场景及其对并发性能的影响。
案例

1. 创建一个测试表
首先，我们需要一个测试表以便演示索引操作及其锁表行为。
sql 代码解读 复制代码
CREATE TABLE employees (
id INT PRIMARY KEY AUTO_INCREMENT,
name VARCHAR ( 100 ) NOT NULL ,
department VARCHAR ( 50 ),
salary DECIMAL ( 10 , 2 ),
hire_date DATE
) ENGINE = InnoDB;
2. 在线添加索引示例
利用 InnoDB 的 Online DDL 技术，可以在不锁表的情况下添加索引，从而减少对业务的影响。
2.1 添加普通索引（Online DDL 操作）
sql 代码解读 复制代码
ALTER TABLE employees ADD INDEX idx_department (department);
说明：
这是一个典型的 Online DDL 操作，MySQL 会在后台创建索引而不锁住整个表。
数据仍可被读写，适合高并发业务场景。
2.2 添加唯一索引（Online DDL 操作）
sql 代码解读 复制代码
ALTER TABLE employees ADD UNIQUE INDEX uq_name_department (name, department);
说明：
唯一索引的添加也支持 Online DDL。
如果表中已有重复数据，操作会失败，因此需要在执行前检查数据完整性。
3. 添加可能锁表的索引
某些操作（如全文索引）可能会锁表，影响业务并发。
3.1 添加全文索引
sql 代码解读 复制代码
ALTER TABLE employees ADD FULLTEXT INDEX ft_name (name);
说明：
添加全文索引会锁住整个表，影响其他读写操作。
适用于对文本字段进行全文搜索的场景（例如模糊查询）。
4. 查看 Online DDL 的进度
在执行较大的 Online DDL 操作时，可以通过以下 SQL 监控其进度：
sql 代码解读 复制代码
SELECT * FROM performance_schema.events_stages_current
WHERE EVENT_NAME LIKE 'stage/innodb/alter%' ;
输出示例：
您可以看到当前 DDL 操作的状态，如 "Sorting index"（排序索引）或 "Copying to tmp table"（复
制到临时表）。
5. 模拟高并发场景下的索引添加
以下示例展示如何在高并发场景中添加索引。
5.1 插入大量数据
sql 代码解读 复制代码
INSERT INTO employees (name, department, salary, hire_date)
VALUES
( 'Alice' , 'Engineering' , 7000 , '2023-01-15' ),
( 'Bob' , 'Sales' , 6000 , '2022-11-20' ),
( 'Charlie' , 'HR' , 5000 , '2021-08-10' ),
-- 添加更多数据
( 'David' , 'Engineering' , 8000 , '2020-05-25' );

5.2 添加索引并发起读写操作
在添加索引期间，尝试同时执行 SELECT 和 UPDATE 操作。
sql 代码解读 复制代码
-- 添加索引（在线操作）
ALTER TABLE employees ADD INDEX idx_salary (salary);
-- 同时运行以下查询
SELECT * FROM employees WHERE department = 'Engineering' ;
UPDATE employees SET salary = salary + 500 WHERE department = 'Sales' ;
说明：
Online DDL 时， 和 操作仍然可以正常执行。 SELECT UPDATE
如果使用的是不支持 Online DDL 的操作（如添加全文索引），上述事务可能会因锁表而等待。
6. 删除索引
删除索引通常是无锁表操作，但需要注意其对性能的影响。
sql 代码解读 复制代码
ALTER TABLE employees DROP INDEX idx_department;
7. 错误处理与数据验证
在添加索引之前，可以检查是否存在可能导致失败的情况，例如重复数据。
7.1 检查重复数据
sql 代码解读 复制代码
SELECT name, department, COUNT ( * )
FROM employees
GROUP BY name, department
HAVING COUNT ( * ) > 1 ;
7.2 删除重复数据
sql 代码解读 复制代码
DELETE FROM employees
WHERE id NOT IN (
SELECT MIN (id)
FROM employees
GROUP BY name, department
);
8. 批量索引操作优化
对于大表的索引创建，建议采用以下优化技巧：
8.1 使用 提高并发性 LOCK=NONE
sql 代码解读 复制代码
ALTER TABLE employees ADD INDEX idx_hire_date (hire_date) LOCK = NONE ;
8.2 在低峰期执行
尽量选择业务低峰期执行索引操作，例如在凌晨时段。
以上代码和 SQL 示例展示了以下内容：
如何添加普通索引、唯一索引和全文索引；
如何利用 InnoDB 的 Online DDL 技术减少锁表的影响；
如何监控 Online DDL 的执行进度；
在高并发场景中实现表数据的无中断操作。
整体流程图

标签： MySQL 数据库 话题： 我的技术写作成长之路
本文收录于以下专栏
MySQL 专栏目录
订阅 数据库、事物、存储、IO、锁机制、ACID、MVCC、持久化
· 3 订阅 15 篇文章
从图书馆借书看MySQL意向锁的工作原理 上一篇
评论 0
登录 / 注册 即可发布评论！
0 / 1000 发送
暂无评论数据
为你推荐
开发易忽视的问题：MySQL Alter操作系统性能问题
逸风尊者 5月前 557 6 1 后端 面试 MySQL
MySQL 之 InnoDB 锁系统源码分析
政采云技术团队已转移到新的政采云技术 2年前 2.6k 16 6 MySQL 后端
MySQL InnoDB 磁盘结构
我见青山2023 1月前 56 1 评论 MySQL
InnoDB 四大特性知道吗？
威哥爱编程 8月前 561 4 评论 Java Java EE 数据库
InnoDB 四大特性知道吗？
威哥爱编程 8月前 180 3 评论 Java Java EE 数据库
MySQL修炼、InnoDB逻辑存储结构
i听风逝夜 3年前 470 6 评论 后端
mysql原理（六）核心模型-表
书包肚肚 3年前 362 3 评论 MySQL
图文实例解析，InnoDB 存储引擎中行锁的三种算法
飞天小牛肉 3年前 823 2 评论 MySQL Java
开发易忽视的问题：InnoDB 行锁设计与实现
逸风尊者 5月前 177 2 评论 后端 面试 MySQL
MySQL-彻底让你搞懂mysql索引
请叫我黄同学 2年前 1.5k 11 评论 MySQL 掘金·日新计划
InnoDB存储引擎的特点：行级锁
JohnZeng 1年前 1.1k 3 评论 后端 数据库 MySQL

InnoDB锁详解
已注销 10月前 673 1 评论 MySQL
MySQL 意向共享锁、意向排他锁、死锁
终有救赎 1年前 861 8 评论 后端 面试 数据库
MySQL之行锁与表锁
阿布 2年前 286 1 评论 后端
Mysql学习总结
酸奶味鲷鱼烧 3年前 1.3k 8 评论 MySQL 后端

