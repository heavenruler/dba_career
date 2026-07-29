---
doc_id: "767d332bd9ae367e226a0c88bdf9cdda"
title: "MySQL 8.0 JSON 功能增强：更高效的存储、索引和查询"
aliases:
  - "MySQL 8.0 JSON 功能增强：更高效的存储、索引和查询"
url: "https://mp.weixin.qq.com/s/Pxi_gjmca5gMs_nynvyq9w"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "JSON"
  - "索引优化"
  - "SQL"
  - "性能优化"
  - "数据库"
  - "DBA"
generated: true
---

# MySQL 8.0 JSON 功能增强：更高效的存储、索引和查询

> [!info] Provenance
> - doc_id: `767d332bd9ae367e226a0c88bdf9cdda`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/Pxi_gjmca5gMs_nynvyq9w)
> - PDF: [open local PDF](../../collector/767d332bd9ae367e226a0c88bdf9cdda.pdf)

## Summary

本文围绕 MySQL 8.0 的 JSON 能力展开，重点包括 JSON 数据类型的存储价值、JSON_EXTRACT/JSON_SET/JSON_REMOVE 等操作、基于生成列的索引优化、JSON_ARRAYAGG/JSON_OBJECTAGG 聚合，以及二进制存储、OPTIMIZE TABLE、ANALYZE TABLE 这类性能相关实践。文末还给出版本差异和测试环境的注意事项。

## Knowledge Outline

- JSON 类型与价值 — MySQL, JSON, 数据库, 性能优化
- 创建 JSON 表 — MySQL, JSON, SQL, 建表
- JSON CRUD 操作 — MySQL, JSON, SQL, JSON_EXTRACT, JSON_SET, JSON_REMOVE
- 生成列与索引 — MySQL, JSON, 索引优化, 生成列, 性能优化
- JSON 聚合函数 — MySQL, JSON, 聚合函数, SQL
- 存储与维护优化 — MySQL, JSON, 存储优化, OPTIMIZE TABLE, ANALYZE TABLE, 性能优化
- 结论与注意事项 — MySQL, JSON, 版本差异, 测试环境, 数据库, 注意事项

## Repository Paths

- PDF: `collector/767d332bd9ae367e226a0c88bdf9cdda.pdf`
- Extracted: `generated/extracted/767d332bd9ae367e226a0c88bdf9cdda/full.md`
- Filtered: `generated/filtered/767d332bd9ae367e226a0c88bdf9cdda/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
