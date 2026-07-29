---
doc_id: "217028f183386f55576c92270b1185be"
title: "从MySQL索引下推看性能优化：减少回表，提升查询效率接着上篇索引优化全攻略：提升排序、GROUP BY与分页性能今天我 - 掘金"
aliases:
  - "从MySQL索引下推看性能优化：减少回表，提升查询效率接着上篇索引优化全攻略：提升排序、GROUP BY与分页性能今天我 - 掘金"
url: "https://juejin.cn/post/7442722732335628342"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "索引下推"
  - "性能优化"
  - "数据库"
  - "SQL"
  - "InnoDB"
generated: true
---

# 从MySQL索引下推看性能优化：减少回表，提升查询效率接着上篇索引优化全攻略：提升排序、GROUP BY与分页性能今天我 - 掘金

> [!info] Provenance
> - doc_id: `217028f183386f55576c92270b1185be`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7442722732335628342)
> - PDF: [open local PDF](../../collector/217028f183386f55576c92270b1185be.pdf)

## Summary

本文讲解 MySQL 索引下推（ICP）的概念、默认开关、适用条件，以及通过联合索引和回表过滤减少 I/O 的性能收益，并给出建表、查询和 profiling 对比示例。

## Knowledge Outline

- ICP 概念 — MySQL, 索引下推, 性能优化, 数据库
- 开启与关闭 — MySQL, 索引下推, SQL, 配置
- 联合索引示例 — MySQL, 联合索引, SQL, 索引下推, InnoDB
- 性能对比 — MySQL, 性能优化, profiling, 索引下推, SQL
- 扫描与成本 — MySQL, 索引下推, 回表, 性能优化, I/O
- 使用条件 — MySQL, 索引下推, InnoDB, MyISAM, 覆盖索引

## Repository Paths

- PDF: `collector/217028f183386f55576c92270b1185be.pdf`
- Extracted: `generated/extracted/217028f183386f55576c92270b1185be/full.md`
- Filtered: `generated/filtered/217028f183386f55576c92270b1185be/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
