---
doc_id: "f23997bda0e84488df8ab87e753bb69c"
title: "MySQL 8.0参数默认值变更，恐致性能下降3倍多"
aliases:
  - "MySQL 8.0参数默认值变更，恐致性能下降3倍多"
url: "https://mp.weixin.qq.com/s/OrflexV6469yVqP5BNlS-g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "性能调优"
  - "InnoDB"
  - "DDL"
  - "数据库"
  - "SRE"
generated: true
---

# MySQL 8.0参数默认值变更，恐致性能下降3倍多

> [!info] Provenance
> - doc_id: `f23997bda0e84488df8ab87e753bb69c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/OrflexV6469yVqP5BNlS-g)
> - PDF: [open local PDF](../../collector/f23997bda0e84488df8ab87e753bb69c.pdf)

## Summary

这篇文章聚焦 MySQL 8.0 中 `innodb_doublewrite_pages` 默认值变更导致的性能回归，重点说明表重建类 DDL、双写机制、受影响场景，以及临时与长期修复建议。

## Knowledge Outline

- 性能回归问题 — MySQL, 性能调优, InnoDB, DDL, 参数默认值

## Repository Paths

- PDF: `collector/f23997bda0e84488df8ab87e753bb69c.pdf`
- Extracted: `generated/extracted/f23997bda0e84488df8ab87e753bb69c/full.md`
- Filtered: `generated/filtered/f23997bda0e84488df8ab87e753bb69c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
