---
doc_id: "c7fe501ea5c0351c788748b4669f0b48"
title: "浅析MySQL代价估计器-阿里云开发者社区"
aliases:
  - "浅析MySQL代价估计器-阿里云开发者社区"
url: "https://developer.aliyun.com/article/1450053"
source_domain: "developer.aliyun.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库优化器"
  - "CBO"
  - "代价估计"
  - "Access Path"
  - "SQL优化"
  - "InnoDB"
  - "索引"
  - "源码解读"
generated: true
---

# 浅析MySQL代价估计器-阿里云开发者社区

> [!info] Provenance
> - doc_id: `c7fe501ea5c0351c788748b4669f0b48`
> - source_kind: `llm_filtered`
> - source: [original URL](https://developer.aliyun.com/article/1450053)
> - PDF: [open local PDF](../../collector/c7fe501ea5c0351c788748b4669f0b48.pdf)

## Summary

本文介绍 MySQL CBO 中代价估计器的作用、Access Path 与 Cost 概念，并基于 MySQL 8.0.34 源码梳理单表访问路径的行数与代价估计方法，包括 Table Scan、Index Scan、Group Range、Skip Scan、Index Range Scan、Roworder Intersect 与 Index Merge Union。

## Knowledge Outline

- 代价估计器定义 — CBO, 代价估计, 优化器
- Access Path 示例 — Access Path, InnoDB, 索引, 物理执行计划
- Access Path 与数据分布 — 数据分布, SQL优化, InnoDB, 回表
- Cost 定义与权重 — Cost, CPU Cost, IO Cost, MySQL
- Cost 常数表 — mysql.server_cost, mysql.engine_cost, 成本模型, 参数
- 源码入口 — MySQL源码, JOIN::estimate_rowcount, choose_table_order, Join Reorder
- estimate_rowcount 逻辑 — JOIN, Access Path, 代价估计
- system const — system, const, 点查, MySQL源码
- Table Scan — Table Scan, InnoDB, 统计信息, MVCC
- Table Scan 公式 — Table Scan, IO Cost, Buffer Pool, 聚簇索引
- Index Scan — Index Scan, 覆盖索引, 二级索引
- Group Range — Group Range, Skip Scan, GROUP BY, MIN, MAX, records_per_key, Cardinality
- Skip Scan — Skip Scan, selectivity, 直方图, B+树
- Index Range Scan 与 SEL_TREE — Index Range Scan, SEL_TREE, WHERE, 索引区间
- SEL_TREE 特点 — SEL_TREE, SEL_ROOT, AND, OR, 红黑树
- Index Dive — Index Dive, records_in_range, eq_range_index_dive_limit, 行数估计
- Index Range Scan Cost — Index Range Scan, 回表, IO Cost, CPU Cost
- Roworder Intersect 与 Index Merge Union — Roworder Intersect, Index Merge Union, 二级索引, 回表
- ROR Scan 与集合操作 — ROR, Rowid-Ordered Retrieval, 多路归并, InnoDB
- Index Merge Union Cost — Index Merge Union, SortBuffer, 去重, 排序, 回表
- 单表 Access Path 汇总 — Access Path, row count, IO Cost, CPU Cost, 总结

## Repository Paths

- PDF: `collector/c7fe501ea5c0351c788748b4669f0b48.pdf`
- Extracted: `generated/extracted/c7fe501ea5c0351c788748b4669f0b48/full.md`
- Filtered: `generated/filtered/c7fe501ea5c0351c788748b4669f0b48/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
