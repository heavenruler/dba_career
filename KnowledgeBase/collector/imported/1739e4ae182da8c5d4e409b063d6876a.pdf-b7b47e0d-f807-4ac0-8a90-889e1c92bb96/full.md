重⽣之 MySQL B+Tree 提前问世⼆⼗年，MySQL之⽗叫我师⽗
重⽣ MySQL 系列第六篇《我重⽣后，B+树提前问世⼆⼗年》。
重⽣之MySQL  索引失效六⼤陷阱
重⽣之我⽤ 2025 年的 InnoDB 知识在 2003 年 IT 圈打⼯
MySQL  MyISAM引擎是什么？有什么致命缺陷？为何现在都不使⽤了？
MySQL ：MyISAM锁表致千万损失！穿越⼯程师如何逆天改命
MySQL 是什么？它的架构是怎样的？假如让你重新设计，你要怎么做？
林渊盯着监控⼤屏上的红⾊警报：[ERROR] Product category tree query timeout after 30s
商品分类树查询超时！
这已经是本周第三次故障。他打开调试⽇志，发现每次查询需要遍历 17 层⼆叉树。
机房的温度飙升到 42 度，磁盘阵列的 LED 指⽰灯疯狂闪烁。
林渊⼼想：是时候展⽰我的技术了，这个时代 B+ tree 还未产⽣。
另⼀边有⼈问道：“⼆叉树 O(logN)的时间复杂度是教科书写的啊！怎么这样？”
进入正⽂前，介绍下我的点击查看详细介绍 -> 《Java ⾯试⾼⼿⼼法  58 讲》专栏内容涵盖 Java 基础、Java
⾼级进阶、Redis、MySQL 、消息中间件、微服务架构设计等⾯试必考点、⾯试⾼频点。
《 Redis ⾼⼿⼼法》作者，后端架构师，精通 Java 与 Go ，宗旨是拥抱技术和对象，⾯向⼈…
239 篇原创内容
码哥跳动
公众号
《重⽣ MySQL》历史回顾
李健青@码哥字节 2025年04⽉07⽇ 08:29 ⼴东原创 码哥跳动
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 1/8

正⽂开始 ......
⼆叉树的致命缺陷
场景还原：商品分类表prod_category的⽗ ID 字段索引。
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 2/8

CREATE TABLE prod_category (
id INT PRIMARY KEY,
parent_id INT,
INDEX idx_parent (parent_id) -- ⼆叉树实现
);
性能灾难：当层级超过 10 层时，查询⼦类⽬需要递归遍历：
// 原始递归代码（林渊的注释版）
public List<Long> findChildren(Long parentId) {
// WARNING! 每次递归都是⼀次磁盘寻道（ 8ms ）
List<Long> children = jdbc.query("SELECT id FROM prod_category WHERE parent_id=?", p
for (Long child : children) {
children.addAll(findChildren(child)); // 指数级 IO 爆炸
}
return children;
}
林渊的实验数据（2004 年实验报告节选）：
数据量 树⾼ 平均查询时间
1 万 14 112ms
10 万 17 136ms
100 万 20 160ms
⼆叉树的机械困境与复杂度陷阱
1970 年代，⼆叉搜索树（BST）的理论时间复杂度 O(logN)掩盖了物理实现的致命缺陷。以机械硬盘为
例：
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 3/8

树⾼灾难：100 万数据产⽣约 20 层⾼度（log₂(1,000,000)=19.9），假设每次 IO 耗时 8ms，单次查询需
160ms
局部性原理失效：随机磁盘寻道导致缓存命中率趋近于 0。
另外，当所有节点都偏向⼀侧时，⼆叉树退化为“链表”。
B Tree
林渊的竞争对⼿ Jake 说：我设计了⼀个 B Tree，相信是绝世⽆双的设计。
B 树通过多路平衡设计解决了磁盘 IO 问题。根据《数据库系统实现》的公式推导，B 树的阶数 m 与磁盘⻚
⼤⼩的关系为：
m ≥ (PageSize - PageHeader) / (KeySize + PointerSize)
以 MySQL 默认 16KB ⻚为例（PageHeader 约 120 字节，KeySize 8 字节，Pointer 6 字节），阶数
m≈(16384-120)/(8+6)=1162。
10 万数据量下，B 树⾼度仅需 2 层（log₁₁₆₂(100000)≈2），查询 IO 次数从 17 次降为 3 次（根节点常驻
内存），总延迟 24ms。
⾸先定义⼀条记录为⼀个⼆元组[key, data] ，key 为记录的键值，对应表中的主键值，data 为⼀⾏记录中
除主键外的数据。对于不同的记录，key 值互不相同。
B-Tree 中的每个节点根据实际情况可以包含⼤量的关键字信息和分⽀，如下图所⽰为⼀个 3 阶的 B-
Tree：
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 4/8

每个节点占⽤⼀个盘块的磁盘空间，⼀个节点上有两个升序排序的关键字和三个指向⼦树根节点的指针，指
针存储的是⼦节点所在磁盘块的地址。
两个关键词划分成的三个范围域对应三个指针指向的⼦树的数据的范围域。
以根节点为例，关键字为 17 和 35，P1 指针指向的⼦树的数据范围为⼩于 17，P2 指针指向的⼦树的数据
范围为 17~35，P3 指针指向的⼦树的数据范围为⼤于 35。
模拟查找关键字 29 的过程：
1. 根据根节点找到磁盘块 1，读入内存。【磁盘 I/O 操作第 1 次】
2. 比较关键字 29 在区间（17,35），找到磁盘块 1 的指针 P2。
3. 根据 P2 指针找到磁盘块 3，读入内存。【磁盘 I/O 操作第 2 次】
4. 比较关键字 29 在区间（26,30），找到磁盘块 3 的指针 P2。
5. 根据 P2 指针找到磁盘块 8，读入内存。【磁盘 I/O 操作第 3 次】
6. 在磁盘块 8 中的关键字列表中找到关键字 29。
分析上⾯过程，发现需要 3 次磁盘 I/O 操作，和 3 次内存查找操作。由于内存中的关键字是⼀个有序表结
构，可以利⽤⼆分法查找提⾼效率。
B+Tree
林渊反驳：“每个节点中不仅包含数据的 key 值，还有 data 值。
⽽每⼀个⻚的存储空间是有限的，如果 data 数据较⼤时将会导致每个节点（即⼀个⻚）能存储的 key 的
数量很⼩，当存储的数据量很⼤时同样会导致 B-Tree 的深度较⼤，增⼤查询时的磁盘 I/O 次数，进⽽
影响查询效率。”
⽽且 BTree 的非叶⼦节点存储数据，导致范围查询需要跨层跳跃。
林渊脑海中立⻢翻阅在 2025 年学到的 B+Tree 数据结构，在《MySQL 内核：InnoDB 存储引擎》中发现
这段代码：
// storage/innobase/btr/btr0btr.cc
void btr_cur_search_to_nth_level(...) {
/* 只有叶⼦节点存储数据  */
if (level == 0) {
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 5/8

page_cur_search_with_match(block, index, tuple, page_mode, &up_match,
&up_bytes, &low_match, &low_bytes, cursor);
}
}
"原来 B+树通过叶⼦层双向链表，把离散的磁盘⻚变成了连续空间！"
整理好思绪，继续补充道：B+树通过以下创新实现质的⻜跃：
1. 全数据叶⼦层：所有数据仅存储在叶⼦节点，非叶节点仅作索引⽬录
2. 双向链表串联：叶⼦节点通过指针形成有序链表，范围扫描时间复杂度从 O(logN)降为 O(1)。
在 B+Tree 中，所有数据记录节点都是按照键值⼤⼩顺序存放在同⼀层的叶⼦节点上，⽽非叶⼦节点上只存
储 key 值信息，这样可以⼤⼤加⼤每个节点存储的 key 值数量，降低 B+Tree 的⾼度。
B+Tree 的非叶⼦节点只存储键值信息，假设每个磁盘块能存储 4 个键值及指针信息，则变成 B+Tree 后其
结构如下图所⽰：
通常在 B+Tree 上有两个头指针，⼀个指向根节点，另⼀个指向关键字最⼩的叶⼦节点，⽽且所有叶⼦节点
（即数据节点）之间是⼀种链式环结构。
因此可以对 B+Tree 进⾏两种查找运算：⼀种是对于主键的范围查找和分⻚查找，另⼀种是从根节点开始，
进⾏随机查找。
MysQL 之⽗眼睛冒光，看着我惊呆了！！恨不得叫我⼀声⼤师。
⻄湖论剑，单挑⾸席
⼀⽉后，全球数据库峰会在⻄⼦湖畔召开。林渊抱着⼀台 IBM 服务器走上讲台："给我 30 秒，让各位⻅
⻅‘未来索引’！”
实时 PK 表演：
-- 场景： 1 亿订单数据查询
-- 传统 B 树（甲骨⽂）
SELECT * FROM orders WHERE id BETWEEN 100000 AND 200000;
-- 耗时 12.8 秒
-- B+ 树（林渊魔改版）
SELECT /*+ BPLUS_SCAN */ * FROM orders BETWEEN 100000 AND 200000;
-- 耗时 0.3 秒
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 6/8

名场⾯台词：
"诸位，这不是优化，是维度的碾压！
B+树把磁盘的物理运动，变成了内存的闪电舞蹈！"— — 当⽇登上《程序员》杂志封⾯。三⽉后，林渊成
立"深空科技"，发布"伏羲 B+引擎"。
美国商务部紧急会议："绝不能让中国掌控数据库⼼脏！"
最后福利
最后，宣传下⾃⼰的新书《 Redis ⾼⼿⼼法》，上市后得到了许多读者的较好⼝碑评价，⽽且上过京东
榜单！原创不易，希望⼤家多多⽀持，谢谢啦。
本书基于 Redis 7.0 版本，将复杂的概念与实际案例相结合，以简洁、诙谐、幽默的⽅式揭⽰了Redis
的精髓。
从  Redis 的第⼀⼈称视⾓出发，拟⼈故事化⽅式和诙谐幽默的⾔语与各路 “ 神仙 ” 对话，配合  158 张
图，由浅入深循序渐进的讲解  Redis 的数据结构实现原理、开发技巧、运维技术和⾼阶使⽤，让⼈轻
松愉快地学习。
以下是读者的好评：
点击下⽅卡片即可购买
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 7/8

京东
Redis ⾼⼿⼼法
京东配送
¥83.75 购买
⼴告
Kafka 4.0 发布：KRaft 替代 Zookeeper、新⼀代重平衡协议、点对点消息模型、移除旧协议 API
38 张图详解 Redis：核⼼架构、发布订阅机制、9⼤数据类型底层原理、RDB和AOF 持久化、⾼可…
拼多多⼆⾯：⾼并发场景扣减商品库存如何防⽌超卖？
云原⽣时代的JVM调优：从被K8s暴打到优雅躺平
⾼并发系统必看！G1如何让亿级JVM吞吐量提升300%？
性能提升300%！JVM分配优化三板斧，JVM 的内存区域划分、对象内存布局、百万 QPS 优化实践
从 12s 到 200ms，MySQL  两千万订单数据 6 种深度分⻚优化全解析
《 Redis ⾼⼿⼼法》作者，后端架构师，精通 Java 与 Go ，宗旨是拥抱技术和对象，⾯向⼈…
239 篇原创内容
码哥跳动
公众号
往期推荐
MySQL · ⽬录
上⼀篇
重⽣之MySQL 索引失效六⼤陷阱
下⼀篇
⼀⽂搞懂 MySQL InnoDB架构 Buffer
Pool、Change Buffer、⾃适应哈希索引、
2025/6/4 凌晨 12:36 重⽣之  MySQL B+Tree 提前问世⼆⼗年， MySQL 之⽗叫我师⽗
https://mp.weixin.qq.com/s/N2budx0ZuoKZMRdicp80SQ 8/8

