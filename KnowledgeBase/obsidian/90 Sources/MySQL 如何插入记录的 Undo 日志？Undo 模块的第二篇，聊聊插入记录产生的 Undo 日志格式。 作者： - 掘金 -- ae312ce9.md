---
doc_id: "ae312ce915141a3b796a129cd7d7170b"
title: "MySQL 如何插入记录的 Undo 日志？Undo 模块的第二篇，聊聊插入记录产生的 Undo 日志格式。 > 作者： - 掘金"
aliases:
  - "MySQL 如何插入记录的 Undo 日志？Undo 模块的第二篇，聊聊插入记录产生的 Undo 日志格式。 > 作者： - 掘金"
url: "https://juejin.cn/post/7456616263915257871"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Undo Log"
  - "MVCC"
  - "数据库"
  - "事务"
generated: true
---

# MySQL 如何插入记录的 Undo 日志？Undo 模块的第二篇，聊聊插入记录产生的 Undo 日志格式。 > 作者： - 掘金

> [!info] Provenance
> - doc_id: `ae312ce915141a3b796a129cd7d7170b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7456616263915257871)
> - PDF: [open local PDF](../../collector/ae312ce915141a3b796a129cd7d7170b.pdf)

## Summary

本文说明 InnoDB 插入记录时的 Undo 日志生成时机、日志格式、日志内容字段，以及 DB_ROLL_PTR 的组成和计算公式。

## Knowledge Outline

- 准备工作 — MySQL, InnoDB, SQL, 数据库
- Insert Undo 日志格式 — MySQL, InnoDB, Undo Log, 事务, 数据库
- Insert Undo 日志内容 — MySQL, InnoDB, Undo Log, SQL, 数据库
- Insert Undo 日志地址 — MySQL, InnoDB, Undo Log, MVCC, 数据库, Shell

## Repository Paths

- PDF: `collector/ae312ce915141a3b796a129cd7d7170b.pdf`
- Extracted: `generated/extracted/ae312ce915141a3b796a129cd7d7170b/full.md`
- Filtered: `generated/filtered/ae312ce915141a3b796a129cd7d7170b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
