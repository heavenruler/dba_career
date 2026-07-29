---
doc_id: "0e9882cbb3c7917b26251aba1dd71df1"
title: "6 mysql底层解析——缓存，Innodb_buffer_pool，包括连接、解析、缓存、引擎、存储等-腾讯云开发者社区-腾讯云"
aliases:
  - "6 mysql底层解析——缓存，Innodb_buffer_pool，包括连接、解析、缓存、引擎、存储等-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/1508324"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Buffer Pool"
  - "Change Buffer"
  - "Redo Log"
  - "性能优化"
  - "数据库"
generated: true
---

# 6 mysql底层解析——缓存，Innodb_buffer_pool，包括连接、解析、缓存、引擎、存储等-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `0e9882cbb3c7917b26251aba1dd71df1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/1508324)
> - PDF: [open local PDF](../../collector/0e9882cbb3c7917b26251aba1dd71df1.pdf)

## Summary

文章系统介绍了 InnoDB Buffer Pool 的作用、默认容量与配置方式、LRU 淘汰机制、读缓存、Insert Buffer / Change Buffer 的工作原理，以及 redo log、checkpoint 和两次写在持久化与崩溃恢复中的角色。

## Knowledge Outline

- Buffer Pool 作用 — MySQL, InnoDB, Buffer Pool, 缓存, 配置
- Pool 大小与 LRU — MySQL, InnoDB, LRU, Buffer Pool, 性能优化
- LRU 热端 — MySQL, InnoDB, LRU, Buffer Pool, 监控
- 读缓存与插入缓冲 — MySQL, InnoDB, Insert Buffer, Change Buffer, 二级索引, 性能优化
- Insert Buffer 原理与 Merge — MySQL, InnoDB, Insert Buffer, B+ Tree, Merge, 二级索引
- Checkpoint 与 redo log — MySQL, InnoDB, Redo Log, Checkpoint, Crash Recovery, Double Write

## Repository Paths

- PDF: `collector/0e9882cbb3c7917b26251aba1dd71df1.pdf`
- Extracted: `generated/extracted/0e9882cbb3c7917b26251aba1dd71df1/full.md`
- Filtered: `generated/filtered/0e9882cbb3c7917b26251aba1dd71df1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
