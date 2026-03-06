掌握 SQL ⼦查询：让你成为查询优化⾼⼿
👋  热爱编程的⼩伙伴们，欢迎来到我的编程技术分享公众号！在这⾥，我会分享编程技巧、实战
经验、技术⼲货，还有各种有趣的编程话题！
1. 引⾔
在  SQL 查询中，⼦查询是⼀种嵌套查询，它可以作为⼀个查询的⼀部分，通常嵌套在  SELECT、
FROM、WHERE  等  SQL 语句中。⼦查询的主要作⽤是为主查询提供额外的数据或条件，从⽽简
化复杂的查询逻辑。掌握⼦查询的使⽤⽅法，不仅能帮助你写出更简洁的  SQL 语句，还能提升你
的查询效率。
2. ⼦查询的基本概念
什么是⼦查询？
⼦查询是嵌套在另⼀个查询中的查询，它的执⾏结果可以作为主查询的⼀部分。⼦查询通常⽤在
以下⼏个地⽅：
WHERE ⼦句：⽤于作为条件来筛选数据。
FROM ⼦句：作为⼀个虚拟表来提供数据源。
SELECT ⼦句：作为计算的结果返回。
⼦查询的作⽤
提供动态的数据源：⼦查询可以返回不同的数据结果，主查询可以根据这些结果进⾏进⼀步的筛选。
简化复杂查询：⼦查询可以将复杂的查询逻辑拆分成多个部分，使查询语句更简洁。
增强查询的灵活性：⼦查询可以处理复杂的条件和计算，增强  SQL 的表达能⼒。
3. ⼦查询的分类
根据不同的使⽤场景和返回结果，⼦查询可以分为以下⼏类：
3.1 根据位置分类
1. WHERE ⼦查询：在   WHERE  ⼦句中使⽤⼦查询来进⾏数据筛选。
星光不问赶路⼈，时光不负有⼼⼈。
166 篇原创内容
源话编程
公众号
2025年01⽉20⽇ 09:49 吉林原创张慧源 源话编程
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 1/7

2. FROM ⼦查询：将⼦查询作为   FROM  ⼦句的⼀部分，作为⼀个临时的虚拟表。
3. SELECT ⼦查询：在   SELECT  ⼦句中使⽤⼦查询，返回计算结果。
3.2 根据返回值分类
1. 标量⼦查询：返回⼀个单⼀值，常⽤于   WHERE  或   SELECT  中。
2. ⾏⼦查询：返回⼀⾏数据，常⽤于   WHERE  ⼦句中。
3. 表⼦查询：返回多⾏多列的数据，通常⽤于   FROM  ⼦句。
4. 相关⼦查询：在⼦查询中引⽤外部查询的列。
5. 非相关⼦查询：独立于外部查询的⼦查询。
4. ⼦查询的常⻅应⽤场景
4.1 ⽤于筛选数据
⼦查询常⽤于从⼀个查询结果中筛选出符合条件的记录。比如，我们可以使⽤⼦查询来查找某个
部⻔的员⼯信息。
⽰例：通过⼦查询筛选数据
SELECT name
FROM employees
WHERE department_id = (SELECT id FROM departments WHERE name = 'HR');
在这个例⼦中，⼦查询  (SELECT id FROM departments WHERE name = 'HR')  返回  HR  部
⻔的  ID ，然后主查询根据这个  ID 筛选出  employees  表中属于该部⻔的员⼯。
4.2 ⽤于聚合数据
⼦查询还可以⽤来进⾏聚合操作，如计算最⼤值、平均值等。
⽰例：计算某部⻔员⼯的平均⼯资
SELECT avg(salary)
FROM (SELECT salary FROM employees WHERE department_id = 1) AS dept_salaries;
在这个例⼦中，⼦查询⾸先筛选出部⻔  ID 为  1 的员⼯的⼯资数据，然后计算这些数据的平均值。
4.3 多表联合查询
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 2/7

⼦查询可以⽤于多表联合查询，解决⼀些复杂的查询需求。例如，我们可以在⼦查询中联接多张
表。
⽰例：查询员⼯及其所在部⻔的信息
SELECT name, salary
FROM employees
WHERE department_id IN (SELECT id FROM departments WHERE location = 'New York');
在这个例⼦中，⼦查询返回  New York  位置的部⻔  ID ，主查询根据这些部⻔  ID 筛选出符合条件
的员⼯信息。
4.4 更新与删除操作中的⼦查询
⼦查询也可以在  UPDATE  和  DELETE  操作中使⽤，从⽽根据查询结果进⾏数据更新或删除。
⽰例：更新员⼯的⼯资
UPDATE employees
SET salary = salary * 1.1
WHERE department_id = (SELECT id FROM departments WHERE name = 'HR');
在这个例⼦中，⼦查询返回  HR  部⻔的  ID ，主查询根据该部⻔  ID 更新该部⻔所有员⼯的⼯资。
4.5 性能优化
在某些情况下，⼦查询可以帮助优化查询性能，减少数据扫描的范围。通过⼦查询，我们可以限
制主查询需要处理的数据量。
5. ⼦查询的具体实例
5.1 WHERE ⼦查询
SELECT name
FROM employees
WHERE department_id = (SELECT id FROM departments WHERE name = 'HR');
解释：在主查询的  WHERE  ⼦句中，使⽤⼦查询来动态获取  HR  部⻔的  ID ，然后筛选出属于该
部⻔的员⼯。
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 3/7

5.2 FROM ⼦查询
SELECT avg(salary)
FROM (SELECT salary FROM employees WHERE department_id = 1) AS dept_salaries;
解释：⼦查询⾸先获取  department_id  为  1 的员⼯⼯资，然后计算这些员⼯的平均⼯资。
5.3 SELECT ⼦查询
SELECT (SELECT COUNT(*) FROM employees) AS employee_count;
解释：通过⼦查询，获取整个员⼯表中的员⼯总数，并返回⼀个计算结果。
5.4 相关⼦查询
SELECT name, salary
FROM employees e
WHERE salary > (SELECT avg(salary) FROM employees WHERE department_id = e.department_id);
解释：相关⼦查询通过引⽤外部查询中的  department_id，动态计算每个部⻔的平均⼯资，并
筛选出⼯资⾼于该部⻔平均⼯资的员⼯。
6. ⼦查询与连接的比较
6.1 ⼦查询  vs. JOIN
有时，⼦查询可以替代  JOIN  来实现相同的查询逻辑。然⽽，⼦查询和  JOIN  的性能差异是需
要考虑的因素。
⼦查询⽰例：
SELECT name
FROM employees
WHERE department_id = (SELECT id FROM departments WHERE name = 'HR');
JOIN ⽰例：
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 4/7

SELECT e.name
FROM employees e
JOIN departments d ON e.department_id = d.id
WHERE d.name = 'HR';
性能分析：对于简单的查询，JOIN  通常比⼦查询更⾼效，尤其是在⼦查询返回⼤量数据时，JO
IN  可以利⽤索引优化查询速度。
7. ⼦查询的优化技巧
7.1 避免嵌套⼦查询
嵌套过深的⼦查询会影响查询性能，尽量避免在  WHERE  ⼦句中使⽤嵌套查询。如果查询变得复
杂，可以考虑拆解查询，使⽤临时表或者优化查询结构。
7.2 使⽤  EXISTS  和  IN  的差异
EXISTS：⽤于检查⼦查询是否返回任何结果，适⽤于检查某个条件是否成立。
IN：⽤于检查某个值是否在⼦查询返回的结果中，适合⽤于多值比较。
-- EXISTS ⽰例
SELECT name
FROM employees e
WHERE EXISTS (SELECT 1 FROM departments d WHERE d.id = e.department_id AND d.name = 'HR')
-- IN ⽰例
SELECT name
FROM employees
WHERE department_id IN (SELECT id FROM departments WHERE name = 'HR');
7.3 将⼦查询转换为  JOIN
对于复杂查询，可以将⼦查询转化为  JOIN，以提⾼查询性能。例如，当⼦查询涉及多个表时，
JOIN  的性能通常优于嵌套⼦查询。
7.4 使⽤索引优化⼦查询
确保在⼦查询所涉及的列上创建索引，以提⾼查询效率。例如，WHERE  ⼦句中的列、JOIN  ⼦
句中的列以及  ORDER BY  ⼦句中的列都应当建立索引。
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 5/7

张慧源
8. ⼦查询常⻅问题及解决⽅案
8.1 ⼦查询返回多个结果时如何处理？
当⼦查询返回多个结果时，可以使⽤  IN  来处理，⽽不是使⽤  =。如果⼦查询只需要返回⼀个
值，确保它只返回单个结果。
8.2 ⼦查询导致查询效率低怎么办？
可以考虑将⼦查询改写为  JOIN，或者使⽤临时表和索引来优化性能。
8.3 相关⼦查询的性能问题如何处理？
避免使⽤不必要的相关⼦查询，考虑拆解查询或者使⽤  JOIN。
结语
⼦查询是  SQL 中非常有⽤的⼯具，能够在复杂查询中提供灵活的解决⽅案。通过合理地使⽤⼦查
询，可以简化查询结构并提⾼查询效率。然⽽，⼦查询也有性能瓶颈，特别是嵌套过深时。理解
⼦查询的使⽤场景、性能优化技巧，并根据实际需求选择合适的查询⽅式，能够帮助你写出更⾼
效、更简洁的  SQL 语句。
个⼈观点，仅供参考，非常感谢各位朋友们的⽀持与关注！
如果你觉得这个作品对你有帮助，请不吝点赞、在看，分享给⾝边更多的朋友。如果你有任何疑
问或建议，欢迎在评论区留⾔交流。
喜欢作者
数据库 · ⽬录
上⼀篇
提升效率的秘密武器：MySQL 常⽤命令速查
宝典
下⼀篇
SQL 全⽂本搜索深度解读
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 6/7

个⼈观点，仅供参考
2025/6/4 凌晨 12:21 掌握  SQL ⼦查询：让你成为查询优化⾼⼿
https://mp.weixin.qq.com/s/1oBUSdJMZz0ZYo5tRlF9SQ 7/7

