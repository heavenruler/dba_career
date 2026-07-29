---
doc_id: "22cfb4facea082f8b8debd6605e8e257"
title: "从单一到多活，麦当劳中国的数据库架构迁移实战"
aliases:
  - "从单一到多活，麦当劳中国的数据库架构迁移实战"
url: "https://mp.weixin.qq.com/s/AdNNN39eqWW_BGtsw28BUA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库架构"
  - "多活"
  - "高可用"
  - "容灾"
  - "BCP"
  - "迁移实战"
  - "RPO/RTO"
  - "跨团队协作"
generated: true
---

# 从单一到多活，麦当劳中国的数据库架构迁移实战

> [!info] Provenance
> - doc_id: `22cfb4facea082f8b8debd6605e8e257`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/AdNNN39eqWW_BGtsw28BUA)
> - PDF: [open local PDF](../../collector/22cfb4facea082f8b8debd6605e8e257.pdf)

## Summary

本文讲麦当劳中国将数据库从单中心迁移到 TiDB 多活/三中心架构的实战，重点包括业务连续性目标、架构方案对比、RPO/RTO 与网络条件的权衡、在线扩缩容迁移流程、故障演练与回滚机制，以及跨团队协作经验和后续多地多活规划。

## Knowledge Outline

- 背景与价值 — 数据库架构, 多活, 餐饮行业数字化, BCP, 高可用
- 单一架构的局限 — 单一数据库, 高可用, 容灾, BCP, TiDB, 3AZ
- 架构选型 — 架构选型, CAP, Raft, TiDB, RPO, RTO, 高可用, 容灾
- 迁移实施 — 迁移实施, 在线扩缩容, 故障演练, 回滚, 跨团队协作, TiDB, BCP
- 后续规划与建议 — 多活演进, ToB, 架构规划, 跨部门协作, RPO=0

## Repository Paths

- PDF: `collector/22cfb4facea082f8b8debd6605e8e257.pdf`
- Extracted: `generated/extracted/22cfb4facea082f8b8debd6605e8e257/full.md`
- Filtered: `generated/filtered/22cfb4facea082f8b8debd6605e8e257/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
