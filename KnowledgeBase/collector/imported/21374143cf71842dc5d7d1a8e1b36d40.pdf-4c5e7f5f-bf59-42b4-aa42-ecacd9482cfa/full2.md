# 去哪面试：1W tps 高并发，MySQL 热点行问题，怎么解决？

作者：尼恩架构团队（FSAC 未来超级架构师）

说在前面  
在我的读者交流群里，最近有小伙伴拿到了一线互联网公司的面试资格，遇到一道重要面试题：

1W tps 高并发，MySQL 热点行问题，怎么解决？

本文系统化地梳理了热点行问题的根因与多种解决方案（短期 / 中期 / 长期），并给出中期与长期方案的架构、核心代码与注意点，适合作为面试和生产实践参考。

---

## 为什么热点操作会卡死？

1. 锁的“独木桥”问题  
一把 MySQL 记录锁就是一条只能过一个人的独木桥，大家抢着过桥，后面的人只能排队。转账或更新同一行数据时（例如账户 A 扣钱、账户 B 加钱），每个事务都要给该行加锁，导致所有操作串行化，TPS 无法扩展。  
真实案例：某电商平台双十一期间，用户频繁充值到同一个公共红包账户，突发流量使该余额行成为热点，TPS 从 1k 升到 10k 甚至 100k，系统几乎瘫痪。

2. 死锁检测的“资源内耗”问题  
当多个事务互相等待对方释放锁时，会造成死锁。MySQL 的死锁检测需要消耗 CPU 资源，在高并发场景中会进一步恶化系统负载。  
真实案例：某支付系统开启死锁检测时 CPU 利用率高达 90%；关闭死锁检测后降到 40%，但会增加超时事务，需要业务层重试。

3. 业务层不断重试——恶性循环  
数据库扛不住时，业务重试（如前端自动重试、服务端事务重试）会把失败请求放大，形成更严重的负载。  
真实案例：某银行促销活动中，未限制重试次数，导致 10% 的失败请求触发了多次重试，实际请求量膨胀至 130%，数据库崩溃。

---

## 热点行根因分析（概览）

| 问题 | 现象 | 解决方案 | 成本 | 效果 |
|---|---:|---|---:|---|
| 锁竞争严重 | 转账超时、系统卡死 | 拆分子账户 | 中 | 提升 5-10 倍 |
| 死锁检测耗 CPU | CPU 高、响应慢 | 关闭死锁检测（可控风险） | 低 | 快速缓解 |
| 重试导致雪崩 | 数据库崩溃 | 限制重试次数 | 低 | 快速止损 |
| 硬件瓶颈 | 付钱就能解决 | 上云数据库（POLARDB/TiDB） | 高 | 立竿见影 |

热点行问题是共性问题，常见场景包括库存扣减、计数器更新（点赞、播放量）、账户积分兑换等。

---

## 热点行问题的四大解决方案

1. 绕过独木桥——最终一致性  
   场景：用 Redis 缓存余额，异步更新到数据库。  
   效果：Redis 单机吞吐量远高于 MySQL。代价：可能出现短暂不一致（如余额显示延迟）。

2. 排队上桥——请求合并  
   场景：在应用层用队列（如 RocketMQ）缓冲请求，每隔 100ms 批量处理一次。  
   效果：将 N 次写合并为 1 次，减少锁竞争。代价：增加延迟（用户看到“处理中”）。

3. 把独木桥拆成多个桥——分治思想（分库/分行/分桶）  
   场景：将红包账户拆分成 100 个子账户（按用户 ID 尾号分）。  
   效果：热点压力分散到多个行，并发能力提升（假设均匀分布）。代价：业务逻辑复杂化、对账麻烦。

4. 升级更宽的桥——投钱（云/分布式数据库）  
   场景：使用 POLARDB、TiDB 等支持高并发的数据库。  
   效果：POLARDB 对热点行优化后能承载上万 TPS。代价：成本高。

短期 / 中期 / 长期建议：
- 短期：关闭死锁检测 + 限制重试次数 + 限流，成本低但用户体验差，能扛活动高峰。
- 中期：采用最终一致性方案（Redis 缓存 + RocketMQ 异步同步），成本较低且用户体验较好。
- 长期：拆分账户/分桶（如拆成 100 个子账户），代码改造成本中等，效果最好。
- 土豪方案：直接上 POLARDB，迅速见效但费用高。

---

## 中期方案：Redis 缓存 + RocketMQ 异步（最终一致性）

利用 RocketMQ 实现可靠异步消息传递，将 Redis 的变更异步同步到 MySQL，实现最终一致性。

### 架构要点
1. Redis 扣减、快速响应（微秒/毫秒级）  
2. RocketMQ 事务消息保证消息可靠落盘  
3. 顺序消费：同一 SKU 的库存变更按顺序消费  
4. 幂等与版本控制：通过 requestId 幂等与版本号防止旧消息覆盖新数据  
5. 补偿机制：死信队列 + 人工/自动修复

### 消息体（JSON 示例）
```json
{
  "requestId": "20231107123456_1001",
  "skuId": 1001,
  "delta": -2,
  "opTime": 1699372800000,
  "version": 1699372800000
}
```

### 中期方案核心代码（Java + Spring Boot + Redis + RocketMQ）

1) 库存扣减与消息发送（生产者）
```java
public class SeckillService {

    // Redis 扣减并发送 MQ 消息
    public boolean deductWithMQ(Long skuId, int num) {
        String stockKey = "sku_stock:" + skuId;
        String versionKey = "sku_version:" + skuId;
        // 1. Redis 原子扣减
        Long stock = redisTemplate.opsForValue().decrement(stockKey, num);
        if (stock < 0) {
            redisTemplate.opsForValue().increment(stockKey, num); // 回滚
            return false;
        }
        // 2. 发送事务消息
        TransactionSendResult result = rocketMQTemplate.sendMessageInTransaction(
            "SeckillTopic",
            MessageBuilder.withPayload(buildStockMessage(skuId, -num)).build(),
            null
        );
        return result.getSendStatus() == SendStatus.SEND_OK;
    }

    private StockMessage buildStockMessage(Long skuId, int delta) {
        return new StockMessage(
            UUID.randomUUID().toString(),
            skuId,
            delta,
            System.currentTimeMillis(),
            (Long) redisTemplate.opsForValue().get("sku_version:" + skuId)
        );
    }
}
```

2) RocketMQ 事务监听器（确保本地操作与消息发送一致）
```java
@RocketMQTransactionListener
public class TransactionListenerImpl implements RocketMQLocalTransactionListener {

    @Override
    public RocketMQLocalTransactionState executeLocalTransaction(Message msg, Object arg) {
        // 若 Redis 扣减成功，则提交消息
        return RocketMQLocalTransactionState.COMMIT;
    }

    @Override
    public RocketMQLocalTransactionState checkLocalTransaction(Message msg) {
        // Redis 操作已成功，无需二次检查
        return RocketMQLocalTransactionState.COMMIT;
    }
}
```

3) 消息消费写入 MySQL（顺序消费 + 幂等 + 版本控制）
```java
@RocketMQMessageListener(
    topic = "SeckillTopic",
    consumerGroup = "StockSyncConsumer",
    selectorExpression = "*",
    consumeMode = ConsumeMode.ORDERLY // 保证同一 SKU 顺序消费
)
public class StockSyncConsumer implements RocketMQListener<StockMessage> {

    @Override
    public void onMessage(StockMessage message) {
        // 1. 幂等检查（通过 requestId 去重）
        if (redisTemplate.opsForValue().get("mq_idempotent:" + message.getRequestId()) != null) {
            return;
        }
        // 2. 版本控制（避免旧消息覆盖新数据）
        Long currentVersion = seckillSkuMapper.getVersion(message.getSkuId());
        if (message.getVersion() <= currentVersion) {
            return;
        }
        // 3. 更新 MySQL（带版本号的乐观锁）
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
            );
        } else {
            // 失败重试（RocketMQ 自带重试机制）
            throw new RuntimeException("Sync failed, retry later");
        }
    }
}

// Mapper 更新语句（示例）
@Update("UPDATE seckill_sku SET stock = stock + #{delta}, version = #{version} WHERE sku_id = #{skuId} AND version < #{version}")
int updateStock(@Param("skuId") Long skuId, @Param("delta") int delta, @Param("version") Long version);
```

4) 补偿机制（监听死信队列）
```java
@RocketMQMessageListener(
    topic = "%DLQ%StockSyncConsumer",
    consumerGroup = "StockSyncDLQConsumer"
)
public class StockSyncDLQConsumer implements RocketMQListener<StockMessage> {

    public void onMessage(StockMessage message) {
        // 1. 记录异常日志并告警
        log.error("库存同步失败: {}", message);
        alertService.notify("库存同步异常", message.toString());
        // 2. 人工介入或自动修复（以 Redis 为准）
        Long redisStock = (Long) redisTemplate.opsForValue().get("sku_stock:" + message.getSkuId());
        Integer dbStock = seckillSkuMapper.getStock(message.getSkuId());
        if (!redisStock.equals(dbStock.longValue())) {
            seckillSkuMapper.forceUpdateStock(
                message.getSkuId(),
                redisStock.intValue(),
                System.currentTimeMillis()
            );
        }
    }
}
```

### 中期方案潜在问题与优化
- 消息顺序与版本控制：网络延迟可能导致旧消息覆盖新版本，消费者应增加版本号校验。
- Redis 与 MySQL 数据偏差：监控关键 SKU 的实时对比（误差超阈值触发告警），并定时全量同步作为兜底。
- 消息堆积风险：根据堆积量动态扩容 Consumer 实例；堆积超阈值时降级处理。

### 分布式锁优化（减少 Redis 压力）
```java
private final Map<Long, ReentrantLock> skuLocks = new ConcurrentHashMap<>();

public boolean deductWithLock(Long skuId, int num) {
    skuLocks.putIfAbsent(skuId, new ReentrantLock());
    ReentrantLock lock = skuLocks.get(skuId);
    try {
        if (lock.tryLock(10, TimeUnit.MILLISECONDS)) {
            return deductWithMQ(skuId, num);
        }
        return false;
    } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
        return false;
    } finally {
        if (lock.isHeldByCurrentThread()) {
            lock.unlock();
        }
    }
}
```

### 效果验证（典型压测）
- 纯 MySQL：TPS ~ 200，平均延迟 500ms，数据一致性延迟 0
- Redis + RocketMQ：TPS ~ 45,000，平均延迟 8ms，一致性延迟 300ms~2s

监控指标：RocketMQ 消息堆积量、同步成功率（目标 99.99%+）、Redis 与 MySQL 库存差异率等。

---

## 中期改进：请求合并方案（秒杀库存批量扣减）

目标：通过消息队列缓冲请求，合并多次扣减操作，减少数据库锁竞争，提升吞吐量。

### 架构设计要点
1. 请求缓冲：使用 RocketMQ 事务消息保证请求不丢失。  
2. 合并窗口：每 100ms 或每累计 100 个请求触发一次批量处理。  
3. 异步响应：前端轮询或 WebSocket 通知处理结果。

### 数据库表结构
```sql
CREATE TABLE seckill_sku (
  sku_id BIGINT PRIMARY KEY,
  stock INT COMMENT '剩余库存',
  version INT COMMENT '乐观锁版本号'
);
```

### 核心代码实现（Java + Spring Boot + RocketMQ）

1) 请求接收层（带本地缓存合并）
```java
@Component
public class RequestBuffer {
    // 合并窗口：100ms
    private static final long BUFFER_WINDOW = 100;
    // 本地缓存（Key: SKU_ID, Value: 待扣减数量累计）
    private final Map<Long, Integer> buffer = new ConcurrentHashMap<>();
    private final ScheduledExecutorService scheduler = Executors.newScheduledThreadPool(1);

    @PostConstruct
    public void init() {
        // 定时触发批量处理
        scheduler.scheduleAtFixedRate(this::flushBuffer, BUFFER_WINDOW, BUFFER_WINDOW, TimeUnit.MILLISECONDS);
    }

    // 接收单个请求（立即返回 "processing" 状态）
    public String handleRequest(Long userId, Long skuId) {
        String requestId = generateRequestId(userId, skuId);
        // 发送事务消息到 RocketMQ（确保消息落盘）
        rocketMQTemplate.sendMessageInTransaction(
            "SeckillTopic",
            MessageBuilder.withPayload(new RequestItem(requestId, skuId, 1)).build(),
            null
        );
        return requestId;
    }

    // 事务消息监听器（本地事务执行）
    @RocketMQTransactionListener
    public class TransactionListenerImpl implements RocketMQLocalTransactionListener {
        @Override
        public RocketMQLocalTransactionState executeLocalTransaction(Message msg, Object arg) {
            RequestItem item = (RequestItem) msg.getPayload();
            buffer.compute(item.getSkuId(), (k, v) -> v == null ? 1 : v + 1);
            return RocketMQLocalTransactionState.COMMIT;
        }
        @Override
        public RocketMQLocalTransactionState checkLocalTransaction(Message msg) {
            return RocketMQLocalTransactionState.COMMIT;
        }
    }

    private void flushBuffer() {
        // 将本地 buffer 批量发送到 MQ 或直接触发批量处理
    }

    private String generateRequestId(Long userId, Long skuId) {
        return userId + "_" + skuId + "_" + System.currentTimeMillis();
    }
}
```

2) 批量处理服务（消费者逻辑）
```java
@RocketMQMessageListener(topic = "SeckillTopic", consumerGroup = "SeckillConsumer")
public class BatchConsumer implements RocketMQListener<List<RequestItem>> {
    @Override
    public void onMessage(List<RequestItem> items) {
        // 按 SKU 分组合并扣减数量
        Map<Long, Integer> deductMap = items.stream()
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
                // 库存不足：部分退款
                handlePartialRefund(skuId, totalDeduct, sku.getStock());
            }
        });
    }

    // 带乐观锁的批量扣减 SQL
    @Update("UPDATE seckill_sku SET stock = stock - #{deductNum}, version = version + 1 WHERE sku_id = #{skuId} AND version = #{version}")
    int deductStockWithVersion(@Param("skuId") Long skuId, @Param("deductNum") int deductNum, @Param("version") int version);
}
```

3) 前端异步查询接口
```java
@RestController
public class ResultController {
    @GetMapping("/result")
    public String getResult(@RequestParam String requestId) {
        // 查询 Redis 中该请求的处理状态
        String status = redisTemplate.opsForValue().get(requestId);
        return status != null ? status : "processing";
    }
}
```

### 合并方案潜在问题与优化
1. 合并导致延迟：用户需等待 100ms~200ms。优化：动态调整合并窗口（如流量高时缩短窗口）。
2. 批量操作部分失败：例如合并扣减 100 件但库存只剩 80 件，需按时间戳顺序部分成功，其余自动退款。
3. 消息堆积：监控 RocketMQ 堆积量，触发自动扩容或降级为直接扣减模式。

### 效果验证（压测）
- 未合并：1000 并发下 DB 侧 TPS ~200，95% 响应时间 >500ms。  
- 合并后：1000 并发下 DB 侧 TPS 提升至 5000+，95% 响应时间 <200ms。  
监控指标包括 RocketMQ 垃圾堆积量、数据库锁等待时间、用户可见延迟分布等。

总结：请求合并方案通过异步化与批量处理，将高频单行更新转化为低频批量操作，显著降低锁竞争，适用于允许短暂延迟的场景。实现需关注消息可靠性、合并策略与部分失败补偿。

---

## 长期方案：分治架构，SKU 分桶（拆分热点行）

将一个 SKU 的库存分散到 N 个子 SKU，降低单行锁竞争，提升并发能力。代价是业务路由与对账逻辑变复杂。

### 架构要点
- 分桶规则：根据用户 ID 或订单 ID 的哈希值取模，决定请求落到哪个子库存。
- 库存分配：总库存 = 子 SKU1 + 子 SKU2 + ... + 子 SKUn。
- 对账机制：定期校验子 SKU 总和与主 SKU 总库存一致性，并提供自动修复手段。

### 数据库表设计
```sql
-- 主 SKU 表（记录总库存和子库存分配）
CREATE TABLE main_sku (
  sku_id BIGINT PRIMARY KEY,
  total_stock INT COMMENT '总库存',
  sub_sku_count INT COMMENT '子 SKU 数量（分桶数）',
  version INT COMMENT '版本号（乐观锁）'
);

-- 子 SKU 表（每个子库存独立记录）
CREATE TABLE sub_sku (
  sub_sku_id BIGINT PRIMARY KEY,
  main_sku_id BIGINT COMMENT '关联主 SKU',
  stock INT COMMENT '当前库存',
  version INT COMMENT '版本号（乐观锁）'
);
```

### 核心代码实现（路由与扣减）
```java
public class RoutingService {
    // 根据用户 ID 哈希取模路由
    public Long getSubSkuId(Long mainSkuId, Long userId, int subSkuCount) {
        int hash = Integer.toUnsignedLong(userId.hashCode()) > Integer.MAX_VALUE ? userId.hashCode() & Integer.MAX_VALUE : userId.hashCode() & Integer.MAX_VALUE;
        int mod = hash % subSkuCount;
        return mainSkuId * 1000 + mod; // 生成子 SKU ID（规则可自定义）
    }
}

@Transactional
public boolean deductStock(Long subSkuId, int deductNum) {
    // 1. 查询子 SKU 当前库存和版本号
    SubSku subSku = subSkuMapper.selectById(subSkuId);
    if (subSku == null || subSku.getStock() < deductNum) {
        return false; // 库存不足
    }
    // 2. 尝试扣减（带版本号校验）
    int rows = subSkuMapper.deductStockWithVersion(subSkuId, deductNum, subSku.getVersion());
    // 3. 更新成功判定
    return rows > 0;
}

// Mapper
@Update("UPDATE sub_sku SET stock = stock - #{deductNum}, version = version + 1 WHERE sub_sku_id = #{subSkuId} AND version = #{version}")
int deductStockWithVersion(@Param("subSkuId") Long subSkuId, @Param("deductNum") int deductNum, @Param("version") int version);
```

### 对账任务（定期校验子 SKU 总和）
```java
@Scheduled(cron = "0 0/5 * * * ?") // 每 5 分钟执行一次
public void reconcileStock() {
    // 1. 查询所有主 SKU
    List<MainSku> mainSkus = mainSkuMapper.selectAll();
    for (MainSku mainSku : mainSkus) {
        // 2. 计算所有子 SKU 库存总和
        Integer totalSubStock = subSkuMapper.sumStockByMainSku(mainSku.getSkuId());
        if (totalSubStock == null) totalSubStock = 0;
        // 3. 对比主 SKU 总库存
        if (!totalSubStock.equals(mainSku.getTotalStock())) {
            // 触发告警 & 自动修复
            alarmService.sendAlert("库存不一致告警: SKU=" + mainSku.getSkuId());
            adjustSubStocks(mainSku, totalSubStock);
        }
    }
}
```

### 长期方案潜在问题与优化
- 子 SKU 分配不均：某些子 SKU 先卖光，其他有剩余。解决：动态调整路由策略，根据子 SKU 剩余库存权重分配请求。
- 对账延迟导致超卖：在扣减子 SKU 前增加总库存校验（例如用 Redis 缓存总剩余库存）。
- 热点子 SKU 二次竞争：增加分桶数或引入二级哈希。

### 效果验证（压测）
- 单行库存：1000 并发下，TPS ~200，95% 响应时间 >500ms。  
- 分桶 100 子 SKU：1000 并发下，TPS 提升至 1800+，95% 响应时间 <50ms。

总结：分治方案通过拆分热点行，将并发压力分散到多个子行，显著提升系统吞吐量，但需额外处理路由逻辑与数据一致性。实现关键点在于路由算法、乐观锁扣减与对账机制。

---

## 土豪方案：直接上云（POLARDB / TiDB）

直接使用托管的高并发数据库是最快的解决方案，但成本显著增加。下面给出粗略成本对比（示例）：

| 维度 | 普通 MySQL（自建） | POLARDB（MySQL 版） | TiDB（分布式） |
|---|---:|---:|---:|
| 计算节点成本 | 约 800 元/月（4核8G） | 约 8,000 元/月（8核64G） | 约 12,000 元/月（3 节点） |
| 存储成本 | 0.3 元/GB/月 | 0.8 元/GB/月（SSD） | 1.2 元/GB/月（分布式） |
| 网络成本 | 0.8 元/GB（出流量） | 同左 | 同左 + 跨节点流量费 |
| 运维成本 | 高（需 DBA 团队） | 低（全托管） | 中（需分布式维护） |

---

## 面试答题建议（不同分数线）

- 60 分（基础答案）：提出缓存 + 异步思路（Redis + MQ），说明优缺点即可。
- 80 分（高手级）：详细描述请求合并、批量扣减、核心代码、合并窗口、补偿机制与监控方案。
- 120 分（塔尖级）：在 80 分基础上，补充分治（分桶）方案、成本对比（POLARDB/TiDB）、对账实现细节和具体压测数据与指标阈值。

在面试中讲清楚原理、权衡、优缺点、工程实现与监控告警策略，会让面试官印象深刻。

---

## 遇到问题，找老架构师取经（附：职业建议）

如果你正在准备面试或职业转型，系统性学习高并发、分布式与架构设计非常重要。实战经验、压测数据与对系统一致性风险的可控方案，会是拿到大厂 offer 的关键。工作之余建议系统刷题与阅读架构笔记，并结合真实项目实践。

（文章到此结束。如需完整代码样例、压测脚本或对接 RocketMQ/Redis 的最佳实践，我可以继续提供更详尽的实现和配置建议。）