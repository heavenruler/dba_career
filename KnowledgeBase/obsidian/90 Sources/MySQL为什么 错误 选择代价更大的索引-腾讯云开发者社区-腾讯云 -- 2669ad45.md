---
doc_id: "2669ad45cecf54d617286f26b3add8cf"
title: "MySQL为什么\"错误\"选择代价更大的索引-腾讯云开发者社区-腾讯云"
aliases:
  - "MySQL为什么\"错误\"选择代价更大的索引-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/1922139"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "查询优化器"
  - "索引选择"
  - "EXPLAIN"
  - "OPTIMIZE_TRACE"
  - "性能测试"
  - "DBA"
generated: true
---

# MySQL为什么"错误"选择代价更大的索引-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `2669ad45cecf54d617286f26b3add8cf`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/1922139)
> - PDF: [open local PDF](../../collector/2669ad45cecf54d617286f26b3add8cf.pdf)

## Summary

文章复现并分析 MySQL 优化器在多个唯一索引代价相同的情况下，为什么会选择 VARCHAR 列索引而非看似更低成本的 INT 列索引；通过 EXPLAIN、EXPLAIN ANALYZE、OPTIMIZE_TRACE、debug trace 与 mysqlslap 对比测试说明索引创建顺序会影响选择，而真实执行耗时可能仍有差异。

## Knowledge Outline

- 问题描述 — MySQL, 索引选择, 查询优化器
- 创建测试表 t1 — MySQL, InnoDB, 唯一索引
- 写入测试数据 — MySQL, 测试数据, mysql_random_data_load
- t1 执行计划 — MySQL, EXPLAIN, 执行计划, 索引选择
- 问题分析结论 — MySQL, 查询优化器, 索引顺序
- 创建测试表 t2 — MySQL, InnoDB, 唯一索引
- t2 执行计划 — MySQL, EXPLAIN, 执行计划, 索引顺序
- EXPLAIN ANALYZE 代价对比 — MySQL, EXPLAIN ANALYZE, 执行计划成本
- OPTIMIZE_TRACE 代价 — MySQL, OPTIMIZE_TRACE, 成本估算, 查询优化器
- debug trace 佐证 — MySQL, debug trace, 查询优化器, 索引顺序
- mysqlslap 对比测试 — MySQL, mysqlslap, 性能测试, point select
- 测试结果与版本 — MySQL, GreatSQL, 性能差异, 查询优化器

## Repository Paths

- PDF: `collector/2669ad45cecf54d617286f26b3add8cf.pdf`
- Extracted: `generated/extracted/2669ad45cecf54d617286f26b3add8cf/full.md`
- Filtered: `generated/filtered/2669ad45cecf54d617286f26b3add8cf/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
