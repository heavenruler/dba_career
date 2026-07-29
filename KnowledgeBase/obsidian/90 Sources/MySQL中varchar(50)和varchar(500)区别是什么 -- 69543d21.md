---
doc_id: "69543d21b92b2836d64184f7a064390e"
title: "MySQL中varchar(50)和varchar(500)区别是什么?"
aliases:
  - "MySQL中varchar(50)和varchar(500)区别是什么?"
url: "https://mp.weixin.qq.com/s/36pk7ljy4OdSLNv1_rFZRw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "varchar"
  - "数据库"
  - "性能调优"
  - "索引"
  - "排序"
  - "sort_buffer_size"
generated: true
---

# MySQL中varchar(50)和varchar(500)区别是什么?

> [!info] Provenance
> - doc_id: `69543d21b92b2836d64184f7a064390e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/36pk7ljy4OdSLNv1_rFZRw)
> - PDF: [open local PDF](../../collector/69543d21b92b2836d64184f7a064390e.pdf)

## Summary

本文通过建表、批量插入 100 万条数据，并分别验证存储空间、索引覆盖查询、索引查询以及全表排序场景，结论是 varchar 长度本身对存储空间影响不明显，但在排序时会影响 MySQL 对内存和临时文件排序的预估，进而显著影响性能。

## Knowledge Outline

- 问题描述 — MySQL, varchar, 数据库, 性能调优
- 存储空间验证 — MySQL, varchar, 存储空间, 数据库, 索引
- 性能验证与结论 — MySQL, 性能调优, 排序, sort_buffer_size, sort_merge_passes, 临时表

## Repository Paths

- PDF: `collector/69543d21b92b2836d64184f7a064390e.pdf`
- Extracted: `generated/extracted/69543d21b92b2836d64184f7a064390e/full.md`
- Filtered: `generated/filtered/69543d21b92b2836d64184f7a064390e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
