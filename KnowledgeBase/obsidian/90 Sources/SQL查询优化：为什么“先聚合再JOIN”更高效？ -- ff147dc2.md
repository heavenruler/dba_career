---
doc_id: "ff147dc2b8a767234da1c5501f270cf2"
title: "SQL查询优化：为什么“先聚合再JOIN”更高效？"
aliases:
  - "SQL查询优化：为什么“先聚合再JOIN”更高效？"
url: "https://mp.weixin.qq.com/s/U692UQeUGk1-Z52UKaQ7CQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SQL"
  - "查询优化"
  - "JOIN"
  - "GROUP BY"
  - "MySQL"
  - "执行计划"
  - "索引优化"
  - "数据库性能"
  - "数据分析"
  - "电商案例"
generated: true
---

# SQL查询优化：为什么“先聚合再JOIN”更高效？

> [!info] Provenance
> - doc_id: `ff147dc2b8a767234da1c5501f270cf2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/U692UQeUGk1-Z52UKaQ7CQ)
> - PDF: [open local PDF](../../collector/ff147dc2b8a767234da1c5501f270cf2.pdf)

## Summary

本文说明 SQL 查询中“先聚合再 JOIN”的优化原则：通过在事实表内先 GROUP BY 压缩数据量，再关联维度表，减少 JOIN 中间结果、内存和 I/O 成本。内容包含 MySQL 示例、EXPLAIN 对比、索引、CTE、分布式场景、物化视图、分区表、缓存，以及电商订单统计案例。

## Knowledge Outline

- 核心概念与优化思想 — SQL, JOIN, GROUP BY, 查询优化
- 创建模拟表 — SQL, DDL, 表结构
- 插入模拟数据 — SQL, 测试数据
- 推荐写法：先聚合再JOIN — SQL, 查询优化, JOIN, GROUP BY
- 不推荐写法：先JOIN再聚合 — SQL, 反模式, JOIN, GROUP BY
- 性能对比 — 性能优化, JOIN, 扩展性
- 优化原则与建议 — SQL, 优化原则, 索引, 执行计划
- EXPLAIN：先聚合再JOIN — MySQL, EXPLAIN, 执行计划
- EXPLAIN结果解读 — MySQL, 执行计划, 临时表, filesort
- EXPLAIN：先JOIN再聚合 — MySQL, EXPLAIN, 反模式
- JOIN后聚合执行计划问题 — 执行计划, GROUP BY, 临时表, filesort
- 添加索引 — 索引, MySQL, GROUP BY, JOIN
- 大数据量测试数据 — MySQL, CTE, 测试数据, 性能测试
- 大数据量查询对比 — 性能测试, SQL, BI, 报表
- 常见误区 — SQL, 查询优化, 误区
- 适用与不适用场景 — 适用场景, 报表, 指标计算, 维度建模
- CTE写法 — CTE, MySQL 8.0, 可维护性
- 分布式场景优化 — 分布式数据库, Spark, ClickHouse, BigQuery, Shuffle
- Spark SQL示例 — Spark SQL, CBO, BroadcastHashJoin
- 多层聚合 — CTE, 多层聚合, SQL
- 窗口函数复杂聚合 — 窗口函数, PERCENT_RANK, 复杂聚合
- 物化视图 — 物化视图, 预计算, SQL优化
- 分区表 — 分区表, 大表优化, SQL
- 缓存策略 — 缓存, Redis, Guava Cache, Caffeine
- 电商案例背景与慢SQL — 电商案例, 慢SQL, JOIN, GROUP BY
- 电商案例瓶颈 — EXPLAIN, join buffer, 磁盘 I/O, 性能瓶颈
- 电商案例优化SQL — 电商案例, SQL优化, 先聚合再JOIN
- 电商案例优化效果 — 性能提升, EXPLAIN, CPU, 内存
- 复合索引 — 复合索引, GROUP BY, SUM
- 按月分区 — 分区表, 时间分区, 扫描优化
- Redis结果缓存 — Redis, 缓存, Key设计
- 优化手段总结 — SQL优化, 复合索引, 分区表, 缓存

## Repository Paths

- PDF: `collector/ff147dc2b8a767234da1c5501f270cf2.pdf`
- Extracted: `generated/extracted/ff147dc2b8a767234da1c5501f270cf2/full.md`
- Filtered: `generated/filtered/ff147dc2b8a767234da1c5501f270cf2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
