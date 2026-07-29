---
doc_id: "02f7ce5680cb3c01e50450fddbe10d04"
title: "面试复盘：MySQL InnoDB 事务隔离级别与 MVCC 分析/为什么可重复读的死锁概率高？_ 最近一次面试中，面 - 掘金"
aliases:
  - "面试复盘：MySQL InnoDB 事务隔离级别与 MVCC 分析/为什么可重复读的死锁概率高？_ 最近一次面试中，面 - 掘金"
url: "https://juejin.cn/post/7486852319461883916"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "事务隔离"
  - "MVCC"
  - "ReadView"
  - "死锁"
  - "面试"
  - "数据库"
generated: true
---

# 面试复盘：MySQL InnoDB 事务隔离级别与 MVCC 分析/为什么可重复读的死锁概率高？_ 最近一次面试中，面 - 掘金

> [!info] Provenance
> - doc_id: `02f7ce5680cb3c01e50450fddbe10d04`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7486852319461883916)
> - PDF: [open local PDF](../../collector/02f7ce5680cb3c01e50450fddbe10d04.pdf)

## Summary

这篇文章围绕 InnoDB 四种事务隔离级别、MVCC、ReadView、可见性规则，以及从 Repeatable Read 切换到 Read Committed 为什么能降低死锁概率，给出了一次面试复盘式整理。

## Knowledge Outline

- 面试背景 — MySQL, InnoDB, 事务隔离, MVCC, 面试
- 四种隔离级别 — MySQL, InnoDB, 事务隔离, 脏读, 不可重复读, 幻读
- MVCC 与 ReadView — MVCC, ReadView, Undo Log, 事务ID, 可见性规则
- ReadView 可见性规则 — ReadView, 可见性规则, Read Committed, Repeatable Read
- 隔离级别解决的问题 — 脏读, 不可重复读, 幻读, 事务隔离, 并发
- RR 切 RC 与死锁 — Repeatable Read, Read Committed, Gap Lock, Next-Key Lock, 死锁, 锁机制
- 总结 — MySQL, InnoDB, MVCC, ReadView, 一致性, 性能权衡

## Repository Paths

- PDF: `collector/02f7ce5680cb3c01e50450fddbe10d04.pdf`
- Extracted: `generated/extracted/02f7ce5680cb3c01e50450fddbe10d04/full.md`
- Filtered: `generated/filtered/02f7ce5680cb3c01e50450fddbe10d04/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
