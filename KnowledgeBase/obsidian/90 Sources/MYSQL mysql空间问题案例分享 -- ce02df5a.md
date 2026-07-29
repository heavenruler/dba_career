---
doc_id: "ce02df5a739df7820a4d3c2094ac4340"
title: "[MYSQL] mysql空间问题案例分享"
aliases:
  - "[MYSQL] mysql空间问题案例分享"
url: "https://mp.weixin.qq.com/s/rVR1pGz0aOs_vOy3OS0J_w"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "空间优化"
  - "索引治理"
  - "主键"
  - "数据存储"
  - "性能与容量"
generated: true
---

# [MYSQL] mysql空间问题案例分享

> [!info] Provenance
> - doc_id: `ce02df5a739df7820a4d3c2094ac4340`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/rVR1pGz0aOs_vOy3OS0J_w)
> - PDF: [open local PDF](../../collector/ce02df5a739df7820a4d3c2094ac4340.pdf)

## Summary

这篇文章用一个 MySQL 空间回收案例说明：先从 information_schema.tables 观察 data_length、index_length、data_free，再用 sys.schema_unused_indexes 找出长期未使用的索引，并结合 mysql.innodb_index_stats 估算这些索引占用的空间；最后讨论添加主键后 rowid 消失可能带来的空间变化，以及用 ibd2sql_web 验证统计信息。

## Knowledge Outline

- 背景与思路 — MySQL, 空间优化, 索引治理
- 查询数据量 — MySQL, DBA, 容量分析, SQL
- 未使用的索引 — MySQL, 索引治理, DBA, SQL
- 未使用索引大小 — MySQL, 索引统计, 空间分析, SQL
- 未使用索引明细与汇总 — MySQL, 索引治理, 空间分析, SQL
- 主键与空间 — MySQL, 主键, 空间优化, DBA
- 工具验证 — MySQL, 工具验证, 索引统计, 参考

## Repository Paths

- PDF: `collector/ce02df5a739df7820a4d3c2094ac4340.pdf`
- Extracted: `generated/extracted/ce02df5a739df7820a4d3c2094ac4340/full.md`
- Filtered: `generated/filtered/ce02df5a739df7820a4d3c2094ac4340/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
