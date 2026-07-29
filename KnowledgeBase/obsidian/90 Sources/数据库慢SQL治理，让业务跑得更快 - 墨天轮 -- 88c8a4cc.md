---
doc_id: "88c8a4cc3a0652039894b5a92745d5d7"
title: "数据库慢SQL治理，让业务跑得更快 - 墨天轮"
aliases:
  - "数据库慢SQL治理，让业务跑得更快 - 墨天轮"
url: "https://www.modb.pro/db/1881879271417851904"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "SQL优化"
  - "DBA"
  - "性能调优"
  - "慢SQL"
  - "锁等待"
  - "索引"
generated: true
---

# 数据库慢SQL治理，让业务跑得更快 - 墨天轮

> [!info] Provenance
> - doc_id: `88c8a4cc3a0652039894b5a92745d5d7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1881879271417851904)
> - PDF: [open local PDF](../../collector/88c8a4cc3a0652039894b5a92745d5d7.pdf)

## Summary

文章围绕慢SQL治理展开，先说明慢SQL对响应速度和用户体验的影响，再对比常见慢日志分析工具的局限，接着介绍 DBdoctor 的慢SQL治理流程，并用锁等待和索引缺失两个案例说明如何定位与优化问题。

## Knowledge Outline

- 慢SQL背景与工具局限 — SQL优化, 工具局限, DBA, 慢SQL
- 治理步骤 — DBdoctor, 慢SQL治理, SQL分析, 性能调优
- 锁等待案例 — 锁等待, 事务拆分, 慢SQL, DBA
- 索引缺失案例 — 索引优化, 执行计划, SQL优化, 性能调优
- 总结 — 慢SQL治理, 性能优化, 巡检, 业务稳定

## Repository Paths

- PDF: `collector/88c8a4cc3a0652039894b5a92745d5d7.pdf`
- Extracted: `generated/extracted/88c8a4cc3a0652039894b5a92745d5d7/full.md`
- Filtered: `generated/filtered/88c8a4cc3a0652039894b5a92745d5d7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
