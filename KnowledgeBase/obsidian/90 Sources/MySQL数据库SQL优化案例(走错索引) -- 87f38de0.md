---
doc_id: "87f38de02a1b77e66adc488b320edb1c"
title: "MySQL数据库SQL优化案例(走错索引)"
aliases:
  - "MySQL数据库SQL优化案例(走错索引)"
url: "https://www.modb.pro/db/1945834983298445312"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "执行计划"
  - "索引选择"
  - "优化器"
  - "统计信息"
  - "慢SQL"
  - "数据库性能调优"
generated: true
---

# MySQL数据库SQL优化案例(走错索引)

> [!info] Provenance
> - doc_id: `87f38de02a1b77e66adc488b320edb1c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1945834983298445312)
> - PDF: [open local PDF](../../collector/87f38de02a1b77e66adc488b320edb1c.pdf)

## Summary

一篇 MySQL 8.0.36 慢 SQL 优化案例，核心问题是优化器选择了 hostid 索引而非 checktime 索引，导致表关联顺序和过滤顺序不佳，慢 SQL 从 11 分钟降至 0.19 秒。内容包含执行计划对比、统计信息检查、直方图与重建表等优化尝试。

## Knowledge Outline

- 数据库版本与问题现象 — MySQL, 慢SQL, 问题现象
- 数据量检查 — MySQL, 数据量, SQL
- 慢执行计划 — MySQL, 执行计划, Nested Loop, 索引
- 慢计划执行过程 — MySQL, 执行计划分析, Nested Loop
- 快执行计划 — MySQL, 执行计划, 索引
- 快计划执行过程 — MySQL, 执行计划分析, 索引过滤
- 强制索引与关联顺序 — MySQL, Hint, FORCE INDEX, JOIN_ORDER
- 慢 SQL 现象归纳 — MySQL, 慢SQL, 索引选择, 过滤顺序
- 优化器成本估算问题 — MySQL, 优化器, 成本估算, 统计信息
- 查看索引统计 — MySQL, SHOW INDEX, 索引统计
- 行数估算偏差 — MySQL, EXPLAIN, 统计信息, 行数估算
- 关联成本低估 — MySQL, 执行计划, 成本估算, Join
- 统计信息与直方图检查 — MySQL, 直方图, column_statistics
- 优化方案尝试 — MySQL, 优化方案, ANALYZE TABLE, 直方图, 复合索引
- 重建表结果 — MySQL, 重建表, 执行计划, 性能优化
- 分区表方案 — MySQL, 分区表, 优化方案

## Repository Paths

- PDF: `collector/87f38de02a1b77e66adc488b320edb1c.pdf`
- Extracted: `generated/extracted/87f38de02a1b77e66adc488b320edb1c/full.md`
- Filtered: `generated/filtered/87f38de02a1b77e66adc488b320edb1c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
