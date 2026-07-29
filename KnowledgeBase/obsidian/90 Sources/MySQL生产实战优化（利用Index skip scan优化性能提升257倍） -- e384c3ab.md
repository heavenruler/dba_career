---
doc_id: "e384c3abb1f2ec298174c21666b0cc67"
title: "MySQL生产实战优化（利用Index skip scan优化性能提升257倍）"
aliases:
  - "MySQL生产实战优化（利用Index skip scan优化性能提升257倍）"
url: "https://mp.weixin.qq.com/s/YO8JW0A3p9_Zc5zU6562WA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Index skip scan"
  - "SQL优化"
  - "性能调优"
  - "数据库"
  - "单表多租户"
generated: true
---

# MySQL生产实战优化（利用Index skip scan优化性能提升257倍）

> [!info] Provenance
> - doc_id: `e384c3abb1f2ec298174c21666b0cc67`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/YO8JW0A3p9_Zc5zU6562WA)
> - PDF: [open local PDF](../../collector/e384c3abb1f2ec298174c21666b0cc67.pdf)

## Summary

这篇文章是一个 MySQL 生产优化案例，核心是在单表多租户场景下，通过改写 SQL、加入 `no_merge()` hint，并利用 `Index skip scan` 将跨租户查询从全表扫描优化到索引访问，性能从 46327ms 降到 178ms。文末还整理了 `Index skip scan` 的适用条件与官方说明。

## Knowledge Outline

- 背景与问题 — MySQL, 单表多租户, SQL优化, 执行计划, 性能调优
- 优化过程 — MySQL, Index skip scan, no_merge, SQL改写, 性能优化
- Index skip scan 条件 — MySQL, Index skip scan, EXPLAIN, 官方说明, 数据库

## Repository Paths

- PDF: `collector/e384c3abb1f2ec298174c21666b0cc67.pdf`
- Extracted: `generated/extracted/e384c3abb1f2ec298174c21666b0cc67/full.md`
- Filtered: `generated/filtered/e384c3abb1f2ec298174c21666b0cc67/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
