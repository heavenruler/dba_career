---
doc_id: "1de9b7d1440ed70776bf9f305e14a986"
title: "TiDB 底层存储结构 LSM 树原理介绍随着数据量的增大，传统关系型数据库越来越不能满足对于海量数据存储的需求。对于分 - 掘金"
aliases:
  - "TiDB 底层存储结构 LSM 树原理介绍随着数据量的增大，传统关系型数据库越来越不能满足对于海量数据存储的需求。对于分 - 掘金"
url: "https://juejin.cn/post/7187222825819144250"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "LSM Tree"
  - "数据库"
  - "存储引擎"
  - "RocksDB"
  - "SSTable"
  - "Compact"
  - "B+树"
  - "NoSQL"
generated: true
---

# TiDB 底层存储结构 LSM 树原理介绍随着数据量的增大，传统关系型数据库越来越不能满足对于海量数据存储的需求。对于分 - 掘金

> [!info] Provenance
> - doc_id: `1de9b7d1440ed70776bf9f305e14a986`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7187222825819144250)
> - PDF: [open local PDF](../../collector/1de9b7d1440ed70776bf9f305e14a986.pdf)

## Summary

本文系统介绍 LSM 树在 TiDB / TiKV 相关存储场景中的原理、组成、Compact 策略、读写查找流程，并与 B+ 树做了写入吞吐、读放大、写放大和空间放大的对比。

## Knowledge Outline

- LSM 树概览 — LSM Tree, 数据库, RocksDB, TiDB, NoSQL
- 算法思路 — LSM Tree, WAL, C0, C1, Compact, 读放大, 写放大
- 组成部分 — MemTable, Immutable MemTable, SSTable, 布隆过滤器, 内存, 磁盘
- Compact 策略与权衡 — Compact, 读放大, 写放大, 空间放大, size-tiered, leveled
- size-tiered 策略 — size-tiered, SSTable, 读放大, 空间放大, Compact
- leveled 策略 — leveled, SSTable, 写放大, 读放大, Compact
- 插入、修改、删除 — 插入, 修改, 删除, L0, Compact
- 查找 — 查找, L0, size-tiered, 布隆过滤器, 缓存
- LSM 树和 B+ 树的比较 — LSM Tree, B+树, 吞吐量, 读写放大, 磁盘IO
- 总结 — LSM Tree, 总结, NoSQL, 读放大, 写放大, 空间放大

## Repository Paths

- PDF: `collector/1de9b7d1440ed70776bf9f305e14a986.pdf`
- Extracted: `generated/extracted/1de9b7d1440ed70776bf9f305e14a986/full.md`
- Filtered: `generated/filtered/1de9b7d1440ed70776bf9f305e14a986/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
