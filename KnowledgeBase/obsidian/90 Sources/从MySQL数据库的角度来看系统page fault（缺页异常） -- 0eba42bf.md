---
doc_id: "0eba42bf7d02a3c3e3598a9722cbd847"
title: "从MySQL数据库的角度来看系统page fault（缺页异常）"
aliases:
  - "从MySQL数据库的角度来看系统page fault（缺页异常）"
url: "https://www.modb.pro/db/1970308942026780672"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "page fault"
  - "内存管理"
  - "性能调优"
  - "数据库"
generated: true
---

# 从MySQL数据库的角度来看系统page fault（缺页异常）

> [!info] Provenance
> - doc_id: `0eba42bf7d02a3c3e3598a9722cbd847`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1970308942026780672)
> - PDF: [open local PDF](../../collector/0eba42bf7d02a3c3e3598a9722cbd847.pdf)

## Summary

文章从 MySQL 视角区分 major page fault、minor page fault 与 invalid page fault，并说明它们与物理内存、swap、InnoDB 缓冲池以及 SQL profile 指标之间的关系。

## Knowledge Outline

- 缺页异常定义 — page fault, 虚拟内存, 操作系统
- Major Page Fault 概念 — major page fault, 磁盘I/O, 操作系统, 性能
- 首次执行示例 — MySQL, profile, BLOCK_OPS_IN, major page fault, InnoDB
- 系统层观测 — mysqld, pidstat, swap, free, major page fault, 内存不足
- InnoDB 与 major fault — InnoDB, 缓冲池, major page fault, 数据库性能, swap
- Minor Page Fault — minor page fault, soft page fault, MMU, MySQL, 性能
- Invalid Page Fault 与结论 — Invalid Page Fault, bug, segment fault, 结论, 数据库调优

## Repository Paths

- PDF: `collector/0eba42bf7d02a3c3e3598a9722cbd847.pdf`
- Extracted: `generated/extracted/0eba42bf7d02a3c3e3598a9722cbd847/full.md`
- Filtered: `generated/filtered/0eba42bf7d02a3c3e3598a9722cbd847/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
