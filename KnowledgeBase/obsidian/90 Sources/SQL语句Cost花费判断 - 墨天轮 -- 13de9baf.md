---
doc_id: "13de9bafc7f57700887118dc971f3b70"
title: "SQL语句Cost花费判断 - 墨天轮"
aliases:
  - "SQL语句Cost花费判断 - 墨天轮"
url: "https://www.modb.pro/db/624887"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "Oracle"
  - "SQL优化"
  - "执行计划"
  - "Cost"
  - "索引"
  - "全表扫描"
  - "统计信息"
generated: true
---

# SQL语句Cost花费判断 - 墨天轮

> [!info] Provenance
> - doc_id: `13de9bafc7f57700887118dc971f3b70`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/624887)
> - PDF: [open local PDF](../../collector/13de9bafc7f57700887118dc971f3b70.pdf)

## Summary

本文讨论 Oracle SQL 执行计划中 Cost 对索引扫描与全表扫描选择的影响，包含 autotrace 基础命令、示例 SQL、索引定义、不同 Hint 下的执行计划与统计信息，以及根据列值分布判断全表扫描与索引扫描成本差异的思路。

## Knowledge Outline

- 结论 — Oracle, SQL优化, Cost, 索引, 全表扫描
- Autotrace 基础命令 — Oracle, autotrace, 执行计划
- SQL 语句信息 — Oracle, SQL, 统计信息
- 索引定义 — Oracle, 索引, SQL优化
- 四列索引 INX_CX3 执行计划 — Oracle, 执行计划, Cost, 索引
- 强制索引 Hint 说明与 INX SQL — Oracle, Hint, 索引, SQL
- INX 执行计划 — Oracle, 执行计划, Cost, 索引
- INX_CX SQL 與執行計畫 — Oracle, 执行计划, Cost, 索引
- 強制全表掃描 — Oracle, 执行计划, Cost, 全表扫描, Hint
- Cost 排序比較 — Oracle, Cost, 索引, 全表扫描, SQL优化
- 列分布與判斷思路 — Oracle, SQL优化, 基数, 选择性, 索引, 全表扫描

## Repository Paths

- PDF: `collector/13de9bafc7f57700887118dc971f3b70.pdf`
- Extracted: `generated/extracted/13de9bafc7f57700887118dc971f3b70/full.md`
- Filtered: `generated/filtered/13de9bafc7f57700887118dc971f3b70/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
