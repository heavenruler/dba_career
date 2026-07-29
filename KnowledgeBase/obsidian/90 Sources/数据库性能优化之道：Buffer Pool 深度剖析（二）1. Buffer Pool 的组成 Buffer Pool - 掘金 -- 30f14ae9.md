---
doc_id: "30f14ae923d74b101276b457397c9e56"
title: "数据库性能优化之道：Buffer Pool 深度剖析（二）1. Buffer Pool 的组成 Buffer Pool - 掘金"
aliases:
  - "数据库性能优化之道：Buffer Pool 深度剖析（二）1. Buffer Pool 的组成 Buffer Pool - 掘金"
url: "https://juejin.cn/post/7459286686830215205"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "Buffer Pool"
  - "InnoDB"
  - "性能优化"
  - "缓存"
  - "LRU"
  - "脏页"
  - "刷盘"
generated: true
---

# 数据库性能优化之道：Buffer Pool 深度剖析（二）1. Buffer Pool 的组成 Buffer Pool - 掘金

> [!info] Provenance
> - doc_id: `30f14ae923d74b101276b457397c9e56`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7459286686830215205)
> - PDF: [open local PDF](../../collector/30f14ae923d74b101276b457397c9e56.pdf)

## Summary

本文围绕 InnoDB Buffer Pool 的组成、LRU/Free/Flush 三类链表，以及初始化、数据页加载、脏页标记、淘汰和刷盘流程进行说明，重点在于缓冲池如何通过内存管理提升数据库性能。

## Knowledge Outline

- Buffer Pool 组成 — MySQL, 数据库, Buffer Pool, InnoDB, 缓存, 脏页
- LRU 实现方式 — MySQL, 数据库, Buffer Pool, LRU, 缓存, 哈希表, 双向链表
- 运行机制 — MySQL, 数据库, Buffer Pool, 性能优化, 脏页, 刷盘, 缓存命中
- 总结 — MySQL, 数据库, Buffer Pool, 性能优化, 总结

## Repository Paths

- PDF: `collector/30f14ae923d74b101276b457397c9e56.pdf`
- Extracted: `generated/extracted/30f14ae923d74b101276b457397c9e56/full.md`
- Filtered: `generated/filtered/30f14ae923d74b101276b457397c9e56/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
