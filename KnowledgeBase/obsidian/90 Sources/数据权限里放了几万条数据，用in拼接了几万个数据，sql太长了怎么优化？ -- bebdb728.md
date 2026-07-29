---
doc_id: "bebdb728929d79ee0a1afbb081a789c9"
title: "数据权限里放了几万条数据，用in拼接了几万个数据，sql太长了怎么优化？"
aliases:
  - "数据权限里放了几万条数据，用in拼接了几万个数据，sql太长了怎么优化？"
url: "https://mp.weixin.qq.com/s/_o5Atv383upx4adDBnd-bg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SQL"
  - "MySQL"
  - "数据权限"
  - "性能优化"
  - "数据库设计"
generated: true
---

# 数据权限里放了几万条数据，用in拼接了几万个数据，sql太长了怎么优化？

> [!info] Provenance
> - doc_id: `bebdb728929d79ee0a1afbb081a789c9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/_o5Atv383upx4adDBnd-bg)
> - PDF: [open local PDF](../../collector/bebdb728929d79ee0a1afbb081a789c9.pdf)

## Summary

讨论数据权限场景下用大量 `IN` 拼接导致 SQL 过长、日志和调试不友好、解析与优化成本上升，并建议用中间表保存权限数据。

## Knowledge Outline

- 权限场景 — SQL, 数据权限, MySQL
- 问题分析 — MySQL, 性能优化, SQL, 索引, 全表扫描
- 解决方案 — 数据库设计, SQL, MySQL, 性能优化, 数据权限

## Repository Paths

- PDF: `collector/bebdb728929d79ee0a1afbb081a789c9.pdf`
- Extracted: `generated/extracted/bebdb728929d79ee0a1afbb081a789c9/full.md`
- Filtered: `generated/filtered/bebdb728929d79ee0a1afbb081a789c9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
