---
doc_id: "8b3b99d613c2bf75e4779522b9170476"
title: "深度解析MySQL的半连接转换"
aliases:
  - "深度解析MySQL的半连接转换"
url: "https://www.modb.pro/db/1943504966363131904"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "半连接"
  - "semijoin"
  - "SQL优化"
  - "执行计划"
  - "optimizer_trace"
  - "数据库性能优化"
generated: true
---

# 深度解析MySQL的半连接转换

> [!info] Provenance
> - doc_id: `8b3b99d613c2bf75e4779522b9170476`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1943504966363131904)
> - PDF: [open local PDF](../../collector/8b3b99d613c2bf75e4779522b9170476.pdf)

## Summary

本文用学生课程管理系统示例说明 MySQL 半连接转换对 IN / EXISTS 子查询的优化效果，介绍 semijoin transformation 的定义、适用场景、optimizer_switch 控制方式、开启关闭后的执行计划差异，并通过 optimizer trace 展示半连接转换、策略选择与查询执行阶段。

## Knowledge Outline

- 应用场景 — MySQL, semijoin, 应用场景
- 内连接去重问题 — JOIN, DISTINCT, SQL查询
- IN 子查询与半连接计划 — IN子查询, EXPLAIN ANALYZE, Nested loop semijoin
- 半连接定义 — Semijoin, Table Pullout, Duplicate Weedout, First Match, Loose Scan, Materialization
- 适用场景 — MySQL 8.0, anti semijoin, NOT IN, NOT EXISTS
- 控制半连接优化 — optimizer_switch, semijoin, loosescan, duplicateweedout
- 关闭半连接后的计划 — EXPLAIN ANALYZE, semijoin=off, 子查询物化
- 传统 EXPLAIN 对比 — EXPLAIN, DEPENDENT SUBQUERY, SIMPLE, 执行计划
- 半连接转换 Trace — optimizer_trace, join_preparation, transformation_to_semi_join
- 半连接策略选择 Trace — optimizer_trace, FirstMatch, MaterializeLookup, DuplicatesWeedout, cost
- 查询执行 Trace — optimizer_trace, join_execution
- 新版优化措施 — MySQL 8.0.41, MySQL 8.4.4, MySQL 9.2, group skip scan, semijoin performance

## Repository Paths

- PDF: `collector/8b3b99d613c2bf75e4779522b9170476.pdf`
- Extracted: `generated/extracted/8b3b99d613c2bf75e4779522b9170476/full.md`
- Filtered: `generated/filtered/8b3b99d613c2bf75e4779522b9170476/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
