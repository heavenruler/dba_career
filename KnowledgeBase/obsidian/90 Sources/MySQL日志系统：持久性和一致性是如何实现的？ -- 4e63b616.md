---
doc_id: "4e63b616ab207e733ae09e3b879e2637"
title: "MySQL日志系统：持久性和一致性是如何实现的？"
aliases:
  - "MySQL日志系统：持久性和一致性是如何实现的？"
url: "https://mp.weixin.qq.com/s/NUjHxYi153OFPv3B4XAxNw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "Redo Log"
  - "Binlog"
  - "2PC"
  - "事务"
  - "崩溃恢复"
generated: true
---

# MySQL日志系统：持久性和一致性是如何实现的？

> [!info] Provenance
> - doc_id: `4e63b616ab207e733ae09e3b879e2637`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/NUjHxYi153OFPv3B4XAxNw)
> - PDF: [open local PDF](../../collector/4e63b616ab207e733ae09e3b879e2637.pdf)

## Summary

本文以更新语句为例，说明 MySQL 如何通过 Redo Log、Binlog 和两阶段提交来保证事务的持久性、一致性，以及崩溃恢复时如何处理 prepare 状态的事务。

## Knowledge Outline

- SQL执行过程回顾 — MySQL, SQL执行, 事务, 数据库
- Redo Log 与 Binlog — MySQL, Redo Log, Binlog, WAL, 主从复制, 崩溃恢复
- 两阶段提交 — MySQL, 2PC, Redo Log, Binlog, 事务一致性
- 崩溃恢复 — MySQL, 崩溃恢复, Redo Log, Binlog, 事务
- 更新语句示例 — MySQL, SQL更新, Redo Log, Binlog, 事务
- 总结 — MySQL, Redo Log, Binlog, 2PC, 总结

## Repository Paths

- PDF: `collector/4e63b616ab207e733ae09e3b879e2637.pdf`
- Extracted: `generated/extracted/4e63b616ab207e733ae09e3b879e2637/full.md`
- Filtered: `generated/filtered/4e63b616ab207e733ae09e3b879e2637/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
