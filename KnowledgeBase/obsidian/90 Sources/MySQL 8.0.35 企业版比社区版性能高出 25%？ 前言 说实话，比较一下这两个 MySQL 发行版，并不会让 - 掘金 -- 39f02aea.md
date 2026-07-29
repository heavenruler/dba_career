---
doc_id: "39f02aea862b12f6283f50d2a9ac4e1c"
title: "MySQL 8.0.35 企业版比社区版性能高出 25%？# 前言 说实话，比较一下这两个 MySQL 发行版，并不会让 - 掘金"
aliases:
  - "MySQL 8.0.35 企业版比社区版性能高出 25%？# 前言 说实话，比较一下这两个 MySQL 发行版，并不会让 - 掘金"
url: "https://juejin.cn/post/7339892484334059557"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "性能测试"
  - "sysbench"
  - "TPC-C"
  - "企业版"
  - "社区版"
  - "基准测试"
generated: true
---

# MySQL 8.0.35 企业版比社区版性能高出 25%？# 前言 说实话，比较一下这两个 MySQL 发行版，并不会让 - 掘金

> [!info] Provenance
> - doc_id: `39f02aea862b12f6283f50d2a9ac4e1c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7339892484334059557)
> - PDF: [open local PDF](../../collector/39f02aea862b12f6283f50d2a9ac4e1c.pdf)

## Summary

本文围绕 MySQL 企业版与社区版的性能差异展开，先说明作者为何对“企业版提升 25%”的结论保持怀疑，再给出测试环境、配置差异、sysbench 与 TPC-c 的测试方法和结果。结论是：在普通默认场景下，两者性能几乎没有差异，企业版若有优势也主要来自额外组件如线程池。

## Knowledge Outline

- 前言与问题缘起 — MySQL, 企业版, 社区版, 性能对比, 基准测试
- 测试环境与配置 — MySQL, 性能测试, sysbench, 配置, EC2
- 配置差异 — MySQL, 配置差异, 企业版, 社区版, license
- 测试方法与结果 — MySQL, sysbench, TPC-C, 性能测试, 读写测试
- 结论 — MySQL, 企业版, 社区版, 结论, 性能

## Repository Paths

- PDF: `collector/39f02aea862b12f6283f50d2a9ac4e1c.pdf`
- Extracted: `generated/extracted/39f02aea862b12f6283f50d2a9ac4e1c/full.md`
- Filtered: `generated/filtered/39f02aea862b12f6283f50d2a9ac4e1c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
