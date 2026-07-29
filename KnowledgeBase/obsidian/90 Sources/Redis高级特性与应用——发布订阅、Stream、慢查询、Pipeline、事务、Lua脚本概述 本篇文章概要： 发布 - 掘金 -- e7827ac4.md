---
doc_id: "e7827ac48447228327d033fd51d65087"
title: "Redis高级特性与应用——发布订阅、Stream、慢查询、Pipeline、事务、Lua脚本概述 本篇文章概要： 发布 - 掘金"
aliases:
  - "Redis高级特性与应用——发布订阅、Stream、慢查询、Pipeline、事务、Lua脚本概述 本篇文章概要： 发布 - 掘金"
url: "https://juejin.cn/post/7412486021172248587"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "消息队列"
  - "发布订阅"
  - "Stream"
  - "慢查询"
  - "Pipeline"
  - "事务"
  - "Lua脚本"
  - "后端"
  - "Java"
generated: true
---

# Redis高级特性与应用——发布订阅、Stream、慢查询、Pipeline、事务、Lua脚本概述 本篇文章概要： 发布 - 掘金

> [!info] Provenance
> - doc_id: `e7827ac48447228327d033fd51d65087`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7412486021172248587)
> - PDF: [open local PDF](../../collector/e7827ac48447228327d033fd51d65087.pdf)

## Summary

本文介绍 Redis 发布订阅、Stream、基于 Redis 实现消息队列、慢查询、Pipeline、事务与 Lua 脚本等高级特性，包含核心概念、命令示例、适用场景、限制与配置建议。

## Knowledge Outline

- 发布订阅机制 — Redis, 发布订阅, 消息机制
- 发布订阅命令 — Redis, 发布订阅, 命令
- 发布订阅场景与缺点 — Redis, 发布订阅, 消息可靠性, 消息队列
- Stream 数据结构 — Redis, Stream, 消费组, 消息队列, PEL
- Stream 生产者命令 — Redis, Stream, xadd, 消息ID
- Stream 消费者命令 — Redis, Stream, xread, 消费者
- 消费组 — Redis, Stream, 消费组, xgroup, xreadgroup, xack
- Redis 消息队列方案对比 — Redis, 消息队列, pub/sub, 架构设计
- List 消息队列限制 — Redis, List, 消息队列, ACK
- ZSet 延迟队列 — Redis, ZSet, 延迟队列
- Stream 消息队列问题 — Redis, Stream, PEL, ACK, 消息丢失
- 死信与高可用 — Redis, Stream, 死信, 高可用, 分区
- 慢查询原理 — Redis, 慢查询, 性能调优, 可观测性
- 慢查询配置 — Redis, 慢查询, 配置
- 慢查询操作与建议 — Redis, 慢查询, 性能调优, 运维
- Pipeline 原理 — Redis, Pipeline, RTT, 性能优化
- Pipeline 限制 — Redis, Pipeline, 网络, 性能优化
- Redis 弱事务 — Redis, 事务, MULTI, EXEC, WATCH
- Pipeline 与事务区别 — Redis, Pipeline, 事务, 原子性
- Lua eval 命令 — Redis, Lua, eval, 脚本
- Lua 脚本缓存 — Redis, Lua, evalsha, script load
- Redis Lua 限流脚本 — Redis, Lua, 限流

## Repository Paths

- PDF: `collector/e7827ac48447228327d033fd51d65087.pdf`
- Extracted: `generated/extracted/e7827ac48447228327d033fd51d65087/full.md`
- Filtered: `generated/filtered/e7827ac48447228327d033fd51d65087/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
