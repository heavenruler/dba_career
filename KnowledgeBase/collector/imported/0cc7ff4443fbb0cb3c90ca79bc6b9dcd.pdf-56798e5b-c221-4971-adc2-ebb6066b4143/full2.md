# InnoDB 中添加索引是否会锁表 & Online DDL 详解

在 InnoDB 存储引擎中，给表添加索引是一个常见操作，但是否会锁表取决于索引的类型和操作方式。下面将关键点拆解说明，并介绍 Online DDL（在线 DDL）技术及实战示例。

## 1. 索引类型对是否锁表的影响

1. 普通索引和唯一索引
   - 是否锁表？添加普通索引或唯一索引时，InnoDB 通常使用行级锁，表中的其他行仍然可以被访问和修改，因此不会完全锁住整个表。
   - 为什么是行级锁？这些索引的创建过程能够逐行扫描数据并更新索引，避免阻塞整个表的操作。

2. 全文索引或分区表的索引
   - 是否锁表？当添加全文索引或涉及某些分区表索引的操作时，InnoDB 可能会使用表级锁，完全锁住表，阻止其他事务的访问或修改。
   - 为什么锁表？这些索引操作往往涉及更复杂的逻辑，无法逐行处理数据，因此需要对整个表加锁以保证数据一致性。

3. 锁的类型对性能的影响
   - 行级锁：影响较小，大部分操作可以并行进行。
   - 表级锁：影响较大，会阻止对表的其他操作，需在高并发场景中特别注意。

4. 避免性能问题的建议
   - 了解索引特性：在添加索引前确认索引类型（普通、唯一、全文、分区等）。
   - 选择合适时机：尽量在业务低峰期执行操作。
   - 备份数据：在可能会锁表的索引操作前备份数据以防意外。

---

## 2. Online DDL（在线 DDL）详细解读

### 什么是 Online DDL？
Online DDL 是 InnoDB 提供的一个功能，允许在执行部分表结构修改（如添加索引、修改列等）时尽可能减少对表数据的锁定。它通过降低锁粒度和优化锁持续时间，使 DDL 操作可以与其他事务并行运行。

### Online DDL 的特点与优势
- 减少锁定范围：主要使用行级锁，避免表的完全锁定，允许其他事务继续访问数据。
- 并发性能提升：适合高并发读写的大型系统，在这些环境中完全锁表会严重影响业务。
- 灵活性：支持在后台执行某些 DDL 操作，同时允许用户对表进行 SELECT、INSERT、UPDATE 等操作。

### Online DDL 支持的操作类型（常见情况）

| 操作类型 | 是否会锁表 | 说明 |
|---|---:|---|
| 添加普通索引 | 不会完全锁表 | 在部分阶段使用行级锁，允许数据读写。 |
| 添加唯一索引 | 不会完全锁表 | 与普通索引类似，但若存在重复数据操作会失败。 |
| 修改列类型 | 视情况而定 | 若涉及数据重组织可能需要更大范围的锁。 |
| 重命名表 | 不会完全锁表 | 几乎瞬时完成，对表无显著锁定影响。 |
| 添加或删除列 | 可能部分锁表 | 某些操作需要重组存储结构，可能使用临时表。 |
| 添加全文索引 | 会锁表 | 需要对全文数据进行扫描和组织，无法完全在线执行。 |
| 添加分区 | 会锁表 | 涉及复杂表结构重组，必须锁表进行。 |
| 表分区变更 | 会锁表 | 涉及全表数据重新布局，需谨慎操作。 |

### Online DDL 的工作机制
- 元数据锁（MDL）：对表的元数据进行短暂加锁，确保修改安全。
- 后台线程执行任务：DDL 操作在后台运行，主线程不会长时间阻塞。
- 行级锁：对索引操作逐行更新索引内容，而不是整表锁定。
- 分阶段操作：Online DDL 将操作分为多个阶段（准备、执行、清理等），只有部分阶段需要短暂锁定表。

### 如何高效使用 Online DDL
- 尽量选择支持 Online DDL 的操作，避免需要表级锁的操作（如全文索引或分区操作）。
- 即便支持 Online DDL，仍建议在业务低峰期执行以减少资源争用。
- 监控执行过程：使用 performance_schema 或 SHOW PROCESSLIST 可以监控 DDL 操作的进度及对系统的影响。

---

## 3. 实例演示

### 1) 创建测试表
```sql
CREATE TABLE employees (
  id INT PRIMARY KEY AUTO_INCREMENT,
  name VARCHAR(100) NOT NULL,
  department VARCHAR(50),
  salary DECIMAL(10, 2),
  hire_date DATE
) ENGINE=InnoDB;
```

### 2) 在线添加索引示例

2.1 添加普通索引（Online DDL 支持）
```sql
ALTER TABLE employees ADD INDEX idx_department (department);
```
说明：这是典型的 Online DDL 操作，MySQL 会在后台创建索引而不锁住整个表，数据仍可被读写。

2.2 添加唯一索引（Online DDL 支持）
```sql
ALTER TABLE employees ADD UNIQUE INDEX uq_name_department (name, department);
```
说明：唯一索引的添加也支持 Online DDL。如果表中已有重复数据，操作会失败，需先检查数据完整性。

### 3) 添加可能锁表的索引

3.1 添加全文索引（可能会锁表）
```sql
ALTER TABLE employees ADD FULLTEXT INDEX ft_name (name);
```
说明：添加全文索引通常会锁住整个表，影响其他读写操作。适用于需要文本全文搜索的场景。

### 4) 查看 Online DDL 的进度
在执行较大 Online DDL 操作时，可通过如下查询监控进度：
```sql
SELECT * FROM performance_schema.events_stages_current
WHERE EVENT_NAME LIKE 'stage/innodb/alter%';
```
输出会显示当前 DDL 操作的状态，如 "Sorting index"（排序索引）或 "Copying to tmp table"（复制到临时表）。

### 5) 模拟高并发场景下的索引添加

5.1 插入大量数据（示例）
```sql
INSERT INTO employees (name, department, salary, hire_date)
VALUES
('Alice', 'Engineering', 7000, '2023-01-15'),
('Bob', 'Sales', 6000, '2022-11-20'),
('Charlie', 'HR', 5000, '2021-08-10'),
-- 添加更多数据
('David', 'Engineering', 8000, '2020-05-25');
```

5.2 添加索引并发发起读写操作
```sql
-- 添加索引（在线操作）
ALTER TABLE employees ADD INDEX idx_salary (salary);

-- 同时运行以下查询
SELECT * FROM employees WHERE department = 'Engineering';
UPDATE employees SET salary = salary + 500 WHERE department = 'Sales';
```
说明：在支持 Online DDL 的情况下，SELECT 和 UPDATE 操作通常可以继续执行。如果使用不支持 Online DDL 的操作（如某些全文索引），上述事务可能会被阻塞直到锁释放。

### 6) 删除索引
删除索引通常为无完整表锁的操作，但仍需注意其对性能的影响。
```sql
ALTER TABLE employees DROP INDEX idx_department;
```

### 7) 错误处理与数据验证

7.1 检查重复数据（为唯一索引做准备）
```sql
SELECT name, department, COUNT(*) AS cnt
FROM employees
GROUP BY name, department
HAVING COUNT(*) > 1;
```

7.2 删除重复数据（保留每组最小 id）
```sql
DELETE FROM employees
WHERE id NOT IN (
  SELECT MIN(id)
  FROM employees
  GROUP BY name, department
);
```

### 8) 批量索引操作优化

8.1 使用 LOCK=NONE 提高并发性（视 MySQL 版本与引擎支持情况）
```sql
ALTER TABLE employees ADD INDEX idx_hire_date (hire_date) LOCK=NONE;
```

8.2 在低峰期执行
尽量选择业务低峰期（例如凌晨）执行大范围索引操作，以减少对生产业务的影响。

---

## 总结

- InnoDB 在添加索引时是否会锁表，主要取决于索引类型与具体操作方式：普通索引和唯一索引通常使用行级锁，不会完全锁表；全文索引和某些分区相关操作可能会锁表。
- Online DDL 是缓解锁表影响的重要手段，通过后台执行、行级锁与分阶段操作，尽可能减少对并发业务的影响。
- 在实际操作中，应根据索引类型、业务峰谷、数据完整性等因素综合判断，并结合监控手段实时观察 DDL 进度与系统影响。