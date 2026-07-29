---
doc_id: "66b76895904726f19c1fb184b1c8fc81"
title: "MySQL 的JSON类型违反第一范式吗？MySQL 在 5.7 版本中正式引入了原生的 JSON 数据类型，网上很多人 - 掘金"
aliases:
  - "MySQL 的JSON类型违反第一范式吗？MySQL 在 5.7 版本中正式引入了原生的 JSON 数据类型，网上很多人 - 掘金"
url: "https://juejin.cn/post/7471150465453785129"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "JSON"
  - "数据库设计"
  - "第一范式"
  - "面试"
  - "技术干货"
generated: true
---

# MySQL 的JSON类型违反第一范式吗？MySQL 在 5.7 版本中正式引入了原生的 JSON 数据类型，网上很多人 - 掘金

> [!info] Provenance
> - doc_id: `66b76895904726f19c1fb184b1c8fc81`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7471150465453785129)
> - PDF: [open local PDF](../../collector/66b76895904726f19c1fb184b1c8fc81.pdf)

## Summary

文章讨论 MySQL 5.7/8.0 的 JSON 能力，并从第一范式（1NF）的角度区分“存储多值集合”与“存储单一结构化对象”。结论是：JSON 是否违反 1NF 取决于数据模型与使用方式，而不是 JSON 类型本身。

## Knowledge Outline

- MySQL 5.7 的 JSON 支持 — MySQL, JSON, 数据库, 性能优化, SQL
- JSON 是否违反第一范式 — 数据库设计, 第一范式, MySQL, JSON
- 违反第一范式的情形 — MySQL, JSON, 第一范式, 数据建模, 查询性能
- 不违反第一范式的情形 — MySQL, JSON, 第一范式, 数据建模, SQL
- 总结 — MySQL, JSON, 第一范式, 数据库设计, 性能, 可维护性

## Repository Paths

- PDF: `collector/66b76895904726f19c1fb184b1c8fc81.pdf`
- Extracted: `generated/extracted/66b76895904726f19c1fb184b1c8fc81/full.md`
- Filtered: `generated/filtered/66b76895904726f19c1fb184b1c8fc81/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
