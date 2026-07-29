---
doc_id: "6b7cb5fbeb631271e97ede60ad1251a6"
title: "PgSQL vs InnoDB脏页刷脏对比"
aliases:
  - "PgSQL vs InnoDB脏页刷脏对比"
url: "https://www.modb.pro/db/2028109116993511424"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "InnoDB"
  - "MySQL"
  - "WAL"
  - "REDO"
  - "脏页刷写"
  - "checkpoint"
  - "double write buffer"
  - "数据库内核"
generated: true
---

# PgSQL vs InnoDB脏页刷脏对比

> [!info] Provenance
> - doc_id: `6b7cb5fbeb631271e97ede60ad1251a6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2028109116993511424)
> - PDF: [open local PDF](../../collector/6b7cb5fbeb631271e97ede60ad1251a6.pdf)

## Summary

對比 PostgreSQL 全页写入与 InnoDB double write buffer 的脏页刷写、checkpoint 与崩溃恢复机制，并总结各自优劣。

## Knowledge Outline

- 引言 — PostgreSQL, MySQL, WAL, REDO, 脏页刷写
- InnoDB 脏页刷写 — InnoDB, 脏页刷写, checkpoint, double write buffer, redo log
- PostgreSQL 脏页刷写 — PostgreSQL, WAL, checkpoint, 脏页刷写, 崩溃恢复
- 优缺点对比 — PostgreSQL, InnoDB, MySQL, WAL, redo log, double write buffer, checkpoint, 性能, 恢复机制

## Repository Paths

- PDF: `collector/6b7cb5fbeb631271e97ede60ad1251a6.pdf`
- Extracted: `generated/extracted/6b7cb5fbeb631271e97ede60ad1251a6/full.md`
- Filtered: `generated/filtered/6b7cb5fbeb631271e97ede60ad1251a6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
