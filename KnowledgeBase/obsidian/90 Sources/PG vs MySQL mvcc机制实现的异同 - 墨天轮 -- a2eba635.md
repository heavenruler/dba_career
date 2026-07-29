---
doc_id: "a2eba635f7a208fceb4b1753c6184b17"
title: "PG vs MySQL mvcc机制实现的异同 - 墨天轮"
aliases:
  - "PG vs MySQL mvcc机制实现的异同 - 墨天轮"
url: "https://www.modb.pro/db/1879802616004227072"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "MySQL"
  - "MVCC"
  - "InnoDB"
  - "事务隔离"
  - "数据库内核"
  - "UNDO"
  - "VACUUM"
generated: true
---

# PG vs MySQL mvcc机制实现的异同 - 墨天轮

> [!info] Provenance
> - doc_id: `a2eba635f7a208fceb4b1753c6184b17`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1879802616004227072)
> - PDF: [open local PDF](../../collector/a2eba635f7a208fceb4b1753c6184b17.pdf)

## Summary

本文比较 PostgreSQL 与 MySQL/InnoDB 的 MVCC 实现，包括多版本数据存储方式、事务快照结构、可见性判断、隔离级别实现，以及两者在旧版本数据处理、VACUUM、UNDO 与回滚成本上的差异。

## Knowledge Outline

- MVCC 实现方法比较 — MVCC, MySQL, PostgreSQL
- PG MVCC 原理 — PostgreSQL, MVCC, 事务快照, 隔离级别
- PG 元组版本字段 — PostgreSQL, tuple, t_xmin, t_xmax, t_ctid
- PG Insert 版本规则 — PostgreSQL, insert, heap_page_items, txid
- PG Delete 版本规则 — PostgreSQL, delete, VACUUM, dead tuple
- PG Update 版本规则 — PostgreSQL, update, tuple version, t_ctid
- PG 事务快照 — PostgreSQL, transaction snapshot, xmin, xmax, xip_list
- PG 快照创建过程 — PostgreSQL, 事务快照, XID
- PG 隔离级别实现 — PostgreSQL, 隔离级别, read committed, repeatable read, serializable
- MySQL 多版本实现 — MySQL, InnoDB, MVCC, row trx_id, UNDO
- MySQL 事务快照 — MySQL, InnoDB, read view, 事务快照, 可见性
- MySQL 隔离级别实现 — MySQL, 隔离级别, read view, repeatable read, read committed
- PG vs MySQL 差异总结 — PostgreSQL, MySQL, MVCC, VACUUM, rollback, 性能

## Repository Paths

- PDF: `collector/a2eba635f7a208fceb4b1753c6184b17.pdf`
- Extracted: `generated/extracted/a2eba635f7a208fceb4b1753c6184b17/full.md`
- Filtered: `generated/filtered/a2eba635f7a208fceb4b1753c6184b17/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
