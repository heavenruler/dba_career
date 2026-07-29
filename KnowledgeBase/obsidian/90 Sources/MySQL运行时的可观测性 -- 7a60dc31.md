---
doc_id: "7a60dc31f53e71ff0b92421183087387"
title: "MySQL运行时的可观测性"
aliases:
  - "MySQL运行时的可观测性"
url: "https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653940337&idx=1&sn=c6d88bea92069d4b9347939a6c8c2615&chksm=bd3b701b8a4cf90d066b9a62036d37a04f13379cf4042c64a6909e11c7c2fa0d3a2b5bad5434&scene=178&cur_album_id=1337959503719137280#rd"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "可观测性"
  - "performance_schema"
  - "sys schema"
  - "DBA"
  - "SQL调优"
  - "运行时监控"
  - "I/O"
  - "内存"
  - "执行进度"
generated: true
---

# MySQL运行时的可观测性

> [!info] Provenance
> - doc_id: `7a60dc31f53e71ff0b92421183087387`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653940337&idx=1&sn=c6d88bea92069d4b9347939a6c8c2615&chksm=bd3b701b8a4cf90d066b9a62036d37a04f13379cf4042c64a6909e11c7c2fa0d3a2b5bad5434&scene=178&cur_album_id=1337959503719137280#rd)
> - PDF: [open local PDF](../../collector/7a60dc31f53e71ff0b92421183087387.pdf)

## Summary

文章讲解如何借助 performance_schema 和 sys schema 观测 MySQL/GreatSQL 运行时状态，包括连接线程映射、SQL 执行时的内存消耗、会话状态指标、I/O 延迟，以及通过 events_stages_% 表查看 SQL 执行进度。

## Knowledge Outline

- 前言 — MySQL, 可观测性, performance_schema, sys schema, DBA
- 安装测试库 — MySQL, GreatSQL, employees, MGR, 测试库, DBA
- 连接与内存 — MySQL, 内存, SQL执行, performance_schema, sys schema, 可观测性
- 状态与I/O — MySQL, 状态指标, slow query log, I/O, latency, SQL执行, performance_schema
- 运行进度 — MySQL, performance_schema, events_stages, 执行进度, 可观测性, DBA

## Repository Paths

- PDF: `collector/7a60dc31f53e71ff0b92421183087387.pdf`
- Extracted: `generated/extracted/7a60dc31f53e71ff0b92421183087387/full.md`
- Filtered: `generated/filtered/7a60dc31f53e71ff0b92421183087387/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
