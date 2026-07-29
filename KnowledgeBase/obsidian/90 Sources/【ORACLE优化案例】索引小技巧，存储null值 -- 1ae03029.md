---
doc_id: "1ae03029be522fca5ed9024238fc1dec"
title: "【ORACLE优化案例】索引小技巧，存储null值"
aliases:
  - "【ORACLE优化案例】索引小技巧，存储null值"
url: "https://mp.weixin.qq.com/s/YsnjHVFH0u7WQymvWCTnxA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "索引"
  - "SQL優化"
  - "性能調優"
  - "DBA"
generated: true
---

# 【ORACLE优化案例】索引小技巧，存储null值

> [!info] Provenance
> - doc_id: `1ae03029be522fca5ed9024238fc1dec`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/YsnjHVFH0u7WQymvWCTnxA)
> - PDF: [open local PDF](../../collector/1ae03029be522fca5ed9024238fc1dec.pdf)

## Summary

這篇文章示範 Oracle 在 `IS NULL` 查詢上的索引行為，說明普通索引因為不存儲全 NULL 值而無法避免全表掃描，並用在索引中加入常量列的方式讓 NULL 值可被索引化，從而把邏輯讀從 4461 降到 8。

## Knowledge Outline

- 背景與效果 — Oracle, 索引, 性能調優
- 测试案例 — Oracle, SQL, 执行计划, 索引
- 普通索引结果 — Oracle, 索引, SQL优化
- 关键技巧 — Oracle, 索引, 性能調優, SQL
- 总结 — Oracle, 索引, 查询优化, DBA

## Repository Paths

- PDF: `collector/1ae03029be522fca5ed9024238fc1dec.pdf`
- Extracted: `generated/extracted/1ae03029be522fca5ed9024238fc1dec/full.md`
- Filtered: `generated/filtered/1ae03029be522fca5ed9024238fc1dec/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
