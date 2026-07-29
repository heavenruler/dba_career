---
doc_id: "e9fe1e133eb7b4c2ffeea38b635d1c99"
title: "为什么调换几个表的连接顺序，SQL性能就能天差地别？"
aliases:
  - "为什么调换几个表的连接顺序，SQL性能就能天差地别？"
url: "https://www.modb.pro/db/1952633848433487872"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "执行计划"
  - "explain analyze"
  - "join order"
  - "hint"
  - "性能调优"
  - "DBA"
generated: true
---

# 为什么调换几个表的连接顺序，SQL性能就能天差地别？

> [!info] Provenance
> - doc_id: `e9fe1e133eb7b4c2ffeea38b635d1c99`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1952633848433487872)
> - PDF: [open local PDF](../../collector/e9fe1e133eb7b4c2ffeea38b635d1c99.pdf)

## Summary

本文分析 MySQL 多表 join 查询因连接顺序导致性能差异的案例，使用 explain analyze 定位嵌套循环与回表瓶颈，并通过调整 flight、booking、passenger 的连接顺序，以及 join_order、JOIN_PREFIX、JOIN_FIXED_ORDER、straight_join 等方式优化执行时间。

## Knowledge Outline

- 待优化 SQL 与耗时 — SQL优化, MySQL, 查询耗时
- 执行计划问题判断 — 执行计划, filtered, 回表, nested loop
- 表结构与条件作用位置 — 表结构, where条件, 连接顺序
- explain analyze 用法 — MySQL8, explain analyze, 执行计划
- 实际执行计划分析 — explain analyze, 嵌套循环, cost, rows, 回表
- 检查条件选择性 — 选择性, flight, 连接顺序
- 优化连接顺序验证 — flight, booking, covering index, 性能验证
- join_order Hint 改写 — hint, join_order, MySQL8.4.5
- 其他 Hint 与 straight_join — JOIN_PREFIX, JOIN_FIXED_ORDER, straight_join, hint
- Hint 语法错误排查 — hint, show warnings, 语法错误, explain

## Repository Paths

- PDF: `collector/e9fe1e133eb7b4c2ffeea38b635d1c99.pdf`
- Extracted: `generated/extracted/e9fe1e133eb7b4c2ffeea38b635d1c99/full.md`
- Filtered: `generated/filtered/e9fe1e133eb7b4c2ffeea38b635d1c99/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
