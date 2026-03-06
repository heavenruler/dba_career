阿⾥⼆⾯：10亿级分库分表，如何丝滑扩容、如何双写灰度？阿⾥
P8⽅案+ 架构图，看完直接上offer！
FSAC未来超级架构师
架构师总动员
实现架构转型，再⽆中年危机
尼恩说在前⾯
在 40 岁老架构师  尼恩的读者交流群(50+) 中，最近有⼩伙伴拿到了⼀线互联⽹企业如阿⾥、滴滴、极兔、有
赞、希⾳、百度、⽹易、美团的⾯试资格，遇到很多很重要的⾯试题：
每天新增 100w 订单，如何的分库分表？
10-100 亿级数据，如何的实现  分库分表    的  丝滑扩容？
尼恩提⽰：
分库分表，是⾯试的核⼼重点。
分库分表，是⾯试的核⼼重点、核⼼重点。
分库分表，是⾯试的核⼼重点、核⼼重点、核⼼重点、核⼼重点。
所以，这⾥尼恩给⼤家做⼀下系统化、体系化的梳理，使得⼤家可以充分展⽰⼀下⼤家雄厚的  “ 技术肌⾁ ” ，让
⾯试官爱到  “ 不能⾃已、⼝⽔直流 ”。也⼀并把这个题⽬以及参考答案，收入咱们的  《尼恩 Java ⾯试宝典 PDF》
V173 版本，供后⾯的⼩伙伴参考，提升⼤家的  3 ⾼  架构、设计、开发⽔平。
最新《尼恩  架构笔记》《尼恩⾼并发三部曲》《尼恩 Java ⾯试宝典》的 PDF ，请关注本公众号【技术⾃由圈】
获取，后台回复：领电⼦书
此⽂为上下两篇⽂章，    尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
本⽂的上⼀篇⽂章，
阿⾥⾯试：每天新增 100w 订单，如何的分库分表？这份答案让我当场拿了 offer
疯狂创客圈（技术⾃由架构圈）：⼀个  技术狂⼈、技术⼤神、⾼性能  发烧友  圈⼦。圈内⼀…
272 篇原创内容
技术⾃由圈
公众号
45岁老架构师尼恩 2025年03⽉08⽇ 13:49 湖北原创 技术⾃由圈
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 1/35

⽂章⽬录：
- 尼恩说在前⾯
- 尼恩解密：⾯试官的考察意图
- ⾯试官的考察意图
- ⼀、分库分表扩容 背景分析
- ⼆、 数据增⻓预测
- 短期趋势
- 中期趋势
- ⻓期趋势
- 三、分库分表丝滑扩容 ⾯临的问题与挑战
- 迁移时间过⻓：
- 准确性验证难：
- 数据⼀致性问题：
- 分布式事务问题：
- 业务中断⻛险：
- 四、分库分表丝滑扩容⽅案（核⼼：新旧双写+灰度切流+ 三级校验）
- 1、数据层架构
- 1.1 分片策略：
- 1.2 数据迁移服务
- 2、DAO 层双写架构
- 2.1 新旧双写模块
- 2.2 ⾃定义刚性事务管理器 / 刚柔结合的双事务架构
- 3、中⼼控制层
- 3.1 配置中⼼
- 3.2 灰度开关
- 5、定时任务
- 6、理论⼩结
- 五：实操1：数据双写同步
- 六：⾃研事务管理器，实现 刚性事务双写
- 6.1.  事务管理器定义
- 2.  事务持有器封装
- 6.2、关键实现细节
- 1.  数据源配置与绑定
- 2.  事务传播控制
- 6.3、异常处理与优化
- 6.4、验证与监控
- 1.  事务⼀致性验证
- 2.  监控指标
- 七：刚柔结合事务控制策略 ，提⾼主事务写入的成功率
- 1.  数据源定义与分片规则绑定
- 2.  事务管理器实现细节
- 3.  双写事务控制代码实现
- 7.2、分布式事务协调与异常处理
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 2/35

- 1.  柔性事务补偿机制
- 2.  数据⼀致性校验⼯具
- 7.4、性能优化与监控
- 1.  连接池与批量写入优化
- 2.  监控指标埋点
- 八：Nacos动态控制 双写开关设计
- 1.  Nacos配置项定义
- 2.  动态配置监听与加载
- 3.  双写逻辑改造
- 4.  路由策略动态切换
- 5、Nacos集成与运维管控
-  5.1配置监听与事件响应
- 5.2.  灰度发布与回滚策略
- 8.6、验证与监控⽅案
- 8.6.1.  双写开关⽣效验证
- 8.6.2   监控⼤盘设计
- 九、读流量灰度：使⽤动态数据源实现 灰度流量切换
- 9.1 动态数据源配置
- 9. 2定义不同的分片规则
- 9.3 DynamicDataSourceRouter  数据源上下⽂管理 和路由
- 数据源  Type 信息 的设置与清理
- 基于 Filter 实现灰度规则判断与清理（伪代码）
- 关键实现要点说明
- 总结  实现流程图
- 9.5. 业务代码 如何 使⽤动态数据源  ⾃动 灰度切流？
- 9.6. 业务代码 如 控制器的实例展⽰
- 注意事项
- ⼗：数据校验与回滚
- 10.1 校验服务（ 三级校验）
- 10.2 ⾃动修复
- 10.3 监控告警
- 120分殿堂答案 (塔尖级)：
- 遇到问题，找老架构师取经
尼恩解密：⾯试官的考察意图
⾯试官的考察意图
分库分表知识：
考察⾯试者对分库分表概念、原理和策略的理解，包括⽔平分库、⽔平分表、垂直分库、垂直分表的适⽤场景
和实现⽅式，看是否能针对  10 亿级数据量选择合适的分库分表⽅案。
扩容技术：
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 3/35

了解⾯试者对数据库扩容技术的掌握程度，如数据迁移、节点添加、负载均衡等，是否熟悉主流的扩容⽅法及
其优缺点。
考察是否了解与分库分表和扩容相关的其他技术，如分布式事务处理、数据⼀致性保证、缓存策略等，以判断
知识体系的完整性。
复 问题分析能⼒：
10 亿级 -10 0 亿级数据的分库分表扩容是复 问题，⾯试官想观察⾯试者能否清晰分析问题，考 数据量、数
据增⻓速度、业务场景、性能影响等多⽅⾯因素，提出合理的扩容思路和⽅案。
应对挑战能⼒：
扩容可能⾯临数据丢失、数据不⼀致、性能下降、业务中断等挑战，通过⾯试者的回答，了解其能否预⻅这些
问题，并给出有效的应对措施，评估解决实际问题的能⼒。
⼀、分库分表扩容 背景分析
随着业务的不断发展，⽤户数量、业务数据量呈爆发式增⻓。
以电商平台为例，从初创时每⽇⼏百笔订单，发展到后来每⽇数⼗万甚⾄数百万笔订单，订单数据、⽤户数
据、商品数据等不断累积，单个数据库表的数据量很快就会达到千万级甚⾄亿级。
当数据量达到⼀定规模后，数据库的读写性能会显著下降，数据的存储和管理也变得越来越困难
⼆、 数据增⻓预测
短期趋势
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 4/35

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
三、分库分表丝滑扩容 ⾯临的问题与挑战
分库分表丝滑扩容⾯临诸多问题与挑战，主要体现在数据迁移、⼀致性保证、性能波动、业务影响  等⽅⾯，具
体如下：
迁移时间过⻓：
对于  10 亿级数据，全量数据迁移耗时久，可能需要数天甚⾄数周时间。
期间若有新数据写入，还需不断进⾏增量数据迁移，增加了迁移的复 性和时间成本。
准确性验证难：
⼤量数据迁移过程中，可能出现数据丢失、重复、错误等情况。
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 5/35

要确保迁移后数据与原数据完全⼀致，进⾏全⾯、准确的验证⼯作难度⼤，需要耗费⼤量的⼈⼒和计算资源。
数据⼀致性问题：
在数据迁移到新的库表过程中，既要保证原库表数据的正常读写，⼜要确保新库表数据的准确写入和同步，可
能会出现数据在新旧库表之间不⼀致的情况。
例如，在迁移过程中发⽣⽹络故障、系统故障等，导致部分数据未成功迁移或迁移出现错误。
分布式事务问题：
扩容后，分布式事务涉及的节点和数据更多，协调和管理分布式事务的难度增⼤。不同数据库节点之间的事务
⼀致性保证更加困难，可能出现部分节点事务提交成功，部分节点失败的情况，从⽽导致数据不⼀致。
业务中断⻛险：
在扩容过程中，尤其是进⾏数据迁移和切换时，可能需要暂停部分业务的读写操作，否则可能会导致数据不⼀
致或数据丢失等问题。
即使采⽤⼀些灰度切换等策略，也很难完全避免对业务的短暂影响，如何在扩容过程中尽可能减少业务中断时
间，是⼀个重要挑战。
四、分库分表丝滑扩容⽅案（核⼼：新旧双写+灰度切流+ 三级校验）
本⽅案旨在通过多维度多层次的设计，实现分库分表的丝滑扩容，确保系统在数据量和流量增⻓时能够平 过
渡，不影响业务的正常运⾏。
⽅案涵盖应⽤ DAO 层、控制层、数据层以及定时任务等多个⽅⾯，形成⼀个全⾯化、系统化的扩容架构。
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 6/35

1、数据层架构
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 7/35

1.1 分片策略：
老库分片 1-N ，新库分片 1-2N
旧库按照既定的分片规则分为  N 个分片，
新库在旧库的基础上进⾏扩容，分为  2N 个分片，以应对未来数据量的增⻓。
确保分片键的选择合理，避免数据热点和分片不均的问题。
复合分片算法  ：采⽤⽤户 ID 哈希 + 时间范围双重路由策略，⽀持动态调整分片数量⽽不影响存量数
据分布
⼀致性哈希环  ：虚拟节点数设置为物理节点的 100 倍，确保扩容后数据均衡
1.2 数据迁移服务
全量数据迁移：
使⽤⾼效的多线程并发  数据迁移⼯具  datax 或者 kettle ，负责将旧库的数据全量迁移到新库。
在迁移过程中，使⽤迁移⼯具  datax 或者 kettle   处理数据类型转换、字段映射等问题，确保数据
的准确性和完整性。
采⽤时间窗⼝分片法，按创建时间顺序分批次迁移
同步偏移量双存储机制（ Redis+MySQL ），防⽌单点故障导致数据丢失
增量数据同步：
利⽤数据库的变更捕获技术（如  MySQL 的  Binlog ），实时同步旧库的增量数据到新库。
基于binlog+canal实现实时增量同步，延 控制在 500ms 内
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 8/35

确保在迁移期间，新库的数据能够与旧库保持同步更新。
数据双写同步：
MySQL Binlog 同步到新库  ，存在数据延 ，导致新库的数据  可能不⼀定能立即可⻅。
可以采⽤  双写同步架构，保障  ，新库的数据能够与旧库保持同步更新。
2、DAO层双写架构
2.1 新旧双写模块
在扩容过程中，确保新旧数据架构的⽆缝切换，避免数据丢失或不⼀致。
实现⽅式：
在数据写入时，同时将数据写入旧库和新库，确保数据的同步性。
提供配置项，可根据业务需求灵活控制双写的开关，便于在扩容前后进⾏切换。
2.2 ⾃定义刚性事务管理器 / 刚柔结合的双事务架构
刚性事务管理器：
针对关键业务操作，设计⾃定义的事务管理器，确保数据操作的原⼦性和⼀致性。
在新旧双写场景下，管理器需同时协调旧库和新库的事务，⼀旦任⼀库的操作失败，能够及时回滚
所有相关操作。
刚柔结合的双事务架构：
对于非关键业务，采⽤柔性事务处理，允许⼀定程度的数据最终⼀致性，通过消息队列等⽅式异步
处理数据同步。
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 9/35

结合刚性和柔性事务的优势，平衡系统的性能和数据⼀致性要求。
智能降级机制  ：在分片路由异常时⾃动切换⾄老库分片模式，保障服务可⽤性
3、中⼼控制层
3.1 配置中⼼
集中管理分库分表的相关配置，如分片规则、数据源信息等，实现配置的动态调整。
实现细节：
选⽤成熟的配置中⼼框架，如  Apollo 、 Nacos 等，确保配置的⾼可⽤性和低延 获取。
将分库分表的配置以键值对的形式存储，便于管理和修改。
提供配置的版本控制和回滚机制，防⽌因配置错误导致系统故障。
3.2 灰度开关
在扩容过程中，能够逐步放开流量，验证新架构的 定性和正确性。
实现⽅式：
在系统中设置灰度开关，通过配置中⼼动态控制开关状态。
初始阶段，仅允许部分⽤户或请求访问新库，其余仍访问旧库。
根据监控数据和业务指标，逐步调整灰度开关，增加新库的流量占比，直⾄完全切换。
多维灰度策略  ：⽀持按⽤户 ID 段、业务类型、地理区域等多维度流量切换
流量染⾊机制  ：通过请求头标记区分新老数据流向，实现灰度发布
灰度切换 ：按 5% 、 20% 、 50% 梯度逐步切换流量，每阶段观察 12 ⼩时
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 10/35

5、定时任务
定期对新旧库的数据进⾏比对，确保数据的⼀致性。
6、理论⼩结
本分库分表丝滑扩容⽅案通过在应⽤ DAO 层、控制层、数据层以及定时任务等多⽅⾯的设计和实现，形成了⼀
个全⾯化、系统化的扩容架构。
在实际的扩容过程中，需严格按照⽅案的步骤和要求进⾏操作，同时密切关注系统的运⾏状态和监控数据，及
时处理可能出现的问题，确保扩容的顺利进⾏和业务的 定运⾏。
接下来，讲究看看要点实操。
五：实操1：数据双写同步
在使⽤  Sharding-JDBC 进⾏数据双写同步前，需要配置两个数据源，分别对应旧库和新库。假设我们使⽤
Spring Boot 项⽬，在 application.yml ⽂件中进⾏如下配置：
spring:
shardingsphere:
datasource:
names: oldDataSource,newDataSource
oldDataSource:
driver-class-name: com.mysql.cj.jdbc.Driver
url: jdbc:mysql://old-db-host:3306/old_db?serverTimezone=UTC
username: old_user
password: old_password
newDataSource:
driver-class-name: com.mysql.cj.jdbc.Driver
url: jdbc:mysql://new-db-host:3306/new_db?serverTimezone=UTC
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 11/35

username: new_user
password: new_password
sharding:
default-database-strategy:
inline:
sharding-column: user_id
algorithm-expression: oldDataSource
tables:
your_table_name:
actual-data-nodes: oldDataSource.your_table_name,newDataSource.your_ta
上述配置定义了两个数据源 oldDataSource 和 newDataSource ，并通过  Sharding-JDBC 的分片策略，指定了
表 your_table_name 在两个数据源中的实际数据节点。
@Transactional
public void doubleWrite(String sql, Object... args) {
TransactionTypeHolder.set(TransactionType.XA);
try {
oldJdbcTemplate.update(sql, args);
newJdbcTemplate.update(sql, args);
} catch (Exception e) {
// 记录异常⽇志
log.error(" 数据双写失败 ", e);
// ⼿动回滚事务
TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();
} finally {
TransactionTypeHolder.clear();
}
}
解下来就是  事务⽅案。
六：⾃研事务管理器，实现 刚性事务双写
第⼀种事务⽅案：⾃研事务管理器，实现  刚性事务双写
实现跨  Sharding-JDBC 数据源的统⼀事务管理，强制两个数据源在同⼀个事务边界内提交或回滚
6.1.  事务管理器定义
通过扩展  AbstractPlatformTransactionManager  实现跨  Sharding-JDBC 数据源的统⼀事务管理，强
制两个数据源在同⼀个事务边界内提交或回滚  。
public class DualShardingTransactionManager extends AbstractPlatformTransactionM
private final DataSource dataSourceOld;  // 旧库分片数据源
private final DataSource dataSourceNew;  // 新库分片数据源
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 12/35

@Override
protected Object doGetTransaction() {
// 绑定两个数据源的 ConnectionHolder
return new DualTransactionHolder(
DataSourceUtils.getConnection(dataSourceOld),
DataSourceUtils.getConnection(dataSourceNew)
);
}
@Override
protected void doCommit(DefaultTransactionStatus status) {
DualTransactionHolder holder = (DualTransactionHolder) status.getTransac
try {
holder.getOldConnection().commit();  // 旧库提交
holder.getNewConnection().commit();  // 新库提交
} catch (SQLException e) {
throw new TransactionSystemException(" 双写提交失败 ", e);
}
}
@Override
protected void doRollback(DefaultTransactionStatus status) {
DualTransactionHolder holder = (DualTransactionHolder) status.getTransac
try {
holder.getOldConnection().rollback();  // 旧库回滚
holder.getNewConnection().rollback();  // 新库回滚
} catch (SQLException e) {
throw new TransactionSystemException(" 双写回滚失败 ", e);
}
}
}
2.  事务持有器封装
private static class DualTransactionHolder {
private final Connection oldConnection;
private final Connection newConnection;
public DualTransactionHolder(Connection oldConn, Connection newConn) {
this.oldConnection = oldConn;
this.newConnection = newConn;
}
}
6.2、关键实现细节
1.  数据源配置与绑定
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 13/35

// 旧库分片配置
shardingOld:
dataSources:
ds_old:
url: jdbc:mysql://old-db:3306/db_old
sharding:
tables:
order:
actualDataNodes: ds_old.order
// 新库分片配置
shardingNew:
dataSources:
ds0: jdbc:mysql://new-db0:3306/db_new
ds1: jdbc:mysql://new-db1:3306/db_new
sharding:
tables:
order:
actualDataNodes: ds$->{0..1}.order_$->{0..9}
2.  事务传播控制
在服务层通过  @Transactional  注解显式指定统⼀事务管理器：
@Service
public class OrderService {
@Transactional(transactionManager = "dualShardingTransactionManager")
public void createOrder(Order order) {
// 旧库分片写入
try (Connection oldConn = DataSourceUtils.getConnection(shardingOldDataS
oldOrderMapper.insert(order);
}
// 新库分片写入
try (Connection newConn = DataSourceUtils.getConnection(shardingNewDataS
newOrderMapper.insert(order);
}
}
}
关键点 ：
使⽤  DataSourceUtils.getConnection()  确保从统⼀事务上下⽂中获取连接
两个分片数据源的  SQL 操作需在同⼀线程内执⾏，避免跨线程事务失效
6.3、异常处理与优化
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 14/35

异常类型 处理⽅案
单数据源提交失
败 强制回滚另⼀个数据源的事务，避免部分提交
连接泄露 通过 DataSourceUtils.releaseConnection() 在 finally 块中释
放资源
6.4、验证与监控
1.  事务⼀致性验证
@Test
public void testDualCommit() {
transactionTemplate.execute(status -> {
oldOrderMapper.insert(order);
newOrderMapper.insert(order);
return null;
});
// 验证新旧库数据⼀致性
Assert.assertEquals(
oldOrderMapper.selectById(order.getId()),
newOrderMapper.selectByShardingKey(order.getMemberId())
);
}
2.  监控指标
指标 采集⽅式
双写事务平均耗
时
Micrometer 统计 dualShardingTransactionManager 提交耗时百
分位
连接持有时间 ⽇志记录 Connection 的 getConnection() 与 close() 时间戳差值
该⽅案通过⾃定义事务管理器实现跨  Sharding-JDBC 数据源的强⼀致性事务，适⽤于对数据⼀致性要求严苛
的双写迁移场景   。
新库如何写入失败，  会对业务产⽣影响。
不建议采⽤这种⽅式。
七：刚柔结合事务控制策略 ，提⾼主事务写入的成功率
在双写场景下，我们需要对主事务（旧库）和⼦事务（新库）采⽤不同的事务控制策略，以保证数据的⼀致性
和系统的 定性。
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 15/35

1.  数据源定义与分片规则绑定
旧库数据源配置 ：
application.yml
oldDataSource:
driver-class-name: com.mysql.jdbc.Driver
url: jdbc:mysql://old-db:3306/db_old
username: root
password: 123456
新库分片数据源配置 ：
shardingDataSource:
dataSources:
ds0:
driver-class-name: com.mysql.jdbc.Driver
url: jdbc:mysql://new-db0:3306/db_new
username: root
password: 123456
ds1:
driver-class-name: com.mysql.jdbc.Driver
url: jdbc:mysql://new-db1:3306/db_new
username: root
password: 123456
shardingRule:
tables:
order:
actualDataNodes: ds$->{0..1}.order_$->{0..9}
tableStrategy:
inline:
shardingColumn: member_id
algorithmExpression: order_$->{member_id % 10}
databaseStrategy:
inline:
shardingColumn: member_id
algorithmExpression: ds$->{member_id % 2}
关键点 ：
新库通过 Sharding-JDBC 定义分片规则，按member_id分库分表  45
旧库保持单库单表结构，与新库分片规则需兼容（如member_id取模逻辑⼀致）  58
2.  事务管理器实现细节
事务管理器定义  ：
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 16/35

@Configuration
public class TransactionConfig {
// 旧库事务管理器
@Bean(name = "transactionManagerOld")
public PlatformTransactionManager oldTransactionManager(
@Qualifier("oldDataSource") DataSource dataSource) {
return new DataSourceTransactionManager(dataSource);
}
// 新库分片事务管理器（绑定 ShardingSphere 数据源）
@Bean(name = "transactionManagerSplit")
public PlatformTransactionManager splitTransactionManager(
@Qualifier("shardingDataSource") DataSource shardingDataSource) {
return new DataSourceTransactionManager(shardingDataSource);
}
}
功能说明  ：
transactionManagerOld管理旧库的本地事务，保证 ACID 特性
transactionManagerSplit管理新库的分布式事务，⽀持跨分片操作
3.  双写事务控制代码实现
服务层代码 ：
@Service
public class OrderService {
@Autowired
private OrderRepositoryOld oldRepository;
@Autowired
private OrderRepositoryNew newRepository;
@Transactional(
propagation = Propagation.REQUIRED,
transactionManager = "transactionManagerOld",
rollbackFor = Exception.class
)
public void createOrder(Order order) {
// 主事务：旧库写入（强⼀致性）
oldRepository.insert(order);
// ⼦事务：新库分片写入（独立事务）
writeToShardingDB(order);
}
@Transactional(
propagation = Propagation.REQUIRES_NEW,
transactionManager = "transactionManagerSplit",
noRollbackFor = {ShardingException.class}
)
private void writeToShardingDB(Order order) {
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 17/35

try {
newRepository.insert(order);
} catch (ShardingException e) {
// 分片路由失败时记录⽇志，不触发主事务回滚
log.error(" 分片写入失败 : orderId={}", order.getId());
mqSender.sendRetryMessage(order);
}
}
}
关键逻辑 ：
主事务（旧库）使⽤REQUIRED传播，确保原⼦性
⼦事务（新库）使⽤REQUIRES_NEW传播，独立提交或回滚
新库写入异常时，通过 MQ 异步补偿保证最终⼀致性
7.2、分布式事务协调与异常处理
1.  柔性事务补偿机制
补偿消费者实现 ：
@Component
@RocketMQMessageListener(topic = "ORDER_RETRY", consumerGroup = "retry-group")
public class OrderRetryConsumer implements RocketMQListener<Order> {
@Override
public void onMessage(Order order) {
// 独立事务重试新库写入
TransactionTemplate transactionTemplate = new TransactionTemplate(transa
transactionTemplate.execute(status -> {
newRepository.insert(order);
return true;
});
}
}
补偿策略 ：
重试队列采⽤指数退避策略（如 1s/5s/30s ）
最⼤重试次数限制（如 3 次），超限后触发⼈⼯⼲预
2.  数据⼀致性校验⼯具
校验逻辑⽰例 ：
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 18/35

public void verifyData(Order order) {
// 旧库查询
Order oldOrder = oldRepository.selectById(order.getId());
// 新库分片查询（需计算分片路由）
String actualNode = shardingAlgorithm.getActualDataNode(order.getMemberId())
Order newOrder = newRepository.selectByShardingKey(actualNode, order.getId()
Assert.isTrue(oldOrder.equals(newOrder), " 数据不⼀致 ");
}
校验维度 ：
主键覆盖完整性（新旧库主键范围⼀致）
关键字段⼀致性（⾦额、状态等）
7.4、性能优化与监控
1.  连接池与批量写入优化
连接池隔离配置 ：
// 旧库使⽤ Druid
oldDataSource:
type: com.alibaba.druid.pool.DruidDataSource
initialSize: 5
maxActive: 20
// 新库使⽤ HikariCP
shardingDataSource:
hikari:
maximum-pool-size: 50
connection-timeout: 5000
批量插入优化 ：
sqlCopy CodeINSERT INTO order_new_${shard} (id, member_id) VALUES (?, ?)
ON DUPLICATE KEY UPDATE member_id=VALUES(member_id)
启⽤rewriteBatchedStatements=true提升批量性能
2.  监控指标埋点
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 19/35

指标 采集⽅式 告警规则
双写事务TPS 通过Micrometer统计transactionManagerS
plit的提交频率
连续5分钟下降50%触
发告警
分片路由失败
率
⽇志分析ShardingSphere的ShardingRouteE
xception 失败率 > 1%触发告警
异步补偿队列
堆积量 RocketMQ控制台监控ORDER_RETRY队列⻓度 堆积量 > 1000触发扩
容
通过以上⽅案，可在 Sharding-JDBC 双写场景下实现⾼可靠的事务管理，结合刚性事务与柔性事务的优势，保
障迁移过程的数据⼀致性与系统 定性
八：Nacos动态控制 双写开关设计
注意我们需要提供⼀个动态开关，去控制开启和关闭新表的写入。
因为需求上线之后，  先同步⼀阶段  老的数据，  同步完毕之后开启同这个开关完成⽆缝对接。
另外，如果新库故障，也可以及时把这个开关关闭。
1.  Nacos配置项定义
在 Nacos 中创建配置项  dual-write-config（ Data ID ），包含以下内容：
dualWrite:
enabled: true  # 双写开关
forceReadNew: false  # 强制读新库
作⽤ ：
enabled  控制是否开启新库写入
forceReadNew  ⽤于灰度阶段强制查询新库（如数据校验完成后）
2.  动态配置监听与加载
配置类实现 ：
@Configuration
@RefreshScope
public class DualWriteConfig {
@Value("${dualWrite.enabled:false}")
private AtomicBoolean enabled;
@Value("${dualWrite.forceReadNew:false}")
private AtomicBoolean forceReadNew;
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 20/35

// 提供线程安全的开关状态访问
public boolean isDualWriteEnabled() {
return enabled.get();
}
public boolean isForceReadNew() {
return forceReadNew.get();
}
}
关键点 ：
使⽤  @RefreshScope  注解实现配置热更新
AtomicBoolean 保证多线程环境下的状态⼀致性
3.  双写逻辑改造
服务层代码改造 ：
@Service
public class OrderService {
@Autowired
private DualWriteConfig dualWriteConfig;
@Transactional(transactionManager = "transactionManagerOld")
public void createOrder(Order order) {
// 旧库必写
oldRepository.insert(order);
// 根据开关判断是否写入新库
if (dualWriteConfig.isDualWriteEnabled()) {
writeToShardingDB(order);
}
}
@Transactional(propagation = Propagation.REQUIRES_NEW,
transactionManager = "transactionManagerSplit")
private void writeToShardingDB(Order order) {
newRepository.insert(order);
}
}
优化点 ：
双写开关⽣效时，主事务仅提交旧库，⼦事务异步处理新库写入
开关关闭后，通过增量同步⼯具（如 Canal ）补偿新库数据
4.  路由策略动态切换
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 21/35

查询路由适配 ：
public Order getOrder(Long orderId) {
if (dualWriteConfig.isForceReadNew()) {
// 强制路由到新库分片
try (HintManager hintManager = HintManager.getInstance()) {
hintManager.setMasterRouteOnly();
return newRepository.selectByShardingKey(orderId);
}
} else {
return oldRepository.selectById(orderId);
}
}
说明 ：
通过  HintManager  强制指定分片路由，⽤于灰度验证阶段
5、Nacos集成与运维管控
5.1配置监听与事件响应
Nacos 监听器注册 ：
@PostConstruct
public void initNacosListener() {
ConfigService configService = NacosFactory.createConfigService(nacosProps);
configService.addListener("dual-write-config", "DEFAULT_GROUP", new Abstract
@Override
public void receiveConfigInfo(String configInfo) {
log.info(" 双写配置变更 : {}", configInfo);
// 触发配置刷新（结合 @RefreshScope ）
refreshScope.refreshAll();
}
});
}
监控指标 ：
配置变更次数（ Nacos 控制台）
双写开关状态（通过 /metrics 端点暴露）  23
5.2.  灰度发布与回滚策略
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 22/35

阶段 操作步骤
灰度开启双写 1. Nacos修改dualWrite.enabled=true 2. 监控新库写入成功率与延迟
全量切换 1. 开启forceReadNew=true 2. 停⽤增量同步⼯具
异常回滚 1. 关闭双写开关 2. 启动反向同步⼯具回补旧库数据
8.6、验证与监控⽅案
8.6.1.  双写开关⽣效验证
// 单元测试验证开关⾏为
@Test
public void testDualWriteSwitch() {
// 初始状态 : 开关开启
orderService.createOrder(order);
assertExistInBothDB(order);
// 动态关闭开关
updateNacosConfig("dualWrite.enabled", "false");
orderService.createOrder(order2);
assertOnlyInOldDB(order2);
}
8.6.2   监控⼤盘设计
监控项 采集⽅式 告警阈值
双写开关状态 通过Spring Actuator暴露配置状态 状态异常持续1分钟
新库写入TPS Micrometer统计transactionManagerSplit提交 TPS下降50%
增量同步延迟 Canal监控Binlog消费延迟 延迟 > 60s
通过 Nacos 动态控制双写开关，可在不重启服务的情况下灵活调整数据流向，结合事务管理器与路由策略，实
现平滑迁移与快速故障恢复  。
九、读流量灰度：使⽤动态数据源实现 灰度流量切换
为了在  Sharding-JDBC 中  实现灰度流量切换，这⾥  使⽤动态数据源。
动态数据源  借助  Spring 的  AbstractRoutingDataSource  来实现动态数据源的切换 / 灰度流量的灰度切
流。
以下是具体的实现步骤
9.1 动态数据源配置
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 23/35

创建⼀个类来加载不同版本的  Sharding-JDBC 配置⽂件，  创建主库（旧规则）和灰度库（新规则）两个
Sharding-JDBC 数据源实例，
使⽤  AbstractRoutingDataSource  并创建  动态数据源  ，  实现动态路由，    通过  @Bean  注解注入  Spring
容器。
import org.apache.shardingsphere.api.config.sharding.ShardingRuleConfiguration;
import org.apache.shardingsphere.shardingjdbc.api.ShardingDataSourceFactory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import javax.sql.DataSource;
import java.sql.SQLException;
import java.util.HashMap;
import java.util.Map;
import java.util.Properties;
// 使⽤  @Configuration 注解将该类标记为  Spring 配置类， Spring 会⾃动扫描并处理其中的  Bean
@Configuration
public class DataSourceConfig {
/
* @throws SQLException 当创建数据源过程中出现  SQL 相关异常时抛出
*/
@Bean(name = "oldDataSource")
public DataSource oldDataSource() throws SQLException {
// 调⽤  loadShardingRuleConfig ⽅法，从  "old-sharding-rule.yaml" ⽂件中加载旧
ShardingRuleConfiguration oldShardingRuleConfig = loadShardingRuleConfig
// 使⽤  ShardingDataSourceFactory 创建旧版本的分片数据源，传入数据源映射、分片规则
return ShardingDataSourceFactory.createDataSource(createDataSourceMap()
}
/
* 创建并返回新版本的分片数据源  Bean
* @return 新版本的分片数据源
* @throws SQLException 当创建数据源过程中出现  SQL 相关异常时抛出
/
@Bean(name = "newDataSource")
public DataSource newDataSource() throws SQLException {
// 调⽤  loadShardingRuleConfig ⽅法，从  "new-sharding-rule.yaml" ⽂件中加载新
ShardingRuleConfiguration newShardingRuleConfig = loadShardingRuleConfig
// 使⽤  ShardingDataSourceFactory 创建新版本的分片数据源，传入数据源映射、分片规则
return ShardingDataSourceFactory.createDataSource(createDataSourceMap()
}
/
* 创建并返回动态数据源  Bean ，作为主要的数据源
* @return 动态数据源
/
@Bean
@Primary
public DataSource dynamicDataSource() {
// 创建⼀个  HashMap ⽤于存储⽬标数据源，键为数据源名称，值为数据源对象
Map<Object, Object> targetDataSources = new HashMap<>();
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 24/35

try {
// 将旧版本的分片数据源添加到⽬标数据源映射中，键为  "old"
targetDataSources.put("old", oldDataSource());
// 将新版本的分片数据源添加到⽬标数据源映射中，键为  "new"
targetDataSources.put("new", newDataSource());
} catch (SQLException e) {
// 若创建数据源过程中出现  SQL 异常，打印异常堆栈信息
e.printStackTrace();
}
// 创建动态数据源路由对象
DynamicDataSourceRouter dataSource = new DynamicDataSourceRouter();
// 设置动态数据源的⽬标数据源映射
dataSource.setTargetDataSources(targetDataSources);
try {
// 设置动态数据源的默认⽬标数据源为旧版本的分片数据源
dataSource.setDefaultTargetDataSource(oldDataSource());
} catch (SQLException e) {
// 若设置默认数据源过程中出现  SQL 异常，打印异常堆栈信息
e.printStackTrace();
}
return dataSource;
}
/
* 从指定的配置⽂件中加载分片规则配置
* @param configFile 配置⽂件的名称
* @return 分片规则配置对象
/
private ShardingRuleConfiguration loadShardingRuleConfig(String configFile)
// 此处需要实现从配置⽂件加载  ShardingRuleConfiguration 的具体逻辑
//   需要根据实际情况进⾏实现
return null;
}
}
9. 2定义不同的分片规则
⾸先，需要为旧版本和新版本分别定义不同的  Sharding-JDBC 分片规则。
旧版本规则⽰例（ old-sharding-rule.yaml ）
dataSources:
ds_0:
url: jdbc:mysql://localhost:3306/ds_0
username: root
password: root
driverClassName: com.mysql.cj.jdbc.Driver
shardingRule:
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 25/35

tables:
t_order:
actualDataNodes: ds_0.t_order_$->{0..1}
tableStrategy:
inline:
shardingColumn: order_id
algorithmExpression: t_order_$->{order_id % 2}
新版本规则⽰例（ new-sharding-rule.yaml ）
dataSources:
ds_0:
url: jdbc:mysql://localhost:3306/ds_0
username: root
password: root
driverClassName: com.mysql.cj.jdbc.Driver
ds_1:
url: jdbc:mysql://localhost:3306/ds_1
username: root
password: root
driverClassName: com.mysql.cj.jdbc.Driver
shardingRule:
tables:
t_order:
actualDataNodes: ds_$->{0..1}.t_order_$->{0..1}
tableStrategy:
inline:
shardingColumn: order_id
algorithmExpression: t_order_$->{order_id % 2}
databaseStrategy:
inline:
shardingColumn: user_id
algorithmExpression: ds_$->{user_id % 2}
9.3 DynamicDataSourceRouter  数据源上下⽂管理 和路由
创建⼀个继承⾃  AbstractRoutingDataSource  的⼦类，⽤于根据⼀定的规则动态切换数据源。
public class DynamicDataSourceRouter extends AbstractRoutingDataSource {
@Override
protected Object determineCurrentLookupKey() {
return DataSourceContextHolder.getDataSourceType();
}
}
⾃定义  DynamicDataSourceRouter  继承  AbstractRoutingDataSource，
通过  DataSourceContextHolder ⼯具类来保存和获取当前使⽤的数据源  Type 信息  。
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 26/35

DataSourceContextHolder ⼯具类  的数据源   Type 信息    从  ThreadLocal  获取当前数据源标识。
public class DataSourceContextHolder {
private static final ThreadLocal<String> contextHolder = new ThreadLocal<>()
public static void setDataSource(String dataSource) {
contextHolder.set(dataSource);
}
public static String getDataSource() {
return contextHolder.get();
}
public static void clearDataSource() {
contextHolder.remove();
}
}
数据源  Type 信息 的设置与清理
下⾯的多数据源路由的例⼦中， DataSourceContextHolder 的设置逻辑，如下
// 根据⽤户  ID 决定使⽤哪个数据源
if (Integer.parseInt(userId) % 2 == 0) {
DataSourceContextHolder.setDataSource("new");
} else {
DataSourceContextHolder.setDataSource("old");
}
尼恩提⽰：如何在 springboot 的 request 请求处理之前，通过 filter 设置，然后在请求处理完了之后，进⾏清除
呢？
基于 Filter 实现灰度规则判断与清理（伪代码）
@Component
public class DataSourceSwitchFilter implements Filter {
@Override
public void doFilter(ServletRequest request, ServletResponse response, Filte
throws IOException, ServletException {
HttpServletRequest httpRequest = (HttpServletRequest) request;
try {
// 1. 从请求头获取灰度标识（⽰例取 user-id ）
String userId = httpRequest.getHeader("user-id");
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 27/35

// 2. 执⾏灰度规则判断（⽰例： 20% 流量切到新库）
if (StringUtils.isNotBlank(userId) &&
Integer.parseInt(userId) % 100 < 20) {
DataSourceContextHolder.setDataSource("new");
} else {
DataSourceContextHolder.setDataSource("old");
}
// 3. 继续执⾏后续请求处理
chain.doFilter(request, response);
} finally {
// 4. 强制清理线程变量（关键步骤）
DataSourceContextHolder.clearDataSource();
}
}
}
Spring Boot 配置类注册  Filter
@Configuration
public class FilterConfig {
@Bean
public FilterRegistrationBean<DataSourceSwitchFilter> registerFilter() {
FilterRegistrationBean<DataSourceSwitchFilter> bean = new FilterRegistra
bean.setFilter(new DataSourceSwitchFilter());
bean.addUrlPatterns("/*"); // 拦截所有请求路径
bean.setOrder(Ordered.HIGHEST_PRECEDENCE); // 最⾼优先级确保最先执⾏
return bean;
}
}
关键实现要点说明
1 灰度标识获取优化
⽀持多维度参数判断，可扩展从  Cookie 、 Session 或  JWT 中提取灰度标记：
// ⽰例：从请求参数获取
String grayFlag = httpRequest.getParameter("gray-version");
// ⽰例：从认证信息获取（需结合  Spring Security ）
Authentication auth = SecurityContextHolder.getContext().getAuthentication()
2 异常处理增强 添加灰度参数校验逻辑避免  NumberFormatException ：
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 28/35

try {
if (StringUtils.isNumeric(userId)) {
// 执⾏模运算判断
}
} catch (Exception e) {
log.error(" 灰度参数解析异常 ", e);
}
<br>**3 动态规则扩展 ** <br> 结合  Nacos/Apollo 实现动态调整灰度比例（需添加配置监听器）  ： <br
@RefreshScope
@Configuration
public class GrayRuleConfig {
@Value("${gray.ratio:20}")
private int grayRatio; // 通过配置中⼼动态修改
}
4   流量染⾊验证
在数据源切换后添加验证⽇志：
log.info(" 当前数据源 : {} ，灰度⽤户 ID: {}",
DataSourceContextHolder.getDataSource(), userId);
<br> 对数据源交叉污染现象进⾏检查。 <br><br><br>**5 压⼒测试验证 ** <br>   使⽤  JMeter 模拟⾼
textCopy CodeHTTP Request
│
▼
[DataSourceSwitchFilter] → 解析灰度标识  → 设置 ThreadLocal
│
▼
[Controller] → 业务处理  → 通过 AbstractRoutingDataSource ⾃动路由 :ml-citation{ref="3"
│
▼
[Response] ←  清理 ThreadLocal （ finally 块保障）
该⽅案通过  Servlet Filter 实现了请求维度的数据源⽣命周期管理，确保每次请求结束后⾃动清理线程变量，
避免内存泄漏和跨请求污染   。
灰度场景，需要结合配置中⼼实现灰度规则动态调整   。
9.5. 业务代码 如何 使⽤动态数据源  ⾃动 灰度切流？
其实很简单了，业务代码是⽆感知的。
在业务代码中根据⼀定的规则（如⽤户  ID ）来决定使⽤哪个数据源。
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 29/35

import org.springframework.stereotype.Service;
import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
@Service
public class BusinessService {
@Autowired
private DataSource routingDataSource;
public void queryOrder(String userId) {
// 根据⽤户  ID 决定使⽤哪个数据源
try (Connection connection = routingDataSource.getConnection();
PreparedStatement preparedStatement = connection.prepareStatement(
preparedStatement.setString(1, userId);
ResultSet resultSet = preparedStatement.executeQuery();
while (resultSet.next()) {
// 处理查询结果
}
} catch (SQLException e) {
e.printStackTrace();
} finally {
// 清除数据源上下⽂
DataSourceContextHolder.clearDataSource();
}
}
}
9.6. 业务代码 如 控制器的实例展⽰
其实很简单了，业务代码是⽆感知的。
创建⼀个简单的控制器来测试灰度流量切换功能。
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RestController;
@RestController
public class OrderController {
@Autowired
private BusinessService businessService;
@GetMapping("/orders/{userId}")
public String queryOrder(@PathVariable String userId) {
businessService.queryOrder(userId);
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 30/35

return "Query order success";
}
}
注意事项
异常处理：
在实际应⽤中，需要对数据源创建、数据库操作等过程中的异常进⾏更完善的处理。
配置⽂件加载：
loadShardingRuleConfig  和  createDataSourceMap  ⽅法需要根据实际情况实现从配置⽂件加载
Sharding-JDBC 规则和数据源信息的逻辑。
线程安全：
由于使⽤了  ThreadLocal  来保存数据源信息，要确保在多线程环境下不会出现数据混乱的问题。
通过以上步骤，  可以在  Sharding-JDBC 中实现基于动态数据源的灰度流量切换。
⼗：数据校验与回滚
10.1 校验服务（ 三级校验）
定期对新旧库的数据进⾏比对，确保数据的⼀致性。
三级校验策略 ：
字段级校验（⼩时级）
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 31/35

选取表中关键字段（如主键、时间戳、业务核⼼字段）作为比对基准，避免全字段比对带来的性能损耗
⾏级 md5 比对（每⽇低⾕期）
通过MD5()函数⽣成哈希值（ MySQL ⽰例：SELECT MD5(col_str) FROM table）
统计指标校验（周级）
分片维度的  记录数
实现细节：
定时任务，定期按照数据的时间戳顺序，分批次对新旧库的数据进⾏比对。
对于比对发现的不⼀致数据，记录详细的信息，包括数据 ID 、字段差异等。
10.2 ⾃动修复
修复策略：
对于数据比对发现的不⼀致情况，设计⾃动归档机制。
修复流程：
异常数据⾃动归档待⼈⼯核查  。
执⾏修复操作，并记录修复⽇志，便于后续审计和问题追溯。
10.3 监控告警
监控指标：
设定关键的监控指标，如数据迁移进度、数据⼀致性比率、系统性能指标等。
通过监控⼯具实时采集这些指标数据，为系统的运⾏状态提供直观的展⽰。
告警机制：
当监控指标超出预设的阈值时，触发告警机制，通知相关⼈员及时处理。
告警⽅式可包括邮件、短信、即时通讯⼯具等多种渠道，确保告警信息能够及时送达。
监控指标体系
监控维度 核⼼指标 告警阈值
事务⼀致性 双写成功率 <99.9% (5分钟)
数据完整性 校验差异率 >0.01%
性能指标 分片P99延迟 >500ms
120分殿堂答案 (塔尖级)：
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 32/35

尼恩提⽰，到了这⾥，讲完  动态库容、灰度切流  ，  可以得到  120 分了。
此⽂上⼀篇⽂章，    尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
阿⾥⾯试：每天新增 100w 订单，如何的分库分表？这份答案让我当场拿了 offer
遇到问题，找老架构师取经
借助此⽂，尼恩给解密了⼀个⾼薪的答题  秘诀，⼤家可以  放⼿⼀试。⼀定会  屡试不爽，涨薪
100%-200% 。
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
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 33/35

100W 年薪    ⼤逆袭 ,   如何实现    ？
100W 案例， 100W 年薪的底层逻辑是什么？  如何实现年薪百万？  如何远离    中年危
机？
100W 案例 2：40岁⼩伙被裁 6 个⽉，猛卷 3 ⽉拿 100W 年薪  ，秘诀：⾸席架构 / 总架构
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
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 34/35

技术⾃由圈
实现架构转型，再⽆中年危机
关注技术⾃由圈公众号，获取每天技术千货
⼀起成为⽜逼的未来超级架构师
⼏⼗篇架构笔记、5000⻚⾯试宝典、20个技术圣经
请加尼恩个⼈微信 免费拿走
暗号，请在 公众号后台 发送消息：领电⼦书
如有收获，请点击底部的"在看"和"赞"，谢谢
2025/6/4 凌晨 12:26 阿⾥⼆⾯： 10 亿级分库分表，如何丝滑扩容、如何双写灰度︖阿⾥ P8 ⽅案 + 架构图，看完直接上 offer ！
https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA 35/35

