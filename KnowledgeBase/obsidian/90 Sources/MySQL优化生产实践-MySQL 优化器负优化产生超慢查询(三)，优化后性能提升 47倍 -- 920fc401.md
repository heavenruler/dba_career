---
doc_id: "920fc401e964bd564fd1ba19586c13d8"
title: "MySQL优化生产实践-MySQL 优化器负优化产生超慢查询(三)，优化后性能提升 47倍"
aliases:
  - "MySQL优化生产实践-MySQL 优化器负优化产生超慢查询(三)，优化后性能提升 47倍"
url: "https://www.modb.pro/db/1971488670347702272"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "性能调优"
  - "慢查询"
  - "优化器"
  - "ICP"
  - "索引"
  - "回表"
generated: true
---

# MySQL优化生产实践-MySQL 优化器负优化产生超慢查询(三)，优化后性能提升 47倍

> [!info] Provenance
> - doc_id: `920fc401e964bd564fd1ba19586c13d8`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1971488670347702272)
> - PDF: [open local PDF](../../collector/920fc401e964bd564fd1ba19586c13d8.pdf)

## Summary

这篇文章记录了一个 MySQL 慢查询案例：当 `in` 条件只有一个值时查询反而很慢，而有两个值时更快。作者通过执行计划、实际耗时和索引区分度分析，定位到倒序排序场景下 ICP 没有生效，导致大量回表。最后给出更换索引和调整 `in` 写法的处理方案。

## Knowledge Outline

- 问题复现 — MySQL, 慢查询, 性能对比, 索引
- 排查过程 — MySQL, 执行计划, ICP, 性能分析
- 原因分析 — MySQL, ICP, 回表, 索引优化
- 解决方案 — MySQL, 索引设计, 查询改写, 优化方案

## Repository Paths

- PDF: `collector/920fc401e964bd564fd1ba19586c13d8.pdf`
- Extracted: `generated/extracted/920fc401e964bd564fd1ba19586c13d8/full.md`
- Filtered: `generated/filtered/920fc401e964bd564fd1ba19586c13d8/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
