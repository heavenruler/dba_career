去哪⾯试：1W tps⾼并发，MySQL 热点⾏ 问题， 怎么解决？
FSAC未来超级架构师
架构师总动员
实现架构转型，再⽆中年危机
说在前⾯
在 45 岁老架构师  尼恩的读者交流群(50+) 中，最近有⼩伙伴拿到了⼀线互联⽹企业如得物、阿⾥、滴滴、极
兔、有赞、希⾳、百度、⽹易、美团、⼩米、  去哪⼉的⾯试资格，遇到很多很重要的⾯试题：：
1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决？
MySQL 转账    热点⾏  问题，  怎么解决？
最近有⼩伙伴在⾯试  去哪⼉，⼜遇到了相关的⾯试题。⼩伙伴懵了，因为没有遇到过，所以⽀⽀吾吾的说了⼏
句，⾯试官不满意，⾯试挂了。
所以，尼恩给⼤家做⼀下系统化、体系化的梳理，使得⼤家内⼒猛增，可以充分展⽰⼀下⼤家雄厚的  “ 技术肌
⾁ ” ，让⾯试官爱到  “ 不能⾃已、⼝⽔直流 ”，然后实现 ”offer 直提 ” 。
当然，这道⾯试题，以及参考答案，也会收入咱们的  《尼恩 Java ⾯试宝典 PDF》 V171 版本，供后⾯的⼩伙伴
参考，提升⼤家的  3 ⾼  架构、设计、开发⽔平。
最新《尼恩  架构笔记》《尼恩⾼并发三部曲》《尼恩 Java ⾯试宝典》的 PDF ，请关注本公众号【技术⾃由圈】
获取，回复：领电⼦书
问题分析：mysql 热点⾏ 问题 ，到底有多么严重
结合互联⽹真实的⾼并发场景（比如双⼗⼀、秒 活动），来看看   mysql 热点问题  ，到底有多么严重。
疯狂创客圈（技术⾃由架构圈）：⼀个  技术狂⼈、技术⼤神、⾼性能  发烧友  圈⼦。圈内⼀…
272 篇原创内容
技术⾃由圈
公众号
尼恩架构团队 2025年03⽉27⽇ 14:55 湖北原创 技术⾃由圈
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 1/22

为什么热点操作会卡死？
1.  锁的“独⽊桥”问题
⼀把 myql 记录锁，就是⼀条只能过⼀个⼈的独⽊桥，⼀堆⼈抢着过桥，后⾯的⼈只能排队。
MySQL 的热点⾏更新就是  “ 独⽊桥 ”   逻辑：     转账  修改，就是⼤家  挤上独⽊桥，  去同⼀⾏数据（比如账户 A 扣
钱，账户 B 加钱），每个事务都要给这⾏数据加锁  ，导致所有操作必须排队。
真实案例 ：
某电商平台在双⼗⼀期间，因⽤户频繁充值，  ⽤户充值⼀般都是到同⼀个账户（比如    ⼀个  公共的平台红包账
户）。
突发流量场景，    导致  平台红包账户    的  余额⾏成为热点， TPS 从正常的 1000 提升到  10000 ，甚⾄  10W ，系统
⼏乎瘫痪。
2. 死锁检测的“资源内耗”问题——  雪上加霜
当多个事务互相等待对⽅释放锁时，就会死锁。
真实案例 ：
某社交平台的⽀付系统，在死锁检测开启时， CPU 利⽤率⾼达 90% ，关闭死锁检测后降到 40% ，但代价是超
时事务增加（需要业务层重试）。
MySQL 有⼀个死锁检测机制，（类似  “ 交警 ” ）负责处理这种情况，但交警⾃⼰也要消耗资源。
假设 10 个⼈同时转账给同⼀个⼈，事务 1 锁了⾏ A 等⾏ B ，事务 2 锁了⾏ B 等⾏ A ，此时交警（死锁检测）需要判
断谁该回滚。
如果每秒有 1000 个事务，交警需要检查 1000×1000=100 万次可能的死锁组合， CPU 直接飙到 100% 。
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 2/22

3. 业务层不断重试——恶性循环
当数据库扛不住⾼并发时，业务层的重试机制（比如 Java 代码⾥的事务重试）会让问题更严重。
真实案例 ：
某银⾏系统在促销活动中，因未限制重试次数，导致 10% 的失败请求触发了 3 次重试，实际请求量膨胀到
130% ，数据库彻底宕机。
⽤户点了⼀次转账，接⼝超时  → 前端⾃动重试  → 重复请求打到数据库  → 锁冲突更多  → 更多超时  → 更多重试
→ 最终数据库崩溃。
热点⾏  根因分析  梳理
问题 现象 解决⽅案 成本 效果
锁竞争严重 转账超时、系统卡死 拆分⼦账户 中 提升5-10倍
死锁检测耗CPU CPU 90%、响应慢 关闭死锁检测 低 ⻛险可控
重试导致雪崩 数据库崩溃 限制重试次数 低 快速⽌损
硬件瓶颈 花钱就能解决，但太贵 ⽤云数据库 ⾼ 立竿⻅影
热点⾏ 问题，是⼀个 共性问题
热点⾏问题不仅出现在转账场景，⼏乎所有⾼并发更新同⼀⾏的操作都会中招：
库存扣减 ：秒 活动中，热点商品库存⾏，    会  被频繁更新。
计数器 ：热点⽂章的点赞数更新  、热点视频的  播放量更新。
账户积分 ：⽤户积分集中兑换。
热点 ⾏问题的四⼤  解决⽅案
⽅案1：绕过独⽊桥——最终⼀致性
场景 ：⽤ Redis 缓存余额，异步更新到数据库。
效果 ： Redis 单机吞吐量 5 万 +/ 秒， ⾼于 MySQL 。
代价 ：可能出现短暂的不⼀致（比如余额显⽰延 ）。
⽅案2：排队上桥——请求合并
场景 ：在 Java 应⽤层⽤队列（比如 RocketMQ ）缓冲请求，每隔 100ms 批量处理⼀次转账。
效果 ：将 100 次写操作合并成 1 次（ update balance=balance-100 ），减少锁竞争。
代价 ：延 增加（⽤户可能看到转账处理中）。
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 3/22

⽅案3：把独⽊桥拆成多个桥——分治思想
场景 ：⽀付宝红包账户拆分成 100 个⼦账户（比如按⽤户 ID 尾号分）。
效果 ：热点⾏压⼒分散到 100 ⾏，并发能⼒提升 10 倍（假设均匀分布）。
代价 ：业务逻辑变复 （需要路由到⼦账户），对账⿇烦。
⽅案4：升级 更宽的桥——投钱
场景 ：使⽤阿⾥云  POLARDB （⾼并发优化的 MySQL ），或改⽤ TiDB （分布式数据库）。
效果 ： POLARDB 热点⾏并发能⼒可达 1 万 + TPS ，是普通 MySQL 的 10 倍。
代价 ：成本⾼（ 1 个 POLARDB 实例 ≈10 台普通 MySQL 服务器的价格）。
短期-中期-⻓期 解决⽅案：
短期：先关死锁检测  + 限制重试次数  + 限流  ，能扛过活动⾼峰。成本最低，但是⽤户体验差。
中期：最终⼀致性⽅案设计： Redis 缓存库存  + RocketMQ 异步同步  。成本较低，⽤户体验好点。
⻓期：把红包账户拆成 100 个⼦账户，代码改造成本中等，效果最好。
⼟豪⽅案：直接上阿⾥云 POLARDB ， 1 ⼩时搞定，但每年多花 50 万。
中期⽅案 ：Redis缓存  + RocketMQ异步 最终⼀致性⽅案设计
利⽤ RocketMQ 实现可靠异步消息传递，将 Redis 库存变更异步同步到 MySQL ，实现    最终⼀致性⽅案。
1、Redis缓存  + RocketMQ异步 分层架构  设计
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 4/22

2. 关键设计点
消息可靠性 ：使⽤ RocketMQ 事务消息确保操作不丢失
顺序保证 ：同⼀ SKU 的库存变更消息按顺序消费
幂等设计 ：通过唯⼀请求 ID 避免重复消费
3. 数据结构设计
RocketMQ 消息体 （ JSON 格式）：
{
"requestId": "20231107123456_1001", // 唯⼀请求 ID
"skuId": 1001,
"delta": -2,                        // 库存变化量（扣减为负，回滚为正）
"opTime": 1699372800000,            // 操作时间戳
"version": 1699372800000            // 版本号（ Redis 同步时间戳）
}
中期⽅案核⼼代码实现（Java + SpringBoot + Redis + RocketMQ）
1. 库存扣减与消息发送（⽣产者）
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 5/22

public class SeckillService {
// Redis 扣减并发送 MQ 消息
public boolean deductWithMQ(Long skuId, int num) {
String stockKey = "sku_stock:" + skuId;
String versionKey = "sku_version:" + skuId;
// 1. Redis 原⼦扣减
Long stock = redisTemplate.opsForValue().decrement(stockKey, num);
if (stock < 0) {
redisTemplate.opsForValue().increment(stockKey, num); // 回滚
return false;
}
// 2. 发送事务消息
TransactionSendResult result = rocketMQTemplate.sendMessageInTransaction
"SeckillTopic",
MessageBuilder.withPayload(buildStockMessage(skuId, -num)).build(),
null
);
return result.getSendStatus() == SendStatus.SEND_OK;
}
构建库存  变更消息
private StockM essage buildStockM essage(L ong skuId, int delta) {
return new StockM essage(
U U ID.randomU U ID().toString(),
skuId,
delta,
System.currentTimeM illis(),
(L ong) redisTemplate.opsForValue().get("sku_version:" + skuId)
);
}
}
RocketMQ 事务监听器（确保本地操作与消息发送⼀致）
@RocketM QTransactionL istener
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 6/22

public class TransactionL istenerImpl implements RocketM QL ocalTransactionL istener {
@O verride
public RocketM QL ocalTransactionState executeL ocalTransaction(M essage msg, O bject arg) {
// 若Redis扣减成功，则提交消息
return RocketM QL ocalTransactionState.CO M M IT;
}
@O verride
public RocketM QL ocalTransactionState checkL ocalTransaction(M essage msg) {
// ⽆需⼆次检查（Redis操作已成功）
return RocketM QL ocalTransactionState.CO M M IT;
}
}
2. 消息消费 写入 MySQL
@RocketMQMessageListener(
topic = "SeckillTopic",
consumerGroup = "StockSyncConsumer",
selectorExpression = "*",
consumeMode = ConsumeMode.ORDERLY // 保证同⼀ SKU 顺序消费
)
public class StockSyncConsumer implements RocketMQListener<StockMessage> {
@Override
public void onMessage(StockMessage message) {
// 1. 幂等检查（通过 requestId 去重）
if (redisTemplate.opsForValue().get("mq_idempotent:" + message.getReques
return;
}
// 2. 版本控制（避免旧消息覆盖新数据）
Long currentVersion = seckillSkuMapper.getVersion(message.getSkuId());
if (message.getVersion() <= currentVersion) {
return;
}
// 3. 更新 MySQL （带版本号的乐观锁）
int rows = seckillSkuMapper.updateStock(
message.getSkuId(),
message.getDelta(),
message.getVersion()
);
// 4. 更新成功则记录幂等标识
if (rows > 0) {
redisTemplate.opsForValue().set(
"mq_idempotent:" + message.getRequestId(),
"1",
5, TimeUnit.MINUTES
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 7/22

);
} else {
// 失败重试（ RocketMQ ⾃带重试机制）
throw new RuntimeException("Sync failed, retry later");
}
}
}
// 数据库操作 Mapper
@Update("UPDATE seckill_sku SET stock = stock + #{delta}, version = #{version}
"WHERE sku_id = #{skuId} AND version < #{version}")
int updateStock(
@Param("skuId") Long skuId,
@Param("delta") int delta,
@Param("version") Long version
);
3. 补偿机制设计
// 监听死信队列（同步失败超过 16 次的消息）
@RocketMQMessageListener(
topic = "%DLQ%StockSyncConsumer",
consumerGroup = "StockSyncDLQConsumer"
)
public class StockSyncDLQConsumer implements RocketMQListener<StockMessage> {
public void onMessage(StockMessage message) {
// 1. 记录异常⽇志并告警
log.error(" 库存同步失败 : {}", message);
alertService.notify(" 库存同步异常 ", message.toString());
// 2. ⼈⼯介入检查（⽰例：⾃动对比 Redis 与 MySQL 库存）
Long redisStock = redisTemplate.opsForValue().get("sku_stock:" + message
Integer dbStock = seckillSkuMapper.getStock(message.getSkuId());
if (!redisStock.equals(dbStock)) {
// ⾃动修复（以 Redis 为准）
seckillSkuMapper.forceUpdateStock(
message.getSkuId(),
redisStock,
System.currentTimeMillis()
);
}
}
}
中期⽅案 潜在问题与优化
消息顺序与版本控制
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 8/22

现象 ：⽹络延 导致旧版本消息覆盖新版本
解决 ：消费者端增加版本号校验（仅处理更⾼版本的消息）
Redis 与 MySQL 数据偏差
监控 ：实时对比关键 SKU 库存（误差 >5% 触发告警）
修复 ：定时任务全量同步（兜底策略，每天凌晨执⾏）
消息堆积⻛险
扩容 ：根据堆积量动态增加 Consumer 实例
降级 ：堆积超过阈值时，暂停非核⼼ SKU 的秒
中期⽅案  分布式锁优化
// 热点 SKU 扣减时增加本地锁（减少 Redis 压⼒）
private final Map<Long, ReentrantLock> skuLocks = new ConcurrentHashMap<>();
public boolean deductWithLock(Long skuId, int num) {
skuLocks.putIfAbsent(skuId, new ReentrantLock());
ReentrantLock lock = skuLocks.get(skuId);
try {
if (lock.tryLock(10, TimeUnit.MILLISECONDS)) {
return deductWithMQ(skuId, num);
}
return false;
} finally {
lock.unlock();
}
}
中期⽅案  效果验证
1 压测对比
场景 TPS 平均延迟 数据⼀致性延迟
纯MySQL 200 500ms 0
Redis+RocketMQ 45,000 8ms 300ms~2s
2 监控指标
RocketMQ 消息堆积量
同步成功率（ 99.99% 以上为正常）
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 9/22

Redis 与 MySQL 库存差异率
⽅案总结：Redis缓存  + RocketMQ异步 最终⼀致性⽅案设计
45 岁老架构师尼恩提⽰：  由于扣减红包、转账等，和  秒 差不多，下⾯以秒 场景为例，进⾏⽅案介绍。
以秒 场景为例。
⽤户抢购时，先在 Redis 完成极速扣减（微秒级响应）
扣减成功后，通过 RocketMQ 可靠消息异步同步到 MySQL
同⼀商品的库存变更按顺序处理，通过版本号避免数据覆盖
万⼀同步失败，先⾃动重试，最终由⼈⼯兜底修复
阶段 技术栈 设计要点
扣减 Redis+L ua+本地锁 原⼦操作、热点数据分散锁
消息⽣产 RocketMQ事务消息 保证本地操作与消息发送的原⼦性
消息消费 顺序消费+幂等+版本控制 避免乱序和重复消费
补偿 死信队列+⾃动修复 系统⾃愈能⼒建设
60分 (菜⻦级) 答案
尼恩提⽰，讲完  缓存 + 异步    ，  可以得到  60 分了。
但是要直接拿到⼤⼚ offer ，或者   offer 直提，需要  120 分答案。
尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
中期改进，请求合并⽅案设计，秒杀库存批量扣减
⽬标 ：通过消息队列缓冲请求，合并多次扣减操作，减少数据库锁竞争，提升吞吐量。
请求合并⽅案设计  架构设计
1  核⼼流程
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 10/22

2  关键设计点
请求缓冲 ：使⽤ RocketMQ 事务消息确保请求不丢失
合并窗⼝ ：每 100ms 或每积累 100 个请求触发⼀次批量处理
异步响应 ：前端轮询或 WebSocket 通知处理结果
3  数据库表结构
CREATE TABLE seckill_sku (
sku_id BIGINT PRIMARY KEY,
stock INT COMMENT ' 剩余库存 ',
version INT COMMENT ' 乐观锁版本号 '
);
中期改进 核⼼代码实现（Java + SpringBoot + RocketMQ）
1. 请求接收层（带本地缓存合并）
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 11/22

@Component
public class RequestBuffer {
// 合并窗⼝： 100ms
private static final long BUFFER_WINDOW = 100;
// 本地缓存（ Key: SKU_ID, Value: 待扣减数量累计）
private final Map<Long, Integer> buffer = new ConcurrentHashMap<>();
private final ScheduledExecutorService scheduler = Executors.newScheduledThr
@PostConstruct
public void init() {
// 定时触发批量处理
scheduler.scheduleAtFixedRate(this::flushBuffer, BUFFER_WINDOW, BUFFER_W
}
// 接收单个请求（立即返回 " 处理中 " 状态）
public String handleRequest(Long userId, Long skuId) {
String requestId = generateRequestId(userId, skuId);
// 发送事务消息到 RocketMQ （确保消息落盘）
rocketMQTemplate.sendMessageInTransaction(
"SeckillTopic",
MessageBuilder.withPayload(new RequestItem(requestId, skuId, 1)).bui
null
);
return requestId;
}
// 事务消息监听器（本地事务执⾏）
@RocketMQTransactionListener
public class TransactionListenerImpl implements RocketMQLocalTransactionList
@Override
public RocketMQLocalTransactionState executeLocalTransaction(Message msg
RequestItem item = (RequestItem) msg.getPayload();
buffer.compute(item.getSkuId(), (k, v) -> v == null ? 1 : v + 1);
return RocketMQLocalTransactionState.COMMIT;
}
@Override
public RocketMQLocalTransactionState checkLocalTransaction(Message msg)
return RocketMQLocalTransactionState.COMMIT;
}
}
}
2. 批量处理服务（消费者逻辑）
@RocketMQMessageListener(topic = "SeckillTopic", consumerGroup = "SeckillConsume
public class BatchConsumer implements RocketMQListener<List<RequestItem>> {
@Override
public void onMessage(List<RequestItem> items) {
// 按 SKU 分组合并扣减数量
Map<Long, Integer> deductMap = items.stream()
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 12/22

.collect(Collectors.groupingBy(
RequestItem::getSkuId,
Collectors.summingInt(RequestItem::getDeductNum)
));
// 批量更新数据库
deductMap.forEach((skuId, totalDeduct) -> {
SeckillSku sku = seckillSkuMapper.selectById(skuId);
if (sku.getStock() >= totalDeduct) {
int rows = seckillSkuMapper.deductStockWithVersion(
skuId, totalDeduct, sku.getVersion()
);
if (rows > 0) {
// 成功：通知前端
notifySuccess(skuId, totalDeduct);
} else {
// 失败：触发补偿逻辑
handleConflict(skuId, totalDeduct);
}
} else {
// 库存不⾜：部分退款
handlePartialRefund(skuId, totalDeduct, sku.getStock());
}
});
}
// 带乐观锁的批量扣减 SQL
@Update("UPDATE seckill_sku SET stock = stock - #{deductNum}, version = vers
"WHERE sku_id = #{skuId} AND version = #{version}")
int deductStockWithVersion(
@Param("skuId") Long skuId,
@Param("deductNum") int deductNum,
@Param("version") int version
);
}
3. 前端异步查询接⼝
@RestController
public class ResultController {
@GetMapping("/result")
public String getResult(@RequestParam String requestId) {
// 查询 Redis 中该请求的处理状态
String status = redisTemplate.opsForValue().get(requestId);
return status != null ? status : "processing";
}
}
中期改进：潜在问题与优化
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 13/22

1 合并导致延
现象 ：⽤户需等待 100ms~200ms 才能得到结果
优化 ：动态调整合并窗⼝（例如： 10ms 内请求量 >50 则立即触发）
2 批量操作部分失败
场景 ：合并扣减 100 件，但库存只剩 80 件
解决 ：按时间戳顺序部分成功，其余请求⾃动退款
3 消息堆积
监控 ：实时监控 RocketMQ 堆积量，触发⾃动扩容
降级 ：堆积超过阈值时，切换为直接扣减模式
中期改进：效果验证
1   压测数据对比
未合并 ： 1000 并发下， TPS 约 200 ， 95% 响应时间 >500ms
合并后 ： 1000 并发下， DB 侧的  TPS 提升⾄ 5000+ ， 95% 响应时间 <200ms
2   监控指标
RocketMQ 消息堆积量
数据库锁等待时间（SHOW ENGINE INNODB STATUS）
⽤户可⻅延 分布（ 90% ⽤户 <200ms ， 99% ⽤户 <300ms ）
中期改进 总结 ：
请求合并⽅案通过异步化与批量处理，将⾼频单⾏更新转化为低频批量操作，显著降低锁竞争，适⽤于允许短
暂延 的场景。
代码实现需重点关注  消息可靠性 、  合并策略 和  部分失败补偿 。
80分 (⾼⼿级) 答案
尼恩提⽰，讲完    请求合并⽅案设计，秒 库存批量扣减    架构  ，  可以得到  80 分了。
但是要直接拿到⼤⼚ offer ，或者   offer 直提，需要  120 分答案。
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 14/22

尼恩带⼤家继续，挺进  120 分，让⾯试官  ⼝⽔直流。
⻓期⽅案：分治架构，秒杀库存拆分（SKU分桶）
将⼀个 SKU 的库存分散到 N 个⼦ SKU ，降低单⾏锁竞争，提升并发能⼒。
场景 ：秒 库⼀个 sku 库存  拆分成 100 个⼦ sku 库存  （比如按 sku 库存  ID 尾号分）。
效果 ：热点⾏压⼒分散到 100 ⾏，并发能⼒提升 10 倍（假设均匀分布）。
代价 ：业务逻辑变复 （需要路由到⼦   sku 库存  ），对账⿇烦。
1、⻓期⽅案 架构设计
分桶规则
路由策略：根据⽤户 ID 或订单 ID 的哈希值取模，决定请求落到哪个⼦库存。
例如：⼦ SKU 编号  = userId % 100
库存分配 ：总库存  = ⼦ SKU1 库存  + ⼦ SKU2 库存  + ... + ⼦ SKUn 库存
2、⻓期⽅案 组件分层
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 15/22

3、⻓期⽅案  数据库表设计
// 主 SKU 表（记录总库存和⼦库存分配）
CREATE TABLE main_sku (
sku_id BIGINT PRIMARY KEY,
total_stock INT COMMENT ' 总库存 ',
sub_sku_count INT COMMENT ' ⼦ SKU 数量（分桶数） ',
version INT COMMENT ' 版本号（乐观锁） '
);
// ⼦ SKU 表（每个⼦库存独立记录）
CREATE TABLE sub_sku (
sub_sku_id BIGINT PRIMARY KEY,
main_sku_id BIGINT COMMENT ' 关联主 SKU',
stock INT COMMENT ' 当前库存 ',
version INT COMMENT ' 版本号（乐观锁） '
);
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 16/22

4、⻓期⽅案 核⼼代码实现（Java + SpringBoot）
路由层逻辑：决定请求落到哪个⼦SKU
public class RoutingService {
// 根据⽤户 ID 哈希取模路由
public Long getSubSkuId(Long mainSkuId, Long userId, int subSkuCount) {
int hash = userId.hashCode() & Integer.MAX_VALUE; // 避免负数
int mod = hash % subSkuCount;
return mainSkuId * 1000 + mod; // ⽣成⼦ SKU ID （规则可⾃定义）
}
}
扣减库存逻辑（带乐观锁）
@Transactional
public boolean deductStock(Long subSkuId, int deductNum) {
// 1. 查询⼦ SKU 当前库存和版本号
SubSku subSku = subSkuMapper.selectById(subSkuId);
if (subSku == null || subSku.getStock() < deductNum) {
return false; // 库存不⾜
}
// 2. 尝试扣减（带版本号校验）
int rows = subSkuMapper.deductStockWithVersion(
subSkuId, deductNum, subSku.getVersion()
);
// 3. 更新成功判定
return rows > 0;
}
// MyBatis Mapper 接⼝⽅法
@Update("UPDATE sub_sku SET stock = stock - #{deductNum}, version = version + 1
"WHERE sub_sku_id = #{subSkuId} AND version = #{version}")
int deductStockWithVersion(
@Param("subSkuId") Long subSkuId,
@Param("deductNum") int deductNum,
@Param("version") int version
);
对账任务：定期校验⼦SKU总和
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 17/22

@Scheduled(cron = "0 0/5 * * * ?") // 每 5 分钟执⾏⼀次
public void reconcileStock() {
// 1. 查询所有主 SKU
List<MainSku> mainSkus = mainSkuMapper.selectAll();
for (MainSku mainSku : mainSkus) {
// 2. 计算所有⼦ SKU 库存总和
Integer totalSubStock = subSkuMapper.sumStockByMainSku(mainSku.getSkuId(
if (totalSubStock == null) totalSubStock = 0;
// 3. 对比主 SKU 总库存
if (!totalSubStock.equals(mainSku.getTotalStock())) {
// 触发告警  & ⾃动修复（例如：调整⼦ SKU 库存）
alarmService.sendAlert(" 库存不⼀致告警 : SKU=" + mainSku.getSkuId());
adjustSubStocks(mainSku, totalSubStock);
}
}
}
⻓期⽅案 潜在问题与优化
⼦ SKU 分配不均
现象 ：某些⼦ SKU 提前卖光，其他⼦ SKU 有剩余。
解决 ：动态调整路由策略（例如：根据⼦ SKU 剩余库存权重分配请求）。
对账延 导致超卖
现象 ：对账任务未运⾏时，可能总库存已超卖。
解决 ：在扣减⼦ SKU 前，增加总库存校验（例如： Redis 缓存总剩余库存）。
热点⼦ SKU ⼆次竞争
现象 ：某个⼦ SKU 仍然成为热点（例如：⽤户 ID 尾号集中）。
解决 ：增加分桶数量（如从 100 调整到 1000 ），或引入⼆级哈希。
⻓期⽅案 效果验证
1  压测对比
单⾏库存 ： 1000 并发下， TPS 约 200 ， 95% 响应时间 >500ms 。
分桶 100 ⼦ SKU ： 1000 并发下， TPS 提升⾄ 1800+ ， 95% 响应时间 <50ms 。
2 监控指标
⼦ SKU 锁等待时间（SHOW ENGINE INNODB STATUS）。
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 18/22

对账任务执⾏成功率与修复次数。
总结 ：分治⽅案通过拆分热点⾏，将并发压⼒分散到多个⼦ SKU ，显著提升系统吞吐量，但需额外处理路由逻
辑与数据⼀致性。代码实现的关键点在于  路由算法 、  乐观锁扣减 和  对账机制 的设计。
⼟豪⽅案：直接上 云
⼟豪⽅案：直接上阿⾥云 POLARDB ， 1 ⼩时搞定，但每年多花 50 万。
费⽤估算对比分析（POL ARDB vs TiDB vs MySQL ）
维度 普通MySQL （⾃
建）
POL ARDB MySQL
版 5 TiDB（分布式架构）
计算节点成
本
约800元/⽉/4核
8G
约8,000元/⽉/8核
64G
约12,000元/⽉/3节点（8核16
G/节点）
存储成本 0.3元/GB/⽉ 0.8元/GB/⽉（SS
D） 1.2元/GB/⽉（分布式存储）
⽹络成本 0.8元/GB（出流
量） 同左 同左 + 跨节点流量费（约0.2元/
GB）
运维成本 ⾼（需DBA团队） 低（全托管服务） 中（需分布式架构维护）
120分殿堂答案 (塔尖级)：
尼恩提⽰，讲到  到了这⾥，  可以得到  120 分了。    去哪⼉的⼤⼚ offer ，  这会就到⼿了。
终于  逆天改命啦。
遇到问题，找老架构师取经
以上的内容，如果⼤家能对答如流，如数家珍，    ⾯试官  直接  献上    膝盖。
⾯试官  爱你  爱到  “ 不能⾃已、⼝⽔直流 ”。
offer ，  也就来了。
在⾯试之前，建议⼤家系统化的刷⼀波  5000 ⻚《尼恩 Java ⾯试宝典》 V174 ，在刷题过程中，如果有啥
问题，⼤家可以来  找  40 岁老架构师尼恩交流。
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 19/22

另外，如果没有⾯试机会，可以找尼恩来帮扶、领路。
⼤龄男的最佳出路是  架构 + 管理
⼤龄女的最佳出路是  DPM ，
女程序员如何成为 DPM ，请参⻅：
DPM （双栖）陪跑，助⼒⼩⽩⼀步登天，升格  产品经理 + 研发经理
领跑模式，尼恩已经指导了⼤量的就业困难的⼩伙伴上岸。
尼恩指导了⼤量的⼩伙伴上岸，前段时间，刚指导⼀个40岁+被裁⼩伙伴，拿到了⼀个年薪100W 的
offer。
狠狠卷，实现  “offer ⾃由 ” 很容易的，  前段时间⼀个武汉的跟着尼恩卷了 2 年的⼩伙伴，  在极度严寒 / 痛苦被裁
的环境下，  offer 拿到⼿软，  实现真正的  “offer ⾃由 ” 。
空窗 1 年 - 空窗 2 年，彻底绝望投递，走投⽆路，如何    起死回⽣    ？
失业 1 年多，负债 20W 多万，彻底绝望，抑郁了。 7 年经验⼩伙，找尼恩帮助后，跳槽 3
次    入国企  年薪40W offer ，逆天改命了
被裁 2 年，天快塌了，家都要散了， 42 岁急救 1 个⽉上岸，成开发经理 offer ，起死回⽣
空窗 8 ⽉：中⼚⼤龄 34 岁，被裁 8 ⽉收⼀⼤⼚ offer ，  年薪 65W ，转架构后逆天改命 !
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 20/22

空窗 2 年： 42 岁被裁 2 年，天快塌了，急救 1 个⽉，拿到开发经理 offer ，起死回⽣
空窗半年： 35 岁被裁 6 个⽉，  职业绝望，转架构急救上岸， DDD 和 3 ⾼项⽬太重要了
空窗 1.5 年：失业 15 个⽉，学习 40 天拿 offer ，  绝境翻盘，如何实现？
100W-200W  P8 级  的天价年薪    ⼤逆袭 ,   如何实现    ？
100W 案例， 100W 年薪的底层逻辑是什么？  如何实现年薪百万？  如何远离    中年危机？
100W 案例 2：40岁⼩伙被裁 6 个⽉，猛卷 3 ⽉拿 100W 年薪  ，秘诀：⾸席架构 / 总架构
环境太糟，如何升  P8 级，年入 100W ？
职业救助站
实现职业转型，极速上岸
关注职业救助站公众号，获取每天职业⼲货
助您实现职业转型、职业升级、极速上岸
---------------------------------
技术⾃由圈
实现架构转型，再⽆中年危机
关注技术⾃由圈公众号，获取每天技术千货
⼀起成为⽜逼的未来超级架构师
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 21/22

⼏⼗篇架构笔记、5000⻚⾯试宝典、20个技术圣经
请加尼恩个⼈微信 免费拿走
暗号，请在 公众号后台 发送消息：领电⼦书
如有收获，请点击底部的"在看"和"赞"，谢谢
2025/6/4 凌晨 1:02 去哪⾯试： 1Wtps ⾼并发， MySQL 热点⾏  问题，  怎么解决︖
https://mp.weixin.qq.com/s/vZgmpCeMFK1K6_xX6PVExw 22/22

