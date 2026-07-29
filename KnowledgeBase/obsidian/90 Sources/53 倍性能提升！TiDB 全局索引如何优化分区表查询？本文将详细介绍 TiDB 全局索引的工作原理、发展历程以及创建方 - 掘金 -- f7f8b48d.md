---
doc_id: "f7f8b48dba959823223bde33edbe760d"
title: "53 倍性能提升！TiDB 全局索引如何优化分区表查询？本文将详细介绍 TiDB 全局索引的工作原理、发展历程以及创建方 - 掘金"
aliases:
  - "53 倍性能提升！TiDB 全局索引如何优化分区表查询？本文将详细介绍 TiDB 全局索引的工作原理、发展历程以及创建方 - 掘金"
url: "https://juejin.cn/post/7472222630070943754"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库"
  - "全局索引"
  - "分区表"
  - "查询性能"
  - "DDL"
  - "性能优化"
generated: true
---

# 53 倍性能提升！TiDB 全局索引如何优化分区表查询？本文将详细介绍 TiDB 全局索引的工作原理、发展历程以及创建方 - 掘金

> [!info] Provenance
> - doc_id: `f7f8b48dba959823223bde33edbe760d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7472222630070943754)
> - PDF: [open local PDF](../../collector/f7f8b48dba959823223bde33edbe760d.pdf)

## Summary

本文介绍 TiDB 全局索引在分区表中的工作原理、版本发展、创建语法、优势、限制、性能测试与最佳实践，重点说明其通过打破索引与分区一对一映射来优化跨分区查询，但会影响部分 DDL 性能。

## Knowledge Outline

- 导读 — TiDB, 全局索引, 分区表, 查询性能
- 全局索引定义 — TiDB, 全局索引, 本地索引, 唯一键
- 发展历程 — TiDB, 版本, 全局索引, GA
- 创建语法 — TiDB, SQL, CREATE INDEX, ALTER TABLE, GLOBAL
- 优势 — 查询性能, 分区表, 迁移, Oracle, 成本
- 基本思想 — TiDB, TiKV, RPC, range, 索引编码
- 编码方式 — TiDB, 索引编码, PartitionID, TableID, DDL
- 限制与注意事项 — DDL, DROP PARTITION, TRUNCATE PARTITION, 聚簇索引, 性能
- 性能测试 — sysbench, 性能测试, SQL, RU, 高并发
- 本地索引选择 — 最佳实践, 全局索引, 本地索引, 数据归档, 分区交换
- 聚簇索引搭配 — 聚簇索引, 全局索引, PointGet, 范围查询, 分区列
- 总结 — TiDB, 索引设计, 查询性能, 维护成本

## Repository Paths

- PDF: `collector/f7f8b48dba959823223bde33edbe760d.pdf`
- Extracted: `generated/extracted/f7f8b48dba959823223bde33edbe760d/full.md`
- Filtered: `generated/filtered/f7f8b48dba959823223bde33edbe760d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
