---
doc_id: "87414491af876ac2bed247c28af3dc32"
title: "一条 SQL 是怎么导致 MySQL TempTable 引擎崩溃的？"
aliases:
  - "一条 SQL 是怎么导致 MySQL TempTable 引擎崩溃的？"
url: "https://mp.weixin.qq.com/s/d6QkC6uNTm4rKPVKhbAoLA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "TempTable"
  - "SQL优化"
  - "源码分析"
  - "事故覆盘"
generated: true
---

# 一条 SQL 是怎么导致 MySQL TempTable 引擎崩溃的？

> [!info] Provenance
> - doc_id: `87414491af876ac2bed247c28af3dc32`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/d6QkC6uNTm4rKPVKhbAoLA)
> - PDF: [open local PDF](../../collector/87414491af876ac2bed247c28af3dc32.pdf)

## Summary

分析一条复杂 SQL 如何在 MySQL 8.0.28 触发 TempTable 引擎崩溃：根因是覆盖索引扫描被错误应用到内部临时表，导致 m_opened_table 为空并在 index_init() 中解引用崩溃，8.0.30 通过在优化阶段排除 TempTable 修复。

## Knowledge Outline

- 问题背景 — MySQL, TempTable, 事故覆盘, 崩溃
- SQL 复现 — SQL, MySQL, TempTable, 复现
- 崩溃堆栈与定位 — MySQL, 崩溃堆栈, 源码分析, TempTable
- 进一步分析 — MySQL, 源码分析, 执行计划, TempTable
- 问题修复 — MySQL, 修复, 执行计划, TempTable
- 表结构 — MySQL, SQL, DDL, 复现

## Repository Paths

- PDF: `collector/87414491af876ac2bed247c28af3dc32.pdf`
- Extracted: `generated/extracted/87414491af876ac2bed247c28af3dc32/full.md`
- Filtered: `generated/filtered/87414491af876ac2bed247c28af3dc32/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
