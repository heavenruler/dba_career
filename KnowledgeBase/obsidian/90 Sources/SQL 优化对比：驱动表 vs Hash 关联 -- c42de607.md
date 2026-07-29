---
doc_id: "c42de607b00a6d208b94059f4d218b1a"
title: "SQL 优化对比：驱动表 vs Hash 关联"
aliases:
  - "SQL 优化对比：驱动表 vs Hash 关联"
url: "https://mp.weixin.qq.com/s/XDb0c6sObPJKqQxfGvxzHQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SQL优化"
  - "OceanBase"
  - "驱动表"
  - "Hash Join"
  - "执行计划"
  - "性能调优"
  - "数据库"
generated: true
---

# SQL 优化对比：驱动表 vs Hash 关联

> [!info] Provenance
> - doc_id: `c42de607b00a6d208b94059f4d218b1a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/XDb0c6sObPJKqQxfGvxzHQ)
> - PDF: [open local PDF](../../collector/c42de607b00a6d208b94059f4d218b1a.pdf)

## Summary

这篇文章用一个 OceanBase SQL 优化案例对比了指定驱动表和改用 Hash 关联的效果。核心结论是：驱动表是否合适不能只看表大小，还要看是否有有效过滤条件、索引和连接顺序；大表在强过滤条件下也可能适合作为驱动表，而 Hash Join 更适合大表且过滤后数据量很小的场景。

## Knowledge Outline

- 问题背景与执行计划 — SQL优化, OceanBase, 执行计划, 驱动表, 索引, 性能调优
- 优化方案对比 — SQL优化, 驱动表, Hash Join, 执行计划, hint, 性能调优
- 总结与适用场景 — SQL优化, OceanBase, Hash Join, 驱动表, 执行计划, 数据库

## Repository Paths

- PDF: `collector/c42de607b00a6d208b94059f4d218b1a.pdf`
- Extracted: `generated/extracted/c42de607b00a6d208b94059f4d218b1a/full.md`
- Filtered: `generated/filtered/c42de607b00a6d208b94059f4d218b1a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
