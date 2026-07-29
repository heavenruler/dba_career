---
doc_id: "2b7f33be7031ea105eaa09a6193da552"
title: "阿里一面：MySQL 一张表最多支持多少个索引？16个？64个？还是无限制？"
aliases:
  - "阿里一面：MySQL 一张表最多支持多少个索引？16个？64个？还是无限制？"
url: "https://mp.weixin.qq.com/s/woAOfER5FC3Pgf_xHF8o7A"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "索引"
  - "InnoDB"
  - "MyISAM"
  - "效能调优"
  - "面试"
generated: true
---

# 阿里一面：MySQL 一张表最多支持多少个索引？16个？64个？还是无限制？

> [!info] Provenance
> - doc_id: `2b7f33be7031ea105eaa09a6193da552`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/woAOfER5FC3Pgf_xHF8o7A)
> - PDF: [open local PDF](../../collector/2b7f33be7031ea105eaa09a6193da552.pdf)

## Summary

本文的核心信息是：MySQL 并不是“无限制”支持索引。InnoDB 支持最多 64 个二级索引，若有主键则总索引数为 65；MyISAM 最多 64 个索引；单个复合索引最多包含 16 列。文章还强调，虽然理论上可建很多索引，实务上通常建议单表控制在 5-6 个左右，以避免写入开销、存储占用和优化器选错索引。

## Knowledge Outline

- InnoDB 索引限制 — MySQL, InnoDB, 索引, 数据库
- MyISAM 索引限制 — MySQL, MyISAM, 索引, 数据库
- 版本差异与误区 — MySQL, 版本差异, 索引, 误区澄清
- 实际应用建议 — MySQL, 索引, 效能调优, 数据库设计, 最佳实践

## Repository Paths

- PDF: `collector/2b7f33be7031ea105eaa09a6193da552.pdf`
- Extracted: `generated/extracted/2b7f33be7031ea105eaa09a6193da552/full.md`
- Filtered: `generated/filtered/2b7f33be7031ea105eaa09a6193da552/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
