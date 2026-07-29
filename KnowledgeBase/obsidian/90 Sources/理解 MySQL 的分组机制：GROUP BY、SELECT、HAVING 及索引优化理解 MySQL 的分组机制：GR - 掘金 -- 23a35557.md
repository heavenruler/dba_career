---
doc_id: "23a35557d03da0e51c3396bd694b4bf5"
title: "理解 MySQL 的分组机制：GROUP BY、SELECT、HAVING 及索引优化理解 MySQL 的分组机制：GR - 掘金"
aliases:
  - "理解 MySQL 的分组机制：GROUP BY、SELECT、HAVING 及索引优化理解 MySQL 的分组机制：GR - 掘金"
url: "https://juejin.cn/post/7487071171194896395"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL"
  - "GROUP BY"
  - "HAVING"
  - "索引优化"
  - "查询优化"
  - "后端"
generated: true
---

# 理解 MySQL 的分组机制：GROUP BY、SELECT、HAVING 及索引优化理解 MySQL 的分组机制：GR - 掘金

> [!info] Provenance
> - doc_id: `23a35557d03da0e51c3396bd694b4bf5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7487071171194896395)
> - PDF: [open local PDF](../../collector/23a35557d03da0e51c3396bd694b4bf5.pdf)

## Summary

本文说明 MySQL 的 GROUP BY 如何分组、SELECT 中非聚合列的约束、HAVING 的分组后过滤语义，以及聚合条件对索引利用的限制和几种优化手段，包括前移 WHERE、复合索引、物化中间结果、避免不必要聚合和分区/分片。

## Knowledge Outline

- GROUP BY 基本机制 — MySQL, GROUP BY, 聚合
- SELECT 非聚合列限制 — MySQL, SELECT, GROUP BY
- HAVING 常见用法 — MySQL, HAVING, 聚合
- HAVING 与索引 — MySQL, 索引, HAVING, 执行顺序
- 索引优化策略 — MySQL, 索引优化, WHERE, 覆盖索引

## Repository Paths

- PDF: `collector/23a35557d03da0e51c3396bd694b4bf5.pdf`
- Extracted: `generated/extracted/23a35557d03da0e51c3396bd694b4bf5/full.md`
- Filtered: `generated/filtered/23a35557d03da0e51c3396bd694b4bf5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
