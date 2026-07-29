---
doc_id: "8d31234716fdeda76cb7fffa732202f6"
title: "为什么DBA要求MySQL表索引不能超过5个"
aliases:
  - "为什么DBA要求MySQL表索引不能超过5个"
url: "https://mp.weixin.qq.com/s/GngfPmMQcTrdE3-MO8tRyA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "索引"
  - "性能调优"
  - "DBA"
generated: true
---

# 为什么DBA要求MySQL表索引不能超过5个

> [!info] Provenance
> - doc_id: `8d31234716fdeda76cb7fffa732202f6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/GngfPmMQcTrdE3-MO8tRyA)
> - PDF: [open local PDF](../../collector/8d31234716fdeda76cb7fffa732202f6.pdf)

## Summary

这篇文章用 MySQL InnoDB 为例，说明索引过多会带来写入维护成本、优化器选择成本、磁盘和内存开销，以及索引选择失误等问题，并给出 DBA 在新增索引时会追问的业务价值、替代方案和代价评估。

## Knowledge Outline

- 索引超标 — MySQL, InnoDB, 索引, 优化器, 性能调优
- 代价与底线 — MySQL, 索引, DBA, 写入性能, 主从延迟
- 帮规 — 数据库, 生产规范, SQL, DDL, 运维

## Repository Paths

- PDF: `collector/8d31234716fdeda76cb7fffa732202f6.pdf`
- Extracted: `generated/extracted/8d31234716fdeda76cb7fffa732202f6/full.md`
- Filtered: `generated/filtered/8d31234716fdeda76cb7fffa732202f6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
