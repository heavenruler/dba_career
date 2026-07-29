---
doc_id: "d0d1305ad59b2d3b0e3f6fbf26f823f7"
title: "性能比拼: MySQL vs PostgreSQL"
aliases:
  - "性能比拼: MySQL vs PostgreSQL"
url: "https://mp.weixin.qq.com/s/EwiCeKvXM9kJJB1UQN2_rw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "PostgreSQL"
  - "資料庫效能"
  - "Benchmark"
  - "延遲"
  - "吞吐量"
  - "CPU"
  - "磁碟IO"
  - "連線池"
  - "Go"
generated: true
---

# 性能比拼: MySQL vs PostgreSQL

> [!info] Provenance
> - doc_id: `d0d1305ad59b2d3b0e3f6fbf26f823f7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/EwiCeKvXM9kJJB1UQN2_rw)
> - PDF: [open local PDF](../../collector/d0d1305ad59b2d3b0e3f6fbf26f823f7.pdf)

## Summary

這是一篇翻譯整理自 Anton Putra 的 MySQL vs PostgreSQL 效能評測，核心內容是以寫入與讀取兩種工作負載比較兩者的延遲、吞吐量、CPU、記憶體、磁碟操作與連線池行為；文中結論是 PostgreSQL 在這組測試下的寫入與讀取表現都優於 MySQL。

## Knowledge Outline

- 評測範圍 — MySQL, PostgreSQL, Benchmark, 延遲, 吞吐量, Saturation
- 測試設計 — 資料庫, SQL, 分析系統, JOIN, 測試設計
- 程式與驅動 — Go, database/sql, pgx, 效能測試, 資料庫驅動
- 寫入測試結果 — MySQL, PostgreSQL, 寫入性能, QPS, CPU, 記憶體, 磁碟IO, 連線池
- 寫入測試分析 — 寫入性能, 資料庫大小, 磁碟效率, PostgreSQL, MySQL
- 讀取測試結果 — MySQL, PostgreSQL, 讀取性能, JOIN, QPS, CPU, 延遲, 效能分析

## Repository Paths

- PDF: `collector/d0d1305ad59b2d3b0e3f6fbf26f823f7.pdf`
- Extracted: `generated/extracted/d0d1305ad59b2d3b0e3f6fbf26f823f7/full.md`
- Filtered: `generated/filtered/d0d1305ad59b2d3b0e3f6fbf26f823f7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
