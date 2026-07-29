---
doc_id: "29407d2fed04e0cb2684a676ffea3fa5"
title: "软件架构，一切尽在权衡本文要介绍的是 2021 年 O'Reilly 出版的书籍 Software Architectu - 掘金"
aliases:
  - "软件架构，一切尽在权衡本文要介绍的是 2021 年 O'Reilly 出版的书籍 Software Architectu - 掘金"
url: "https://juejin.cn/post/7380579033547685925"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "软件架构"
  - "分布式架构"
  - "微服务"
  - "服务拆分"
  - "数据拆分"
  - "架构权衡"
  - "分布式事务"
  - "Saga"
  - "工作流编排"
  - "可扩展性"
  - "可用性"
generated: true
---

# 软件架构，一切尽在权衡本文要介绍的是 2021 年 O'Reilly 出版的书籍 Software Architectu - 掘金

> [!info] Provenance
> - doc_id: `29407d2fed04e0cb2684a676ffea3fa5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7380579033547685925)
> - PDF: [open local PDF](../../collector/29407d2fed04e0cb2684a676ffea3fa5.pdf)

## Summary

本文是《Software Architecture: The Hard Parts》的读书摘要，核心主题是软件架构中的权衡：架构量子、服务拆分、数据拆分、拆分粒度、服务间代码复用、分布式事务、工作流编排与 Saga 模式。

## Knowledge Outline

- 荐语 — 软件架构, 架构权衡, 分布式架构
- 为什么叫 The Hard Part — 架构权衡, 软件架构
- Fitness Function — 架构治理, CI/CD, Fitness Function, 测试
- 架构量子 — 架构量子, 独立部署, 微服务
- 软件中的耦合 — 耦合, 服务拆分, 静态耦合, 动态耦合
- 服务拆分驱动因素 — 服务拆分, 可维护性, 可测试性, 可部署性, 可扩展性, 可用性
- 可维护性 — 可维护性, 单体架构, 分布式架构
- 可测试性 — 可测试性, 自动化测试, 服务拆分
- 可部署性 — 可部署性, 部署风险, 动态耦合
- 可扩展性与可用性 — 可扩展性, 可伸缩性, 可用性
- 服务拆分方法论 — 服务拆分, Component-Based Decomposition, Tactical Forking
- 基于组件的拆分 — 组件, 服务拆分, 命名空间
- 明确组件及大小 — 组件识别, 复杂度, statement
- 公共领域组件 — 公共领域, 组件聚合, 公共服务
- 组件扁平化 — 组件扁平化, 服务拆分
- 组件依赖关系 — 组件依赖, 拆分代价, 重构
- 领域组件与领域服务 — 领域组件, 服务化架构, 微服务
- Tactical Forking — Tactical Forking, 服务拆分, 代码删除
- 数据拆分驱动因素 — 数据拆分, 数据库, 架构量子
- 数据拆分变更影响 — 数据拆分, 限界上下文, 数据库变更
- 数据库连接与扩展 — 数据库连接池, 分库, 可扩展性
- 容错性与架构量子 — 容错性, 架构量子, 强一致性, 最终一致性
- 数据库类型选择 — 数据库选型, OLTP, OLAP, 数据建模
- 不建议数据拆分 — 数据拆分, 外键, 数据库事务, ACID
- 数据拆分步骤 — 数据拆分, schema, 数据库迁移
- 数据表归类方法 — 数据表归属, 服务接口, 合并服务
- 分布式数据访问 — 分布式数据, 服务调用, 数据副本, 分布式缓存
- 服务间接口调用 — 服务调用, 接口契约, 性能, 可用性
- 数据副本 — 数据副本, 数据一致性, 数据同步
- 分布式缓存 — 分布式缓存, Redis, Memcached, Hazelcast, Apache Ignit
- 去中心化缓存缺点 — 去中心化缓存, 内存, TCP, 数据同步
- 拆分粒度权衡 — 拆分粒度, 单一职责原则, 架构权衡
- 驱动细粒度服务 — 细粒度服务, 服务职责, 代码改动频率, 吞吐量, 容错性
- 安全与可延展性 — 安全, 可延展性, 可扩展性, 服务拆分
- 驱动粗粒度服务 — 粗粒度服务, ACID, 数据依赖, 工作流
- 共享代码影响粒度 — 共享代码, 领域层, 版本控制, 服务拆分
- 服务间代码复用 — 代码复用, 分布式系统
- 代码复制 — 代码复制, 零共享架构, 代码复用
- 共享库 — 共享库, jar, so, 版本管理
- 共享库优缺点 — 共享库, 依赖管理, 版本管理
- 共享服务 — 共享服务, 代码复用, 运行时依赖, 异构系统
- 共享服务优缺点 — 共享服务, 性能, 可用性, 单点瓶颈
- ACID 事务 — ACID, 数据库事务, 单体架构
- 分布式事务不遵循 ACID — 分布式事务, 微服务, ACID
- BASE 性质 — BASE, 最终一致性, 异步通信
- 最终一致性方法 — 最终一致性, 后台同步, 同步通信, 事件通知, 消息队列
- 后台同步优缺点 — 后台同步, 最终一致性, 数据同步
- 同步通信优缺点 — 同步通信, 最终一致性, 异常处理
- 事件通知优缺点 — 事件通知, 最终一致性, 异步通信
- 工作流编排 — 工作流, Orchestration, Choreography
- Orchestration — Orchestration, 工作流编排, 单点瓶颈
- Choreography — Choreography, 工作流编排, 状态管理, 错误处理
- Saga 分布式事务 — Saga, 分布式事务, 补偿事务
- Saga 模式分类 — Saga, 分布式事务, Orchestration, Choreography
- Saga 权衡 — Saga, 架构权衡, Horror Story Saga
- 最后 — SAHP, 服务通信协议, 数据分析, 架构权衡

## Repository Paths

- PDF: `collector/29407d2fed04e0cb2684a676ffea3fa5.pdf`
- Extracted: `generated/extracted/29407d2fed04e0cb2684a676ffea3fa5/full.md`
- Filtered: `generated/filtered/29407d2fed04e0cb2684a676ffea3fa5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
