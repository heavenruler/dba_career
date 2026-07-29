---
doc_id: "14864ba5b579b1db6ae864769d76b093"
title: "Day 28｜大厂怎么用 PostgreSQL？"
aliases:
  - "Day 28｜大厂怎么用 PostgreSQL？"
url: "https://mp.weixin.qq.com/s/IbXREmGAh9S3_HHWVNGXog"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "数据库架构"
  - "Sharding"
  - "Citus"
  - "PgBouncer"
  - "混合架构"
  - "性能调优"
  - "SRE"
generated: true
---

# Day 28｜大厂怎么用 PostgreSQL？

> [!info] Provenance
> - doc_id: `14864ba5b579b1db6ae864769d76b093`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/IbXREmGAh9S3_HHWVNGXog)
> - PDF: [open local PDF](../../collector/14864ba5b579b1db6ae864769d76b093.pdf)

## Summary

这篇文章用 Instagram、Shopify、Discord 三个案例说明大厂如何在 PostgreSQL 上做分片、ID 生成、索引优化、连接池、读写分离，以及在关系型数据和海量写入之间采用混合架构。

## Knowledge Outline

- Instagram 案例 — PostgreSQL, Instagram, Sharding, ID生成, 数据库架构
- Instagram ID 生成 — PostgreSQL, ID生成, 索引优化, 性能调优, Instagram
- Shopify 案例 — PostgreSQL, Shopify, Citus, 分片, 分布式数据库, 横向扩展
- Discord 案例 — Discord, PostgreSQL, Cassandra, 混合架构, 关系型数据, ACID, 权限系统
- 共同规律 — PostgreSQL, PgBouncer, 读写分离, 缓存, 性能调优, 架构设计, SRE

## Repository Paths

- PDF: `collector/14864ba5b579b1db6ae864769d76b093.pdf`
- Extracted: `generated/extracted/14864ba5b579b1db6ae864769d76b093/full.md`
- Filtered: `generated/filtered/14864ba5b579b1db6ae864769d76b093/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
