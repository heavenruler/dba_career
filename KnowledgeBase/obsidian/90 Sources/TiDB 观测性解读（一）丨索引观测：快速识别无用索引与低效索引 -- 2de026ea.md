---
doc_id: "2de026eacc1b893ed1226f2bd873037c"
title: "TiDB 观测性解读（一）丨索引观测：快速识别无用索引与低效索引"
aliases:
  - "TiDB 观测性解读（一）丨索引观测：快速识别无用索引与低效索引"
url: "https://mp.weixin.qq.com/s/hoALPGuaV7K-GAn2U-H47w"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "可观测性"
  - "索引优化"
  - "DBA"
  - "SQL"
  - "数据库性能"
  - "不可见索引"
  - "统计信息"
generated: true
---

# TiDB 观测性解读（一）丨索引观测：快速识别无用索引与低效索引

> [!info] Provenance
> - doc_id: `2de026eacc1b893ed1226f2bd873037c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/hoALPGuaV7K-GAn2U-H47w)
> - PDF: [open local PDF](../../collector/2de026eacc1b893ed1226f2bd873037c.pdf)

## Summary

本文围绕 TiDB 索引观测展开，重点说明如何通过 `TIDB_INDEX_USAGE`、`schema_unused_indexes` 和不可见索引识别无用索引与低效索引，并用逐步验证的方式降低删除索引的风险。

## Knowledge Outline

- 背景与索引价值 — TiDB, 可观测性, 索引, 数据库性能优化, DBA
- TiDB 索引观测 — TiDB, TIDB_INDEX_USAGE, schema_unused_indexes, 不可见索引, 观测性
- 删除未使用索引 — TiDB, 无用索引, 不可见索引, SQL, DBA, 运维
- 低效索引优化 — TiDB, 低效索引, SQL, 执行计划, 统计信息, 性能优化, DBA

## Repository Paths

- PDF: `collector/2de026eacc1b893ed1226f2bd873037c.pdf`
- Extracted: `generated/extracted/2de026eacc1b893ed1226f2bd873037c/full.md`
- Filtered: `generated/filtered/2de026eacc1b893ed1226f2bd873037c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
