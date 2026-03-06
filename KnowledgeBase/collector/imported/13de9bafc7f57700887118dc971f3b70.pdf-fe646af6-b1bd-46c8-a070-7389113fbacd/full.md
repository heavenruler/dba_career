首页 / SQL语句Cost花费判断
12
SQL语句Cost花费判断
原创 三石 All China Database Union 2023-04-23 1965
3
三石 一、结论
关注
为什么有的时候SQL语句会走索引，有的会走全表扫描，这是根据COST成本来判断的，也就是说当全表
50 130 78K+ 扫描的花费成本比走索引的底，那走全表扫描很正常。 文章 粉丝 浏览量
当你要查询的这个列符合条件的数值，当他的值大于等于所占比例其中的9成时，那还不如不走索引，直 364 获得了 次点赞
接全表扫描更快。 109 内容获得 次评论
392 获得了 次收藏
二、基础知识 热门文章
Oracle统计信息的一些总结
2021-01-06 6567浏览 序号 命令 解释
Expdp导出受阻，状态为DEFINING，分析
前因后果
1 set autotrace off 默认值，关闭Autotrace 2021-04-15 6126浏览
Oracle rac集群启动防火墙
2021-05-25 5120浏览 2 set autotrace on explan 只显示执行计划
Oracle Asm 磁盘组的相关知识
2021-10-27 4492浏览
3 set autotrace on statistics 只显示执行的统计计划
ORA-30556:在要修改的列上已定义函数
索引或位图连接索引
2021-02-20 4383浏览 4 set autotrace on 包含2、3两项内容
最新文章
set autotrace traceonly
5 与ON相似，但是不显示语句的执行结果 OB4.3.5数据库参数查询和优化
4天前 17浏览
Oracle19C搭建Adg失败，导致数据库异
常重启 6 set timing on 显示执行时间
2025-07-31 165浏览
Oracle多实例异常重启失败定位
查看数据库SQL语句真实的执行计划需要通过上述命令来达到，主要用到5和6 2025-07-28 216浏览
log file sync的建议判断引起原因
三、SQL语句信息 2025-06-25 211浏览
归档和闪回的处理步骤
2025-04-28 48浏览 1、全表扫描（当un列和gs列具体的数值不一样时）
目录
SELECT yt.km bh,
一、结论 SUM (yt.jf) nc
FROM mj_cx yt 二、基础知识
WHERE cl = 101
三、SQL语句信息 AND (un = '18' )
2、使用索引——INX（当un列和gs列具体的数值不一样时） AND (fl = '01' )
AND (gs = 'G' ) 3、表的收集统计信息时间（时间很近，也就是说和统计信息无关）
GROUP BY km;
4、该表拥有索引，其中跟语句相关的条件列，只有
四、判断思路 2、使用索引——INX（当un列和gs列具体的数值不一样时）
1、这个是创建了只属于四个列的合适索引的执行sql语句——INX_CX3
2、走的索引——INX SELECT yt.km bh,
3、走的索引——INX_CX SUM (yt.jf) nc
FROM mj_cx yt 4、强制全表扫描
WHERE cl = 101
5、通过表格排序 AND (un = '30' )
6、梳理解释 AND (fl = '01' )
AND (gs = 'S' )
GROUP BY km;
3、表的收集统计信息时间（时间很近，也就是说和统计信息无关）
SQL> select last_analyzed from dba_tables where table_name= 'MJ' ;
LAST_ANALYZE
------------
17 -APR -23

4、该表拥有索引，其中跟语句相关的条件列，只有 INX 和 INX_CX
create index INX on mj_cx (CL,UN,GS,FL,CO,KM,BK,WB);
create index INX_CX on mj_cx (CL,UN,GS,FL,KM);
create index INX_CX1 on mj_cx (CL,UN,FL,KM);
create index INX_CX2 on mj_cx (CL,UN,FL,CO,KM);
创建一个索引专属于四列
create index INX_CX 3 on mj_cx(CL, UN, FL,GS);
四、判断思路
1、这个是创建了只属于四个列的合适索引的执行sql语句——INX_CX3
Execution Plan
----------------------------------------------------------
Plan hash value: 3169905893
--------------------------------------------------------------------------------------------------------------
| Id | Operation | Name | Rows | Bytes | Cost (%CPU)|
--------------------------------------------------------------------------------------------------------------
| 0 | SELECT STATEMENT | | 16162 | 615 K | 10231 ( 1 )
| 1 | HASH GROUP BY | | 16162 | 615 K | 10231 ( 1 )
| 2 | TABLE ACCESS BY INDEX ROWID BATCHED | MJ | 75837 | 2888 K | 10228
|* 3 | INDEX RANGE SCAN | INX_CX3 | 75837 | | 333 ( 0 )
--------------------------------------------------------------------------------------------------------------
Predicate Information ( identified by operation id ):
---------------------------------------------------
3 - access ( "F_CLIENT" = 101 AND "F_UNITID" = '18' AND "F_FLZBH" = '01' AND "F_GSDMBH" = 'G' )
Statistics
----------------------------------------------------------
3 recursive calls
0 db block gets
13623 consistent gets
0 physical reads
0 redo size
119375 bytes sent via SQL *Net to client
3314 bytes received via SQL *Net from client
248 SQL *Net roundtrips to / from client
0 sorts ( memory )
0 sorts (disk)
3698 rows processed
#########################################################################
##################################################
2、走的索引——INX
select /*+index(t pk_emp)*/* from emp t
--强制索引，/*.....*/第一个星星后不能有空格，里边内容结构为：加号index(表名 空格 索引名)。
--如果表用了别名，注释里的表也要使用别名
SELECT /*+index(yt INX)*/ yt.km bh,
SUM (yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
AND (un = '18' )
AND (fl = '01' )
AND (gs = 'G' )
GROUP BY km;

Execution Plan
----------------------------------------------------------
Plan hash value: 1540358647
---------------------------------------------------------------------------------------------------------
| Id | Operation | Name | Rows | Bytes | Cost (%CPU)| Time
----------------------------------------------------------------------------------------------------------
| 0 | SELECT STATEMENT | | 16162 | 615 K | 40262 ( 1 )| 00 : 00
| 1 | HASH GROUP BY | | 16162 | 615 K | 40262 ( 1 )| 00 : 00
| 2 | TABLE ACCESS BY INDEX ROWID BATCHED| MJ | 75837 | 2888 K | 40259 ( 1 )|
|* 3 | INDEX RANGE SCAN | INX | 75837 | | 761 ( 1 ) | 00 : 00
----------------------------------------------------------------------------------------------------------
Predicate Information ( identified by operation id ):
---------------------------------------------------
3 - access ( "CL" = 101 AND "UN" = '18' AND "GS" = 'G' AND "FL" = '01' )
Statistics
----------------------------------------------------------
2 recursive calls
0 db block gets
81927 consistent gets
1085 physical reads
0 redo size
119375 bytes sent via SQL *Net to client
3314 bytes received via SQL *Net from client
248 SQL *Net roundtrips to / from client
0 sorts ( memory )
0 sorts (disk)
3698 rows processed
#########################################################################
##################################################
3、走的索引——INX_CX
SELECT /*+index(yt INX_CX)*/ yt.km bh,
SUM (yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
AND (un = '18' )
AND (fl = '01' )
AND (gs = 'G' )
GROUP BY km;
Execution Plan
----------------------------------------------------------
Plan hash value: 3877613795
-----------------------------------------------------------------------------------------------------
| Id | Operation | Name | Rows | Bytes | Cost (%CPU)| Time |
-----------------------------------------------------------------------------------------------------
| 0 | SELECT STATEMENT | | 16162 | 615 K | 72878 ( 1 ) | 00 : 00 : 03 |
| 1 | SORT GROUP BY NOSORT | | 16162 | 615 K | 72878 ( 1 ) | 00 : 00 : 03 |
| 2 | TABLE ACCESS BY INDEX ROWID | MJ | 75837 | 2888 K| 72878 ( 1 ) | 00 : 00 : 03 |
|* 3 | INDEX RANGE SCAN | INX_CX | 75837 | | 490 ( 0 ) | 00 : 00 : 01 |
-----------------------------------------------------------------------------------------------------
Predicate Information ( identified by operation id ):
---------------------------------------------------
3 - access ( "CL" = 101 AND "UN" = '18' AND "GS" = 'G' AND "FL" = '01' )
Statistics
----------------------------------------------------------
2 recursive calls
0 db block gets
103294 consistent gets
695 physical reads
0 redo size
128327 bytes sent via SQL *Net to client
3314 bytes received via SQL *Net from client
248 SQL *Net roundtrips to / from client
0 sorts ( memory )
0 sorts (disk)
3698 rows processed
#########################################################################
##################################################
4、强制全表扫描
表名
(1) 若表有 '别名'，则是 '别名'
(2) 若表没有 '别名'，则是 '表名' 全称

SELECT /*+ full(yt)*/ yt.km bh,
SUM (yt.jf) nc
FROM mj_cx yt
WHERE cl = 101
AND (un = '18' )
AND (fl = '01' )
AND (gs = 'G' )
GROUP BY km;
Execution Plan
----------------------------------------------------------
Plan hash value: 1975139930
------------------------------------------------------------------------------------
| Id | Operation | Name | Rows | Bytes | Cost (%CPU)| Time |
------------------------------------------------------------------------------------
| 0 | SELECT STATEMENT | | 16162 | 615 K | 10542 ( 1 ) | 00 : 00 : 01 |
| 1 | HASH GROUP BY | | 16162 | 615 K | 10542 ( 1 ) | 00 : 00 : 01 |
|* 2 | TABLE ACCESS FULL | MJ | 75837 | 2888 K| 10540 ( 1 ) | 00 : 00 : 01 |
------------------------------------------------------------------------------------
Predicate Information ( identified by operation id ):
---------------------------------------------------
2 - filter( "UN" = '18' AND "GS" = 'G' AND "CL" = 101 AND "FL" = '01' )
Statistics
----------------------------------------------------------
6 recursive calls
0 db block gets
392606 consistent gets
0 physical reads
0 redo size
119375 bytes sent via SQL *Net to client
3314 bytes received via SQL *Net from client
248 SQL *Net roundtrips to / from client
0 sorts ( memory )
0 sorts (disk)
3698 rows processed
5、通过表格排序
序号 sql语句执行使用索引情况 涉及列 花费成本 花费最少排序
1 INX_CX3（四列索引） CL, UN, FL, GS 10231 第一
2 INX（八列索引） CL, UN, GS, FL, CO, KM, BK, WB 40262 第三
3 INX_CX（五列索引） CL, UN, GS, FL, KM 72878 第四
4 强制全表扫描 10542 第二
有意思的是 走专属的 INX_CX3（四列索引）其实就比全表扫描 Cost花费少 311，不管是花费还是执行
时间都相差不多
6、梳理解释
select distinct cl, count (*) from mj_cx group by cl;
select distinct un, count (*) from mj_cx group by un;
select distinct fl, count (*) from mj_cx group by fl;
select distinct gs, count (*) from mj_cx group by gs;
两个sql语句的得出数量值不一样，相差五倍
全表扫描 107850
走索引 22228
当某列查询数据时全表扫描和索引扫描相差不多时（甚至索引产生的伪列 rowid，产生IO）

CL count(*)
1 101 354165
UN COUNT(*)
2 30 22228
9 18 107850
FL COUNT(*)
1 01 354165
GS COUNT(*)
1 S 22228
3 G 249040
走全表扫描时，distinct值不明显
select count ( * ) from ackmje_cx2022 where f_gsdmbh = 'G'
249040
也就是说当你要查询的这个列符合条件的数值，当他的值大于等于所占比例其中的9成时，那还不如不走
索引，直接全表扫描更快
墨力计划
最后修改时间：2023-04-23 14:42:18
「喜欢这篇文章，您的关注和赞赏是给作者最好的鼓励」
关注作者 赞赏
【版权声明】本文为墨天轮用户原创内容，转载时必须标注文章的来源（墨天轮），文章链接，文章作者等基本信息，否则作者和墨天轮有权追究
责任。如果您发现墨天轮中有涉嫌抄袭或者侵权的内容，欢迎发送邮件至：contact@modb.pro进行举报，并提供相关证据，一经查实，墨天轮将
立刻删除相关内容。
评论
tom gang
向大佬学习
2年前 点赞 评论
青學會會長
2年前 1 1
三石
2年前 点赞 回复
相关阅读
腾讯iOA企业级安全办公解决方案
若城 131292次阅读 2025-08-08 13:45:43
2025年8月中国数据库排行榜：双星竞入三甲榜，TDSQL 连跃位次升
墨天轮编辑部 1525次阅读 2025-08-07 16:22:24
【DBA坦白局】第三期：作为DBA，你加过最晚的班是到几点？在干什么？
墨天轮编辑部 1428次阅读 2025-07-15 10:28:44
2025年7月国产数据库大事记：GoldenDB创千万级大单，可信数据库大会召开，openGauss HyBench打榜
第一，电科金仓举办2025产品发布会……
墨天轮编辑部 880次阅读 2025-08-05 17:20:33
IDC报告：2024中国金融行业集中式事务型数据库市场破11.6亿元，Oracle领跑、达梦强势追赶
通讯员 677次阅读 2025-07-16 16:59:44
优炫数据库在山东省寿光市人民检察院成功应用！
优炫软件 650次阅读 2025-07-16 09:50:01
2025年7月国产数据库中标情况一览：长沙银行千万采购GoldenDB，秦皇岛银行近七百万采购TDSQL！
通讯员 627次阅读 2025-08-07 10:18:23
重磅发布：Oracle ADG 一键自动化搭建脚本
Lucifer三思而后行 616次阅读 2025-07-17 17:04:48
重磅 | 万里数据库GreatDB亮相上合组织数字经济论坛 以硬核科技共绘“数字丝路”新图景
万里数据库 594次阅读 2025-07-15 09:45:41
中国信通院2025上半年“可信数据库”新增标准解读
大数据技术标准推进委员会 574次阅读 2025-07-21 10:45:15

