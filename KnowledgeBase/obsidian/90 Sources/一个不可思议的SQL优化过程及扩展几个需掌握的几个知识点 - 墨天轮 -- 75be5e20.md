---
doc_id: "75be5e203e2525680ca0da0f0f670615"
title: "一个不可思议的SQL优化过程及扩展几个需掌握的几个知识点 - 墨天轮"
aliases:
  - "一个不可思议的SQL优化过程及扩展几个需掌握的几个知识点 - 墨天轮"
url: "https://www.modb.pro/db/1869200405658349568"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "执行计划"
  - "派生表"
  - "索引覆盖"
  - "数据库"
  - "性能调优"
generated: true
---

# 一个不可思议的SQL优化过程及扩展几个需掌握的几个知识点 - 墨天轮

> [!info] Provenance
> - doc_id: `75be5e203e2525680ca0da0f0f670615`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1869200405658349568)
> - PDF: [open local PDF](../../collector/75be5e203e2525680ca0da0f0f670615.pdf)

## Summary

本文围绕一个 MySQL 慢 SQL 案例，解释为什么子查询里是否包含 `LIMIT`、是否使用 `*` 会影响派生表合并、索引扫描与索引覆盖，并给出 `show warnings`、`no_merge`、`derived_merge`、`set_var` 等控制方法。

## Knowledge Outline

- 问题复现 — MySQL, SQL优化, 执行计划, 派生表
- 问题分析 — MySQL, 执行计划, 派生表, 索引覆盖
- 派生表控制 — MySQL, 派生表, 执行计划, hint, derived_merge
- 避免星号与索引覆盖 — MySQL, SQL优化, 索引扫描, 索引覆盖, 组合索引
- 优化结论 — MySQL, SQL优化, 执行计划, 索引覆盖

## Repository Paths

- PDF: `collector/75be5e203e2525680ca0da0f0f670615.pdf`
- Extracted: `generated/extracted/75be5e203e2525680ca0da0f0f670615/full.md`
- Filtered: `generated/filtered/75be5e203e2525680ca0da0f0f670615/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
