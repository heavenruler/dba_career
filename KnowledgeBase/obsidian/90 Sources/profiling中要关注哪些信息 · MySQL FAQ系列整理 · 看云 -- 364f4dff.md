---
doc_id: "364f4dfffda278498ec5ad5699969eeb"
title: "profiling中要关注哪些信息 · MySQL FAQ系列整理 · 看云"
aliases:
  - "profiling中要关注哪些信息 · MySQL FAQ系列整理 · 看云"
url: "https://www.kancloud.cn/thinkphp/mysql-faq/47449"
source_domain: "www.kancloud.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "profiling"
  - "效能調優"
  - "資料庫"
  - "query cache"
  - "鎖"
generated: true
---

# profiling中要关注哪些信息 · MySQL FAQ系列整理 · 看云

> [!info] Provenance
> - doc_id: `364f4dfffda278498ec5ad5699969eeb`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.kancloud.cn/thinkphp/mysql-faq/47449)
> - PDF: [open local PDF](../../collector/364f4dfffda278498ec5ad5699969eeb.pdf)

## Summary

本文說明 MySQL PROFILE 的用途，以及分析時主要關注的 Status 和 Duration，並列出需要特別留意的狀態與對應優化方向，重點包括 System lock、Sending data、Table lock、create sort index 與 query cache 相關狀態。

## Knowledge Outline

- PROFILE 作用 — MySQL, profiling, 效能調優, 資料庫
- 重點狀態 — MySQL, profiling, 效能調優, 資料庫, query cache, 鎖

## Repository Paths

- PDF: `collector/364f4dfffda278498ec5ad5699969eeb.pdf`
- Extracted: `generated/extracted/364f4dfffda278498ec5ad5699969eeb/full.md`
- Filtered: `generated/filtered/364f4dfffda278498ec5ad5699969eeb/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
