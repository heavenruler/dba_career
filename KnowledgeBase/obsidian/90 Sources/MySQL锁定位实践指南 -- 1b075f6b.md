---
doc_id: "1b075f6bffd67f550f942f6b81dabf9d"
title: "MySQL锁定位实践指南"
aliases:
  - "MySQL锁定位实践指南"
url: "https://www.modb.pro/db/1939284373065445376"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "锁"
  - "性能调优"
  - "排障"
  - "DBA"
  - "performance_schema"
  - "sys"
generated: true
---

# MySQL锁定位实践指南

> [!info] Provenance
> - doc_id: `1b075f6bffd67f550f942f6b81dabf9d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1939284373065445376)
> - PDF: [open local PDF](../../collector/1b075f6bffd67f550f942f6b81dabf9d.pdf)

## Summary

本文系统整理了 MySQL 中全局读锁、表锁、MDL 锁与行锁的常见场景、典型表现和排查 SQL，重点提供了按版本区分的诊断脚本与生产环境可观测性建议。

## Knowledge Outline

- 概述 — MySQL, 锁, DBA, 排障
- 全局读锁 — MySQL, 全局读锁, performance_schema, 排障
- 表锁 — MySQL, 表锁, performance_schema, 排障
- MDL锁 — MySQL, MDL, 元数据锁, sys, 排障
- 行锁 — MySQL, 行锁, InnoDB, 锁等待, performance_schema, sys, 排障
- 结论 — MySQL, 可观测性, performance_schema, sys, 生产建议

## Repository Paths

- PDF: `collector/1b075f6bffd67f550f942f6b81dabf9d.pdf`
- Extracted: `generated/extracted/1b075f6bffd67f550f942f6b81dabf9d/full.md`
- Filtered: `generated/filtered/1b075f6bffd67f550f942f6b81dabf9d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
