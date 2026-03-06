阿里面试：每天新增 100w 订单，如何分库分表？这份答案让我当场拿了 offer
作者：45岁老架构师 尼恩

文章目录：
- 尼恩说在前面
- 尼恩解密：面试官的考察意图
  - （1）对分布式数据库设计的理解
  - （2）对业务需求的分析能力
  - （3）对技术细节的掌握
- 一：分库分表 背景分析
  - 1. 场景分析
  - 2. 数据增长预测（短期 / 中期 / 长期）
  - 3. 面临的问题与挑战（查询劣化、写入劣化、容量瓶颈、备份、清理）
- 二：分库分表三大策略
  - 一致性 hash 取模策略
  - 按时间范围分库分表
  - 组合模式分库分表（ID 取模分库 + 时间范围分表）
- 三：一致性 hash 取模分库分表
  - 1. 前期规划
  - 2. 分库策略
  - 3. 分表策略
  - 4. 优势
  - 5. 劣势
- 四：按照时间范围分库分表
  - 1. 分库策略
  - 2. 分表策略
  - 3. 路由策略
  - 4. 优点
  - 5. 不足
- 五：组合模式分库分表（ID 取模分库、时间范围分表）
  - 1. 前期规划
  - 2. 分库策略：ID 取模分库
  - 3. 分表策略：时间范围分表
- 六：如何使用 ShardingSphere 实现组合策略分库分表
  - 模式说明：JDBC / Proxy / Sidecar
  - Sharding-JDBC 常见五种分片策略（Standard / Complex / Hint / None / Inline）
- 七、实操：组合模式分库分表（ID 取模分库、时间范围分表）
  - 分库算法：DBShardingAlgorithm（取模分库）
  - 分表算法：TableShardingAlgorithm（月分表 / 基于日期或 Snowflake ID 时间戳）
  - application.properties 示例要点
- 八：优化：如何避免 ID 查询时的全库路由问题？
  - 1. 引入异构索引表
  - 2. 使用时间基因法
- 九：使用雪花 ID 的时间基因，解决 ID 查询时的全库路由问题
  - 1. 雪花算法 ID 结构
  - 2. 如何从 ID 中提取时间并确定时间范围
  - 3. 实操（解析雪花 ID、修改分片算法、修改配置）
- 未完待续：读写分离架构、动态扩容架构与实现
- 结语与职业建议

尼恩说在前面
这篇文章系统性地梳理了“每天新增 100 万订单，如何做分库分表”的思路与实操示例，覆盖面试时常被问到的技术点、策略选择、实现细节以及优化方向。可以作为面试中回答该题时的结构化答案与参考实现。

尼恩解密：面试官的考察意图
（1）对分布式数据库设计的理解  
面试官希望候选人理解分库分表的目的、常见策略（水平分片、垂直分片、按范围分片等），能权衡各方案优劣并选择适合业务的方案。

（2）对业务需求的分析能力  
面试官会关注：每天新增 100w 订单的访问模式（读写比例、热点）、数据生命周期（热数据与归档）、一致性需求（是否需要分布式事务）等。好的回答需要结合这些维度给出设计权衡。

（3）对技术细节的掌握  
分库分表涉及分片键选择、分布式事务、数据迁移、查询优化、路由问题（全库路由）等。面试官希望看到候选人能提出可行的解决办法，比如引入索引表、利用 ID 的时间基因、采用合适的中间件（ShardingSphere）等。

一：分库分表 背景分析
1. 场景分析  
订单是电商等业务的核心数据。以中等规模电商为例，每天新增订单可能达到 100 万条以上，订单包含订单编号、用户信息、商品详情、交易金额、时间等，对运营与分析很重要。

2. 数据增长预测  
- 短期（1-2 年）：假设年增长 30%-50%，每天新增 100w 可能增长到 130w-150w，总量上亿级。  
- 中期（3-5 年）：年增长 20%-30%，每天新增接近 250w，总量到 10 亿级。  
- 长期（5-10 年）：年增长 10%-20%，每天新增接近 600w，总量到百亿级。

3. 面临的问题与挑战  
- 查询劣化：单表数据增长会导致响应时间大幅上升。  
- 写入劣化：高并发写入会触碰单库吞吐瓶颈，出现延迟或失败。  
- 容量瓶颈：单库存储有限，扩容成本高。  
- 数据备份困难：大体量备份耗时、占空间。  
- 数据清理困难：归档与清理复杂，涉及业务关联。

二、分库分表三大策略
- 一致性 hash（或一致性哈希取模）策略  
- 按时间范围分库分表（按年/月/日等）  
- 组合模式（例如 ID 取模分库 + 时间范围分表）

三、一致性 hash 取模分库分表
场景示例：20 亿数据，128 张表，按 id 一致性 hash 取模分库分表。

1. 前期规划  
- 根据硬件和负载初步确定分库数量，例如 8 或 16 个库。  
- 总表数 128 张，均摊到各库。

2. 分库策略  
- 使用一致性哈希算法（如 MurmurHash），计算 hash(id)，再 % 库数得到 db_index。  
- 示例公式：db_index = hash(id) % 16

3. 分表策略  
- 在确定库之后，对每库内的表数量再做 % 操作得到 table_index，例如 table_index = hash(id) % 8。  
- 最终表名格式：db_{db_index}.table_{table_index}

4. 一致性哈希的优势  
- 数据分布相对均匀；节点增减时数据迁移量小；高扩展性；容错性强。

5. 一致性哈希的劣势  
- 算法实现和维护复杂；数据分布并非绝对均匀（需虚拟节点）；维护成本高；不利于范围查询。

四：按照时间范围分库分表
在 20 亿数据情况下，按时间范围分库分表能利用时间有序性优化查询与归档。

1. 分库策略  
- 建议按时间或按年分库，例如 16 个库，db_index = (year - baseYear) % 16。

2. 分表策略  
- 每个库内再按月（或其他粒度）分表，例如每库 8 张表，总表数 16 × 8 = 128。  
- 表名示例：t_YYYYMM（如 t_202502 表示 2025 年 2 月数据）。

3. 路由策略  
- 选择合适的时间单位（年/月/周/天），为每个时间范围映射唯一的 db_index 和 table_index。

4. 时间范围分库的优点  
- 查询特定时间段数据时只访问对应表，避免全表扫描；便于归档和备份；扩容简单；适合时间序列数据。

5. 时间范围分库的不足  
- 热点集中（最近时间窗口）；跨表查询复杂；表数量增长后迁移与维护成本高；应用层路由逻辑复杂；跨库事务复杂。

五：组合模式分库分表（ID 取模分库、时间范围分表）
组合模式兼顾均衡分布与时间查询优势，适用于订单类场景。

1. 前期规划  
- 根据并发与资源先确定分库数量（如 8 个 db_0..db_7），按月分表（t_YYYYMM）。

2. 分库策略（ID 取模）  
- 分片键选择高基数字段，如 order_id 或 user_id。  
- 分片算法：shard_id = id % N（N 为库数），均匀分布到不同库。

3. 分表策略（时间范围分表）  
- 以 create_time 为依据按月分表，表名如 order_202401、order_202402 等。

六：如何使用 ShardingSphere 实现组合策略分库分表
ShardingSphere 提供三种使用模式：
- JDBC 模式（Sharding-JDBC）：嵌入应用，轻量，适合 Java 应用。
- Proxy 模式（ShardingSphere-Proxy）：数据库代理，支持多客户端工具，DBA 友好。
- Sidecar 模式：Kubernetes 下的 Sidecar 模式（云原生路线，正逐步完善）。

在实际项目中，JDBC 模式因与 Java 应用集成便捷常被采用。

Sharding-JDBC 的五种分片策略概览：
1. StandardShardingStrategy（标准分片策略）  
   - 支持 =, >, <, >=, <=, IN, BETWEEN AND 等操作。  
   - 算法包括 PreciseShardingAlgorithm（处理 = 和 IN）和 RangeShardingAlgorithm（处理范围查询）。

示例代码：Precise 和 Range 分片算法（示例）
```java
// 精确分片算法示例
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import java.util.Collection;

public class MyPreciseShardingAlgorithm implements PreciseShardingAlgorithm<Long> {
    @Override
    public String doSharding(Collection<String> availableTargetNames,
                             PreciseShardingValue<Long> shardingValue) {
        for (String each : availableTargetNames) {
            if (each.endsWith(String.valueOf(shardingValue.getValue() % 2))) {
                return each;
            }
        }
        throw new UnsupportedOperationException();
    }
}

// 范围分片算法示例
import org.apache.shardingsphere.api.sharding.standard.RangeShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.RangeShardingValue;
import com.google.common.collect.Range;
import java.util.Collection;
import java.util.LinkedHashSet;

public class MyRangeShardingAlgorithm implements RangeShardingAlgorithm<Long> {
    @Override
    public Collection<String> doSharding(Collection<String> availableTargetNames,
                                         RangeShardingValue<Long> shardingValue) {
        Collection<String> result = new LinkedHashSet<>();
        Range<Long> range = shardingValue.getValueRange();
        for (Long i = range.lowerEndpoint(); i <= range.upperEndpoint(); i++) {
            for (String each : availableTargetNames) {
                if (each.endsWith(String.valueOf(i % 2))) {
                    result.add(each);
                }
            }
        }
        return result;
    }
}
```

2. ComplexShardingStrategy（复合分片策略）  
   - 支持多个分片键，灵活但需要开发者实现复合逻辑。

3. HintShardingStrategy（Hint 分片策略）  
   - 通过 HintManager 手动指定分片值，绕过 SQL 解析。

示例：
```java
try (HintManager hintManager = HintManager.getInstance()) {
    hintManager.addDatabaseShardingValue("table_name", 1);
    // 执行 SQL 操作
}
```

4. NoneShardingStrategy（不分片策略）  
   - 用于不需要分片的表或单一数据源的场景。

5. InlineShardingStrategy（行表达式分片策略）  
   - 基于表达式（如 order_id % 2）快速配置，适合简单场景。

示例 YAML：
```yaml
tables:
  order_table:
    actualDataNodes: ds_${0..1}.order_table_${0..1}
    tableStrategy:
      inline:
        shardingColumn: order_id
        algorithmExpression: order_table_${order_id % 2}
```

七、实操：组合模式分库分表（ID 取模分库、时间范围分表）
示例思路：db 以订单 id 取模分库，table 以订单创建时间分表（按月）。

分库算法：DBShardingAlgorithm（取模分库）
```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.util.Collection;

public class DBShardingAlgorithm implements PreciseShardingAlgorithm<Long> {
    private static final Logger log = LoggerFactory.getLogger(DBShardingAlgorithm.class);

    @Override
    public String doSharding(Collection<String> availableTargetNames,
                             PreciseShardingValue<Long> shardingValue) {
        log.info("DB PreciseShardingAlgorithm");
        availableTargetNames.forEach(item -> log.info("actual node db:{}", item));
        log.info("logic table name:{}, route column:{}", shardingValue.getLogicTableName(), shardingValue.getColumnName());
        log.info("column value:{}", shardingValue.getValue());

        long orderId = shardingValue.getValue();
        long dbIndex = Math.abs(Long.valueOf(orderId).hashCode()) % 16; // 示例：hash % 16
        String targetDb = "db_" + dbIndex;

        for (String each : availableTargetNames) {
            if (each.equals(targetDb)) {
                return each;
            }
        }
        throw new IllegalArgumentException("No matching database found for orderId: " + orderId);
    }
}
```

分表算法：TableShardingAlgorithm（月分表（基于 Date）示例）
```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Date;

public class TableShardingAlgorithm implements PreciseShardingAlgorithm<Date> {
    private static final Logger log = LoggerFactory.getLogger(TableShardingAlgorithm.class);

    @Override
    public String doSharding(Collection<String> availableTargetNames,
                             PreciseShardingValue<Date> shardingValue) {
        log.info("table PreciseShardingAlgorithm");
        availableTargetNames.forEach(item -> log.info("actual node table:{}", item));
        log.info("logic table name:{}, route column:{}", shardingValue.getLogicTableName(), shardingValue.getColumnName());
        log.info("column value:{}", shardingValue.getValue());

        String tbName = shardingValue.getLogicTableName();
        Date date = shardingValue.getValue();
        SimpleDateFormat yearFormat = new SimpleDateFormat("yyyy");
        SimpleDateFormat monthFormat = new SimpleDateFormat("MM");
        String year = yearFormat.format(date);
        String month = monthFormat.format(date);
        tbName = tbName + year + "_" + month;
        log.info("tb_name:{}", tbName);

        for (String each : availableTargetNames) {
            if (each.equals(tbName)) {
                return each;
            }
        }
        throw new IllegalArgumentException("No matching table found: " + tbName);
    }
}
```

application.properties 配置要点（示意）
- 配置多个数据源名称（db_0..db_15）并配置各数据源连接信息（JDBC URL、用户名、密码等）。  
- 配置默认数据源。  
- 配置表的 actual-data-nodes，例如：db_${0..15}.t_order_${202501..202512}（视具体版本与表达式功能）。  
- 指定数据库分片列（order_id）和对应 Precise 分片算法类；指定表分片列（create_time 或 order_id（若使用雪花解析））和对应 Precise 分片算法类。  
- 可配置 Snowflake 作为主键生成器。

八：优化：如何避免 ID 查询时的全库路由问题？
组合策略能缓解许多情况，但当只有 ID 没有时间字段时，查询单个 ID 仍可能触发全库路由。常见优化：

1. 引入异构索引表（空间换时间）  
- 在写入时同时将 order_id 与时间信息或路由信息写到一张索引表（例如按天分区的 order_time_index）。  
- 查询时先查索引表定位被存储的库/表，再直接路由到目标表。

示例索引表 DDL：
```sql
CREATE TABLE order_time_index (
  day DATE NOT NULL,
  order_id VARCHAR(64) NOT NULL,
  PRIMARY KEY (day, order_id)
) ENGINE=InnoDB
PARTITION BY RANGE (TO_DAYS(day)) (
  PARTITION p20230901 VALUES LESS THAN (TO_DAYS('2023-09-02')),
  PARTITION p20230902 VALUES LESS THAN (TO_DAYS('2023-09-03'))
);
```

2. 使用时间基因法（在 ID 中嵌入时间信息）  
- 生成 ID 时嵌入时间片段（如 yyyyMMdd + 序号），分片时直接根据时间前缀定位分片，避免全库扫描。

九：使用雪花 ID 的时间基因，解决 ID 查询时的全库路由问题？
雪花 ID（Snowflake）本身包含时间戳信息，可以解析时间戳并据此定位分表。

1. 雪花 ID 结构（常见 64 位）  
- 符号位（1）  
- 时间戳（41）——相对于基准时间的毫秒差  
- 数据中心 ID（5）  
- 机器 ID（5）  
- 序列号（12）

2. 如何从 ID 中提取时间戳  
常见提取公式（根据具体实现位数调整）：
```java
long timestamp = (id >> 22) + twepoch;
Date date = new Date(timestamp);
```
其中 twepoch 为起始时间戳（例如 2024-01-01 的毫秒值），22 = 数据中心+机器+序列号位数（示例）。

3. 实操：将雪花 ID 的时间戳作为分表基因
- 编写 SnowflakeIdParser 解析 ID 得到 Date：
```java
public class SnowflakeIdParser {
    private static final long TIMESTAMP_SHIFT = 22; // 示例，视具体实现而定
    private static final long EPOCH = 1577836800000L; // 2020-01-01 00:00:00
    public static java.util.Date getDateFromSnowflakeId(long snowflakeId) {
        long timestamp = (snowflakeId >> TIMESTAMP_SHIFT) + EPOCH;
        return new java.util.Date(timestamp);
    }
}
```
- 修改 TableShardingAlgorithm 的 PreciseShardingAlgorithm<Long> 实现，从 order_id 提取时间并定位到表名（如 t_YYYYMM）。

修改后的 TableShardingAlgorithm（示例）：
```java
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingAlgorithm;
import org.apache.shardingsphere.api.sharding.standard.PreciseShardingValue;
import java.text.SimpleDateFormat;
import java.util.Collection;
import java.util.Date;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class TableShardingAlgorithm implements PreciseShardingAlgorithm<Long> {
    private static final Logger log = LoggerFactory.getLogger(TableShardingAlgorithm.class);

    @Override
    public String doSharding(Collection<String> availableTargetNames,
                             PreciseShardingValue<Long> shardingValue) {
        log.info("table PreciseShardingAlgorithm");
        availableTargetNames.forEach(item -> log.info("actual node table:{}", item));
        log.info("logic table name:{}, route column:{}", shardingValue.getLogicTableName(), shardingValue.getColumnName());
        log.info("column value:{}", shardingValue.getValue());

        String tbName = shardingValue.getLogicTableName();
        Date date = SnowflakeIdParser.getDateFromSnowflakeId(shardingValue.getValue());
        SimpleDateFormat yearFormat = new SimpleDateFormat("yyyy");
        SimpleDateFormat monthFormat = new SimpleDateFormat("MM");
        String year = yearFormat.format(date);
        String month = monthFormat.format(date);
        tbName = tbName + year + "_" + month;
        log.info("tb_name:{}", tbName);

        for (String each : availableTargetNames) {
            if (each.equals(tbName)) {
                return each;
            }
        }
        throw new IllegalArgumentException("No matching table found: " + tbName);
    }
}
```
- 在配置文件中把表分片列设置为 order_id（雪花 ID 列），并指定上述算法类。此时，只有 ID 也能准确定位到对应时间分片，避免全库路由。

未完待续：读写分离架构
- 在高并发场景中，读写分离（主库写，从库读）是提升性能的常见做法，写入由主库负责、读取由多个从库分担。实践中需考虑主从同步延迟、异步复制与读写一致性策略（如强一致性需求的场景需谨慎）。具体实操将在后续文章中展开。

未完待续：动态扩容架构与实现
- 设计需支持动态扩容：增加数据库实例、分片迁移、灰度切流与在线迁移策略、监控与自动化调度。如何和读写分离同时实现、如何做在线扩容与流量切分等将在后续详细介绍。

结语与职业建议
- 对于面试，回答此类题需要结构化：先给出总体策略与理由（为什么选该策略）、再讲实现细节（路由、分片算法、迁移、备份、索引、事务处理）、最后给出优化与可演进的方案（读写分离、动态扩容、监控与告警）。  
- 实操方面掌握 ShardingSphere（或中间件）、Snowflake ID 时间解析、索引表设计等实用技巧，会在面试中加分。  
- 若需更深的动态扩容、灰度切流、跨库事务处理方案与实战脚本，可在接下来专题中继续分享。

遇到技术或职业问题可系统化学习并请教有经验的架构师；面试答案要有条理、有权衡并能落地实现，既能展示架构视角，也能覆盖工程细节。