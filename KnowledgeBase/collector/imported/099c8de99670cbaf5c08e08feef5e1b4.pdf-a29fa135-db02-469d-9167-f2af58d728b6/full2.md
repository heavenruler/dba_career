# 希音面试：第三方挂了，我们总背锅。设计一套靠谱的高可用方案，让外部依赖稳如泰山

作者：尼恩架构团队（技术自由圈）

尼恩说在前面：
最近大厂机会多了。在读者交流群中，很多小伙伴遇到一道面试题：第三方服务经常挂，你的系统怎么保证高可用？第三方挂了，我们总在背锅。如何设计一个靠谱的高可用方案，让外部依赖稳如泰山？这道题很考察候选人的架构思维：优秀的架构设计恰恰体现在对异常场景的处理能力上。

通过第三方不可用的高可用设计，我们可以实现三大价值：
1. 保障核心业务连续性：例如支付接口挂了，能切换到备用渠道，确保用户能正常下单付款。
2. 避免自身系统被拖垮：通过限流、熔断，防止第三方的问题扩散到自身服务。
3. 降低故障影响范围：非核心功能（如推荐、广告）出问题，不影响用户的核心操作（如浏览、购买）。

接下来从多个维度，系统化、体系化地拆解可落地的方案。

## 开篇：第三方服务不稳定的本质
在微服务和分布式架构普及的今天，没有任何系统能脱离外部依赖独立运行。但第三方服务的不稳定性往往会成为我们系统高可用的短板——这部分问题看似是别人的问题，实则需要我们从自身架构设计出发，建立一套完整的容错体系。

几乎所有互联网系统都需要通过第三方服务调用，常见场景包括：
- 身份与安全：微信/QQ扫码登录、手机号验证（运营商接口）、人脸识别（第三方AI服务）
- 支付与金融：支付宝/微信支付接口、银行转账/清结算接口、汇率查询（金融数据服务）
- 消息与通知：短信验证码（短信服务商）、App推送（极光/个推）、邮件发送（第三方邮件服务）
- 专业能力服务：天气查询（气象局接口）、地图定位（高德/百度地图）、PDF转码（第三方工具服务）

之所以要花大量精力应对第三方服务问题，核心原因在于其三大不可控性（网络、服务稳定性、限流策略等），而很多人对第三方接入只停留在“能调用”层面，缺乏容错设计。

---

## 第一招：引入 ACL（防腐层）
第三方服务的不稳定（如宕机、API变更）会直接影响核心业务系统。第一招是引入 ACL 防腐层。防腐层通过接口隔离和协议转换，将外部服务的波动封装在边界内，使核心系统保持稳定性和技术一致性。

例如在电商支付场景中，订单服务只需要调用标准支付接口，无需关心微信支付或支付宝的技术细节差异。

ACL 防腐层可以屏蔽掉“脏活累活”，功能包括：
- 协议转换：HTTP/RPC/私有协议统一适配
- 数据规范：JSON/XML/form-data 统一转换
- 安全处理：MD5/SHA256/RSA 签名验签
- 回调机制：同步/异步通知统一标准化

优势：
- 提升研发效率：业务开发者无需学习各种第三方 API 规范，只需调用标准化接口。
- 增强系统扩展性：新增支付渠道时，只需添加实现类并注册到工厂，对上游透明。

有了 ACL 防腐层，就可以在此基础上实现各种治理策略，为系统高可用打下基础。

---

## 第二招：引入策略模式支持主备切换
当核心第三方服务出现故障时，快速切换到备用渠道是最直接的应对方式。通过策略模式实现主备切换：优先调用主供应商，超时或错误后切换到备供应商，动态维护一个健康供应商池。

示例（短信服务）：

```java
// 策略接口定义
public interface SmsSupplier {
    SendResult sendSms(String phone, String content);
}

// 具体策略实现（示例：供应商A）
public class SupplierA implements SmsSupplier {
    @Override
    public SendResult sendSms(String phone, String content) {
        // 调用供应商A的API实现
    }
}

// 策略上下文（含自动切换逻辑）
public class SmsRouter {
    private List<SmsSupplier> healthySuppliers; // 健康供应商池

    public SendResult routeSend(String phone, String content) {
        for (SmsSupplier supplier : healthySuppliers) {
            try {
                return supplier.sendSms(phone, content); // 尝试发送
            } catch (SupplierException e) {
                markSupplierUnhealthy(supplier); // 标记故障
            }
        }
        throw new AllSuppliersDownException(); // 全渠道熔断
    }

    // 基于健康检查更新供应商池
    void refreshHealthySuppliers() {
        healthySuppliers = allSuppliers.stream()
            .filter(s -> healthChecker.isHealthy(s)) // 健康检测
            .collect(Collectors.toList());
    }
}
```

关键点：
- 策略接口统一服务协议（SmsSupplier）
- 动态选择可用供应商（SmsRouter）
- 定时更新健康池（refreshHealthySuppliers）

健康检测维度示例：
- 响应时间：>3000ms 视为异常
- 错误率：连续 5 次失败触发熔断
- 超时率：10 秒内超时率 >40% 自动隔离

多级降级策略：当所有渠道不可用时启动应急方案（备用渠道、本地队列、异步入库等）。

实际案例：某金融系统使用动态权重路由，根据供应商历史成功率自动分配流量（如 A:B:C = 7:2:1），并能在几秒内根据实时性能调整权重，实现无感切换。

---

## 第三招：引入流量防卫层，精准限流保障不会过载
第三方服务通常有严格的 API 调用限制（如每秒 10 次）。在客户端实施精准限流，可以在发起网络调用前拦截超额请求，实现快速失败和资源保护。常用工具：Guava RateLimiter、Sentinel 等。

四大限流策略设计：
1. 多级限流配置：针对核心服务设置宽松阈值，非核心服务设置严格限流，优先保障核心流程。
2. 动态调整机制：监控第三方状态异常时自动降低限流阈值；结合业务高峰期自动调整。
3. 限流后的处理策略：
   - 核心请求：加入队列等待重试
   - 非核心请求：直接返回友好提示
   - 批量任务：延迟执行或分片处理
4. 多层次限流保护：在用户层、API 层、服务层等不同维度实施限流，避免单点限流带来的局限性。

实战案例：某电商平台在双十一期间采用三级限流：
- 用户层：单个用户每秒最多下单 2 次
- API 层：支付接口每秒限流 5000 次
- 服务层：整体订单服务限流 20000 QPS

---

## 第四招：容错机制——超时控制与失败重试
第三方服务出现响应缓慢或偶发错误很常见。把重试逻辑放在 ACL 防腐层统一处理，可以提升整体可用性，但前提是第三方接口的幂等性必须得到保证（尤其是写操作如扣款、创建订单等）。

推荐使用渐进式后退重试策略（Backoff Retry），如固定间隔、指数退避、随机延迟等，避免密集重试造成雪崩。

示例（Guava Retrying 库）：

```java
// 使用 Retryer 构建重试机制（Guava Retrying 库示例）
Retryer<Boolean> retryer = RetryerBuilder.<Boolean>newBuilder()
    .retryIfException(throwable -> throwable instanceof SocketTimeoutException)
    .retryIfResult(result -> result == false) // 按条件重试
    .withWaitStrategy(WaitStrategies.exponentialWait(1000, 5, TimeUnit.MINUTES))
    .withStopStrategy(StopStrategies.stopAfterAttempt(5)) // 最大重试5次
    .build();

// 执行需重试的方法
retryer.call(() -> callThirdPartyService(params));
```

要点：
- 明确哪些异常触发重试（超时、5xx 等）
- 指定指数退避策略，限制最大等待时间
- 设置最大重试次数，避免无限重试
- 在重试日志中加入请求 ID 便于链路追踪

---

## 第五招：熔断与降级，防止系统雪崩
当第三方服务持续报错或变慢时，熔断器（Circuit Breaker）可以在故障达到阈值时自动“熔断”，停止对下游的调用，保护自身资源。熔断配合降级（Fallback）可以返回预设的兜底结果，保证核心业务继续运行。

熔断器通常基于错误率和慢调用比例来决策，并包含三种状态：CLOSED、OPEN、HALF-OPEN。结合分布式配置中心可以动态调整阈值。

示例（Resilience4j）：

```java
// 1. 配置熔断器规则
CircuitBreakerConfig config = CircuitBreakerConfig.custom()
    .failureRateThreshold(50) // 错误率阈值：50%
    .slowCallRateThreshold(80) // 慢调用阈值：80%
    .slowCallDurationThreshold(Duration.ofSeconds(5)) // 慢调用界限：5秒
    .waitDurationInOpenState(Duration.ofSeconds(30)) // OPEN 状态等待时间：30秒
    .slidingWindowType(SlidingWindowType.COUNT_BASED) // 基于调用次数
    .slidingWindowSize(20) // 统计窗口大小：最近20次调用
    .build();

// 2. 创建熔断器实例
CircuitBreaker circuitBreaker = CircuitBreaker.of("thirdPartyService", config);

// 3. 使用熔断器装饰业务调用，并指定降级策略
CheckedFunction0<String> decoratedSupplier = CircuitBreaker
    .decorateCheckedSupplier(circuitBreaker, () -> callThirdPartyService(params));
String result = Try.of(decoratedSupplier) // 尝试执行
    .recover(throwable -> getFallbackResult(params)) // 调用失败时执行降级方法
    .get(); // 获取最终结果
```

要点：
- failureRateThreshold：按下游稳定性调整触发阈值
- slowCallRateThreshold：关注慢调用比例，防止仅因响应变慢耗尽资源
- recover：提供降级逻辑（缓存旧数据、默认值等）

---

## 第六招：全链路可观测性
完善的监控体系是应对第三方不可控性的前提。现代可观测性建立在三大支柱上：指标（Metrics）、日志（Logs）和链路（Traces）。三者联动，才能完整还原每次调用的真相。

核心监控指标（在客户端集成 Prometheus 客户端等）：
- 性能指标：调用耗时（平均值、P95、P99）
- 流量指标：QPS、并发线程数
- 错误指标：成功率、错误率（按错误类型细分）
- 治理指标：限流触发次数、熔断器状态变化、重试次数

告警必须分层分级，避免警报疲劳：
- P0（电话/短信）：核心接口短时间内错误率激增或不可用时立即通知
- P1（即时通讯）：P99 响应时间连续异常或熔断器触发时通知相关人员
- 业务通知（邮件/站内信）：第三方长时间不可用时通知业务方评估影响

分布式链路追踪（如 SkyWalking）为每个请求分配 Trace ID，串联用户端到多个第三方服务的完整调用链，便于定位责任边界。

---

## 第七招：异步降级，保护核心业务不牵连
当第三方严重性能问题时，同步调用会阻塞业务线程，拖垮系统。针对非核心或对实时性要求不高的场景（如数据上报、日志同步），可以采用同步转异步的降级策略：用空间换时间，保障核心业务。

设计思路将请求拆成两阶段：
1. 快速接收阶段：立即接收请求，将数据暂存至高速存储
2. 异步处理阶段：后台任务消费暂存数据，完成第三方调用

两种常见实现方案：

方案1：数据库暂存（适合中小型系统）

```java
// 数据暂存服务
public class AsyncService {
    @Autowired
    private RequestRepository requestRepo; // 数据访问层

    public Response handleRequest(Request request) {
        if (isThirdPartyHealthy()) { // 检查第三方状态
            return callThirdPartyDirectly(request); // 正常同步调用
        }
        // 降级为异步模式
        StoredRequest stored = new StoredRequest(request);
        requestRepo.save(stored); // 快速存储到数据库
        return Response.success("请求已接收，处理中");
    }
}

// 后台任务处理器
@Scheduled(fixedRate = 5000) // 每5秒执行一次
public void processPendingRequests() {
    List<StoredRequest> pendingRequests = requestRepo.findByStatus("PENDING");
    for (StoredRequest req : pendingRequests) {
        try {
            callThirdPartyService(req.getData());
            req.setStatus("COMPLETED");
        } catch (Exception e) {
            req.setRetryCount(req.getRetryCount() + 1);
            if (req.getRetryCount() > 3) req.setStatus("FAILED");
        }
        requestRepo.save(req);
    }
}
```

注意：
- 用熔断器或监控指标判断第三方是否可用（isThirdPartyHealthy）
- 重试计数器避免无限重试导致任务堆积
- @Scheduled 控制后台处理频率

方案2：消息队列解耦（适合高并发场景）
- 消息队列：RabbitMQ / RocketMQ / Kafka，提供持久化和削峰填谷能力
- 死信队列：处理超过重试次数的消息，避免阻塞主队列
- 消费者集群：水平扩展的异步处理服务

方案对比（简要）：

| 方案类型     | 适用场景                  | 优势                        | 注意事项                          |
|--------------|---------------------------|-----------------------------|-----------------------------------|
| 数据库暂存   | 低频调用（<100 QPS）      | 实现简单，无需中间件        | 需考虑分库分表，避免单点故障     |
| 消息队列     | 高频调用（>500 QPS）      | 天然解耦，支持水平扩展      | 增加运维复杂度，需监控消息积压   |

架构建议：关键业务场景建议同时实现两种方案。常态使用消息队列，消息队列故障时自动降级到数据库暂存，形成双保险。

---

## 第八招：引入 Mock 服务，搭建全面的测试体系
测试时面临第三方测试环境不稳定、调用成本高、无法模拟异常场景以及压测环境难以获取等挑战。Mock 服务可以识别测试流量（如带 X-Test-Mode: true 请求头）并返回模拟响应，无需调用真正的第三方。

Mock 服务至少应支持三项能力：
1. 模拟各种响应场景
   - 成功场景：返回“支付成功”“短信已发送”等标准响应
   - 业务失败：模拟“余额不足”“验证码过期”等业务错误
   - 系统异常：模拟“网络超时”“连接拒绝”“返回畸形报文”等极端情况
   测试用例可通过参数（如 mock_scene=timeout）指定场景。

2. 模拟第三方回调，形成完整闭环
   - 模拟支付成功后主动调用业务方回调地址
   - 模拟重复回调，验证业务去重逻辑

3. 支持性能压测，模拟真实耗时
   - 模拟真实响应时间分布（例如平均 300ms，波动 ±50ms）
   - 在高并发下稳定返回，不成为压测瓶颈
   - 能模拟在高负载下第三方开始超时的场景，验证限流与熔断策略

实战：某支付系统在双十一压测时，用 Mock 模拟微信支付真实耗时（平均 200ms，峰值 500ms），在 QPS 达 5000 时触发超时，用以发现重试策略在高并发下可能导致线程池耗尽的问题，并据此优化线程池参数和重试策略。

---

## 总结与面试建议
第三方不可控是常态。面试中回答此类问题时，按上面体系化的方案作答会非常完整：从防腐层、主备切换、限流、防御性重试、熔断降级、可观测性、异步降级到测试体系（Mock），逐层说明设计理念、实现要点和监控告警策略，并结合指标与实际案例，能充分展示架构思维和工程落地能力。

按此体系化梳理作答，既能体现对异常场景的处理能力，也能展示实战经验和工程细节，面试官会很容易被说服。若用于实际工程，请结合业务优先级、成本和运维能力做取舍，并在实现过程中逐步迭代、验证与完善。