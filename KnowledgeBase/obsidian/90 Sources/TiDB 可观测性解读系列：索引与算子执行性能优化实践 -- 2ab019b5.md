---
doc_id: "2ab019b57c025f2f4972986577ee1f5c"
title: "TiDB 可观测性解读系列：索引与算子执行性能优化实践"
aliases:
  - "TiDB 可观测性解读系列：索引与算子执行性能优化实践"
url: "https://mp.weixin.qq.com/s/udQNyROzQsPOLYxv3Ah4HA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "可观测性"
  - "索引优化"
  - "SQL执行诊断"
  - "DBA"
  - "性能调优"
generated: true
---

# TiDB 可观测性解读系列：索引与算子执行性能优化实践

> [!info] Provenance
> - doc_id: `2ab019b57c025f2f4972986577ee1f5c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/udQNyROzQsPOLYxv3Ah4HA)
> - PDF: [open local PDF](../../collector/2ab019b57c025f2f4972986577ee1f5c.pdf)

## Summary

本文主要讲 TiDB 的索引观测、无用索引/低效索引识别、不可见索引验证流程，以及通过算子 execution info、慢日志和 profiling 诊断 SQL 性能问题的思路与案例。

## Knowledge Outline

- 索引问题概述 — TiDB, 索引优化, DBA, 性能调优
- 索引优化支持 — TiDB, 索引优化, TIDB_INDEX_USAGE, DBA, 可观测性
- 无用索引与不可见索引 — TiDB, 索引优化, 不可见索引, DBA, 最佳实践
- 算子执行诊断 — TiDB, 执行计划, explain analyze, 慢查询, profiling, 性能诊断
- 未来展望 — TiDB, 可观测性, TiFlash, 执行信息, 性能诊断

## Repository Paths

- PDF: `collector/2ab019b57c025f2f4972986577ee1f5c.pdf`
- Extracted: `generated/extracted/2ab019b57c025f2f4972986577ee1f5c/full.md`
- Filtered: `generated/filtered/2ab019b57c025f2f4972986577ee1f5c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
