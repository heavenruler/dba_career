---
doc_id: "b15cea0e52bc2b147a982bd0d42b77f5"
title: "为何要小表驱动大表？为什么要小表驱动大表？ MySQL在执行Join操作时，优先使用较小的表作为驱动表（也称为外层表）去 - 掘金"
aliases:
  - "为何要小表驱动大表？为什么要小表驱动大表？ MySQL在执行Join操作时，优先使用较小的表作为驱动表（也称为外层表）去 - 掘金"
url: "https://juejin.cn/post/7460125459046481920"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Join"
  - "索引"
  - "SQL优化"
  - "数据库性能"
generated: true
---

# 为何要小表驱动大表？为什么要小表驱动大表？ MySQL在执行Join操作时，优先使用较小的表作为驱动表（也称为外层表）去 - 掘金

> [!info] Provenance
> - doc_id: `b15cea0e52bc2b147a982bd0d42b77f5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7460125459046481920)
> - PDF: [open local PDF](../../collector/b15cea0e52bc2b147a982bd0d42b77f5.pdf)

## Summary

这篇文章解释了 MySQL Join 中“小表驱动大表”的原因，核心在于减少扫描行数和匹配次数；当被驱动表上有索引时，性能差异会更明显。文中用 employees 和 departments 的伪代码对比了大表驱动小表与小表驱动大表的执行成本。

## Knowledge Outline

- 小表驱动大表原理 — MySQL, Join, 索引, 执行计划, 性能优化

## Repository Paths

- PDF: `collector/b15cea0e52bc2b147a982bd0d42b77f5.pdf`
- Extracted: `generated/extracted/b15cea0e52bc2b147a982bd0d42b77f5/full.md`
- Filtered: `generated/filtered/b15cea0e52bc2b147a982bd0d42b77f5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
