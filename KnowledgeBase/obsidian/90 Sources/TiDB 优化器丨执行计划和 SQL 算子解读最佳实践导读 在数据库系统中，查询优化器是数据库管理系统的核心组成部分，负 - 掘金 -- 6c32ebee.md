---
doc_id: "6c32ebeee3402f4f05f5d5ab547357db"
title: "TiDB 优化器丨执行计划和 SQL 算子解读最佳实践导读 在数据库系统中，查询优化器是数据库管理系统的核心组成部分，负 - 掘金"
aliases:
  - "TiDB 优化器丨执行计划和 SQL 算子解读最佳实践导读 在数据库系统中，查询优化器是数据库管理系统的核心组成部分，负 - 掘金"
url: "https://juejin.cn/post/7423288346123993115"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "SQL 优化器"
  - "执行计划"
  - "SQL 算子"
  - "Join 算法"
  - "数据库性能调优"
  - "DBA"
generated: true
---

# TiDB 优化器丨执行计划和 SQL 算子解读最佳实践导读 在数据库系统中，查询优化器是数据库管理系统的核心组成部分，负 - 掘金

> [!info] Provenance
> - doc_id: `6c32ebeee3402f4f05f5d5ab547357db`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7423288346123993115)
> - PDF: [open local PDF](../../collector/6c32ebeee3402f4f05f5d5ab547357db.pdf)

## Summary

本文系统介绍 TiDB SQL 执行流、优化器逻辑与物理优化、SQL 算子、Join 算法选择、执行计划字段解读，以及 Explain Analyze 的观测方法。

## Knowledge Outline

- 优化器导读 — SQL 优化器, HTAP, 性能稳定性
- SQL 执行流 — SQL 执行流, LogicalPlan, TiKV, TiFlash
- TiDB 内部优化流程 — TiDB, PlanCache, Logical Optimize, Physical Optimize
- SQL 算子与 Query Block — SQL 算子, Query Block, Logical Plan, IR
- LogicalApply — LogicalApply, 子查询, LogicalJoin
- LogicalTopN — LogicalTopN, LogicalLimit, LogicalSort
- Index Join — Index Join, Join 算法, Hint, TiDB 参数
- Index Join 使用建议 — Index Join, 并发, Batch Size, Explain Analyze
- Hash Join — Hash Join, Join 算法, 内存
- Hash Join 参数与建议 — Hash Join, tidb_mem_quota_query, tidb_hash_join_concurrency
- Merge Join — Merge Join, Join 算法, 流式执行
- Null Aware Join — Null Aware Join, 集合谓词, NOT IN, EXISTS
- SQL 算子最佳实践 — Join 算法选择, Hash Join, Index Join, Merge Join
- Join 选择关注点 — Join 算法选择, 性能调优, TiKV Cop
- 逻辑执行计划 — 逻辑执行计划, 常量传播, 列裁剪, 谓词下推
- 谓词下推 — 谓词下推, TiKV, TiDB Server, 逻辑优化
- 执行计划观测 — Explain, optimizer tracer, 执行计划
- Explain 字段 — Explain, 执行计划字段, TableFullScan, IndexLookUp
- Explain Analyze — EXPLAIN ANALYZE, actRows, execution info, memory, disk
- 算子执行顺序 — 算子执行顺序, Build, Probe, 并行执行

## Repository Paths

- PDF: `collector/6c32ebeee3402f4f05f5d5ab547357db.pdf`
- Extracted: `generated/extracted/6c32ebeee3402f4f05f5d5ab547357db/full.md`
- Filtered: `generated/filtered/6c32ebeee3402f4f05f5d5ab547357db/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
