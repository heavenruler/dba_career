---
doc_id: "fda87a7de4f9cc233b1d5413ae62fa22"
title: "MySQL 8.0 优化器迷思：索引误选是如何发生的？"
aliases:
  - "MySQL 8.0 优化器迷思：索引误选是如何发生的？"
url: "https://www.modb.pro/db/2030655697537556480"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "优化器"
  - "索引"
  - "EXPLAIN"
  - "EXPLAIN ANALYZE"
  - "Performance Schema"
  - "效能调优"
  - "事故排查"
  - "SRE"
  - "数据库"
generated: true
---

# MySQL 8.0 优化器迷思：索引误选是如何发生的？

> [!info] Provenance
> - doc_id: `fda87a7de4f9cc233b1d5413ae62fa22`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2030655697537556480)
> - PDF: [open local PDF](../../collector/fda87a7de4f9cc233b1d5413ae62fa22.pdf)

## Summary

本文以 MySQL 8.0 的索引误选与查询优化为主线，覆盖 EXPLAIN / EXPLAIN ANALYZE / TREE 的解读、ORDER BY ... LIMIT 场景下的索引选择、Performance Schema 排查锁等待，以及 Linux 与 MySQL 参数层面的效能调优。

## Knowledge Outline

- 文章目标与结构 — MySQL, EXPLAIN, Performance Schema, 效能调优
- EXPLAIN 与 TREE — MySQL, EXPLAIN, EXPLAIN ANALYZE, 执行计划, 统计信息
- 索引与执行计划变化 — MySQL, 索引, EXPLAIN ANALYZE, Nested Loop Join, 效能调优
- ORDER BY LIMIT 误选 — MySQL, 索引误选, ORDER BY LIMIT, 优化器, Hint
- Performance Schema 等待定位 — Performance Schema, 锁等待, MySQL, 故障排查, SRE
- 系统与参数优化 — MySQL, Linux, NUMA, Buffer Pool, Doublewrite, 参数调优, 效能调优

## Repository Paths

- PDF: `collector/fda87a7de4f9cc233b1d5413ae62fa22.pdf`
- Extracted: `generated/extracted/fda87a7de4f9cc233b1d5413ae62fa22/full.md`
- Filtered: `generated/filtered/fda87a7de4f9cc233b1d5413ae62fa22/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
