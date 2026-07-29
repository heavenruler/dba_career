---
doc_id: "ca14bed799d35fc4adb9a0f62af1bd8a"
title: "MVCC如何应对MySQL并发问题数据库使用事务来保持数据最终一致性，但是在并发下执行事务，会引起脏读、不可重复读、幻读 - 掘金"
aliases:
  - "MVCC如何应对MySQL并发问题数据库使用事务来保持数据最终一致性，但是在并发下执行事务，会引起脏读、不可重复读、幻读 - 掘金"
url: "https://juejin.cn/post/7460346925407240232"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "数据库"
  - "MySQL"
  - "InnoDB"
  - "MVCC"
  - "事务隔离"
  - "Undo Log"
  - "Read View"
  - "并发控制"
generated: true
---

# MVCC如何应对MySQL并发问题数据库使用事务来保持数据最终一致性，但是在并发下执行事务，会引起脏读、不可重复读、幻读 - 掘金

> [!info] Provenance
> - doc_id: `ca14bed799d35fc4adb9a0f62af1bd8a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7460346925407240232)
> - PDF: [open local PDF](../../collector/ca14bed799d35fc4adb9a0f62af1bd8a.pdf)

## Summary

讲解 MySQL InnoDB 中 MVCC 的概念、适用隔离级别、隐藏字段、Undo Log 版本链、Read View 可见性判断，以及 RC 和 RR 在快照读上的差异。

## Knowledge Outline

- MVCC概述 — 数据库, MySQL, MVCC, 事务隔离, 并发控制
- 隐藏字段与版本链 — 数据库, MySQL, InnoDB, Undo Log, 版本链
- 当前读与Read View — 数据库, MySQL, Read View, 快照读, MVCC
- 可见性算法 — 数据库, MySQL, Read View, 可见性判断, MVCC
- RC与RR差异 — 数据库, MySQL, RC, RR, 不可重复读, MVCC

## Repository Paths

- PDF: `collector/ca14bed799d35fc4adb9a0f62af1bd8a.pdf`
- Extracted: `generated/extracted/ca14bed799d35fc4adb9a0f62af1bd8a/full.md`
- Filtered: `generated/filtered/ca14bed799d35fc4adb9a0f62af1bd8a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
