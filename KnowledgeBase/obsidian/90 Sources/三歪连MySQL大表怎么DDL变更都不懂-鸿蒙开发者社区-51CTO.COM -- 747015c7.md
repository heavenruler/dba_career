---
doc_id: "747015c71672d076a19bf363ff9e7bc5"
title: "三歪连MySQL大表怎么DDL变更都不懂-鸿蒙开发者社区-51CTO.COM"
aliases:
  - "三歪连MySQL大表怎么DDL变更都不懂-鸿蒙开发者社区-51CTO.COM"
url: "https://ost.51cto.com/posts/11578"
source_domain: "ost.51cto.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DDL"
  - "Online DDL"
  - "Metadata Lock"
  - "大表变更"
  - "主从延迟"
  - "数据仓库"
generated: true
---

# 三歪连MySQL大表怎么DDL变更都不懂-鸿蒙开发者社区-51CTO.COM

> [!info] Provenance
> - doc_id: `747015c71672d076a19bf363ff9e7bc5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://ost.51cto.com/posts/11578)
> - PDF: [open local PDF](../../collector/747015c71672d076a19bf363ff9e7bc5.pdf)

## Summary

文章说明 MySQL DDL 的基本类型、元数据与 Metadata Lock 的影响，比较 COPY / INPLACE / INSTANT 三种执行方式，进一步讨论大表变更在读写分离与数仓同步场景下的风险，以及 pt-osc 和 MySQL 8.0 INSTANT 的适用性与监控方式。

## Knowledge Outline

- DDL与前言 — MySQL, DDL, 概念
- 元数据与锁 — MySQL, Metadata Lock, 概念
- DDL执行方式 — MySQL, DDL, Online DDL
- COPY / INPLACE / INSTANT — MySQL, COPY, INPLACE, INSTANT
- ONLINE DDL — MySQL, Online DDL, 概念
- 大表DDL风险 — MySQL, 大表变更, 主从延迟, 数据仓库
- ONLINE DDL与pt-osc — MySQL, pt-osc, gh-ost, 主从延迟
- pt-osc流程 — MySQL, pt-osc, 监控, 主从延迟
- MySQL 8.0 与监控 — MySQL, INSTANT, 监控, performance_schema
- 总结 — MySQL, DDL, 在线变更, 总结

## Repository Paths

- PDF: `collector/747015c71672d076a19bf363ff9e7bc5.pdf`
- Extracted: `generated/extracted/747015c71672d076a19bf363ff9e7bc5/full.md`
- Filtered: `generated/filtered/747015c71672d076a19bf363ff9e7bc5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
