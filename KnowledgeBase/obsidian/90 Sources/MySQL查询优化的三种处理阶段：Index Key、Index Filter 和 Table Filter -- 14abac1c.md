---
doc_id: "14abac1ce6e1ea52c5e109f2b0e10a9a"
title: "MySQL查询优化的三种处理阶段：Index Key、Index Filter 和 Table Filter"
aliases:
  - "MySQL查询优化的三种处理阶段：Index Key、Index Filter 和 Table Filter"
url: "https://mp.weixin.qq.com/s/f-XSLDTfEZaDLIONOH2BaQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "索引下推"
  - "ICP"
  - "查询优化"
  - "数据库"
  - "性能调优"
generated: true
---

# MySQL查询优化的三种处理阶段：Index Key、Index Filter 和 Table Filter

> [!info] Provenance
> - doc_id: `14abac1ce6e1ea52c5e109f2b0e10a9a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/f-XSLDTfEZaDLIONOH2BaQ)
> - PDF: [open local PDF](../../collector/14abac1ce6e1ea52c5e109f2b0e10a9a.pdf)

## Summary

这篇文章解释了 MySQL 查询优化中的三种处理阶段：Index Key、Index Filter 和 Table Filter，并说明了索引下推（ICP）如何把部分过滤下放到存储引擎层，以减少回表次数和 Server 层压力。

## Knowledge Outline

- 处理阶段概览 — MySQL, 查询优化, ICP, 数据库
- Index Key — MySQL, Index Key, 索引, 查询优化
- Index Filter — MySQL, Index Filter, 索引下推, ICP, 性能优化
- Table Filter — MySQL, Table Filter, 回表, 查询优化, 性能
- 三类过滤物理过程 — MySQL, 索引, ICP, 查询执行
- 索引下推要点 — MySQL 5.6, ICP, 索引下推, 性能优化
- 示例 — MySQL, 示例, Index Key, Index Filter, Table Filter, SQL
- 小结 — MySQL, ICP, 覆盖索引, 性能优化

## Repository Paths

- PDF: `collector/14abac1ce6e1ea52c5e109f2b0e10a9a.pdf`
- Extracted: `generated/extracted/14abac1ce6e1ea52c5e109f2b0e10a9a/full.md`
- Filtered: `generated/filtered/14abac1ce6e1ea52c5e109f2b0e10a9a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
