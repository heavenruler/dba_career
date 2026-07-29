---
doc_id: "dbfd739fa6148e81c1b1e24263eafbf3"
title: "《MySQL开发规范》过时了，视图的查询性能提升了一万倍-腾讯云开发者社区-腾讯云"
aliases:
  - "《MySQL开发规范》过时了，视图的查询性能提升了一万倍-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2005391"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "数据库优化"
  - "视图"
  - "派生条件下推"
  - "查询优化"
  - "执行计划"
  - "性能调优"
generated: true
---

# 《MySQL开发规范》过时了，视图的查询性能提升了一万倍-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `dbfd739fa6148e81c1b1e24263eafbf3`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2005391)
> - PDF: [open local PDF](../../collector/dbfd739fa6148e81c1b1e24263eafbf3.pdf)

## Summary

文章讨论 MySQL 8.0 的派生条件下推优化，以及 MySQL 8.0.29 对包含 union 子句派生表的优化支持，说明该特性如何改善视图查询性能，并通过 MySQL 5.7.26 与 MySQL 8.0.29 的执行计划和耗时对比展示性能差异。

## Knowledge Outline

- 前言 — MySQL, 视图, DBA, 开发规范
- 派生条件下推定义 — MySQL 8.0, 优化器, 派生条件下推, 索引
- 派生条件下推限制 — MySQL, 派生条件下推, 限制条件
- 无聚合派生表示例 — SQL, 派生表, 查询优化
- group by 非分组字段示例 — SQL, group by, having, 查询优化
- group by 分组字段示例 — SQL, group by, where, 查询优化
- union 派生表特例 — MySQL 8.0.29, union, 派生条件下推, 视图
- union 视图定义 — SQL, CREATE VIEW, UNION ALL, 索引
- union 视图执行计划 — EXPLAIN, 执行计划, 索引, 派生条件下推
- 视图查询性能问题 — MySQL, 视图, 性能瓶颈, 全表扫描, 临时表
- 版本对比方法 — MySQL 5.7.26, MySQL 8.0.29, sysbench, 性能对比
- 性能对比视图定义 — SQL, CREATE VIEW, sysbench, UNION ALL
- MySQL 5.7.26 执行计划 — MySQL 5.7.26, EXPLAIN, 全表扫描, 性能测试
- MySQL 8.0.29 执行计划 — MySQL 8.0.29, EXPLAIN ANALYZE, 索引范围扫描, 派生条件下推
- 性能差异结论 — MySQL, 性能调优, 索引, 查询效率
- 总结 — MySQL 8.0, MySQL 8.0.29, 视图, 查询优化, DBA

## Repository Paths

- PDF: `collector/dbfd739fa6148e81c1b1e24263eafbf3.pdf`
- Extracted: `generated/extracted/dbfd739fa6148e81c1b1e24263eafbf3/full.md`
- Filtered: `generated/filtered/dbfd739fa6148e81c1b1e24263eafbf3/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
