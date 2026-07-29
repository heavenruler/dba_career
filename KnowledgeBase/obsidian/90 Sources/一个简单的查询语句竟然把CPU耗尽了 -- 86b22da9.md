---
doc_id: "86b22da9cb093413535d4c60d6d7ccf3"
title: "一个简单的查询语句竟然把CPU耗尽了"
aliases:
  - "一个简单的查询语句竟然把CPU耗尽了"
url: "https://www.modb.pro/db/2020786428029001728"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "SQL优化"
  - "性能调优"
  - "DBA"
  - "执行计划"
  - "索引优化"
  - "事故复盘"
generated: true
---

# 一个简单的查询语句竟然把CPU耗尽了

> [!info] Provenance
> - doc_id: `86b22da9cb093413535d4c60d6d7ccf3`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2020786428029001728)
> - PDF: [open local PDF](../../collector/86b22da9cb093413535d4c60d6d7ccf3.pdf)

## Summary

一篇 Oracle SQL 优化案例，围绕一条多表关联查询导致 CPU 飙高展开。文章按 TopSQL 识别、执行计划分析、问题诊断、复合索引优化、窗口排序优化和效果验证的顺序，给出了具体的 ASH 查询、执行计划特征和索引设计思路。

## Knowledge Outline

- 问题背景 — Oracle, SQL优化, CPU, 性能调优
- 确认TopSQL — Oracle, ASH, TopSQL, CPU, SQL
- 问题诊断 — 执行计划, 全表扫描, 排序, HASH JOIN, CPU
- 主体优化 — 索引优化, 复合索引, 执行计划, Oracle, DBA
- 开窗排序优化 — 窗口排序, 索引优化, Oracle, 执行计划, 性能调优
- 其他优化与效果 — 索引优化, 性能对比, CPU, I/O, Oracle
- 总结 — 事故复盘, SQL优化, Oracle, DBA, 性能调优

## Repository Paths

- PDF: `collector/86b22da9cb093413535d4c60d6d7ccf3.pdf`
- Extracted: `generated/extracted/86b22da9cb093413535d4c60d6d7ccf3/full.md`
- Filtered: `generated/filtered/86b22da9cb093413535d4c60d6d7ccf3/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
