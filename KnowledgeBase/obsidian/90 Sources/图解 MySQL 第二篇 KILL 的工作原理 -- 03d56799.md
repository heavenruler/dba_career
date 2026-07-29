---
doc_id: "03d5679966d22435f119ed5d4289921e"
title: "图解 MySQL 第二篇 | KILL 的工作原理"
aliases:
  - "图解 MySQL 第二篇 | KILL 的工作原理"
url: "https://mp.weixin.qq.com/s/F5XqlOegYGzyMjTL3h-cGg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "KILL"
  - "线程管理"
  - "DBA"
  - "故障排查"
generated: true
---

# 图解 MySQL 第二篇 | KILL 的工作原理

> [!info] Provenance
> - doc_id: `03d5679966d22435f119ed5d4289921e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/F5XqlOegYGzyMjTL3h-cGg)
> - PDF: [open local PDF](../../collector/03d5679966d22435f119ed5d4289921e.pdf)

## Summary

本文说明 MySQL 的 KILL 不是由发起 KILL 的线程直接执行终止，而是被终止的线程在执行过程中周期性检查 `thd_killed()` 标志后自行中止；同时展示了查询中止时会丢弃临时表并回滚活动事务。

## Knowledge Outline

- KILL 机制 — MySQL, KILL, 线程管理, DBA
- Kill 标志与函数 — MySQL, KILL, thd_killed, is_killed, 线程管理
- 结论 — MySQL, KILL, 生产环境, 风险, DBA

## Repository Paths

- PDF: `collector/03d5679966d22435f119ed5d4289921e.pdf`
- Extracted: `generated/extracted/03d5679966d22435f119ed5d4289921e/full.md`
- Filtered: `generated/filtered/03d5679966d22435f119ed5d4289921e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
