---
doc_id: "02222d3b5e103580e0ba3e888fcb3677"
title: "PG vs MySQL 统计信息收集的异同 - 墨天轮"
aliases:
  - "PG vs MySQL 统计信息收集的异同 - 墨天轮"
url: "https://www.modb.pro/db/1881532545678979072"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "MySQL"
  - "DBA"
  - "统计信息"
  - "查询优化器"
  - "性能调优"
generated: true
---

# PG vs MySQL 统计信息收集的异同 - 墨天轮

> [!info] Provenance
> - doc_id: `02222d3b5e103580e0ba3e888fcb3677`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1881532545678979072)
> - PDF: [open local PDF](../../collector/02222d3b5e103580e0ba3e888fcb3677.pdf)

## Summary

这篇文章对比了 PostgreSQL 与 MySQL 的统计信息作用、系统表、自动收集触发条件、手动收集方式，以及两者在精度和性能影响上的差异。

## Knowledge Outline

- 统计信息的作用 — 统计信息, 查询优化器, 性能调优
- PG 的统计信息相关表 — PostgreSQL, 系统表, 统计信息
- pg_stats 看列的统计信息 — PostgreSQL, pg_stats, 列统计信息
- PG 自动与手动收集 — PostgreSQL, autovacuum, analyze, 统计信息
- MySQL 统计信息相关表 — MySQL, innodb_table_stats, innodb_index_stats, 统计信息
- MySQL 自动与手动收集 — MySQL, innodb_stats, analyze, 统计信息
- PG vs MySQL 对比 — PostgreSQL, MySQL, 对比, 性能, 统计信息精度

## Repository Paths

- PDF: `collector/02222d3b5e103580e0ba3e888fcb3677.pdf`
- Extracted: `generated/extracted/02222d3b5e103580e0ba3e888fcb3677/full.md`
- Filtered: `generated/filtered/02222d3b5e103580e0ba3e888fcb3677/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
