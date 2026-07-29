---
doc_id: "65c5f6a8dcc99c54543b28bda6809b6e"
title: "从Oracle走向更广阔的世界：我的MySQL/PostgreSQL并发设计学习笔记"
aliases:
  - "从Oracle走向更广阔的世界：我的MySQL/PostgreSQL并发设计学习笔记"
url: "https://www.modb.pro/db/2008913618751528960"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "数据库"
  - "Oracle"
  - "MySQL"
  - "PostgreSQL"
  - "MVCC"
  - "并发控制"
  - "锁机制"
  - "事务隔离级别"
  - "性能调优"
  - "架构设计"
generated: true
---

# 从Oracle走向更广阔的世界：我的MySQL/PostgreSQL并发设计学习笔记

> [!info] Provenance
> - doc_id: `65c5f6a8dcc99c54543b28bda6809b6e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2008913618751528960)
> - PDF: [open local PDF](../../collector/65c5f6a8dcc99c54543b28bda6809b6e.pdf)

## Summary

本文以 Oracle 为锚点，对比 MySQL InnoDB 与 PostgreSQL 的 MVCC、锁机制、隔离级别、读写/写写冲突处理方式，并总结写写冲突在生产中的常见陷阱，如间隙锁、大范围 UPDATE、应用层读改写丢失更新、死锁与分区表锁范围误解。

## Knowledge Outline

- 对比学习法 — 学习方法, 数据库, 并发控制
- 并发控制问题 — 并发控制, 事务, 锁机制
- Oracle 原理 — Oracle, MVCC, Undo, SCN, 锁机制, 隔离级别
- Oracle 读写冲突 — Oracle, 读写冲突, 一致性读, Undo
- Oracle 写写冲突 — Oracle, 写写冲突, 行锁, 丢失更新
- InnoDB 原理 — MySQL, InnoDB, MVCC, Undo Log, Read View, Next-Key Lock, 隔离级别
- InnoDB 读写冲突 — MySQL, InnoDB, 读写冲突, Read View, 脏读
- InnoDB 写写冲突 — MySQL, InnoDB, 写写冲突, X锁
- PostgreSQL 原理 — PostgreSQL, MVCC, Heap, xmin, xmax, Snapshot, SSI
- PostgreSQL 读写冲突 — PostgreSQL, 读写冲突, Snapshot, MVCC
- PostgreSQL 写写冲突 — PostgreSQL, 写写冲突, Tuple Lock, Heap
- 三大数据库机制对比 — Oracle, MySQL, PostgreSQL, MVCC, 锁机制, 隔离级别, 对比
- 写写冲突进阶场景 — 写写冲突, 生产实践, 锁等待
- MySQL 间隙锁阻塞插入 — MySQL, InnoDB, 间隙锁, Next-Key Lock, 幻读, 锁等待
- 无 WHERE UPDATE — UPDATE, 行锁, 锁等待, DML, 性能调优
- 应用层丢失更新 — Lost Update, 读改写, 悲观锁, 乐观锁, SELECT FOR UPDATE
- 交叉加锁死锁 — 死锁, Deadlock, 事务, 锁顺序
- 分区表锁范围 — 分区表, Oracle, PostgreSQL, MySQL, 行锁, 全局索引
- 架构取舍 — 架构设计, Oracle, MySQL, PostgreSQL, 技术选型, 权衡
- 最后反思 — 数据库, 架构设计, 技术选型, 学习方法

## Repository Paths

- PDF: `collector/65c5f6a8dcc99c54543b28bda6809b6e.pdf`
- Extracted: `generated/extracted/65c5f6a8dcc99c54543b28bda6809b6e/full.md`
- Filtered: `generated/filtered/65c5f6a8dcc99c54543b28bda6809b6e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
