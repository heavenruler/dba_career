---
doc_id: "7bff90a70d31863b2836c1fa9e5c903e"
title: "MySQL性能分析的“秘密武器”，深度剖析SQL问题 - 墨天轮"
aliases:
  - "MySQL性能分析的“秘密武器”，深度剖析SQL问题 - 墨天轮"
url: "https://www.modb.pro/db/1882246676358901760"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL性能分析"
  - "DBA"
  - "profile"
  - "optimizer trace"
  - "執行計畫"
  - "效能調優"
generated: true
---

# MySQL性能分析的“秘密武器”，深度剖析SQL问题 - 墨天轮

> [!info] Provenance
> - doc_id: `7bff90a70d31863b2836c1fa9e5c903e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1882246676358901760)
> - PDF: [open local PDF](../../collector/7bff90a70d31863b2836c1fa9e5c903e.pdf)

## Summary

本文介紹 MySQL 中 profile 與 optimizer trace 兩個 SQL 性能分析工具，包含啟用方式、查看 SQL 執行耗時與資源開銷、查詢 information_schema.profiling、查看 optimizer_trace JSON，以及分析優化器選擇執行計畫的過程。

## Knowledge Outline

- profile 工具用途 — MySQL, profile, SQL性能分析
- profile 支援與配置查詢 — MySQL, profile, configuration
- 開啟 profile — MySQL, profile
- profile 對比 SQL — MySQL, SQL优化, profile
- show profiles 查看耗時 — MySQL, profile, SQL性能分析
- show profile 查看執行狀態 — MySQL, profile, 執行狀態
- profile 資源開銷類型 — MySQL, CPU, IO, profile
- profiling 表彙總耗時 — MySQL, information_schema, profile, SQL性能分析
- profile state 字段含義 — MySQL, profile, reference
- 停止 profile — MySQL, profile
- trace 工具用途 — MySQL, optimizer trace, 執行計畫
- trace 使用注意 — MySQL, optimizer trace, production
- trace 配置與開啟 — MySQL, optimizer trace, configuration
- 查詢 trace 詳情 — MySQL, optimizer trace, information_schema
- optimizer trace 範例片段 — MySQL, optimizer trace, JSON, 執行計畫
- 關閉 trace — MySQL, optimizer trace
- 總結 — MySQL, SQL性能分析, 執行計畫

## Repository Paths

- PDF: `collector/7bff90a70d31863b2836c1fa9e5c903e.pdf`
- Extracted: `generated/extracted/7bff90a70d31863b2836c1fa9e5c903e/full.md`
- Filtered: `generated/filtered/7bff90a70d31863b2836c1fa9e5c903e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
