---
doc_id: "c5ccce85f8dd2d29e4493536ecda5797"
title: "MySQL如何加速读写速度？来看看Buffer Pool什么是 Buffer Pool 什么是 Buffer Pool？ - 掘金"
aliases:
  - "MySQL如何加速读写速度？来看看Buffer Pool什么是 Buffer Pool 什么是 Buffer Pool？ - 掘金"
url: "https://juejin.cn/post/7461825527058546726"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Buffer Pool"
  - "数据库"
  - "性能优化"
  - "LRU"
  - "监控"
generated: true
---

# MySQL如何加速读写速度？来看看Buffer Pool什么是 Buffer Pool 什么是 Buffer Pool？ - 掘金

> [!info] Provenance
> - doc_id: `c5ccce85f8dd2d29e4493536ecda5797`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7461825527058546726)
> - PDF: [open local PDF](../../collector/c5ccce85f8dd2d29e4493536ecda5797.pdf)

## Summary

本文围绕 InnoDB Buffer Pool 的作用、内部结构、三类链表管理方式、LRU 优化、预读失效与缓冲池污染、多个 Buffer Pool 实例、动态调整容量，以及如何用 InnoDB 标准监视器观察缓冲池指标展开。

## Knowledge Outline

- Buffer Pool 是什么 — MySQL, InnoDB, Buffer Pool, 数据库
- Buffer Pool 结构 — MySQL, InnoDB, Buffer Pool, 内存, 数据页
- 管理方式 — MySQL, InnoDB, Buffer Pool, LRU
- Free List — MySQL, InnoDB, Buffer Pool, Free List
- Flush List — MySQL, InnoDB, Buffer Pool, 脏页, Flush List
- LRU List — MySQL, InnoDB, Buffer Pool, LRU, 性能优化
- 预读失效 — MySQL, InnoDB, Buffer Pool, 预读, LRU
- Buffer Pool 污染 — MySQL, InnoDB, Buffer Pool, 全表扫描, 索引失效, 性能优化
- 多 Buffer Pool — MySQL, InnoDB, Buffer Pool, 并发, 性能优化
- 动态调整 — MySQL, InnoDB, Buffer Pool, chunk, 容量调整
- 容量建议 — MySQL, InnoDB, Buffer Pool, 容量规划, 参数
- 监控指标 — MySQL, InnoDB, Buffer Pool, 监控, 指标

## Repository Paths

- PDF: `collector/c5ccce85f8dd2d29e4493536ecda5797.pdf`
- Extracted: `generated/extracted/c5ccce85f8dd2d29e4493536ecda5797/full.md`
- Filtered: `generated/filtered/c5ccce85f8dd2d29e4493536ecda5797/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
