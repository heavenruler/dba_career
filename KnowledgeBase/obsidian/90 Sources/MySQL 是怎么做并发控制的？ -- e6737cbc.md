---
doc_id: "e6737cbc96da2ff050b837cf2d0e665f"
title: "MySQL 是怎么做并发控制的？"
aliases:
  - "MySQL 是怎么做并发控制的？"
url: "https://mp.weixin.qq.com/s/EjKtAj9H6KpuRlWAfoLYSA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "并发控制"
  - "MDL"
  - "表锁"
  - "B+tree"
  - "行锁"
  - "死锁"
  - "性能排查"
  - "DBA"
generated: true
---

# MySQL 是怎么做并发控制的？

> [!info] Provenance
> - doc_id: `e6737cbc96da2ff050b837cf2d0e665f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/EjKtAj9H6KpuRlWAfoLYSA)
> - PDF: [open local PDF](../../collector/e6737cbc96da2ff050b837cf2d0e665f.pdf)

## Summary

本文以 MySQL 8.0.35 / InnoDB 为主，整理 MySQL 在表、页、行三个层级的并发访问控制机制，涵盖 MDL、Server/Engine 表锁、B+tree page latch、SMO、InnoDB 行锁类型、插入死锁案例与排查思路。

## Knowledge Outline

- 并发控制总体结构 — MySQL, 架构, 并发控制
- Online DDL 背景 — MySQL, DDL, Online DDL
- MDL 锁等待关系 — MDL, DDL, 锁等待, MySQL 源码
- Server 层表锁流程 — Server 层表锁, InnoDB, CSV, MySQL 源码
- InnoDB 表锁入口 — InnoDB, 表锁, Engine Handler
- 表级别问题处理 — MDL, performance_schema, metadata_locks, general_log, CSV
- B+tree 基本结构 — B+tree, InnoDB, Page, 索引
- B+tree 查询与页内修改加锁 — B+tree, Page Lock, 乐观更新
- SMO 悲观更新加锁 — SMO, B+tree, SX 锁, 悲观更新
- 行锁类型 — InnoDB, 行锁, Gap Lock, Next-Key Lock, Insert Intention Lock
- 插入死锁根因 — 死锁, Insert, Gap Lock, Rec Lock, 源码调试
- 典型死锁场景 — 死锁, 唯一索引, Next-Key Lock, Insert Intention Lock
- 死锁排查思路 — 死锁排查, performance_schema, data_locks, innodb_deadlock_detect
- 行级别总结 — 行锁, 锁兼容性, 事务
- 全文总结 — MySQL, 并发控制, MDL, B+tree, 行锁, MVCC

## Repository Paths

- PDF: `collector/e6737cbc96da2ff050b837cf2d0e665f.pdf`
- Extracted: `generated/extracted/e6737cbc96da2ff050b837cf2d0e665f/full.md`
- Filtered: `generated/filtered/e6737cbc96da2ff050b837cf2d0e665f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
