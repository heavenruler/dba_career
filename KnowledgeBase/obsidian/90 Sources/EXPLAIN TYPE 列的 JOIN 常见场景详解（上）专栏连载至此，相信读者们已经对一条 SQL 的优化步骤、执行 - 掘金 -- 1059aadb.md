---
doc_id: "1059aadb9ba78b94ac181ac7b2f82d3d"
title: "EXPLAIN TYPE 列的 JOIN 常见场景详解（上）专栏连载至此，相信读者们已经对一条 SQL 的优化步骤、执行 - 掘金"
aliases:
  - "EXPLAIN TYPE 列的 JOIN 常见场景详解（上）专栏连载至此，相信读者们已经对一条 SQL 的优化步骤、执行 - 掘金"
url: "https://juejin.cn/post/7456635153332731919"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "EXPLAIN"
  - "执行计划"
  - "索引优化"
  - "数据库"
  - "SQL优化"
generated: true
---

# EXPLAIN TYPE 列的 JOIN 常见场景详解（上）专栏连载至此，相信读者们已经对一条 SQL 的优化步骤、执行 - 掘金

> [!info] Provenance
> - doc_id: `1059aadb9ba78b94ac181ac7b2f82d3d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7456635153332731919)
> - PDF: [open local PDF](../../collector/1059aadb9ba78b94ac181ac7b2f82d3d.pdf)

## Summary

本文围绕 MySQL EXPLAIN 的 type 列，按 const、eq_ref、ref、range、index 五种常见场景解释其含义，并用具体 SQL 与执行计划对比优化效果。

## Knowledge Outline

- 引言 — MySQL, EXPLAIN, 执行计划, JOIN, 数据库
- const — MySQL, EXPLAIN, const, 主键, 数据库
- eq_ref — MySQL, EXPLAIN, eq_ref, JOIN, 主键, 数据库
- ref — MySQL, EXPLAIN, ref, JOIN, 索引, 数据库
- range — MySQL, EXPLAIN, range, 执行成本, 数据库
- index — MySQL, EXPLAIN, index, 覆盖索引, LIMIT, 数据库

## Repository Paths

- PDF: `collector/1059aadb9ba78b94ac181ac7b2f82d3d.pdf`
- Extracted: `generated/extracted/1059aadb9ba78b94ac181ac7b2f82d3d/full.md`
- Filtered: `generated/filtered/1059aadb9ba78b94ac181ac7b2f82d3d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
