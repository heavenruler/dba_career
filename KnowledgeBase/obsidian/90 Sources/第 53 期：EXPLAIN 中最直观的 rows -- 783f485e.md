---
doc_id: "783f485ee2a4566af9ddf900f7f8bb56"
title: "第 53 期：EXPLAIN 中最直观的 rows"
aliases:
  - "第 53 期：EXPLAIN 中最直观的 rows"
url: "https://mp.weixin.qq.com/s/AEH9xzn1Um6FI-YOykuWYQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "EXPLAIN"
  - "执行计划"
  - "索引调优"
  - "SQL优化"
generated: true
---

# 第 53 期：EXPLAIN 中最直观的 rows

> [!info] Provenance
> - doc_id: `783f485ee2a4566af9ddf900f7f8bb56`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/AEH9xzn1Um6FI-YOykuWYQ)
> - PDF: [open local PDF](../../collector/783f485ee2a4566af9ddf900f7f8bb56.pdf)

## Summary

這篇文章說明 EXPLAIN 的 rows 只能作為參考，不能單獨用來判斷 SQL 是否高效。不同索引選擇、範圍掃描、以及 JOIN 順序場景下，rows 可能和實際效能不一致，必須結合成本模型、統計資訊與資料分布一起看。

## Knowledge Outline

- rows 含义 — MySQL, EXPLAIN, 执行计划, SQL优化
- rows 值小，性能高 — MySQL, EXPLAIN, 索引调优, SQL优化
- rows 值小，性能不一定 — MySQL, EXPLAIN, 执行计划, SQL优化, 性能分析
- 不适合看 rows 值 — MySQL, EXPLAIN, JOIN, 执行计划, 统计信息
- 总结 — MySQL, EXPLAIN, 执行计划, SQL优化

## Repository Paths

- PDF: `collector/783f485ee2a4566af9ddf900f7f8bb56.pdf`
- Extracted: `generated/extracted/783f485ee2a4566af9ddf900f7f8bb56/full.md`
- Filtered: `generated/filtered/783f485ee2a4566af9ddf900f7f8bb56/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
