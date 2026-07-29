---
doc_id: "4504ec57cff1695d52509f095590eb57"
title: "CloudJump II：云数据库在共享存储场景下的优化与实现（发表于SIGMOD 2025）"
aliases:
  - "CloudJump II：云数据库在共享存储场景下的优化与实现（发表于SIGMOD 2025）"
url: "http://mysql.taobao.org/monthly/2025/07/03/"
source_domain: "mysql.taobao.org"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "CloudJump"
  - "云数据库"
  - "共享存储"
  - "计存分离"
  - "MVD"
  - "日志索引"
  - "主从一致性"
  - "恢复"
  - "扩展性"
generated: true
---

# CloudJump II：云数据库在共享存储场景下的优化与实现（发表于SIGMOD 2025）

> [!info] Provenance
> - doc_id: `4504ec57cff1695d52509f095590eb57`
> - source_kind: `llm_filtered`
> - source: [original URL](http://mysql.taobao.org/monthly/2025/07/03/)
> - PDF: [open local PDF](../../collector/4504ec57cff1695d52509f095590eb57.pdf)

## Summary

文章聚焦云数据库从计存分离走向共享存储后的核心问题，重点分析 RO 一致性、刷脏约束、日志索引维护以及恢复/扩展/还原能力，并提出以 MVD 和日志索引为中心的实现思路。

## Knowledge Outline

- 计存分离与共享存储 — 云数据库, 共享存储, 计存分离, 物理复制, Buffer Pool
- 一致性挑战与约束 — 共享存储, 主从一致性, RO, RW, Redo, LSN, B+Tree, 脏页
- MVD 与日志索引 — MVD, 日志索引, Redo Hash, Page Version, CloudJump
- DB 能力增强与总结 — WAL, Write Elision, Instant Recovery, RO扩展, One-Pass Restore, Backtrack, 恢复, 性能优化

## Repository Paths

- PDF: `collector/4504ec57cff1695d52509f095590eb57.pdf`
- Extracted: `generated/extracted/4504ec57cff1695d52509f095590eb57/full.md`
- Filtered: `generated/filtered/4504ec57cff1695d52509f095590eb57/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
