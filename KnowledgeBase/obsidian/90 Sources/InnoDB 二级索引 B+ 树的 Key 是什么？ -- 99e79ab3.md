---
doc_id: "99e79ab39ea9004943b9c92dfcdcceb9"
title: "InnoDB 二级索引 B+ 树的 Key 是什么？"
aliases:
  - "InnoDB 二级索引 B+ 树的 Key 是什么？"
url: "http://mysql.taobao.org/monthly/2025/07/02/"
source_domain: "mysql.taobao.org"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "二级索引"
  - "B+树"
  - "MVCC"
  - "数据库内核"
generated: true
---

# InnoDB 二级索引 B+ 树的 Key 是什么？

> [!info] Provenance
> - doc_id: `99e79ab39ea9004943b9c92dfcdcceb9`
> - source_kind: `llm_filtered`
> - source: [original URL](http://mysql.taobao.org/monthly/2025/07/02/)
> - PDF: [open local PDF](../../collector/99e79ab39ea9004943b9c92dfcdcceb9.pdf)

## Summary

本文用源码分析说明 InnoDB 二级索引的 Key 不是单纯的二级索引字段，而是二级索引字段加上不在其中的主键字段。文章进一步解释了二级索引叶子节点与中间节点的 record 结构，以及为什么这种设计既支持非 unique 二级索引，也能满足 MVCC 下的更新与一致性读要求。

## Knowledge Outline

- 导言 — MySQL, InnoDB, 二级索引, MVCC
- 二级索引结构 — MySQL, InnoDB, 二级索引, 源码阅读
- 二级索引叶子节点 — MySQL, InnoDB, 二级索引, record结构, 源码阅读
- 二级索引中间节点 — MySQL, InnoDB, 二级索引, B+树, 源码阅读
- 二级索引更新与 MVCC — MySQL, InnoDB, MVCC, 二级索引, 更新流程
- 总结 — MySQL, InnoDB, 二级索引, 总结, MVCC

## Repository Paths

- PDF: `collector/99e79ab39ea9004943b9c92dfcdcceb9.pdf`
- Extracted: `generated/extracted/99e79ab39ea9004943b9c92dfcdcceb9/full.md`
- Filtered: `generated/filtered/99e79ab39ea9004943b9c92dfcdcceb9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
