---
doc_id: "0d98d837392fad916ca0ec993690421e"
title: "学习 MySQL 必须了解的几个 Undo 概念Undo 模块的第一篇，聊聊 Undo 相关的几个概念。 > 作者：操盛 - 掘金"
aliases:
  - "学习 MySQL 必须了解的几个 Undo 概念Undo 模块的第一篇，聊聊 Undo 相关的几个概念。 > 作者：操盛 - 掘金"
url: "https://juejin.cn/post/7446981141453324315"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Undo log"
  - "事务"
  - "数据库"
  - "回滚段"
  - "Undo表空间"
  - "系统变量"
generated: true
---

# 学习 MySQL 必须了解的几个 Undo 概念Undo 模块的第一篇，聊聊 Undo 相关的几个概念。 > 作者：操盛 - 掘金

> [!info] Provenance
> - doc_id: `0d98d837392fad916ca0ec993690421e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7446981141453324315)
> - PDF: [open local PDF](../../collector/0d98d837392fad916ca0ec993690421e.pdf)

## Summary

本文基于 MySQL 8.0.32 源码，梳理 InnoDB 的 Undo 相关概念：Undo 页、Undo 段、回滚段、Undo 表空间，以及插入/更新删除产生的 Undo 日志在持久化、清除时机和回滚段分配上的差异。

## Knowledge Outline

- 引子 — MySQL, Undo log, 事务, 数据库
- Undo 页 — MySQL, Undo页, Undo log, InnoDB
- Undo 段 — MySQL, Undo段, Undo log, 回滚, MVCC
- 回滚段 — MySQL, 回滚段, Undo段, 临时表, Redo log, 持久化
- Undo 表空间 — MySQL, Undo表空间, 系统变量, 回滚段, 磁盘空间, 高并发
- 总结 — MySQL, 总结, Undo log, 回滚段, 事务

## Repository Paths

- PDF: `collector/0d98d837392fad916ca0ec993690421e.pdf`
- Extracted: `generated/extracted/0d98d837392fad916ca0ec993690421e/full.md`
- Filtered: `generated/filtered/0d98d837392fad916ca0ec993690421e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
