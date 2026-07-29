---
doc_id: "aa5eda94ae1f55aaf2e53ca0bef8e683"
title: "MySQL高阶调优，一文让你从入门到精通！ - 墨天轮"
aliases:
  - "MySQL高阶调优，一文让你从入门到精通！ - 墨天轮"
url: "https://www.modb.pro/db/1734824646452256768"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL调优"
  - "索引"
  - "B+树"
  - "EXPLAIN"
  - "Join算法"
  - "数据库架构"
  - "性能调优"
generated: true
---

# MySQL高阶调优，一文让你从入门到精通！ - 墨天轮

> [!info] Provenance
> - doc_id: `aa5eda94ae1f55aaf2e53ca0bef8e683`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1734824646452256768)
> - PDF: [open local PDF](../../collector/aa5eda94ae1f55aaf2e53ca0bef8e683.pdf)

## Summary

本文涵盖 MySQL 逻辑架构、查询流程、SQL 执行顺序、索引原理与 B+ 树、MyISAM/InnoDB 索引实现、Join 类型与连接算法、EXPLAIN 执行计划字段解读，以及 SQL 调优与索引失效案例。

## Knowledge Outline

- 前言与受众 — MySQL, DBA, 面试, SQL调优
- MySQL逻辑架构 — MySQL, 数据库架构, 存储引擎
- 查询流程 — MySQL, 查询优化器, SQL执行
- SQL性能问题 — SQL调优, 索引, 服务器调优
- 索引本质 — 索引, 数据结构, 查询算法
- B+树索引结构 — B+树, InnoDB, 索引, IO
- MyISAM与InnoDB索引实现 — MyISAM, InnoDB, 聚集索引, 非聚集索引
- 索引优缺点与时机 — 索引, SQL调优, 查询优化
- Join类型 — Join, SQL, 表连接
- Join差集与并集SQL — Join, SQL, UNION
- Nested-Loops Join — Join算法, Nested-Loop Join, MySQL
- Index Nested Loops Join — Join算法, 索引, Index Nested Loops Join
- Block Nested-Loop Join — Block Nested-Loop Join, Join Buffer, IO, MySQL
- BKA与Hash Join — Batched Key Access Join, Hash Join, MRR, MySQL8.0
- Join优化思路 — Join优化, SQL调优, 索引
- EXPLAIN作用 — EXPLAIN, 执行计划, MySQL
- EXPLAIN字段id与type — EXPLAIN, type, 执行计划
- EXPLAIN访问类型 — EXPLAIN, 索引扫描, 全表扫描
- EXPLAIN关键字段总结 — EXPLAIN, possible_keys, key_len, rows, filtered, Extra
- SQL调优环境准备 — SQL调优, DDL, MySQL
- 单表优化案例 — SQL调优, 复合索引, filesort, 范围查询
- 两表优化案例 — Join优化, 左连接, 索引, 执行计划
- 三表优化案例 — Join优化, BNL, Join Buffer, NestedLoop
- 复合索引与回表 — 复合索引, 回表, 覆盖索引
- 最佳左前缀法则 — 最佳左前缀法则, 索引失效, Using index condition
- 索引列操作失效 — 索引失效, 函数, 类型转换
- 范围之后索引失效 — 索引失效, 范围查询, MySQL5.7
- 不等于与NULL索引失效 — 索引失效, 不等于, NULL
- LIKE与覆盖索引 — LIKE, 覆盖索引, 索引失效
- 字符串与OR索引失效 — 索引失效, 隐式转换, OR

## Repository Paths

- PDF: `collector/aa5eda94ae1f55aaf2e53ca0bef8e683.pdf`
- Extracted: `generated/extracted/aa5eda94ae1f55aaf2e53ca0bef8e683/full.md`
- Filtered: `generated/filtered/aa5eda94ae1f55aaf2e53ca0bef8e683/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
