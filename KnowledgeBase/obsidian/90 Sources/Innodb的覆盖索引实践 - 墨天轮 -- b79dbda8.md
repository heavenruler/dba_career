---
doc_id: "b79dbda815b5964f80e03209fc7b8e33"
title: "Innodb的覆盖索引实践 - 墨天轮"
aliases:
  - "Innodb的覆盖索引实践 - 墨天轮"
url: "https://www.modb.pro/db/1759522060955111424"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "覆盖索引"
  - "索引设计"
  - "效能調優"
  - "資料庫"
generated: true
---

# Innodb的覆盖索引实践 - 墨天轮

> [!info] Provenance
> - doc_id: `b79dbda815b5964f80e03209fc7b8e33`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1759522060955111424)
> - PDF: [open local PDF](../../collector/b79dbda815b5964f80e03209fc7b8e33.pdf)

## Summary

本文用 MySQL 5.7.34 的实验，比较主键查询、普通二级索引、正确的覆盖索引与错误顺序的覆盖索引，说明组合索引顺序对是否触发 filesort 和 temporary、以及查询性能的影响。

## Knowledge Outline

- 前言 — MySQL, InnoDB, 索引, 覆盖索引
- 实验环境 — MySQL, 实验环境, 索引, SQL
- 主键查询 — MySQL, 主键, EXPLAIN, 性能
- 非主键索引 — MySQL, 二级索引, 索引
- 正确的覆盖索引 — MySQL, 覆盖索引, 组合索引
- 错误的覆盖索引 — MySQL, filesort, temporary, 覆盖索引, 性能
- 性能记录 — MySQL, 性能测试, 覆盖索引
- 总结 — MySQL, InnoDB, 覆盖索引, 索引设计, 性能调优

## Repository Paths

- PDF: `collector/b79dbda815b5964f80e03209fc7b8e33.pdf`
- Extracted: `generated/extracted/b79dbda815b5964f80e03209fc7b8e33/full.md`
- Filtered: `generated/filtered/b79dbda815b5964f80e03209fc7b8e33/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
