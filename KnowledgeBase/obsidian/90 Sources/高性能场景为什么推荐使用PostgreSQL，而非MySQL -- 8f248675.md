---
doc_id: "8f248675052975f863e75b5d853d4076"
title: "高性能场景为什么推荐使用PostgreSQL，而非MySQL?"
aliases:
  - "高性能场景为什么推荐使用PostgreSQL，而非MySQL?"
url: "https://www.cnblogs.com/12lisu/p/19132585"
source_domain: "www.cnblogs.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "MySQL"
  - "数据库"
  - "高性能"
  - "索引"
  - "查询优化"
  - "MVCC"
  - "并发控制"
  - "技术选型"
  - "迁移"
generated: true
---

# 高性能场景为什么推荐使用PostgreSQL，而非MySQL?

> [!info] Provenance
> - doc_id: `8f248675052975f863e75b5d853d4076`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.cnblogs.com/12lisu/p/19132585)
> - PDF: [open local PDF](../../collector/8f248675052975f863e75b5d853d4076.pdf)

## Summary

文章比较 PostgreSQL 与 MySQL 在高性能场景下的架构、索引、复杂查询优化、数据类型、事务并发、性能测试与迁移策略，并给出技术选型建议。

## Knowledge Outline

- 前言 — 技术选型, PostgreSQL, MySQL
- MySQL 架构特点 — MySQL, 架构, 连接池, 并发
- PostgreSQL 架构优势 — PostgreSQL, 架构, 连接池, 资源隔离
- MySQL 索引限制 — MySQL, 索引, B+Tree, JSON
- PostgreSQL 多元索引 — PostgreSQL, 索引, GIN, BRIN, JSONB
- 复杂查询优化 — 查询优化, CTE, JOIN, 并行查询
- 数据类型和扩展性 — 数据类型, JSONB, 数组, 几何类型, PostgreSQL, MySQL
- 事务与并发控制 — MVCC, 事务, 并发控制, 锁, SKIP LOCKED
- 实战性能对比 — 性能测试, TPS, PostgreSQL, 高并发
- 迁移考虑 — 迁移, Flyway, PostgreSQL, MySQL
- 选型总结 — 技术选型, PostgreSQL, MySQL, 高性能, 数据一致性

## Repository Paths

- PDF: `collector/8f248675052975f863e75b5d853d4076.pdf`
- Extracted: `generated/extracted/8f248675052975f863e75b5d853d4076/full.md`
- Filtered: `generated/filtered/8f248675052975f863e75b5d853d4076/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
