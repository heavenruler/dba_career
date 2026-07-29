---
doc_id: "938ec8b854beade0cca15aaaba177790"
title: "京东面试：mysql深度分页 严重影响性能？根本原因是什么？如何优化？"
aliases:
  - "京东面试：mysql深度分页 严重影响性能？根本原因是什么？如何优化？"
url: "https://mp.weixin.qq.com/s/LXvQMQFf_SyLWh1zI6onkA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "深度分页"
  - "LIMIT"
  - "性能调优"
  - "索引"
  - "B+树"
  - "回表查询"
  - "覆盖索引"
  - "数据库优化"
  - "面试"
generated: true
---

# 京东面试：mysql深度分页 严重影响性能？根本原因是什么？如何优化？

> [!info] Provenance
> - doc_id: `938ec8b854beade0cca15aaaba177790`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/LXvQMQFf_SyLWh1zI6onkA)
> - PDF: [open local PDF](../../collector/938ec8b854beade0cca15aaaba177790.pdf)

## Summary

本文围绕 MySQL LIMIT 深度分页的性能问题，说明 offset 增大时查询变慢的现象、server 层与存储引擎层的执行机制、全表扫描与 filesort 的原因，并补充 B+ 树索引、聚簇索引、非聚簇索引、回表查询、覆盖索引等基础概念，最后列出覆盖索引、子查询、标签记录法、分区表等优化方式。

## Knowledge Outline

- 线上事故背景 — MySQL, 深度分页, 事故案例, 慢SQL
- LIMIT 语法 — MySQL, LIMIT, 分页
- OFFSET 增大影响 — MySQL, LIMIT, 性能调优, 慢查询
- MySQL 服务端架构 — MySQL, Server层, 存储引擎, InnoDB
- 深度分页执行机制 — MySQL, 深度分页, filesort, 全表扫描, 回表查询
- LIMIT M,N 的代价 — MySQL, LIMIT, 执行计划, 性能调优
- B+ 树索引特点 — MySQL, B+树, 索引
- 聚簇索引 — MySQL, 聚簇索引, B+树
- 非聚簇索引 — MySQL, 非聚簇索引, B+树
- 执行计划类型 — MySQL, 执行计划, 全表扫描
- 索引扫描 — MySQL, 索引扫描, B+树, I/O
- 回表查询与覆盖扫描 — MySQL, 回表查询, 覆盖索引, 联合索引
- 执行计划性能对比 — MySQL, 执行计划, 性能对比
- 回表查询定义与影响 — MySQL, 回表查询, InnoDB, 覆盖索引, I/O
- 深度分页问题总结 — MySQL, LIMIT, 深度分页, 优化方案
- 优化一：索引覆盖扫描 — MySQL, 覆盖索引, 深度分页优化
- 优化二：子查询 — MySQL, 子查询, 深度分页优化
- 优化三：标签记录法 — MySQL, 游标分页, 标签记录法, 深度分页优化
- 优化四：分区表 — MySQL, 分区表, 深度分页优化

## Repository Paths

- PDF: `collector/938ec8b854beade0cca15aaaba177790.pdf`
- Extracted: `generated/extracted/938ec8b854beade0cca15aaaba177790/full.md`
- Filtered: `generated/filtered/938ec8b854beade0cca15aaaba177790/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
