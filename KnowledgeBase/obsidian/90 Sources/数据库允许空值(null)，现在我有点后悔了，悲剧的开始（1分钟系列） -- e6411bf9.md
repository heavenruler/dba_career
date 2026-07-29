---
doc_id: "e6411bf956d1fcd106513aaaaa682ec0"
title: "数据库允许空值(null)，现在我有点后悔了，悲剧的开始（1分钟系列）"
aliases:
  - "数据库允许空值(null)，现在我有点后悔了，悲剧的开始（1分钟系列）"
url: "https://mp.weixin.qq.com/s/E5Ubqml4TfSsWNVDrYsVCg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "NULL"
  - "索引"
  - "EXPLAIN"
  - "UNION"
  - "数据库"
generated: true
---

# 数据库允许空值(null)，现在我有点后悔了，悲剧的开始（1分钟系列）

> [!info] Provenance
> - doc_id: `e6411bf956d1fcd106513aaaaa682ec0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/E5Ubqml4TfSsWNVDrYsVCg)
> - PDF: [open local PDF](../../collector/e6411bf956d1fcd106513aaaaa682ec0.pdf)

## Summary

本文用一个 MySQL 小实验说明：允许 NULL 的字段在 `!=` 查询中不会返回空值记录；`or` 条件可能导致全表扫描，可改写为 `union` 以尽量命中索引；并建议通过 `explain` 检查执行计划。

## Knowledge Outline

- 实验过程 — MySQL, NULL, 索引, SQL
- 空值与不等于 — MySQL, NULL, 索引, EXPLAIN, SQL
- or 与 union — MySQL, SQL优化, EXPLAIN, UNION, NULL, 索引

## Repository Paths

- PDF: `collector/e6411bf956d1fcd106513aaaaa682ec0.pdf`
- Extracted: `generated/extracted/e6411bf956d1fcd106513aaaaa682ec0/full.md`
- Filtered: `generated/filtered/e6411bf956d1fcd106513aaaaa682ec0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
