---
doc_id: "a5942d69737dabb237ff6442c5b6b6c4"
title: "14TB 之后我们才承认：MongoDB 不是“灵活”，是昂贵"
aliases:
  - "14TB 之后我们才承认：MongoDB 不是“灵活”，是昂贵"
url: "https://mp.weixin.qq.com/s/T9Gc6O5IsH0JuS46AJEMcA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MongoDB"
  - "PostgreSQL"
  - "数据建模"
  - "数据迁移"
  - "双写"
  - "backfill"
  - "数据一致性"
  - "约束"
  - "查询性能"
  - "架构设计"
  - "效能调优"
generated: true
---

# 14TB 之后我们才承认：MongoDB 不是“灵活”，是昂贵

> [!info] Provenance
> - doc_id: `a5942d69737dabb237ff6442c5b6b6c4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/T9Gc6O5IsH0JuS46AJEMcA)
> - PDF: [open local PDF](../../collector/a5942d69737dabb237ff6442c5b6b6c4.pdf)

## Summary

文章用一次 14TB 级别的数据迁移说明：当业务开始频繁查询关联、状态一致性和报表聚合时，MongoDB 的“灵活”会转化为维护成本、数据不确定性和查询复杂度；PostgreSQL 通过约束、外键、索引和原生 join，把原本依赖代码与记忆维持的规则变成数据库层契约。

## Knowledge Outline

- 问题起点 — MongoDB, 查询, 报表, 架构设计, 数据建模
- 问题本质 — MongoDB, 数据一致性, 规则缺失, 报表, 性能, 数据质量
- 迁移与建模 — MongoDB, PostgreSQL, 数据迁移, 数据建模, backfill, 一致性
- 迁移策略 — 数据迁移, 双写, backfill, verifier, 架构设计, PostgreSQL, MongoDB
- 效果与结论 — PostgreSQL, MongoDB, join, 约束, 效能调优, 架构设计, 决策框架

## Repository Paths

- PDF: `collector/a5942d69737dabb237ff6442c5b6b6c4.pdf`
- Extracted: `generated/extracted/a5942d69737dabb237ff6442c5b6b6c4/full.md`
- Filtered: `generated/filtered/a5942d69737dabb237ff6442c5b6b6c4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
