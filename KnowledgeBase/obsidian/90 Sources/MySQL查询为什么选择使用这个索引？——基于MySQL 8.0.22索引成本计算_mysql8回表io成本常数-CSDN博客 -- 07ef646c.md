---
doc_id: "07ef646c6cb296008218c2bde1fa7c48"
title: "MySQL查询为什么选择使用这个索引？——基于MySQL 8.0.22索引成本计算_mysql8回表io成本常数-CSDN博客"
aliases:
  - "MySQL查询为什么选择使用这个索引？——基于MySQL 8.0.22索引成本计算_mysql8回表io成本常数-CSDN博客"
url: "https://blog.csdn.net/qq_34115899/article/details/120217907"
source_domain: "blog.csdn.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "索引优化"
  - "查询优化器"
  - "成本模型"
  - "执行计划"
  - "InnoDB"
  - "SQL性能调优"
  - "连接查询"
generated: true
---

# MySQL查询为什么选择使用这个索引？——基于MySQL 8.0.22索引成本计算_mysql8回表io成本常数-CSDN博客

> [!info] Provenance
> - doc_id: `07ef646c6cb296008218c2bde1fa7c48`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.csdn.net/qq_34115899/article/details/120217907)
> - PDF: [open local PDF](../../collector/07ef646c6cb296008218c2bde1fa7c48.pdf)

## Summary

本文解释 MySQL 8.0.22 查询优化器如何基于 I/O 成本、CPU 成本、成本常数、扫描区间、回表记录数、condition filtering 和连接顺序选择执行计划，并用单表查询与连接查询示例展示索引成本计算。

## Knowledge Outline

- 成本定义 — MySQL, 成本模型, InnoDB
- 查看成本常数 — MySQL, 成本常数, server_cost, engine_cost
- 单表优化步骤 — MySQL, 查询优化器, 执行计划
- 示例查询 — MySQL, 索引选择, EXPLAIN
- 全表扫描成本 — MySQL, 全表扫描, InnoDB, 统计信息
- 全表扫描公式 — MySQL, 成本计算, Data_length, Rows
- 唯一索引成本 — MySQL, uk_key2, 扫描区间, 回表
- 回表成本 — MySQL, 回表, I/O成本, CPU成本
- EXPLAIN JSON 验证 — MySQL, EXPLAIN, query_cost
- 普通索引成本 — MySQL, idx_key1, 普通索引, 回表
- 索引方案对比 — MySQL, 索引合并, 执行计划, 成本对比
- 强制索引分析 — MySQL, EXPLAIN, force index
- 连接查询成本 — MySQL, 连接查询, 嵌套循环连接, fanout
- 条件过滤 — MySQL, Condition filtering, 查询优化器
- 连接公式 — MySQL, 连接查询, 成本公式, 内连接
- 连接顺序分析 — MySQL, JOIN, 连接顺序, ON, WHERE
- 连接优化重点 — MySQL, JOIN优化, 索引设计, 驱动表
- 多表连接搜索 — MySQL, 多表连接, 连接顺序, 优化器
- 多表连接剪枝 — MySQL, optimizer_search_depth, optimizer_prune_level, 启发式规则
- 外连接转内连接 — MySQL, 外连接, 内连接, reject-NULL, JOIN优化

## Repository Paths

- PDF: `collector/07ef646c6cb296008218c2bde1fa7c48.pdf`
- Extracted: `generated/extracted/07ef646c6cb296008218c2bde1fa7c48/full.md`
- Filtered: `generated/filtered/07ef646c6cb296008218c2bde1fa7c48/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
