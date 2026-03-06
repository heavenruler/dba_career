阿⾥⾯试：每天新增100w订单，如何的分库分表？这份答案让我当
场拿了offer
FSAC未来超级架构师
架构师总动员
实现架构转型，再⽆中年危机
尼恩说在前⾯
在 40 岁老架构师  尼恩的读者交流群(50+) 中，最近有⼩伙伴拿到了⼀线互联⽹企业如阿⾥、滴滴、极兔、有
赞、希⾳、百度、⽹易、美团的⾯试资格，遇到很多很重要的⾯试题：
每天新增 100w 订单，如何的分库分表？
10 亿级数据，如何的分库分表？
所以，这⾥尼恩给⼤家做⼀下系统化、体系化的梳理，使得⼤家可以充分展⽰⼀下⼤家雄厚的  “ 技术肌⾁ ” ，让
⾯试官爱到  “ 不能⾃已、⼝⽔直流 ”。也⼀并把这个题⽬以及参考答案，收入咱们的  《尼恩 Java ⾯试宝典 PDF》
V173 版本，供后⾯的⼩伙伴参考，提升⼤家的  3 ⾼  架构、设计、开发⽔平。
最新《尼恩  架构笔记》《尼恩⾼并发三部曲》《尼恩 Java ⾯试宝典》的 PDF ，请关注本公众号【技术⾃由圈】获
取，后台回复：领电⼦书
⽂章⽬录：
- 尼恩说在前⾯
- 尼恩解密：⾯试官的考察意图
- （ 1 ）对分布式数据库设计的理解
- （ 2 ）对业务需求的分析能⼒
- （ 3 ）对技术细节的掌握
- ⼀：分库分表  背景分析
- 1 、场景分析
- 2 、  数据增⻓预测
- 短期趋势
疯狂创客圈（技术⾃由架构圈）：⼀个  技术狂⼈、技术⼤神、⾼性能  发烧友  圈⼦。圈内⼀…
272 篇原创内容
技术⾃由圈
公众号
45岁老架构师尼恩 2025年02⽉28⽇ 07:35 湖北原创 技术⾃由圈
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 1/27

- 中期趋势
- ⻓期趋势
- 3 、⾯临的问题与挑战
- 1: 查询劣化
- 2: 写入劣化
- 3: 容量瓶颈
- 4: 数据备份困难
- 5 ：数据清理难困难
- ⼆、分库分表三⼤策略
- 三、⼀致性 hash 取模分库分表
- 1 前期规划
- 2 分库策略
- 3 分表策略
- 4 ：⼀致性哈希  优势
- 4.1. 数据分布相对均匀
- 4.2. 节点增减时数据迁移量⼩
- 4.3. ⾼扩展性
- 4.4. 容错性强
- 5 ：⼀致性哈希  劣势
- 1. 算法复杂度较⾼
- 2. 数据分布并非绝对均匀
- 3. 维护成本较⾼
- 4. 难以处理范围查询
- 四：按照时间范围分库分表
- 1. 分库策略
- 2. 分表策略
- 3. 路由策略
- 4. 时间范围进⾏分库优点
- 5. 时间范围进⾏分库不⾜
- 五、组合模式分库分表（ ID 取模分库、时间范围分表）
- 1. 前期规划
- 2. 分库策略： ID 取模分库
- 3. 分表策略：时间范围分表
- 60 分  ( 菜⻦级 ) 答案
- 六、如何使⽤  shardingsphere 实现组合策略分库分表
- 1. JDBC 模式  (Sharding-JDBC)
- 2. Proxy 模式 (ShardingSphere)
- 3. Sidecar 模式
- Sharding-JDBC 5 种分片策略
- 1. 标准分片策略（ StandardShardingStrategy ）
- ⽀持的  SQL 操作
- 分片算法
- ⽰例代码（ Java ）
- 2. 复合分片策略（ ComplexShardingStrategy ）
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 2/27

- ⽀持的  SQL 操作
- 特点
- ⽰例代码（ Java ）
- 3. Hint 分片策略（ HintShardingStrategy ）
- 分片⽅式
- ⽰例代码
- 4. 不分片策略（ NoneShardingStrategy ）
- ⽰例配置（ YAML ）
- 5. ⾏表达式分片策略（ InlineShardingStrategy ）
- 特点
- ⽰例配置（ YAML ）
- 七、实操：组合模式分库分表（ ID 取模分库、时间范围分表）实操
- 分库算法   DBShardingAlgorithm （取模分库）
- `TableShardingAlgorithm`   ⽉份分表
- `application.properties` 配置
- 八：优化、如何避免 ID 查询时的全库路由问题？
- 1. 引入异构索引表
- 2. 使⽤时间基因法
- 80 分  答案   ( ⾼⼿级 )
- 九、使⽤  雪花 id 的时间基因，  解决 ID 查询时的全库路由问题？
- 1. 雪花算法 ID 结构
- 2. 如何计算 ID 的时间范围
- 2.1 提取时间戳
- 2.2 转换为具体时间
- 2.3 确定时间范围
- 3 雪花 id ⾥边的时间戳值  作为分表基因的实操
- 3.1. 解析雪花  ID 中的时间戳
- 3.2. 修改表分片算法
- 3.3. 修改配置⽂件
- 未完待续：读写分离架构
- 未完待续：动态扩容架构与实现
- 120 分殿堂答案  ( 塔尖级 ) ：
- 遇到问题，找老架构师取经
尼恩解密：⾯试官的考察意图
（1）对分布式数据库设计的理解
分库分表是解决⼤规模数据存储和⾼性能查询的常⻅策略。⾯试官希望了解候选⼈是否熟悉这些概念，并能够
根据业务需求设计合理的分库分表⽅案。
考察候选⼈是否能够权衡不同的分库分表策略（如⽔平分片、垂直分片、时间范围分表等）的优缺点，并选择
最适合的⽅案。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 3/27

（2）对业务需求的分析能⼒
每天新增 100 万订单是⼀个具体的业务场景，⾯试官希望候选⼈能够结合实际业务需求进⾏分析，例如：
订单数据的访问模式（读多写少、热点数据等）。
数据的⽣命周期（短期⾼频访问、⻓期归档）。
数据⼀致性要求（是否需要分布式事务）。
考察候选⼈是否能够从业务⾓度出发，设计出既能满⾜性能需求，⼜能兼顾扩展性和维护性的⽅
案。
（3）对技术细节的掌握
分库分表涉及多个技术细节，如数据分片键的选择、分布式事务处理、数据迁移、查询优化等。
⾯试官希望了解候选⼈是否熟悉这些技术细节，并能够针对具体问题提出解决⽅案。例如：
如何避免全库路由问题？
如何处理跨表查询？
如何保证数据⼀致性？
⼀：分库分表 背景分析
1、场景分析
在当今数字化商业环境中，各类电商平台、在线服务提供商以及⾦融交易系统等业务场景下，订单处理是核⼼
业务流程之⼀。
随着业务的快速发展和市场规模的不断扩⼤，订单数据量呈现出爆发式增⻓的态势。
以⼀个中等规模以上的电商平台为例，每天新增的订单数量可能达到  100 万条 ,   甚⾄更多。
这些订单数据包含了丰富的信息，如订单编号、⽤户信息、商品详情、交易⾦额、交易时间等，对于  运营管
理、决策分析以及客户服务等⽅⾯都具有重要的价值。
2、 数据增⻓预测
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 4/27

短期趋势
在未来  1 - 2 年内，随着市场推⼴⼒度的加⼤、⽤户数量的持续增加以及业务拓展到新的领域，预计订单数据
将以每年  30% - 50% 的速度增⻓。
这意味着：   1 - 2 年内  ，每天新增的订单数量可能在达到  130 万  - 150 万条。  订单总量  在  1 亿级别。
中期趋势
在  3 - 5 年的中期阶段，随着业务的 定发展和市场份额的进⼀步扩⼤，订单数据的增⻓速度可能会有所放
缓，但仍然会保持在每年  20% - 30% 的⽔平。
这意味着：  在  3 - 5 年内  ，每天新增订单数量可能接近  250 万条。订单总量  在  10 亿级别。
⻓期趋势
从  5 - 10 年的⻓期来看，考 到市场的饱和以及竞争的加剧，订单数据的增⻓速度可能会逐渐 定在每年
10% - 20% 左右。
这意味着：  在  5 - 10 年内  ，每天新增订单数量可能接近  600 万条。订单总量  在  100 亿级别。
3、⾯临的问题与挑战
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 5/27

1:查询劣化
随着订单数据量的不断增加，单⼀数据库表中的数据⾏数会急剧增⻓。
当数据量达到数百万甚⾄数千万级别时，简单的查询操作（如按订单编号查询、按⽤户  ID 查询订单列表等）
的响应时间会显著增加。
例如，在⼀个包含  1000 万条订单记录的单表中，⼀次简单的查询操作可能需要数秒甚⾄数⼗秒才能完成，这
严重影响了系统的实时性和⽤户体验。
2:写入劣化
在⾼并发场景下，单⼀数据库的写入性能会受到严重限制，可能会出现写入延 、数据丢失等问题。
例如，当多个⽤户同时下单时，数据库可能⽆法及时处理所有的写入请求，导致订单处理失败或延 。
单⼀数据库的并发处理能⼒也是有限的，⽆法满⾜⽇益增⻓的⾼并发订单处理需求。
当并发请求数超过数据库的处理能⼒时，系统会出现性能下降、响应时间延⻓等问题，甚⾄可能导致系统崩
溃。
3:容量瓶颈
单⼀数据库的存储容量是有限的，随着订单数据的不断积累，很快会达到数据库的存储上限。⼀旦存储容量不
⾜，就需要进⾏数据库扩容，这不仅会带来⾼昂的成本，还会影响系统的正常运⾏。
4:数据备份困难
在数据量巨⼤的情况下，数据库的备份和恢复操作变得非常困难和耗时。
⼀次完整的数据库备份可能需要数⼩时甚⾄数天才能完成，⽽且备份数据的存储和管理也需要⼤量的资源。
5：数据清理难困难
随着时间的推移，⼤量的历史订单数据会占据数据库的存储空间，影响系统的性能。
但在单⼀数据库中，进⾏数据归档和清理操作会非常复 ，需要考 数据的关联性、业务需求等多⽅⾯因素。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 6/27

⼆、分库分表三⼤策略
⼀致性 hash 取模策略
按照时间范围分库分表
组合模式分库分表（ ID 取模分库、时间范围分表）实操
三、⼀致性hash取模分库分表
20 亿数据， 128 张表  ，  按照  id ⼀致性 hash 取模分库分表，如何设计？
1 前期规划
分库数量：
假设我们有N个数据库，可以根据实际的硬件资源和性能需求来确定。⼀般来说，可以先初步设定为  8 个库  。
分表数量：
由于总共有  128 张表，若分  8 个库，则每个库中平均有  16 张表。
⼀致性哈希算法：
选择⼀个合适的⼀致性哈希算法库，如MurmurHash等。该算法能将数据的id映射为⼀个固定范围（通常是  0
到  2^32-1 ）内的哈希值。
2 分库策略
分库数量：根据数据量和业务需求，建议分为  16 个库（ 16 是⼀个便于扩展的数字，后续可以按需扩容）。
分库规则：对 ID 进⾏⼀致性哈希取模，公式为：
db_index = hash(id) % 16
其中， hash(id)
使⽤⼀致性哈希算法（如 MurmurHash ）保证数据分布均匀。
3 分表策略
计算哈希值与取模
对于每⼀条数据的id，使⽤选定的⼀致性哈希算法计算出其哈希值。
然后，将  哈希值对数据库数量N取模，得到的结果即为该数据应该存储的数据库编号。
例如，若取模结果为  3 ，则该数据应存储在第  3 个数据库中。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 7/27

在确定了数据库之后，再将哈希值对每个数据库中的表数量取模，得到该数据应该存储的表编号。例如，若每
个库中有  16 张表，取模结果为  12 ，则该数据应存储在对应数据库的第  12 张表中。
分表数量：每个库分为  8 张表，总表数为  16 库  × 8 表  = 128 表。
分表规则：在分库的基础上，对 ID 进⾏⼆次取模，公式为：
table_index = hash(id) % 8
最终表名为：
db_index.table_{table_index}
4：⼀致性哈希 优势
4.1. 数据分布相对均匀
⼀致性哈希算法能够将数据均匀地映射到不同的数据库或表中。通过对数据的键（如  id）进⾏哈希计算，使
得各个节点（数据库或表）承担的数据量相对均衡。例如，在⼀个分布式数据库系统中，有多个数据库节点，
使⽤⼀致性哈希取模可以避免某些节点数据过多⽽其他节点数据过少的情况，有效提⾼系统的整体性能和资源
利⽤率。
4.2. 节点增减时数据迁移量⼩
当需要增加或减少数据库节点时，传统的取模算法可能需要对⼤量数据进⾏重新计算和迁移。⽽⼀致性哈希算
法在节点变化时，只有部分数据需要迁移。例如，在⼀个有  10 个节点的系统中，增加⼀个新节点，只会影响
到该新节点在哈希环上相邻的部分数据，其他⼤部分数据仍然可以保持在原节点，⼤⼤减少了数据迁移的⼯作
量和对系统的影响。
4.3. ⾼扩展性
⼀致性哈希取模分库分表具有良好的扩展性。随着业务的发展，数据量不断增加，可以⽅便地通过增加数据库
节点来扩展系统的存储和处理能⼒。
新节点可以平滑地加入到系统中，不会对现有数据的分布和访问造成太⼤的影响，保证了系统的可扩展性和灵
活性。
4.4. 容错性强
当某个数据库节点出现故障时，⼀致性哈希算法可以将原本分配到该节点的数据⾃动转移到其他节点上。
由于数据的迁移范围较⼩，对系统的影响也相对较⼩，能够在⼀定程度上保证系统的可⽤性和数据的可靠性。
5：⼀致性哈希 劣势
1. 算法复杂度较⾼
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 8/27

⼀致性哈希算法的实现相对复 ，需要考 哈希函数的选择、哈希环的构建和维护等问题。
与简单的取模算法相比，⼀致性哈希算法的计算量更⼤，特别是在⾼并发场景下，可能会对系统的性能产⽣⼀
定的影响。
2. 数据分布并非绝对均匀
虽然⼀致性哈希算法可以使数据分布相对均匀，但在实际应⽤中，由于哈希函数的特性和节点数量的限制，可
能会出现数据分布不均匀的情况。
例如，当节点数量较少时，哈希环上的节点分布可能不够均匀，导致部分节点承担的数据量相对较⼤。为了缓
解这个问题，通常需要引入虚拟节点的概念，但这会增加系统的复 度和管理成本。
3. 维护成本较⾼
⼀致性哈希取模分库分表需要对哈希环和节点信息进⾏维护。
当节点发⽣变化时，需要及时更新哈希环的状态，确保数据能够正确地路由到相应的节点。
此外，还需要对虚拟节点进⾏管理和调整，以保证数据的均匀分布。这些维护⼯作增加了系统的管理成本和复
度。
4. 难以处理范围查询
⼀致性哈希算法是基于数据的键进⾏哈希计算和数据分片的，对于范围查询（如按照时间范围、数值范围进⾏
查询）的⽀持较差。
在进⾏范围查询时，可能需要对多个节点进⾏扫描和合并结果，增加了查询的复 度和时间开销。
相比之下，按范围分库分表更适合处理范围查询。
四：按照时间范围分库分表
在 20 亿数据的情况下，按照时间范围进⾏分库分表的设计，可以充分利⽤时间的有序性和业务需求，实现数据
的⾼效存储与查询。
1.分库策略
分库数量：建议分为 16 个库。
分库规则：根据时间范围划分库。例如，按年分库：
db_index = (year - 2023) % 16
其中， year   是数据的时间字段（如创建时间）的年份部分。
2.分表策略
分表数量：
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 9/27

每个库分为  8 张表，总表数为  16 库  × 8 表  = 128 表。
分表规则
在分库的基础上，进⼀步按时间范围分表。
例如，按⽉分表：
table_index = (month - 1)
最终表名为：
db_{db_index}.table__{table_index}
3. 路由策略
时间单位：根据业务需求选择合适的时间单位（如年、⽉、周、天）。
时间单位：根据业务需求选择合适的时间单位（如年、⽉、周、天）。
时间范围映射：为每个时间范围分配⼀个唯⼀的 db_index 和 table_index
例如：
2023 年 1 ⽉：db_index = 0, table_index = 0
2023 年 2 ⽉：db_index = 0, table_index = 1
...
2024 年 1 ⽉：db_index = 1, table_index = 0
4. 时间范围进⾏分库优点
(1) 提升查询性能
按时间范围分表后，查询特定时间段的数据时，可以直接定位到对应的表，避免了全表扫描，显著提升查询效
率。
(2) ⽅便数据归档和备份
历史数据可以按时间范围归档到不同的表或库中，便于管理和备份，同时可以减少主表的存储压⼒。(3) 易于
扩容和扩展
随着时间推移，可以按需新增表或库来存储新数据，扩容过程相对简单，且对现有数据影响较⼩。
(4) 适合时间序列数据
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 10/27

对于⽇志、订单、监控数据等时间序列数据，按时间范围分表可以更好地利⽤数据的时间局部性，提⾼读写性
能。
5. 时间范围进⾏分库不⾜
(1) 热点问题
最新的时间范围表（如最近⼀个⽉的表）可能会集中⼤部分的读写请求，导致热点问题，影响性能。
(2) 跨表查询复
如果查询涉及多个时间范围，需要在多个表中分别执⾏查询并合并结果，增加了开发和维护的复 性。
(3) 数据迁移和维护成本⾼
随着时间推移，表的数量会不断增加，需要定期清理老旧数据，且数据迁移和备份的复 度也会增加。
(4) 应⽤逻辑复 度增加
分表策略需要在应⽤层或中间件中实现数据路由逻辑，增加了系统的复 性。
(5) 分布式事务问题
如果涉及跨库操作，可能需要引入分布式事务管理⼯具，增加了系统的复 性和开发成本。
五、组合模式分库分表（ID取模分库、时间范围分表）
20 亿数据， 128 张表  ，  按照    组合模式（ ID 取模分库、时间范围分表）分库分表，如何设计？
通过 ID 取模分库，将数据均匀分布到多个数据库中；
按时间范围分表，将数据按时间段划分到不同的表中。
以下是具体的设计思路和实现步骤：
1.前期规划
分库数量需要根据业务的并发量、硬件资源以及未来的扩展性来综合考 。
⼀般来说，如果数据量为  20 亿且有⼀定的并发访问，可先设定为  8 个数据库，分别命名为  db_0  到  db_7。
根据业务查询特点和数据增⻓规律，选择合适的时间粒度进⾏分表。若业务常按⽉份进⾏数据统计和查询，可
按⽉分表。
表名采⽤  t_YYYYMM  的格式，如  t_202502  代表  2025 年  2 ⽉的数据表。
2. 分库策略：ID取模分库
分片键选择：
选择业务中具有⾼基数的字段（如⽤户 ID 、订单 ID ）作为分片键。
分库数量：
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 11/27

根据数据量和业务需求，假设分库数量为N（例如 4 个库）。
分库算法：
使⽤哈希取模算法，shard_id = id % N，将数据均匀分布到不同的库中。
3. 分表策略：时间范围分表
分表依据：
根据时间字段（如create_time）进⾏分表，例如按⽉分表。
表命名规则：
表名可以设计为order_YYYYMM，例如order_202401、order_202402。
分表数量：
假设按⽉分表，⼀年最多 12 张表，结合业务需求调整。
60分 (菜⻦级) 答案
尼恩提⽰，讲完  3 ⼤分库分表策略，  可以得到  60 分了。
但是要直接拿到⼤⼚ offer ，或者   offer 直提，需要  120 分答案。
尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
六、如何使⽤ shardingsphere 实现组合策略分库分表
ShardingSphere 提供三种主要的使⽤模式，分别是  JDBC 模式、 Proxy 模式和  Sidecar 模式。
Apache ShardingSphere 官⽹
以下是它们的特点：
1. JDBC 模式 (Sharding-JDBC)
定位：作为轻量级  Java 框架，提供增强版的  JDBC 驱动。
特点：直接嵌入  Java 应⽤中，以  Jar 包形式提供服务，⽆需额外部署。完全兼容  JDBC 和各种
ORM 框架，使⽤客户端直连数据库。
适⽤场景：适合基于  Java 的应⽤开发，尤其是已有系统需要⽆缝集成分库分表功能时。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 12/27

2. Proxy 模式(ShardingSphere)
定位：类似于  Mycat ，是⼀个透明化的数据库代理端。
特点：封装了数据库的⼆进制协议，⽀持异构语⾔。提供  MySQL 和  PostgreSQL 版本，⽀持使⽤
兼容  MySQL/PostgreSQL 协议的客户端（如  MySQL Command Client 、 MySQL Workbench 、
Navicat 等）进⾏操作，对  DBA 更友好。
适⽤场景：适合多种语⾔的开发环境，尤其是需要跨语⾔⽀持的场景。
3. Sidecar 模式
定位：作为  Kubernetes 的云原⽣数据库代理。
特点：以  Sidecar 的形式代理所有对数据库的访问，提供⽆中⼼、零侵入的数据库交互层
（ Database Mesh ）。⽬前仍处于规划阶段。
适⽤场景：适合  Kubernetes 环境下的云原⽣应⽤。
在实际项⽬中，  尼恩选择了  JDBC 模式（ Sharding-JDBC ），因为它与现有的  Java 应⽤集成最为便捷，且完
全兼容现有的  ORM 框架。
Sharding-JDBC 5 种分片策略
分片策略主要包含分片键和分片算法。
或者说， “ 分片键  + 分片算法 ” ，这两者组合起来就是所谓的分片策略。
Sharding - JDBC 是⼀个开源的分布式数据库中间件，它提供了  5 种分片策略，以下为你详细介绍：
1. 标准分片策略（StandardShardingStrategy）
这是⼀种较为常⽤的分片策略，适⽤于单分片键的场景，它能对  SQL 语句中的多种比较和范围操作进⾏分片
处理。
⽀持的 SQL 操作
⽀持  =, >, <, >=, <=, IN  和  BETWEEN AND  这些操作符的分片操作。
分片算法
PreciseShardingAlgorithm：必选算法，主要⽤于处理  =  和  IN  操作的分片。当  SQL 语句中使
⽤  =  或  IN  来筛选数据时，该算法会根据分片键的值精确地确定数据应该存储在哪个分片上。
RangeShardingAlgorithm：可选算法，⽤于处理  BETWEEN AND, >, <, >=, <=  操作的分片。如
果不配置这个算法， SQL 中的  BETWEEN AND  操作将按照全库路由处理，也就是会在所有分片上
进⾏查询。
⽰例代码（Java）
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 13/27

// 精确分片算法⽰例
public class MyPreciseShardingAlgorithm implements PreciseShardingAlgorithm<Long
@Override
public String doSharding(Collection<String> availableTargetNames, PreciseSha
for (String each : availableTargetNames) {
if (each.endsWith(shardingValue.getValue() % 2 + "")) {
return each;
}
}
throw new UnsupportedOperationException();
}
}
// 范围分片算法⽰例
public class MyRangeShardingAlgorithm implements RangeShardingAlgorithm<Long> {
@Override
public Collection<String> doSharding(Collection<String> availableTargetNames
Collection<String> result = new LinkedHashSet<>();
Range<Long> range = shardingValue.getValueRange();
for (Long i = range.lowerEndpoint(); i <= range.upperEndpoint(); i++) {
for (String each : availableTargetNames) {
if (each.endsWith(i % 2 + "")) {
result.add(each);
}
}
}
return result;
}
}
2. 复合分片策略（ComplexShardingStrategy）
当需要使⽤多个分片键进⾏分片时，就可以使⽤复合分片策略。它为处理复 的分片逻辑提供了⽀持。
⽀持的 SQL 操作
⽀持  =, >, <, >=, <=, IN  和  BETWEEN AND  这些操作符的分片操作。
特点
由于多分片键之间的关系复 ，该策略没有进⾏过多的封装，⽽是直接将分片键值组合以及分片操作符传递给
分片算法，由应⽤开发者根据具体业务需求⾃⾏实现分片逻辑，提供了很⼤的灵活性。
⽰例代码（Java）
public class MyComplexShardingAlgorithm implements ComplexKeysShardingAlgorithm<
@Override
public Collection<String> doSharding(Collection<String> availableTargetNames
// ⾃定义多分片键的分片逻辑
Collection<String> result = new ArrayList<>();
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 14/27

// 实现具体的分片逻辑
return result;
}
}
3. Hint 分片策略（HintShardingStrategy）
在某些情况下，⽆法从  SQL 语句中提取分片键的值，或者希望⼿动指定分片的⽬标，这时就可以使⽤  Hint 分
片策略。
分片⽅式
通过  HintManager  来指定分片值，⽽不是从  SQL 语句中提取分片值。这种⽅式可以绕过  SQL 解析，直接指
定数据要存储或查询的分片。
⽰例代码
try (HintManager hintManager = HintManager.getInstance()) {
hintManager.addDatabaseShardingValue("table_name", 1);
// 执⾏  SQL 操作
}
4. 不分片策略（NoneShardingStrategy）
这是⼀种最简单的策略，即不进⾏分片操作。当某些表不需要进⾏数据分片，或者只在⼀个数据库或分片中存
储时，可以使⽤该策略。
⽰例配置（YAML）
tables:
non_sharding_table:
actualDataNodes: ds_0.non_sharding_table
tableStrategy:
none:
5. ⾏表达式分片策略（InlineShardingStrategy）
⾏表达式分片策略是⼀种基于  Groovy 表达式的简单分片策略，它允许通过简单的表达式来定义分片规则。
特点
使⽤简洁，适合简单的分片场景，通过配置⾏表达式可以快速实现分片逻辑。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 15/27

⽰例配置（YAML）
tables:
order_table:
actualDataNodes: ds_${0..1}.order_table_${0..1}
tableStrategy:
inline:
shardingColumn: order_id
algorithmExpression: order_table_${order_id % 2}
这  5 种分片策略各有特点，开发者可以根据具体的业务需求和数据特点选择合适的分片策略来实现数据的分布
式存储和查询。
七、实操：组合模式分库分表（ID取模分库、时间范围分表）实操
以订单为例
db 以  订单 id 取模  分库
table 以  订单创建时间  分表
写两个类，实现  PreciseShardingAlgorithm 精确分片算法，⼀个⽤于 db 取模，⼀个⽤于 table 按⽉份分片。
分库算法  DBShardingAlgorithm （取模分库）
DBShardingAlgorithm   实现  PreciseShardingAlgorithm 接⼝，⽤于根据订单  ID 进⾏数据库的精确分片，数
据库分库。
PreciseShardingAlgorithm：  主要⽤于处理  =  和  IN  操作的分片。当  SQL 语句中使⽤  =  或  IN  来筛选数据
时，该算法会根据分片键的值精确地确定数据应该存储在哪个分片上。
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.util.Collection;
// 实现  PreciseShardingAlgorithm 接⼝，⽤于根据订单  ID 进⾏数据库的精确分片
public class DBShardingAlgorithm implements PreciseShardingAlgorithm<Long> {
// 使⽤  SLF4J ⽇志框架记录⽇志
private static final Logger log = LoggerFactory.getLogger(DBShardingAlgorith
/*
* 实现精确分片的核⼼⽅法
* @param availableTargetNames 可⽤的数据库名称集合
* @param shardingValue 分片键的值，包含逻辑表名、分片列名和具体的值
* @return 分片后要使⽤的数据库名称
/
@Override
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 16/27

public String doSharding(Collection<String> availableTargetNames, PreciseSha
// 记录⽇志，表⽰进入数据库精确分片算法
log.info("DB PreciseShardingAlgorithm");
// 遍历可⽤的数据库名称集合，并记录每个数据库名称，⽅便调试查看
availableTargetNames.forEach(item -> log.info("actual node db:{}", item)
// 记录逻辑表名和分片列名，⽅便调试
log.info("logic table name:{},rout column:{}", shardingValue.getLogicTab
// 记录分片键的具体值，⽅便调试
log.info("column value:{}", shardingValue.getValue());
// 获取订单  ID
long orderId = shardingValue.getValue();
// 对订单  ID 进⾏取模操作，确定要使⽤的数据库索引，这⾥是 hash( orderId)   对  16 取模
long dbIndex = hash( orderId) % 16;
// ⽣成⽬标数据库名称，格式为  "db_" 加上数据库索引
String targetDb = "db_" + dbIndex;
// 遍历可⽤的数据库名称集合
for (String each : availableTargetNames) {
// 如果找到与⽬标数据库名称匹配的数据库
if (each.equals(targetDb)) {
// 返回该数据库名称
return each;
}
}
// 如果没有找到匹配的数据库，抛出异常
throw new IllegalArgumentException();
}
}
TableShardingAlgorithm  ⽉份分表
实现  PreciseShardingAlgorithm 接⼝，⽤于根据订单创建时间进⾏表的精确分片
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Date;
// 实现  PreciseShardingAlgorithm 接⼝，⽤于根据订单创建时间进⾏表的精确分片
public class TableShardingAlgorithm implements PreciseShardingAlgorithm<Date> {
// 使⽤  SLF4J ⽇志框架记录⽇志
private static final Logger log = LoggerFactory.getLogger(TableShardingAlgor
/*
* 实现精确分片的核⼼⽅法
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 17/27

* @param availableTargetNames 可⽤的表名称集合
* @param shardingValue 分片键的值，包含逻辑表名、分片列名和具体的值
* @return 分片后要使⽤的表名称
/
@Override
public String doSharding(Collection<String> availableTargetNames, PreciseSha
// 记录⽇志，表⽰进入表精确分片算法
log.info("table PreciseShardingAlgorithm");
// 遍历可⽤的表名称集合，并记录每个表名称，⽅便调试查看
availableTargetNames.forEach(item -> log.info("actual node table:{}", it
// 记录逻辑表名和分片列名，⽅便调试
log.info("logic table name:{},rout column:{}", shardingValue.getLogicTab
// 记录分片键的具体值，⽅便调试
log.info("column value:{}", shardingValue.getValue());
// 初始化表名前缀，为逻辑表名加上  ""
String tbName = shardingValue.getLogicTableName() + "";
// 获取订单创建时间
Date date = shardingValue.getValue();
// 创建⽇期格式化对象，⽤于格式化年份
SimpleDateFormat yearFormat = new SimpleDateFormat("yyyy");
// 创建⽇期格式化对象，⽤于格式化⽉份
SimpleDateFormat monthFormat = new SimpleDateFormat("MM");
// 格式化年份
String year = yearFormat.format(date);
// 格式化⽉份
String month = monthFormat.format(date);
// ⽣成完整的表名，格式为逻辑表名加上年份和⽉份
tbName = tbName + year + "_" + month;
// 记录⽣成的表名，⽅便调试
log.info("tb_name:{}", tbName);
// 遍历可⽤的表名称集合
for (String each : availableTargetNames) {
// 如果找到与⽣成的表名匹配的表
if (each.equals(tbName)) {
// 返回该表名称
return each;
}
}
// 如果没有找到匹配的表，抛出异常
throw new IllegalArgumentException();
}
}
application.properties 配置
db 以  订单 id 取模
table 以  订单创建时间  分库
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 18/27

// 配置  16 个数据源，数据源名称分别为  db_0 到  db_15
spring.shardingsphere.datasource.names=db_0,db_1,db_2,db_3,db_4,db_5,db_6,db_7,d
// 设置默认数据源为  db_0
spring.shardingsphere.sharding.default-data-source-name=db_0
// 配置  db_0 数据源的基本信息
// 数据源类型为  HikariDataSource ，这是⼀个⾼性能的  JDBC 连接池
spring.shardingsphere.datasource.db_0.type=com.zaxxer.hikari.HikariDataSource
// 数据库驱动类名，使⽤  MySQL 的  JDBC 驱动
spring.shardingsphere.datasource.db_0.driver-class-name=com.mysql.cj.jdbc.Driver
// 数据库连接  URL ，指定数据库地址、端⼝、数据库名以及⼀些连接参数
spring.shardingsphere.datasource.db_0.jdbc-url=jdbc:mysql://localhost:3306/db_0?
// 数据库⽤户名
spring.shardingsphere.datasource.db_0.username=root
// 数据库密码
spring.shardingsphere.datasource.db_0.password=root
// 其他  15 个数据源配置 ... （这⾥省略了其他数据源的详细配置，可按照  db_0 的配置⽅式依次添加）
// 配置  t_order 表的实际数据节点，数据会分布在  16 个数据库中，每个数据库中有  2025 年到  2026
spring.shardingsphere.sharding.tables.t_order.actual-data-nodes=db_$->{0..15}.t_
// ⾃定义  分片算法
// 分库分片健       database-strategy 数据库策略
// 指定分库的分片列名为  order_id
spring.shardingsphere.sharding.tables.t_order.database-strategy.standard.shardin
// ⾃定义  分片  策略
// 指定分库的精确分片算法类的全限定名
spring.shardingsphere.sharding.tables.t_order.database-strategy.standard.precise
//                  table-strategy   表  的  策略
// 指定分表的分片列名为  create_time
spring.shardingsphere.sharding.tables.t_order.table-strategy.standard.sharding-c
// 指定分表的精确分片算法类的全限定名
spring.shardingsphere.sharding.tables.t_order.table-strategy.standard.precise-al
// 使⽤  SNOWFLAKE 算法⽣成主键
// 指定主键⽣成的列名为  order_id
spring.shardingsphere.sharding.tables.t_order.key-generator.column=order_id
// 指定主键⽣成算法类型为  SNOWFLAKE
spring.shardingsphere.sharding.tables.t_order.key-generator.type=SNOWFLAKE
//   雪花算法的  workId   机器为标识  0 - 1024
// 设置雪花算法的⼯作机器  ID 为  123
spring.shardingsphere.sharding.tables.t_order.key-generator.props.worker.id=123
⼤功告成
八：优化、如何避免ID查询时的全库路由问题？
通过时间范围分表和 ID 取模分库的组合策略，可以有效提升查询性能和数据管理效率。
然⽽，如果没有时间  只有 id ，会发⽣全库路由问题。
如何优化  呢？
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 19/27

可以采⽤以下优化策略：
1. 引入异构索引表
异构索引表是⼀种 “ ⽤空间换时间 ” 的设计。
通过在写入数据时，将 ID 和时间范围信息同步存储到⼀张索引表中，可以在查询时快速定位到⽬标数据所在的
库和表。
1 创建索引表：
创建⼀张按时间范围分区的索引表，存储时间范围和对应的ID 列表。
CREATE TABLE order_time_index (
day DATE NOT NULL,
order_id VARCHAR(64) NOT NULL,
PRIMARY KEY (day, order_id)
) ENGINE=InnoDB
PARTITION BY RANGE (TO_DAYS(day)) (
PARTITION p20230901 VALUES LESS THAN (TO_DAYS('2023-09-02')),
PARTITION p20230902 VALUES LESS THAN (TO_DAYS('2023-09-03'))
);
2 写入时同步索引：
在写入数据时，同时将order_id和时间范围插入到索引表中。
3   查询优化：
查询时，先通过索引表定位到具体的order_id，再根据 ID 直接查询⽬标表。
2. 使⽤时间基因法
在 ID 中嵌入时间基因，使同⼀时间段的 ID 集中分布到特定分片。
例如，将订单 ID 设计为⽇期前缀  + 唯⼀序号，如20230901_0001。
步骤如下：
1 ⽣成含时间基因的 ID ：在⽣成订单 ID 时，嵌入时间信息。
2 分片规则：分表的时候，直接  根据⽇期前缀进⾏分片，
例如：
shard_id = (year_month) % 12  -- 例如 202309 → 9 % 12 = 9
3 查询优化：通过时间基因直接定位到⽬标分片，避免全库扫描。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 20/27

80分 答案  (⾼⼿级)
尼恩提⽰，讲完  组合模式的分库分表    ，  可以得到  80 分了。
但是要直接拿到⼤⼚ offer ，或者   offer 直提，需要  120 分答案。
尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
九、使⽤ 雪花id的时间基因， 解决ID查询时的全库路由问题？
雪花 id ⾥边，其实就有时间基因。雪花  ID （ Snowflake ID ）是⼀种分布式唯⼀  ID ⽣成算法，其⽣成的  ID 包含
了时间戳信息。
在使⽤雪花算法（ Snowflake Algorithm ）⽣成 ID 时，可以通过解析 ID 中的时间戳部分来计算其对应的时间范
围。以下是具体的实现⽅法和原理：
1. 雪花算法ID结构
雪花算法⽣成的 64 位 ID 由以下⼏部分组成：
符号位（ 1 位）：
始终为 0 ，表⽰ ID 为正数。
时间戳（ 41 位）：
表⽰⾃基准时间（如 2024 年 1 ⽉ 1 ⽇）以来的毫秒数。
数据中⼼ ID （ 5 位）
⽤于标识数据中⼼。 - 机器 ID （ 5 位）：
⽤于标识同⼀数据中⼼内的机器。
序列号（ 12 位）：
⽤于同⼀毫秒内⽣成的多个 ID 。
2. 如何计算ID的时间范围
雪花算法的时间戳部分记录了⽣成 ID 时的毫秒级时间戳。
2.1 提取时间戳
假设基准时间是2024-01-01 00:00:00，时间戳部分占 41 位，可以使⽤以下公式提取时间戳：
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 21/27

long timestamp = (id >> 22) + twepoch;
其中：
id  是⽣成的雪花 ID 。
twepoch  是基准时间戳（如1640995200000L，对应 2024 年 1 ⽉ 1 ⽇）。
22  是序列号部分的位数（ 12 位）加上数据中⼼ ID 和机器 ID 的位数（ 10 位）。
2.2 转换为具体时间
将提取的时间戳转换为具体的时间：
Date date = new Date(timestamp);
2.3 确定时间范围
根据提取的时间戳，可以确定 ID ⽣成的具体时间范围。
例如：如果 ID ⽣成于 2025 年 1 ⽉ 1 ⽇，那么时间范围可以是2025-01-01 00:00:00到2025-01-01
23:59:59。
3 雪花id ⾥边的时间戳值 作为分表基因的实操
使⽤  雪花 id ⾥边的时间戳值，作为  上⾯案例中  时间范围分表    的  ⽇期输入，  如何实现？
要使⽤雪花  ID ⾥的时间戳值作为上⾯案例中时间范围分表的⽇期输入，可按以下步骤实现：
3.1. 解析雪花 ID 中的时间戳
雪花  ID 的结构通常包含了⼀个时间戳部分，不同的雪花  ID 实现可能会有细微差异，但⼀般都可以从  ID 中提
取出时间戳信息。
⾸先定义⼀个 parse ，⽤于从雪花  ID 中提取时间戳并转换为⽇期：
public class SnowflakeIdParser {
// 假设雪花  ID 中时间戳部分从第  22 位开始，⻓度为  41 位
private static final long TIMESTAMP_SHIFT = 22;
// 雪花  ID 算法的起始时间戳（ 2020-01-01 00:00:00 ）
private static final long EPOCH = 1577836800000L;
public static java.util.Date getDateFromSnowflakeId(long snowflakeId) {
// 提取时间戳部分
long timestamp = (snowflakeId >> TIMESTAMP_SHIFT) + EPOCH;
return new java.util.Date(timestamp);
}
}
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 22/27

3.2. 修改表分片算法
在之前的  TableShardingAlgorithm  类基础上，修改  doSharding  ⽅法，使其可以接收雪花  ID 并从中提
取时间戳来确定表名。
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Date;
public class TableShardingAlgorithm implements PreciseShardingAlgorithm<Long> {
private static final Logger log = LoggerFactory.getLogger(TableShardingAlgor
@Override
public String doSharding(Collection<String> availableTargetNames, PreciseSha
log.info("table PreciseShardingAlgorithm");
availableTargetNames.forEach(item -> log.info("actual node table:{}", it
log.info("logic table name:{},rout column:{}", shardingValue.getLogicTab
log.info("column value:{}", shardingValue.getValue());
String tbName = shardingValue.getLogicTableName() + "";
// 从雪花  ID 中提取⽇期
Date date = SnowflakeIdParser.getDateFromSnowflakeId(shardingValue.getVa
SimpleDateFormat yearFormat = new SimpleDateFormat("yyyy");
SimpleDateFormat monthFormat = new SimpleDateFormat("MM");
String year = yearFormat.format(date);
String month = monthFormat.format(date);
tbName = tbName + year + "" + month;
log.info("tb_name:{}", tbName);
for (String each : availableTargetNames) {
if (each.equals(tbName)) {
return each;
}
}
throw new IllegalArgumentException();
}
}
3.3. 修改配置⽂件
确保  application.properties  中表分片的分片列配置为雪花  ID 所在的列（通常为  order_id），并且精
确分片算法类指向修改后的  TableShardingAlgorithm  类。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 23/27

// 其他配置保持不变
spring.shardingsphere.sharding.tables.t_order.table-strategy.standard.sharding-c
spring.shardingsphere.sharding.tables.t_order.table-strategy.standard.precise-al
如果没有时间  只有 id ，也不会发⽣全库路由问题了  。
未完待续：读写分离架构
在⾼并发场景中，读写分离是提⾼系统性能的有效⼿段。可以采⽤主从架构：
主库：
主库负责写入操作。
如何    实操实现？    尼恩下⼀篇⽂章给⼤家介绍。
从库：
主库负责读取操作。
如何    实操实现？    尼恩下⼀篇⽂章给⼤家介绍。
通过这种⽅式，可以将写请求和读请求分开，降低主库的负载。
主库的写入请求会⾃动同步到从库，确保数据⼀致性。
未完待续：动态扩容架构与实现
监控与调优：
定期监控数据库的性能指标，及时调整分库分表策略，以应对不断变化的业务需求。
监控与调优  如何    和读写分离同时实现？    尼恩下⼀篇⽂章给⼤家介绍。
动态扩展：
设计⽅案需⽀持动态扩展，随着数据量的增⻓，可以增加更多的数据库实例和表。
动态扩展    如何    和读写分离同时实现？    尼恩下⼀篇⽂章给⼤家介绍。
120分殿堂答案 (塔尖级)：
尼恩提⽰，讲完  动态库容、灰度切流  ，  可以得到  120 分了。
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 24/27

下⼀篇⽂章，    尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
遇到问题，找老架构师取经
借助此⽂，尼恩给解密了⼀个⾼薪的  秘诀，⼤家可以  放⼿⼀试。保证    屡试不爽，涨薪   100%-200% 。
后⾯，尼恩 java ⾯试宝典回录成视频，  给⼤家打造⼀套进⼤⼚的塔尖视频。
通过这个问题的深度回答，可以充分展⽰⼀下⼤家雄厚的  “ 技术肌⾁ ” ，让⾯试官爱到  “ 不能⾃已、⼝⽔直
流”，然后实现 ”offer 直提 ” 。
在⾯试之前，建议⼤家系统化的刷⼀波  5000 ⻚《尼恩 Java ⾯试宝典 PDF》，⾥边有⼤量的⼤⼚真题、⾯试难
题、架构难题。
很多⼩伙伴刷完后，  吊打⾯试官，  ⼤⼚横着走。
在刷题过程中，如果有啥问题，⼤家可以来  找  40 岁老架构师尼恩交流。
另外，如果没有⾯试机会，可以找尼恩来改简历、做帮扶。
遇到职业难题，找老架构取经，  可以省去太多的折腾，省去太多的弯路。
尼恩指导了⼤量的⼩伙伴上岸，前段时间，刚指导⼀个 40 岁 + 被裁⼩伙伴，拿到了⼀个年薪 100W 的 offer 。
狠狠卷，实现  “offer ⾃由 ” 很容易的，  前段时间⼀个武汉的跟着尼恩卷了 2 年的⼩伙伴，  在极度严寒 / 痛苦被裁
的环境下，  offer 拿到⼿软，  实现真正的  “offer ⾃由 ” 。
空窗 1 年 / 空窗 2 年，如何通过⼀份绝世好简历，    起死回⽣    ？
空窗 8 ⽉：中⼚⼤龄 34 岁，被裁 8 ⽉收⼀⼤⼚ offer ，  年薪 65W ，转架构后逆天改命 !
空窗 2 年： 42 岁被裁 2 年，天快塌了，急救 1 个⽉，拿到开发经理 offer ，起死回⽣
空窗半年： 35 岁被裁 6 个⽉，  职业绝望，转架构急救上岸， DDD 和 3 ⾼项⽬太重要了
空窗 1.5 年：失业 15 个⽉，学习 40 天拿 offer ，  绝境翻盘，如何实现？
100W 年薪    ⼤逆袭 ,   如何实现    ？
100W 案例， 100W 年薪的底层逻辑是什么？  如何实现年薪百万？  如何远离    中年危
机？
100W 案例 2：40岁⼩伙被裁 6 个⽉，猛卷 3 ⽉拿 100W 年薪  ，秘诀：⾸席架构 / 总架构
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 25/27

环境太糟，如何升  P8 级，年入 100W ？
如何    凭借    ⼀份绝世好简历，  实现逆天改命，包含 AI 、⼤数据、 golang 、 Java   等
逆天⼤涨：暴涨 200% ， 29 岁 /7 年 / 双非⼀本  ，  从 13K 涨到  37K ，如何做到的？
逆天改命： 27 岁被裁 2 ⽉，转 P6 降维攻击， 2 个⽉提  JD/PDD 两⼤ offer ，时来运转，
⼈⽣翻盘 !!   ⼤逆袭 !!
急救上岸： 29 岁（ golang ）被裁 3 ⽉，转架构降维打击，收 3 个⼤⼚ offer ，  年薪
60W ，逆天改命
绝地逢⽣：9 年经验⾃考⼩伙伴，跟着尼恩狠卷 3 ⽉硬核技术，⾯试机会爆表， 2
周后收 3 个 offer ，满⾎复活
职业救助站
实现职业转型，极速上岸
关注职业救助站公众号，获取每天职业⼲货
助您实现职业转型、职业升级、极速上岸
---------------------------------
技术⾃由圈
实现架构转型，再⽆中年危机
关注技术⾃由圈公众号，获取每天技术千货
⼀起成为⽜逼的未来超级架构师
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 26/27

⼏⼗篇架构笔记、5000⻚⾯试宝典、20个技术圣经
请加尼恩个⼈微信 免费拿走
暗号，请在 公众号后台 发送消息：领电⼦书
如有收获，请点击底部的"在看"和"赞"，谢谢
2025/6/4 凌晨 1:00 阿⾥⾯试：每天新增 100w 订单，如何的分库分表︖这份答案让我当场拿了 offer
https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg 27/27

