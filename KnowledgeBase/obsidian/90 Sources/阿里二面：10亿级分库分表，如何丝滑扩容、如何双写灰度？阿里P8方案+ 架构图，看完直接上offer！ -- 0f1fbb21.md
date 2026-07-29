---
doc_id: "0f1fbb21bfa72846d928642ab8afa178"
title: "阿里二面：10亿级分库分表，如何丝滑扩容、如何双写灰度？阿里P8方案+ 架构图，看完直接上offer！"
aliases:
  - "阿里二面：10亿级分库分表，如何丝滑扩容、如何双写灰度？阿里P8方案+ 架构图，看完直接上offer！"
url: "https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "分库分表"
  - "数据库扩容"
  - "Sharding-JDBC"
  - "双写"
  - "灰度发布"
  - "分布式事务"
  - "数据一致性"
  - "Nacos"
  - "系统设计"
  - "面试"
generated: true
---

# 阿里二面：10亿级分库分表，如何丝滑扩容、如何双写灰度？阿里P8方案+ 架构图，看完直接上offer！

> [!info] Provenance
> - doc_id: `0f1fbb21bfa72846d928642ab8afa178`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/Cj-v4k6kORjrfySfC1_wtA)
> - PDF: [open local PDF](../../collector/0f1fbb21bfa72846d928642ab8afa178.pdf)

## Summary

本文围绕 10 亿至 100 亿级数据量下的分库分表扩容，讨论数据增长预测、迁移与一致性挑战、新旧双写、灰度切流、Nacos 动态开关、动态数据源路由、事务补偿、三级校验与监控回滚方案。

## Knowledge Outline

- 面试考察意图 — 面试, 分库分表, 系统设计
- 扩容背景 — 数据库扩容, 性能
- 数据增长预测 — 容量规划, 数据增长
- 扩容挑战 — 数据迁移, 一致性, 分布式事务, 业务连续性
- 总体方案 — 架构设计, 扩容方案
- 分片与迁移策略 — 分片策略, DataX, Kettle, Binlog, Canal, 双写
- DAO 双写架构 — DAO, 双写, 事务, 最终一致性
- 配置中心与灰度开关 — 配置中心, Nacos, Apollo, 灰度发布, 流量染色
- 双写配置示例 — Spring Boot, Sharding-JDBC, 双写
- 双写代码示例 — Java, 双写, 事务
- 刚性事务管理器 — Java, 事务管理器, Sharding-JDBC, 强一致性
- 刚柔结合事务策略 — 事务, 双写, 数据源
- 新库分片数据源 — Sharding-JDBC, 分片规则
- 双事务控制代码 — Java, Spring, 事务传播, MQ, 最终一致性
- 补偿机制 — RocketMQ, 补偿事务, 重试
- 一致性校验示例 — 数据校验, 一致性
- 性能监控指标 — Micrometer, 监控, 告警, RocketMQ
- Nacos 双写开关 — Nacos, 双写开关, 灰度
- Nacos 配置类 — Nacos, Spring Cloud, 热更新
- 双写逻辑改造 — 双写, Canal, 事务
- 路由策略切换 — HintManager, 灰度验证, 路由
- 灰度回滚策略 — 灰度发布, 回滚, Nacos
- 动态数据源灰度 — 动态数据源, AbstractRoutingDataSource, Sharding-JDBC, 灰度切流
- 旧新分片规则 — YAML, 分片规则, Sharding-JDBC
- 动态路由实现 — Java, ThreadLocal, 动态路由
- Filter 灰度判断 — Servlet Filter, 灰度规则, ThreadLocal
- 动态数据源注意事项 — 线程安全, 异常处理, Sharding-JDBC
- 三级校验与回滚 — 数据校验, MD5, 回滚, 监控告警
- 监控指标体系 — 监控, 告警阈值, SRE

## Repository Paths

- PDF: `collector/0f1fbb21bfa72846d928642ab8afa178.pdf`
- Extracted: `generated/extracted/0f1fbb21bfa72846d928642ab8afa178/full.md`
- Filtered: `generated/filtered/0f1fbb21bfa72846d928642ab8afa178/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
