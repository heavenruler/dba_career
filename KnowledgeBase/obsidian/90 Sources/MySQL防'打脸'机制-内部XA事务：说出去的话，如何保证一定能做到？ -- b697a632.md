---
doc_id: "b697a6325edb82e5bff5f2f0f34c4c3a"
title: "MySQL防'打脸'机制-内部XA事务：说出去的话，如何保证一定能做到？"
aliases:
  - "MySQL防'打脸'机制-内部XA事务：说出去的话，如何保证一定能做到？"
url: "https://mp.weixin.qq.com/s/YrheLK6WdBDK1iLBLcKDMA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "XA事务"
  - "两阶段提交"
  - "Binlog"
  - "InnoDB"
  - "主从复制"
  - "崩溃恢复"
generated: true
---

# MySQL防'打脸'机制-内部XA事务：说出去的话，如何保证一定能做到？

> [!info] Provenance
> - doc_id: `b697a6325edb82e5bff5f2f0f34c4c3a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/YrheLK6WdBDK1iLBLcKDMA)
> - PDF: [open local PDF](../../collector/b697a6325edb82e5bff5f2f0f34c4c3a.pdf)

## Summary

这篇文章用内部 XA 事务解释 MySQL 如何协调 Binlog 与 InnoDB 的提交顺序，保证主从一致，并通过两阶段提交和崩溃恢复机制避免“写了 Binlog 但没提交”或“提交了但没写 Binlog”的不一致问题。

## Knowledge Outline

- 问题背景 — MySQL, Binlog, InnoDB, 主从复制, 内部XA事务
- 角色与冲突 — Binlog, InnoDB, Redo Log, Undo Log, ACID, 原子性, 主从一致性
- 内部XA与2PC — 内部XA事务, XA, 2PC, Transaction Coordinator, Crash Recovery, PREPARE, XID
- 实践与验证 — MySQL, XA, PREPARE, INNODB_TRX, Performance Schema, Information Schema, SQL
- 结语 — MySQL, 内部XA事务, 主从一致性, 事务提交, 崩溃恢复

## Repository Paths

- PDF: `collector/b697a6325edb82e5bff5f2f0f34c4c3a.pdf`
- Extracted: `generated/extracted/b697a6325edb82e5bff5f2f0f34c4c3a/full.md`
- Filtered: `generated/filtered/b697a6325edb82e5bff5f2f0f34c4c3a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
