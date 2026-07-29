---
doc_id: "e17662648434859bd6be76ed3b95a212"
title: "MySQL 用 limit 为什么会影响性能？有什么优化方案？"
aliases:
  - "MySQL 用 limit 为什么会影响性能？有什么优化方案？"
url: "https://mp.weixin.qq.com/s/SHloLVl2PaYWTHoeTxw1Pw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL"
  - "索引"
  - "分页查询"
  - "性能优化"
  - "数据库"
generated: true
---

# MySQL 用 limit 为什么会影响性能？有什么优化方案？

> [!info] Provenance
> - doc_id: `e17662648434859bd6be76ed3b95a212`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/SHloLVl2PaYWTHoeTxw1Pw)
> - PDF: [open local PDF](../../collector/e17662648434859bd6be76ed3b95a212.pdf)

## Summary

本文说明 LIMIT offset 较大时 MySQL 为什么会变慢：查询需要扫描大量索引记录和数据页，并丢弃前面的无用记录；同时整理了 B+ 树索引、聚簇/非聚簇索引、回表查询，以及覆盖索引、子查询、分区表等优化思路。

## Knowledge Outline

- 问题引入 — MySQL, SQL, 分页查询, 性能
- 索引结构 — MySQL, 索引, B+树, 数据库
- 聚簇与非聚簇 — MySQL, 聚簇索引, 非聚簇索引, 索引
- 查询过程 — MySQL, 查询优化, 回表查询, 执行计划
- Limit 影响 — MySQL, LIMIT, 性能问题, I/O, 分页查询
- 覆盖索引优化 — MySQL, 覆盖索引, 性能优化, SQL
- 子查询优化 — MySQL, 子查询, 性能优化, SQL
- 分区表优化 — MySQL, 分区表, 性能优化, 数据库

## Repository Paths

- PDF: `collector/e17662648434859bd6be76ed3b95a212.pdf`
- Extracted: `generated/extracted/e17662648434859bd6be76ed3b95a212/full.md`
- Filtered: `generated/filtered/e17662648434859bd6be76ed3b95a212/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
