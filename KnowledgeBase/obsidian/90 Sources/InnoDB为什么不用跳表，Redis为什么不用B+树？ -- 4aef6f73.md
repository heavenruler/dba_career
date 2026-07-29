---
doc_id: "4aef6f739e31d7fce382d6b841946eff"
title: "InnoDB为什么不用跳表，Redis为什么不用B+树？"
aliases:
  - "InnoDB为什么不用跳表，Redis为什么不用B+树？"
url: "https://mp.weixin.qq.com/s/XNyUy1f42Lxs3yEcNkxpOw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "InnoDB"
  - "Redis"
  - "B+树"
  - "跳表"
  - "数据库原理"
  - "存储引擎"
  - "ZSET"
  - "内存数据库"
  - "磁盘IO"
  - "对比分析"
generated: true
---

# InnoDB为什么不用跳表，Redis为什么不用B+树？

> [!info] Provenance
> - doc_id: `4aef6f739e31d7fce382d6b841946eff`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/XNyUy1f42Lxs3yEcNkxpOw)
> - PDF: [open local PDF](../../collector/4aef6f739e31d7fce382d6b841946eff.pdf)

## Summary

對比 InnoDB 與 Redis 在 B+ 树和跳表之间的选型，重点围绕磁盘 I/O、范围查询、并发与事务支持、内存访问、实现复杂度和空间效率展开。

## Knowledge Outline

- 问题背景 — InnoDB, Redis, B+树, 跳表, 对比分析
- InnoDB 选型 — InnoDB, B+树, 跳表, 磁盘IO, 范围查询, MVCC, 并发控制
- Redis 选型 — Redis, 跳表, ZSET, 内存数据库, 范围查询, 高性能, B+树
- 对比总结 — B+树, 跳表, 对比, InnoDB, Redis

## Repository Paths

- PDF: `collector/4aef6f739e31d7fce382d6b841946eff.pdf`
- Extracted: `generated/extracted/4aef6f739e31d7fce382d6b841946eff/full.md`
- Filtered: `generated/filtered/4aef6f739e31d7fce382d6b841946eff/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
