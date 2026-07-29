---
doc_id: "1bb42ceacac9fdb371ef81785f2c8b29"
title: "阿里面试：每天新增100w订单，如何的分库分表？这份答案让我当场拿了offer"
aliases:
  - "阿里面试：每天新增100w订单，如何的分库分表？这份答案让我当场拿了offer"
url: "https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "数据库"
  - "分库分表"
  - "ShardingSphere"
  - "系统设计"
  - "Java"
  - "面试"
  - "雪花ID"
  - "高并发"
generated: true
---

# 阿里面试：每天新增100w订单，如何的分库分表？这份答案让我当场拿了offer

> [!info] Provenance
> - doc_id: `1bb42ceacac9fdb371ef81785f2c8b29`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/XkbtHrZVRtx-f7REzi-eBg)
> - PDF: [open local PDF](../../collector/1bb42ceacac9fdb371ef81785f2c8b29.pdf)

## Summary

本文围绕每天新增 100w 订单、20 亿级订单数据的分库分表面试题，讨论业务增长预测、单库单表瓶颈、一致性 hash、按时间范围、ID 取模加时间范围组合策略、ShardingSphere 使用模式与分片策略，并给出雪花 ID 时间基因避免全库路由的实现思路。

## Knowledge Outline

- 面试考察意图 — 系统设计, 分库分表, 面试
- 订单场景与增长预测 — 订单系统, 容量规划, 系统设计
- 单库单表挑战 — 数据库, 性能瓶颈, 高并发
- 一致性 Hash 取模方案 — 一致性Hash, 分库分表, 数据库
- 一致性 Hash 优劣 — 一致性Hash, 扩展性, 范围查询
- 按时间范围分库分表 — 时间分片, 分库分表, 路由策略
- 时间范围方案优劣 — 时间分片, 热点问题, 数据归档
- 组合模式设计 — 组合分片, ID取模, 时间分表
- ShardingSphere 使用模式 — ShardingSphere, Sharding-JDBC, 数据库代理, Kubernetes
- Sharding-JDBC 分片策略 — Sharding-JDBC, 分片策略, SQL
- 分库算法示例 — Java, Sharding-JDBC, 分库算法
- 索引表避免全库路由 — 异构索引, SQL, 查询优化, 全库路由
- 时间基因法 — 时间基因, 分片键, 查询优化
- 雪花 ID 时间戳结构 — 雪花ID, 分布式ID, 时间戳, 全库路由
- 雪花 ID 解析实现 — Java, 雪花ID, 分片算法

## Repository Paths

- PDF: `collector/1bb42ceacac9fdb371ef81785f2c8b29.pdf`
- Extracted: `generated/extracted/1bb42ceacac9fdb371ef81785f2c8b29/full.md`
- Filtered: `generated/filtered/1bb42ceacac9fdb371ef81785f2c8b29/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
