---
doc_id: "15fc67fda4eb410aaca2c5e353ebfe55"
title: "面试官：MySQL 空值字段应该保存 NULL 还是默认值？"
aliases:
  - "面试官：MySQL 空值字段应该保存 NULL 还是默认值？"
url: "https://mp.weixin.qq.com/s/nNwSGsoRzIbBX1RHgWQMWg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "NULL"
  - "数据库设计"
  - "面试"
  - "存储结构"
  - "索引"
generated: true
---

# 面试官：MySQL 空值字段应该保存 NULL 还是默认值？

> [!info] Provenance
> - doc_id: `15fc67fda4eb410aaca2c5e353ebfe55`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/nNwSGsoRzIbBX1RHgWQMWg)
> - PDF: [open local PDF](../../collector/15fc67fda4eb410aaca2c5e353ebfe55.pdf)

## Summary

这篇文章先说明 InnoDB 行记录里与 NULL、变长字段相关的存储结构，再从存储、索引、统计、语义和系统一致性几个角度比较字段应定义为 NULL 还是 NOT NULL / 默认值。

## Knowledge Outline

- 行数据存储 — MySQL, InnoDB, 存储结构, NULL
- NULL 处理 — MySQL, NULL, 数据库设计, 索引, 面试

## Repository Paths

- PDF: `collector/15fc67fda4eb410aaca2c5e353ebfe55.pdf`
- Extracted: `generated/extracted/15fc67fda4eb410aaca2c5e353ebfe55/full.md`
- Filtered: `generated/filtered/15fc67fda4eb410aaca2c5e353ebfe55/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
