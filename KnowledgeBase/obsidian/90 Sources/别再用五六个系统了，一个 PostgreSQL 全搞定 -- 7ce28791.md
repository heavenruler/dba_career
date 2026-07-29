---
doc_id: "7ce28791c2392bae5ca0e574fca75ca5"
title: "别再用五六个系统了，一个 PostgreSQL 全搞定"
aliases:
  - "别再用五六个系统了，一个 PostgreSQL 全搞定"
url: "https://mp.weixin.qq.com/s/epP2lc36z0DpNeaSesUOMQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "架构设计"
  - "DBA"
  - "运维"
  - "平台工程"
  - "JSONB"
  - "pgvector"
  - "pgmq"
  - "PostGIS"
  - "Timescale"
  - "全文搜索"
  - "一致性"
  - "性能调优"
generated: true
---

# 别再用五六个系统了，一个 PostgreSQL 全搞定

> [!info] Provenance
> - doc_id: `7ce28791c2392bae5ca0e574fca75ca5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/epP2lc36z0DpNeaSesUOMQ)
> - PDF: [open local PDF](../../collector/7ce28791c2392bae5ca0e574fca75ca5.pdf)

## Summary

这篇文章主张用 PostgreSQL 的扩展生态整合关系型、JSONB、向量检索、队列、全文搜索等能力，减少多系统拼接带来的同步、监控、备份和一致性复杂度。文章也给出推荐系统的简化案例，并强调 PostgreSQL 不是银弹，仍需按场景保留专门化系统。

## Knowledge Outline

- 传统架构困境 — PostgreSQL, 运维, 架构设计, 一致性, 微服务
- 扩展生态 — PostgreSQL, Extension, pgvector, pgmq, PITR, 运维
- 混合存储 — PostgreSQL, JSONB, GIN, ACID, 文档存储, 关系型数据库
- 队列与事件 — PostgreSQL, NOTIFY, LISTEN, logical replication, 事件驱动, 运维
- 推荐系统案例 — PostgreSQL, pgvector, pg_trgm, 全文搜索, JSONB, 推荐系统, 运维
- 研发收益 — 研发效率, 一致性, SQL, 技术债务, 架构简化
- 边界与最佳实践 — PostgreSQL, 选型, 最佳实践, ClickHouse, Spanner, CockroachDB, 监控
- 平台化思维 — PostgreSQL, 平台工程, 架构设计, 运维, 决策框架

## Repository Paths

- PDF: `collector/7ce28791c2392bae5ca0e574fca75ca5.pdf`
- Extracted: `generated/extracted/7ce28791c2392bae5ca0e574fca75ca5/full.md`
- Filtered: `generated/filtered/7ce28791c2392bae5ca0e574fca75ca5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
