---
doc_id: "db466c72aba42f19b73eb86c22209606"
title: "MySQL8.0后的double write有什么变化 - 墨天轮"
aliases:
  - "MySQL8.0后的double write有什么变化 - 墨天轮"
url: "https://www.modb.pro/db/1871454243706646528"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "DBA"
  - "性能调优"
  - "数据库原理"
generated: true
---

# MySQL8.0后的double write有什么变化 - 墨天轮

> [!info] Provenance
> - doc_id: `db466c72aba42f19b73eb86c22209606`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1871454243706646528)
> - PDF: [open local PDF](../../collector/db466c72aba42f19b73eb86c22209606.pdf)

## Summary

本文解释 MySQL/InnoDB double write 的作用、脏页部分写问题、写性能影响，以及 8.0 后 doublewrite 独立文件与参数 `innodb_doublewrite_pages` 的变化。

## Knowledge Outline

- 什么是double write — MySQL, InnoDB, double write, 存储引擎
- 为什么要有双写机制 — MySQL, InnoDB, redo log, double write, 数据恢复
- 双写是否会大大降低写性能 — MySQL, InnoDB, 性能调优, fsync, IO
- 5.7和8.0的区别 — MySQL, InnoDB, MySQL 8.0, 参数, 性能调优

## Repository Paths

- PDF: `collector/db466c72aba42f19b73eb86c22209606.pdf`
- Extracted: `generated/extracted/db466c72aba42f19b73eb86c22209606/full.md`
- Filtered: `generated/filtered/db466c72aba42f19b73eb86c22209606/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
