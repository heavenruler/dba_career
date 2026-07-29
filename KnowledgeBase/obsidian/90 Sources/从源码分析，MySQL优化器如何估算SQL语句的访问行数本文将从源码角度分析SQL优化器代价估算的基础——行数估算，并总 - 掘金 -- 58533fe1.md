---
doc_id: "58533fe1f1c6095cb0e2f3955e58159b"
title: "从源码分析，MySQL优化器如何估算SQL语句的访问行数本文将从源码角度分析SQL优化器代价估算的基础——行数估算，并总 - 掘金"
aliases:
  - "从源码分析，MySQL优化器如何估算SQL语句的访问行数本文将从源码角度分析SQL优化器代价估算的基础——行数估算，并总 - 掘金"
url: "https://juejin.cn/post/7435664118186590259"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "优化器"
  - "CBO"
  - "行数估算"
  - "统计信息"
  - "Index Dive"
  - "InnoDB"
  - "慢SQL"
  - "执行计划"
  - "数据库性能调优"
  - "DBA"
generated: true
---

# 从源码分析，MySQL优化器如何估算SQL语句的访问行数本文将从源码角度分析SQL优化器代价估算的基础——行数估算，并总 - 掘金

> [!info] Provenance
> - doc_id: `58533fe1f1c6095cb0e2f3955e58159b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7435664118186590259)
> - PDF: [open local PDF](../../collector/58533fe1f1c6095cb0e2f3955e58159b.pdf)

## Summary

本文从 MySQL 8.0.32 源码角度说明优化器行数估算的基础，包括 CBO 代价模型、统计信息采集、InnoDB 索引采样算法、Index Dive 实时下探算法、设计限制，以及一个生产环境执行计划误判案例。

## Knowledge Outline

- 慢SQL与行数估算背景 — 慢SQL, EXPLAIN, 行数估算, DBA
- 逻辑优化和物理优化 — MySQL优化器, 逻辑优化, 物理优化, Access Path
- 逻辑优化示例 — 谓词简化, 统计信息, 访问路径
- 代价计算模型 — CBO, 代价模型, CPU代价, IO代价, mysql.server_cost, mysql.engine_cost
- 统计信息作用 — 统计信息, WHERE, JOIN, 执行计划
- 统计信息采集 — InnoDB, 统计信息, Cardinality, ANALYZE TABLE, innodb_stats_persistent
- InnoDB采样算法 — InnoDB, 采样算法, innodb_stats_persistent_sample_pages
- InnoDB索引结构 — InnoDB, 聚簇索引, 二级索引, B+树
- n-prefix-boring记录 — n-prefix, boring记录, 索引统计
- prefix组合与算法参数 — 联合索引, 最左匹配, prefix, 采样参数
- 统计源码核心函数 — 源码分析, dict_stats_analyze_index_low, B+树, 统计信息
- 统计采样退化为全表扫描 — 全表扫描, 采样算法, dict_stats_analyze_index_level
- 统计辅助变量 — 源码分析, n_diff_on_level, n_diff_boundaries, n_diff_data_t
- 统计流程实现 — 源码分析, dict_stats_analyze_index_level, dict_stats_analyze_index_for_n_prefix
- 统计函数职责 — dict_stats_analyze_index_level, dict_stats_analyze_index_for_n_prefix, dict_stats_analyze_index_below_cur, dict_stats_index_set_n_diff
- 行数估算两种方式 — 行数估算, 统计信息, Index Dive, eq_range_index_dive_limit
- Index Dive适用场景 — Index Dive, 非唯一索引, 索引前缀, 范围查询
- Index Dive算法流程 — Index Dive, B+树, 范围估算
- Index Dive节点估算 — Index Dive, 平均记录数, B+树层级, 估算
- Index Dive路径变量 — 源码分析, btr_estimate_n_rows_in_range_low, btr_path_t
- Index Dive返回估算上限 — 源码分析, Index Dive, 估算限制
- 单层范围估算函数 — btr_estimate_n_rows_in_range_on_level, N_PAGES_READ_LIMIT, Index Dive
- 行数估算限制 — 统计信息不准, 数据倾斜, ANALYZE TABLE, 执行计划
- 现网问题现象 — 慢SQL, 现网案例, 执行计划
- 现网定位过程 — Access Path, 执行计划, 行数估算, 统计信息
- 现网根因判断 — EXPLAIN, ref访问, 数据倾斜, 索引统计信息
- 现网解决方案 — ANALYZE TABLE, 索引选择性, innodb_stats_persistent_sample_pages, 直方图
- Statement Outline方案 — Statement Outline, index hints, SQL优化
- 全文总结 — 行数估算, 源码分析, 问题定位, 解决方案

## Repository Paths

- PDF: `collector/58533fe1f1c6095cb0e2f3955e58159b.pdf`
- Extracted: `generated/extracted/58533fe1f1c6095cb0e2f3955e58159b/full.md`
- Filtered: `generated/filtered/58533fe1f1c6095cb0e2f3955e58159b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
