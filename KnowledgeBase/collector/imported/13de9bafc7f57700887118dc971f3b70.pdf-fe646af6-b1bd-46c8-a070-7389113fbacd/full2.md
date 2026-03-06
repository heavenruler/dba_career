# SQL语句Cost花费判断

作者：三石（All China Database Union） 2023-04-23

## 一、结论

为什么有的时候 SQL 语句会走索引，有的会走全表扫描？这是根据 COST 成本来判断的，也就是说当全表扫描的花费成本比走索引低，那走全表扫描很正常。

当你要查询的这个列符合条件的数值占比很高（例如大于等于该列值总量的约 90%）时，使用索引往往不如直接全表扫描更快。

---

## 二、基础知识

查看数据库 SQL 语句真实的执行计划常用 autotrace 与 timing 等命令，主要用到以下几项：

1. `set autotrace off` — 默认值，关闭 Autotrace  
2. `set autotrace on explain` — 只显示执行计划  
3. `set autotrace on statistics` — 只显示执行的统计信息  
4. `set autotrace on` — 同时包含执行计划和统计信息（相当于 2 和 3）  
5. `set autotrace traceonly` — 与 ON 相似，但不显示语句的执行结果  
6. `set timing on` — 显示执行时间

通常通过第 5 和第 6 项可以查看更真实的执行成本与时间。

---

## 三、SQL 语句信息

本例中的 SQL：

```sql
SELECT yt.km bh,
       SUM(yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
  AND (un = '18')
  AND (fl = '01')
  AND (gs = 'G')
GROUP BY km;
```

常见执行方式：
1. 全表扫描（当 un 列和 gs 列的分布使得成本偏高或选择性低时）
2. 使用索引 —— INX（当 un 列和 gs 列的选择性合适时）
3. 表的收集统计信息时间（本例时间很近，和统计信息关系不大）
4. 该表拥有多个索引，其中和语句相关的条件列主要是 INX、INX_CX、INX_CX3 等

---

## 四、索引与判断思路

表上已有的索引：

```sql
create index INX on mj_cx (CL,UN,GS,FL,CO,KM,BK,WB);
create index INX_CX on mj_cx (CL,UN,GS,FL,KM);
create index INX_CX1 on mj_cx (CL,UN,FL,KM);
create index INX_CX2 on mj_cx (CL,UN,FL,CO,KM);
-- 创建一个专属于四列的索引
create index INX_CX3 on mj_cx (CL,UN,FL,GS);
```

下面对不同索引或强制策略下的执行计划进行对比与分析。

### 1) 使用四列专属索引 INX_CX3（CL, UN, FL, GS）

Execution Plan:

```
Plan hash value: 3169905893
--------------------------------------------------------------------------------------------------------------
| Id | Operation                          | Name     | Rows  | Bytes | Cost (%CPU)|
--------------------------------------------------------------------------------------------------------------
| 0  | SELECT STATEMENT                   |          | 16162 | 615 K | 10231 (1)  |
| 1  | HASH GROUP BY                      |          | 16162 | 615 K | 10231 (1)  |
| 2  | TABLE ACCESS BY INDEX ROWID BATCHED| MJ       | 75837 | 2888 K| 10228      |
|*3  | INDEX RANGE SCAN                   | INX_CX3  | 75837 |       | 333 (0)    |
--------------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
3 - access ( "F_CLIENT" = 101 AND "F_UNITID" = '18' AND "F_FLZBH" = '01' AND "F_GSDMBH" = 'G' )

Statistics
----------------------------------------------------------
3 recursive calls
0 db block gets
13623 consistent gets
0 physical reads
0 redo size
119375 bytes sent via SQL*Net to client
3314 bytes received via SQL*Net from client
248 SQL*Net roundtrips to/from client
0 sorts (memory)
0 sorts (disk)
3698 rows processed
```

该计划显示 Cost 为 10231。

---

### 2) 强制使用索引 INX（八列索引）

示例 SQL（强制索引）：

```sql
SELECT /*+ index(yt INX) */ yt.km bh,
       SUM(yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
  AND (un = '18')
  AND (fl = '01')
  AND (gs = 'G')
GROUP BY km;
```

Execution Plan:

```
Plan hash value: 1540358647
----------------------------------------------------------------------------------------------------------
| Id | Operation                          | Name | Rows  | Bytes | Cost (%CPU)| Time     |
----------------------------------------------------------------------------------------------------------
| 0  | SELECT STATEMENT                   |      | 16162 | 615 K | 40262 (1)  | 00:00    |
| 1  | HASH GROUP BY                      |      | 16162 | 615 K | 40262 (1)  | 00:00    |
| 2  | TABLE ACCESS BY INDEX ROWID BATCHED| MJ   | 75837 | 2888 K| 40259 (1)  |          |
|*3  | INDEX RANGE SCAN                   | INX  | 75837 |       | 761 (1)    | 00:00    |
----------------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
3 - access ( "CL" = 101 AND "UN" = '18' AND "GS" = 'G' AND "FL" = '01' )

Statistics
----------------------------------------------------------
2 recursive calls
0 db block gets
81927 consistent gets
1085 physical reads
0 redo size
119375 bytes sent via SQL*Net to client
3314 bytes received via SQL*Net from client
248 SQL*Net roundtrips to/from client
0 sorts (memory)
0 sorts (disk)
3698 rows processed
```

该计划显示 Cost 为 40262。

---

### 3) 使用 INX_CX（五列索引）

```sql
SELECT /*+ index(yt INX_CX) */ yt.km bh,
       SUM(yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
  AND (un = '18')
  AND (fl = '01')
  AND (gs = 'G')
GROUP BY km;
```

Execution Plan:

```
Plan hash value: 3877613795
-----------------------------------------------------------------------------------------------------
| Id | Operation                  | Name    | Rows  | Bytes | Cost (%CPU)| Time          |
-----------------------------------------------------------------------------------------------------
| 0  | SELECT STATEMENT           |         | 16162 | 615 K | 72878 (1)  | 00:00:03      |
| 1  | SORT GROUP BY NOSORT       |         | 16162 | 615 K | 72878 (1)  | 00:00:03      |
| 2  | TABLE ACCESS BY INDEX ROWID| MJ      | 75837 | 2888 K| 72878 (1)  | 00:00:03      |
|*3  | INDEX RANGE SCAN           | INX_CX  | 75837 |       | 490 (0)    | 00:00:01      |
-----------------------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
3 - access ( "CL" = 101 AND "UN" = '18' AND "GS" = 'G' AND "FL" = '01' )

Statistics
----------------------------------------------------------
2 recursive calls
0 db block gets
103294 consistent gets
695 physical reads
0 redo size
128327 bytes sent via SQL*Net to client
3314 bytes received via SQL*Net from client
248 SQL*Net roundtrips to/from client
0 sorts (memory)
0 sorts (disk)
3698 rows processed
```

该计划显示 Cost 为 72878。

---

### 4) 强制全表扫描

示例 SQL（强制全表扫描）：

```sql
SELECT /*+ full(yt) */ yt.km bh,
       SUM(yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
  AND (un = '18')
  AND (fl = '01')
  AND (gs = 'G')
GROUP BY km;
```

Execution Plan:

```
Plan hash value: 1975139930
------------------------------------------------------------------------------------
| Id | Operation        | Name | Rows  | Bytes | Cost (%CPU)| Time          |
------------------------------------------------------------------------------------
| 0  | SELECT STATEMENT |      | 16162 | 615 K | 10542 (1)  | 00:00:01      |
| 1  | HASH GROUP BY    |      | 16162 | 615 K | 10542 (1)  | 00:00:01      |
|*2  | TABLE ACCESS FULL| MJ   | 75837 | 2888 K| 10540 (1)  | 00:00:01      |
------------------------------------------------------------------------------------

Predicate Information (identified by operation id):
---------------------------------------------------
2 - filter( "UN" = '18' AND "GS" = 'G' AND "CL" = 101 AND "FL" = '01' )

Statistics
----------------------------------------------------------
6 recursive calls
0 db block gets
392606 consistent gets
0 physical reads
0 redo size
119375 bytes sent via SQL*Net to client
3314 bytes received via SQL*Net from client
248 SQL*Net roundtrips to/from client
0 sorts (memory)
0 sorts (disk)
3698 rows processed
```

该计划显示 Cost 为 10542。

---

## 五、成本比较与排序

对比不同执行方式的 Cost（按示例数据）：

1. INX_CX3（四列索引） — 涉及列：CL, UN, FL, GS — Cost = 10231 — 排名：第一（最小）
2. INX（八列索引） — 涉及列：CL, UN, GS, FL, CO, KM, BK, WB — Cost = 40262 — 排名：第三
3. INX_CX（五列索引） — 涉及列：CL, UN, GS, FL, KM — Cost = 72878 — 排名：第四
4. 强制全表扫描 — Cost = 10542 — 排名：第二

有意思的是，专属的 INX_CX3（四列索引）比全表扫描的 Cost 还要低 311，无论花费还是执行时间差别不大。

---

## 六、进一步分析（统计、基数与选择性）

用以下查询查看各列的基数（distinct / count）：

```sql
select distinct cl, count(*) from mj_cx group by cl;
select distinct un, count(*) from mj_cx group by un;
select distinct fl, count(*) from mj_cx group by fl;
select distinct gs, count(*) from mj_cx group by gs;
```

两个 SQL 的结果显示数量差异较大（相差约五倍）：

- 全表扫描：107850（示例值）
- 走索引：22228（示例值）

示例统计结果摘录：

CL count(*)
- 101: 354165

UN COUNT(*)
- 30: 22228
- 18: 107850

FL COUNT(*)
- 01: 354165

GS COUNT(*)
- S: 22228
- G: 249040

当某列的查询数据分布使得全表扫描与索引扫描差别不大时（甚至索引产生伪列 rowid 导致额外 IO），索引未必是最佳选择。例如：

```sql
select count(*) from ackmje_cx2022 where f_gsdmbh = 'G';
-- 返回 249040
```

也就是说，当你查询的列满足条件的记录占比非常高（如接近或超过 90%）时，使用索引往往不如全表扫描，直接全表扫描可能更快。

---

## 总结

- Oracle 优化器根据 Cost 来选择执行计划，Cost 最低的方案通常会被采用。
- 索引是否被使用与列的选择性（基数）和索引覆盖的列密切相关。
- 当过滤条件命中大多数行（高选择性不成立，即低选择性，命中率高）时，全表扫描通常比索引更高效。
- 在实际优化中，应结合 autotrace、timing、统计信息以及不同索引的测试执行计划来判断最优方案。