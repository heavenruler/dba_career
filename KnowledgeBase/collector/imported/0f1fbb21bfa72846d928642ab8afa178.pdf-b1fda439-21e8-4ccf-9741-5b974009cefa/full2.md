# 阿里二面：10亿级分库分表，如何丝滑扩容、如何双写灰度？阿里 P8方案 + 架构图，看完直接上 offer！

作者：45岁老架构师 尼恩

文章目录：
- 尼恩说在前面
- 面试官的考察意图
- 一、分库分表扩容 背景分析
- 二、数据增长预测
  - 短期趋势
  - 中期趋势
  - 长期趋势
- 三、分库分表丝滑扩容面临的问题与挑战
- 四、分库分表丝滑扩容方案（核心：新旧双写 + 灰度切流 + 三级校验）
  - 1. 数据层架构
    - 1.1 分片策略
    - 1.2 数据迁移服务
  - 2. DAO 层双写架构
    - 2.1 新旧双写模块
    - 2.2 自定义刚性事务管理器 / 刚柔结合的双事务架构
  - 3. 中心控制层
    - 3.1 配置中心
    - 3.2 灰度开关
  - 5. 定时任务
  - 6. 理论小结
- 五：实操1：数据双写同步
- 六：自研事务管理器，实现刚性事务双写
  - 6.1 事务管理器定义
  - 6.2 关键实现细节
  - 6.3 异常处理与优化
  - 6.4 验证与监控
- 七：刚柔结合事务控制策略，提高主事务写入的成功率
  - 7.1 数据源定义与分片规则绑定
  - 7.2 分布式事务协调与异常处理
  - 7.4 性能优化与监控
- 八：Nacos 动态控制双写开关设计
  - 1. Nacos 配置项定义
  - 2. 动态配置监听与加载
  - 3. 双写逻辑改造
  - 4. 路由策略动态切换
  - 5. Nacos 集成与运维管控
  - 8.6 验证与监控方案
- 九：读流量灰度：使用动态数据源实现灰度流量切换
  - 9.1 动态数据源配置
  - 9.2 定义不同的分片规则
  - 9.3 DynamicDataSourceRouter 数据源上下文管理和路由
  - 9.5 业务代码如何使用动态数据源自动灰度切流？
  - 9.6 控制器示例
- 十：数据校验与回滚
  - 10.1 校验服务（三级校验）
  - 10.2 自动修复
  - 10.3 监控告警
- 120分殿堂答案（塔尖级）

尼恩说在前面
----------------
在面试交流群中，最近有小伙伴拿到了阿里、滴滴、极兔、有赞、希音、百度、网易、美团等一线互联网企业的面试资格，面试题中常出现一些核心题目，例如：

- 每天新增 100w 订单，如何分库分表？
- 10–100 亿级数据，如何实现分库分表的丝滑扩容？
  
分库分表是面试的核心重点之一。本文将系统化、体系化地梳理该问题的思路与实现要点，覆盖扩容背景、问题识别、设计方案、实操代码、校验与监控等内容，适合作为面试与实际工程参考。

面试官的考察意图
----------------
考察点包括但不限于：

- 分库分表概念、原理和策略：水平分库、水平分表、垂直分库、垂直分表的适用场景与实现方式，是否能针对 10 亿级数据选择合适方案。
- 扩容技术掌握：数据迁移、节点添加、负载均衡等，是否熟悉主流扩容方法及优缺点。
- 相关技术栈：分布式事务、数据一致性保证、缓存策略等，知识体系的完整性。
- 复杂问题分析能力：能否清晰分析问题（数据量、增速、业务场景、性能影响等），并提出合理扩容思路与方案。
- 应对挑战能力：预见扩容中可能出现的数据丢失、一致性问题、性能下降、业务中断等，并给出有效应对措施。

一、分库分表扩容 背景分析
----------------
随着业务发展，用户数和业务数据呈爆发式增长。以电商为例，从每天数百笔到数十万、数百万笔订单，订单、用户、商品等数据不断累积，单表数据量可能达到千万乃至亿级。数据规模增长会导致读写性能下降、存储与管理复杂化，需要分库分表与扩容策略来保障系统可用性与性能。

二、数据增长预测
----------------
短期趋势（1–2年）：受市场推广与业务扩展影响，订单数据可能以每年 30%–50% 增长。每天新增订单可能在 130万–150万，订单总量达到 1 亿级别。

中期趋势（3–5年）：增速放缓至每年 20%–30%，每天新增订单可能接近 250 万，订单总量达到 10 亿级别。

长期趋势（5–10年）：市场趋于饱和，增速稳定在每年 10%–20%，每天新增订单可能接近 600 万，订单总量达到 100 亿级别。

三、分库分表丝滑扩容面临的问题与挑战
----------------
主要挑战包括：

- 迁移时间过长：10 亿级数据全量迁移耗时可能为天级或周级，且需要处理迁移期间的增量数据。
- 准确性验证难：大量迁移过程中可能出现数据丢失、重复或错误，保证迁移后数据完全一致需要耗费大量人力和计算资源。
- 数据一致性问题：迁移期间需保证旧库可读写，同时新库准确写入，网络或系统故障可能导致新旧库不一致。
- 分布式事务复杂：扩容后涉及更多节点，事务一致性协调难度大，可能出现部分节点提交失败。
- 业务中断风险：数据迁移与切换期间可能需要暂停部分业务读写，灰度策略虽能减少影响，但仍难彻底避免短暂中断。

四、分库分表丝滑扩容方案（核心：新旧双写 + 灰度切流 + 三级校验）
----------------
目标：通过多维度、多层次设计实现分库分表的无缝扩容，确保在数据与流量增长时平滑过渡，不影响业务正常运行。方案覆盖 DAO 层、控制层、数据层与定时任务等。

1. 数据层架构

1.1 分片策略
- 老库分片：1..N， 新库分片：1..2N（在旧库基础上扩容为 2N 分片以应对未来增长）。
- 选择合理分片键，避免热点与不均衡。
- 复合分片算法：用户 ID 哈希 + 时间范围双路由，支持动态调整分片数量而不影响存量数据分布。
- 一致性哈希环：虚拟节点数可设置为物理节点的 100 倍，确保扩容后数据均衡。

1.2 数据迁移服务
- 全量迁移：使用高效多线程并发迁移工具（如 DataX、Kettle），按创建时间窗口分批迁移，处理字段映射与类型转换。采用同步偏移量双存储（Redis + MySQL）防止单点故障丢失位点信息。
- 增量同步：使用变更捕获（如 MySQL Binlog + Canal）实时同步旧库增量到新库，延迟控制在 500ms 以内。
- 数据双写同步：因 Binlog 同步可能有可见性延迟，可在应用层实现双写保证新库尽快可见。

2. DAO 层双写架构

2.1 新旧双写模块
- 写入时同时写旧库与新库，提供配置开关动态控制双写启停，便于扩容过程中的切换与回滚。

2.2 自定义刚性事务管理器 / 刚柔结合的双事务架构
- 刚性事务管理器：针对关键业务，设计自定义事务管理器，协调旧库与新库事务，任一失败则回滚所有操作（强一致性）。
- 刚柔结合：对非关键业务使用柔性事务，允许最终一致性，通过消息队列异步补偿。

智能降级机制：当分片路由异常时自动切回老库保证可用性。

3. 中心控制层

3.1 配置中心
- 集中管理分片规则、数据源信息等配置，使用成熟配置中心（如 Nacos、Apollo），支持动态更新、版本控制与回滚。

3.2 灰度开关
- 通过灰度开关逐步放开流量验证新架构正确性。支持多维灰度策略（按用户 ID 段、业务类型、地域等）和流量染色（请求头标记）。
- 建议按梯度（5%、20%、50%）逐步切换，每阶段观察 12 小时并基于监控数据调整。

5. 定时任务
- 定期对新旧库数据进行比对，确保一致性；对于发现的不一致记录详细信息并发起修复流程。

6. 理论小结
- 通过 DAO 层双写、控制层灰度开关、数据层迁移与定时比对，形成系统化的扩容架构。扩容需严格按步骤执行并密切监控系统状态。

五：实操1：数据双写同步
----------------
在使用 Sharding-JDBC 进行双写时，需配置两个数据源（旧库、新库）。示例（application.yml 片段）：

```yaml
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
        username: new_user
        password: new_password
    sharding:
      default-database-strategy:
        inline:
          sharding-column: user_id
          algorithm-expression: oldDataSource
      tables:
        your_table_name:
          actual-data-nodes: oldDataSource.your_table_name,newDataSource.your_table_name
```

示例应用层双写方法（Java）：

```java
@Transactional
public void doubleWrite(String sql, Object... args) {
    TransactionTypeHolder.set(TransactionType.XA);
    try {
        oldJdbcTemplate.update(sql, args);
        newJdbcTemplate.update(sql, args);
    } catch (Exception e) {
        // 记录异常日志
        log.error("数据双写失败", e);
        // 手动回滚事务
        TransactionAspectSupport.currentTransactionStatus().setRollbackOnly();
    } finally {
        TransactionTypeHolder.clear();
    }
}
```

六：自研事务管理器，实现刚性事务双写
----------------
第一种方案：自研事务管理器实现跨 Sharding-JDBC 数据源的统一事务管理，强制两个数据源在同一事务边界内提交或回滚。

6.1 事务管理器定义（示例）

```java
public class DualShardingTransactionManager extends AbstractPlatformTransactionManager {
    private final DataSource dataSourceOld; // 旧库
    private final DataSource dataSourceNew; // 新库

    public DualShardingTransactionManager(DataSource old, DataSource ne) {
        this.dataSourceOld = old;
        this.dataSourceNew = ne;
    }

    @Override
    protected Object doGetTransaction() {
        return new DualTransactionHolder(
            DataSourceUtils.getConnection(dataSourceOld),
            DataSourceUtils.getConnection(dataSourceNew)
        );
    }

    @Override
    protected void doCommit(DefaultTransactionStatus status) {
        DualTransactionHolder holder = (DualTransactionHolder) status.getTransaction();
        try {
            holder.getOldConnection().commit(); // 旧库提交
            holder.getNewConnection().commit(); // 新库提交
        } catch (SQLException e) {
            throw new TransactionSystemException("双写提交失败", e);
        }
    }

    @Override
    protected void doRollback(DefaultTransactionStatus status) {
        DualTransactionHolder holder = (DualTransactionHolder) status.getTransaction();
        try {
            holder.getOldConnection().rollback(); // 旧库回滚
            holder.getNewConnection().rollback(); // 新库回滚
        } catch (SQLException e) {
            throw new TransactionSystemException("双写回滚失败", e);
        }
    }

    private static class DualTransactionHolder {
        private final Connection oldConnection;
        private final Connection newConnection;
        public DualTransactionHolder(Connection oldConn, Connection newConn) {
            this.oldConnection = oldConn;
            this.newConnection = newConn;
        }
        public Connection getOldConnection() { return oldConnection; }
        public Connection getNewConnection() { return newConnection; }
    }
}
```

6.2 关键实现细节
- 数据源配置与绑定：为旧库与新库分别配置分片信息，确保 Sharding-JDBC 的数据源映射正确。
- 事务传播控制：在服务层通过 @Transactional 指定统一事务管理器，并使用 DataSourceUtils.getConnection() 确保从统一事务上下文获取连接。两端操作必须在同一线程执行。

示例服务层（伪代码）：

```java
@Service
public class OrderService {
    @Transactional(transactionManager = "dualShardingTransactionManager")
    public void createOrder(Order order) {
        // 旧库写入
        oldOrderMapper.insert(order);
        // 新库写入
        newOrderMapper.insert(order);
    }
}
```

6.3 异常处理与优化
- 单数据源提交失败：强制回滚另一数据源，避免部分提交。
- 连接泄露：通过 DataSourceUtils.releaseConnection() 在 finally 块中释放资源。

6.4 验证与监控
- 事务一致性验证（单元测试）：在事务提交后比较旧库与新库的数据一致性。
- 监控指标：双写事务平均耗时、连接持有时间等，通过 Micrometer、日志采集等手段监控。

备注：自研刚性事务管理器在保证强一致性方面有效，但复杂度与对业务影响较大（新库写入失败会直接影响业务）。在多数场景，不建议作为首选方案，除非一致性要求极高。

七：刚柔结合事务控制策略，提高主事务写入的成功率
----------------
在双写场景下，主事务（旧库）与子事务（新库）采用不同策略，保证数据一致性与系统稳定性。

7.1 数据源定义与分片规则绑定（示例配置片段）

旧库（单库单表）与新库（分片）需在分片规则上兼容（例如 member_id 的取模逻辑一致）：

```yaml
oldDataSource:
  driver-class-name: com.mysql.jdbc.Driver
  url: jdbc:mysql://old-db:3306/db_old
  username: root
  password: 123456

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
```

7.2 事务管理器实现细节
配置两个事务管理器：一个管理旧库本地事务（transactionManagerOld），一个管理新库分片事务（transactionManagerSplit）。服务层使用 REQUIRED 提交主事务并在子方法中使用 REQUIRES_NEW 提交新库写入，配合异步补偿机制处理新库失败场景。

示例服务代码：

```java
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
        // 主事务：旧库写入（强一致性）
        oldRepository.insert(order);
        // 子事务：新库分片写入（独立提交或回滚）
        writeToShardingDB(order);
    }

    @Transactional(
        propagation = Propagation.REQUIRES_NEW,
        transactionManager = "transactionManagerSplit",
        noRollbackFor = {ShardingException.class}
    )
    private void writeToShardingDB(Order order) {
        try {
            newRepository.insert(order);
        } catch (ShardingException e) {
            // 分片路由失败时记录日志，不触发主事务回滚
            log.error("分片写入失败: orderId={}", order.getId());
            mqSender.sendRetryMessage(order); // 异步补偿
        }
    }
}
```

关键逻辑：主事务保证写入旧库的原子性，子事务独立提交，子事务异常由 MQ 异步补偿处理，保证最终一致性。

7.2 分布式事务协调与异常处理
- 柔性事务补偿：通过消息队列（如 RocketMQ）异步重试新库写入，采用指数退避与重试次数上限（例如 3 次），超限触发人工处理。
- 数据一致性校验工具：实现跨库比对方法，按路由计算实际数据节点并比对主键与关键字段一致性。

示例校验逻辑（伪代码）：

```java
public void verifyData(Order order) {
    Order oldOrder = oldRepository.selectById(order.getId());
    String actualNode = shardingAlgorithm.getActualDataNode(order.getMemberId());
    Order newOrder = newRepository.selectByShardingKey(actualNode, order.getId());
    Assert.isTrue(oldOrder.equals(newOrder), "数据不一致");
}
```

7.4 性能优化与监控
- 连接池与批量写入优化：旧库可使用 Druid，新库使用 HikariCP。启用 rewriteBatchedStatements=true 提升批量写入性能。
- 监控埋点：双写事务 TPS、分片路由失败率、异步补偿队列堆积量等，通过 Micrometer、日志与消息中间件控制台监控并设置告警阈值。

八：Nacos 动态控制双写开关设计
----------------
为实现可控的双写与灰度切换，需要一个动态开关以在无需重启的情况下开启/关闭新表写入。

1. Nacos 配置项定义（示例）

```yaml
dualWrite:
  enabled: true     # 双写开关
  forceReadNew: false  # 强制读新库
```

- enabled 控制是否开启新库写入；
- forceReadNew 用于灰度阶段强制查询新库。

2. 动态配置监听与加载（Spring 示例）

```java
@Configuration
@RefreshScope
public class DualWriteConfig {
    @Value("${dualWrite.enabled:false}")
    private AtomicBoolean enabled;
    @Value("${dualWrite.forceReadNew:false}")
    private AtomicBoolean forceReadNew;

    public boolean isDualWriteEnabled() { return enabled.get(); }
    public boolean isForceReadNew() { return forceReadNew.get(); }
}
```

关键点：使用 @RefreshScope 实现配置热更新，AtomicBoolean 保证线程安全。

3. 双写逻辑改造
在服务层根据开关决定是否写新库：

```java
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
```

4. 路由策略动态切换（读取侧）
示例读取逻辑：

```java
public Order getOrder(Long orderId) {
    if (dualWriteConfig.isForceReadNew()) {
        try (HintManager hintManager = HintManager.getInstance()) {
            hintManager.setMasterRouteOnly();
            return newRepository.selectByShardingKey(orderId);
        }
    } else {
        return oldRepository.selectById(orderId);
    }
}
```

5. Nacos 集成与运维管控
- 注册配置变更监听器，触发 @RefreshScope 刷新。
- 监控项：配置变更次数、双写开关状态及相关指标（通过 /metrics 暴露）。

8.6 验证与监控方案
- 单元测试验证开关行为（双写开启/关闭场景）。
- 监控大盘：双写开关状态、新库写入 TPS、增量同步延迟等，并设置告警规则（例如增量同步延迟 > 60s 报警）。

九、读流量灰度：使用动态数据源实现灰度流量切换
----------------
通过 AbstractRoutingDataSource 实现请求维度的数据源切换，配合 Filter 在请求前设置数据源上下文并在 finally 中清理，确保线程安全与无污染。

9.1 动态数据源配置（核心思路）
- 为旧版本与新版本分别创建 Sharding-JDBC 数据源实例（oldDataSource 与 newDataSource）。
- 使用 AbstractRoutingDataSource 的子类 DynamicDataSourceRouter，根据 ThreadLocal 中的标识路由到对应数据源。
- 注入动态数据源 Bean 供应用使用。

示例 DataSourceConfig（简要片段）：

```java
@Configuration
public class DataSourceConfig {
    @Bean(name = "oldDataSource")
    public DataSource oldDataSource() throws SQLException {
        // 从 old-sharding-rule.yaml 加载配置并构建 ShardingDataSource
        return ShardingDataSourceFactory.createDataSource(createOldDataSourceMap(), oldShardingRuleConfig, new Properties());
    }

    @Bean(name = "newDataSource")
    public DataSource newDataSource() throws SQLException {
        // 从 new-sharding-rule.yaml 加载配置并构建 ShardingDataSource
        return ShardingDataSourceFactory.createDataSource(createNewDataSourceMap(), newShardingRuleConfig, new Properties());
    }

    @Bean
    @Primary
    public DataSource dynamicDataSource() {
        Map<Object, Object> targetDataSources = new HashMap<>();
        try {
            targetDataSources.put("old", oldDataSource());
            targetDataSources.put("new", newDataSource());
        } catch (SQLException e) {
            e.printStackTrace();
        }
        DynamicDataSourceRouter dataSource = new DynamicDataSourceRouter();
        dataSource.setTargetDataSources(targetDataSources);
        try {
            dataSource.setDefaultTargetDataSource(oldDataSource());
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return dataSource;
    }

    // loadShardingRuleConfig 和 createDataSourceMap 等方法需按项目实现
}
```

9.2 定义不同的分片规则
分别为旧版本与新版本定义 Sharding-JDBC 的分片规则（yaml 示例）：

old-sharding-rule.yaml（示例）：
```yaml
dataSources:
  ds_0:
    url: jdbc:mysql://localhost:3306/ds_0
    username: root
    password: root
    driverClassName: com.mysql.cj.jdbc.Driver
shardingRule:
  tables:
    t_order:
      actualDataNodes: ds_0.t_order_$->{0..1}
      tableStrategy:
        inline:
          shardingColumn: order_id
          algorithmExpression: t_order_$->{order_id % 2}
```

new-sharding-rule.yaml（示例）：
```yaml
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
```

9.3 DynamicDataSourceRouter 数据源上下文管理和路由

```java
public class DynamicDataSourceRouter extends AbstractRoutingDataSource {
    @Override
    protected Object determineCurrentLookupKey() {
        return DataSourceContextHolder.getDataSource();
    }
}
```

DataSourceContextHolder（ThreadLocal 工具类）：

```java
public class DataSourceContextHolder {
    private static final ThreadLocal<String> contextHolder = new ThreadLocal<>();
    public static void setDataSource(String ds) { contextHolder.set(ds); }
    public static String getDataSource() { return contextHolder.get(); }
    public static void clearDataSource() { contextHolder.remove(); }
}
```

基于 Filter 实现灰度规则判断与清理（伪代码）：

```java
@Component
public class DataSourceSwitchFilter implements Filter {
    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain chain)
            throws IOException, ServletException {
        HttpServletRequest httpRequest = (HttpServletRequest) request;
        try {
            String userId = httpRequest.getHeader("user-id");
            if (StringUtils.isNotBlank(userId) && StringUtils.isNumeric(userId)
                && Integer.parseInt(userId) % 100 < 20) { // 20% 灰度示例
                DataSourceContextHolder.setDataSource("new");
            } else {
                DataSourceContextHolder.setDataSource("old");
            }
            chain.doFilter(request, response);
        } finally {
            DataSourceContextHolder.clearDataSource();
        }
    }
}
```

Filter 注册示例：

```java
@Configuration
public class FilterConfig {
    @Bean
    public FilterRegistrationBean<DataSourceSwitchFilter> registerFilter() {
        FilterRegistrationBean<DataSourceSwitchFilter> bean = new FilterRegistrationBean<>();
        bean.setFilter(new DataSourceSwitchFilter());
        bean.addUrlPatterns("/*");
        bean.setOrder(Ordered.HIGHEST_PRECEDENCE);
        return bean;
    }
}
```

关键实现要点：
- 灰度标识获取可扩展到 Cookie、Session、JWT、请求参数等。
- 添加灰度参数解析异常处理，避免 NumberFormatException。
- 结合配置中心（Nacos/Apollo）动态调整灰度比例。
- 在切换后做好日志记录以便排查交叉污染问题。
- 使用压力测试（JMeter 等）验证灰度场景下系统稳定性。

9.5 业务代码如何使用动态数据源自动灰度切流？
业务代码无感知，直接使用注入的 DataSource。示例服务：

```java
@Service
public class BusinessService {
    @Autowired
    private DataSource routingDataSource;

    public void queryOrder(String userId) {
        try (Connection connection = routingDataSource.getConnection();
             PreparedStatement ps = connection.prepareStatement("SELECT * FROM t_order WHERE user_id = ?")) {
            ps.setString(1, userId);
            try (ResultSet rs = ps.executeQuery()) {
                while (rs.next()) {
                    // 处理查询结果
                }
            }
        } catch (SQLException e) {
            e.printStackTrace();
        } finally {
            DataSourceContextHolder.clearDataSource();
        }
    }
}
```

9.6 控制器示例

```java
@RestController
public class OrderController {
    @Autowired
    private BusinessService businessService;

    @GetMapping("/orders/{userId}")
    public String queryOrder(@PathVariable String userId) {
        businessService.queryOrder(userId);
        return "Query order success";
    }
}
```

注意事项：
- 完善异常处理与资源释放。
- 实现 loadShardingRuleConfig 与 createDataSourceMap 等方法用于从配置文件加载规则与数据源信息。
- ThreadLocal 使用时要确保在多线程环境不会产生污染。

十：数据校验与回滚
----------------
10.1 校验服务（三级校验）
定期比对新旧库数据，确保一致性。三级校验策略：
- 字段级校验（小时级）：选择关键字段（主键、时间戳、业务关键字段）进行比对，避免全字段比对带来的性能消耗。
- 行级 MD5 比对（每日低谷期）：使用 MD5 对关键字段或字符串列做哈希对比。
- 统计指标校验（周级）：按分片统计记录数、分布等指标监控。

实现细节：定时任务按时间戳顺序分批比对，记录不一致数据详情（ID、字段差异等）。

10.2 自动修复
- 对发现的不一致数据设计自动修复或归档机制，异常数据先归档待人工核查，执行修复并记录审计日志。

10.3 监控告警
- 关键监控指标：数据迁移进度、数据一致性比率、系统性能指标（P99延迟等）。
- 告警方式：邮件、短信、即时通讯工具等，确保告警及时送达和响应。

监控指标示例与告警阈值：
- 事务一致性（双写成功率） < 99.9%（5分钟）
- 数据完整性（校验差异率） > 0.01%
- 性能指标（分片 P99 延迟） > 500ms

120分殿堂答案（塔尖级）
----------------
到此，结合动态扩容、灰度切流、双写事务与三级校验的综合方案，已经展示了面试题的完整工程化思路与实现要点，这类深度回答在面试中极具说服力。实际工程中，请根据业务特性和团队的可执行性，选择合适的强一致性或最终一致性策略，并做好充足的监控与应急预案。

总结与建议
----------------
- 分库分表扩容是复杂系统工程，需要考虑数据迁移、双写策略、事务一致性、灰度切流、校验与监控等多方面。
- 面试回答要结构化：背景分析 → 问题识别 → 设计方案（包含权衡）→ 实施步骤 → 校验与回滚 → 监控与告警。
- 在工程实践中，优先使用刚柔结合的方案（主事务强一致，异步补偿保证最终一致）以平衡可用性与一致性。

如果你正在准备相关面试，建议把这些关键模块（数据迁移、双写设计、灰度策略、事务管理、校验与监控）形成结构化的答题模板，并准备部分代码说明与监控指标示例，能够在面试中脱颖而出。