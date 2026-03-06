# MySQL 的 performance_schema：你的数据库隐形监控官！

作者：DB哥

performance_schema，一个在 MySQL 世界里专门负责性能监控的“隐形人”。别看我不起眼，数据库的一举一动可都逃不过我的眼睛！

想象一下，如果你的数据库突然变慢，就像一辆跑车突然变成了拖拉机，你会怎么办？是盲目地重启服务，还是像无头苍蝇一样到处查看日志？别担心！今天介绍的就是 MySQL 世界里的“福尔摩斯”——performance_schema，它能帮你洞察数据库内部的每一个细节，让性能问题无所遁形。

## 什么是 performance_schema？

官方定义：MySQL 的监控神器。performance_schema 是 MySQL 自带的一个性能监控存储引擎，它就像给你的数据库安装了一个 24 小时不休息的监控摄像头，实时记录数据库的每一个动作。

```sql
-- 看看你的 MySQL 是否支持 performance_schema
SELECT * FROM INFORMATION_SCHEMA.ENGINES
WHERE ENGINE = 'PERFORMANCE_SCHEMA';

-- 或者更简单的方式
SHOW ENGINES;
```

如果你看到 Support 字段为 YES，那么恭喜你，你的数据库已经自带监控功能了！

## 为什么需要 performance_schema？

还记得那次数据库突然变慢的经历吗？老板在催，用户在骂，而你却一脸茫然……传统的排查方式如下：

```sql
-- 传统的排查方式
SHOW PROCESSLIST; -- 看看谁在运行
SHOW STATUS;      -- 看看各种状态值
SHOW VARIABLES;   -- 看看配置参数
```

这些命令就像盲人摸象，只能看到一部分情况。而 performance_schema 则提供了全景视角！

## performance_schema 的超级能力

- 特点一：实时监控，零干扰  
  performance_schema 最大的优点就是监控不影响性能！它就像个轻功高手，在数据库内部悄无声息地收集信息。

```sql
-- 启用 performance_schema（通常在 my.cnf 中配置）
performance_schema = ON
```

- 特点二：事件驱动的监控模式  
  performance_schema 通过事件来监控数据库活动。这里的事件不是指“数据库结婚”这种大事，而是函数调用、操作系统等待、SQL 语句执行阶段、资源消耗情况等。

- 特点三：内存存储，重启消失  
  performance_schema 的数据都存在内存中，重启后就消失了，所以要及时查询。

```sql
-- performance_schema 的数据都存在内存中
-- 重启后就消失了，所以要及时查询哦！
SELECT * FROM performance_schema.events_statements_current;
```

## 实战：使用 performance_schema 监控数据库

### 第一步：检查并启用 performance_schema

```sql
-- 检查 performance_schema 状态
SELECT * FROM performance_schema.setup_actors;

-- 查看所有的 instruments（监控点）
SELECT * FROM performance_schema.setup_instruments;
```

### 第二步：创建测试数据库和表

```sql
CREATE DATABASE IF NOT EXISTS dbbro_db;
USE dbbro_db;

-- 创建测试表
CREATE TABLE dbbro_user (
  id INT AUTO_INCREMENT PRIMARY KEY,
  name VARCHAR(50) NOT NULL,
  email VARCHAR(100) UNIQUE,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_dbbro_user_name (name)
) ENGINE = InnoDB;

CREATE TABLE dbbro_order (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT,
  amount DECIMAL(10,2),
  status ENUM('pending','completed','cancelled'),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_dbbro_order_user_id (user_id),
  INDEX idx_dbbro_order_status (status),
  FOREIGN KEY fk_dbbro_order_user_id(user_id) REFERENCES dbbro_user(id)
) ENGINE = InnoDB;
```

### 第三步：插入测试数据

```sql
-- 插入用户数据
INSERT INTO dbbro_user (name, email) VALUES
('张三', 'zhangsan@dbbro.com'),
('李四', 'lisi@dbbro.com'),
('王五', 'wangwu@dbbro.com');

-- 插入订单数据
INSERT INTO dbbro_order (user_id, amount, status) VALUES
(1, 100.00, 'completed'),
(1, 200.00, 'pending'),
(2, 150.00, 'completed'),
(3, 300.00, 'cancelled');
```

### 第四步：开始监控 SQL 执行

```sql
-- 启用语句监控
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME LIKE '%statements%';

-- 启用等待事件监控
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME LIKE '%waits%';

-- 执行一些测试 SQL
SELECT * FROM dbbro_user WHERE name = '张三';
SELECT * FROM dbbro_order WHERE amount > 150;
```

### 第五步：查看监控结果

```sql
-- 查看当前执行的语句
SELECT * FROM performance_schema.events_statements_current;

-- 查看历史语句执行情况
SELECT * FROM performance_schema.events_statements_history;

-- 查看语句摘要（类似慢查询日志）
SELECT * FROM performance_schema.events_statements_summary_by_digest;
```

## 深入理解 performance_schema 的表结构

### 语句事件记录表

```sql
-- 当前语句事件表
DESC performance_schema.events_statements_current;

-- 历史语句事件表
DESC performance_schema.events_statements_history;

-- 长语句历史事件表
DESC performance_schema.events_statements_history_long;
```

### 等待事件记录表

```sql
-- 查看等待事件配置
SELECT * FROM performance_schema.setup_instruments
WHERE NAME LIKE '%wait%';

-- 查看当前的等待事件
SELECT * FROM performance_schema.events_waits_current;
```

### 阶段事件记录表

```sql
-- 查看 SQL 执行阶段信息
SELECT * FROM performance_schema.events_stages_current;
```

## 高级监控示例

- 监控最耗时的 SQL

```sql
-- 查找最耗时的 SQL 语句
SELECT DIGEST_TEXT, COUNT_STAR, SUM_TIMER_WAIT / 1000000000 AS total_sec,
       AVG_TIMER_WAIT / 1000000000 AS avg_sec
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT IS NOT NULL
ORDER BY SUM_TIMER_WAIT DESC
LIMIT 10;
```

- 监控锁等待情况

```sql
-- 查看当前的锁等待情况
SELECT * FROM performance_schema.data_lock_waits;
```

- 监控文件 I/O

```sql
-- 查看文件 I/O 统计
SELECT * FROM performance_schema.file_summary_by_instance;
```

## performance_schema 与 INFORMATION_SCHEMA 的区别

很多同学容易混淆 performance_schema 和 information_schema，其实它们很好区分：

- information_schema：数据库的“户口本”，记录静态信息  
- performance_schema：数据库的“体检报告”，记录动态性能信息

```sql
-- information_schema 查看表信息（静态）
SELECT * FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA = 'dbbro_db';

-- performance_schema 查看表操作（动态）
SELECT * FROM performance_schema.table_io_waits_summary_by_table
WHERE OBJECT_SCHEMA = 'dbbro_db';
```

## 性能优化实战：找出数据库瓶颈

案例：发现慢查询

```sql
-- 用 performance_schema 找出慢查询
SELECT DIGEST_TEXT, COUNT_STAR,
       SUM_TIMER_WAIT / 1000000000 AS total_exec_time_sec,
       MIN_TIMER_WAIT / 1000000000 AS min_exec_time_sec,
       MAX_TIMER_WAIT / 1000000000 AS max_exec_time_sec
FROM performance_schema.events_statements_summary_by_digest
WHERE DIGEST_TEXT LIKE '%SELECT%'
ORDER BY max_exec_time_sec DESC
LIMIT 5;
```

## performance_schema 配置详解

### 主要配置参数

```sql
-- 查看 performance_schema 配置
SELECT * FROM performance_schema.setup_actors;
SELECT * FROM performance_schema.setup_consumers;
SELECT * FROM performance_schema.setup_instruments;
```

### 动态配置示例

```sql
-- 动态启用/禁用特定监控
UPDATE performance_schema.setup_instruments
SET ENABLED = 'YES', TIMED = 'YES'
WHERE NAME = 'wait/io/file/sql/binlog';

-- 启用特定消费者
UPDATE performance_schema.setup_consumers
SET ENABLED = 'YES'
WHERE NAME = 'events_waits_current';
```

### 内存使用优化

由于 performance_schema 使用内存存储数据，需要关注内存使用情况：

```sql
-- 查看 performance_schema 内存使用
SELECT * FROM performance_schema.memory_summary_global_by_event_name
ORDER BY SUM_NUMBER_OF_BYTES_ALLOC DESC
LIMIT 10;
```

performance_schema 就像是 MySQL 的全科医生，24 小时值班，随时准备为你的数据库做全面体检。它不会说话，但通过各种表和指标，告诉你数据库的每一个“不舒服”。下次遇到数据库变慢，别急着重启，先问问 performance_schema：“兄弟，刚才发生了什么？”