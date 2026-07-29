---
doc_id: "dacc7b2ec50c463fd88b3c0f76cfad04"
title: "MySQL 分配 Undo 段分配完回滚段，接下来该分享 Undo 段了。 > 作者：操盛春，爱可生技术专家，公众号『一 - 掘金"
aliases:
  - "MySQL 分配 Undo 段分配完回滚段，接下来该分享 Undo 段了。 > 作者：操盛春，爱可生技术专家，公众号『一 - 掘金"
url: "https://juejin.cn/post/7456622508910067739"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Undo"
  - "事务"
  - "数据库"
  - "并发控制"
generated: true
---

# MySQL 分配 Undo 段分配完回滚段，接下来该分享 Undo 段了。 > 作者：操盛春，爱可生技术专家，公众号『一 - 掘金

> [!info] Provenance
> - doc_id: `dacc7b2ec50c463fd88b3c0f76cfad04`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7456622508910067739)
> - PDF: [open local PDF](../../collector/dacc7b2ec50c463fd88b3c0f76cfad04.pdf)

## Summary

本文讲解 MySQL/InnoDB 在已分配回滚段之后如何分配 Undo 段，包括缓存链表复用、创建新 Undo 段、挂入回滚段链表，以及通过互斥量避免并发冲突。

## Knowledge Outline

- 背景与缓存结构 — MySQL, InnoDB, Undo, 缓存, 事务
- 创建新的 Undo 段 — MySQL, InnoDB, Undo, 错误, 并发
- Undo 段链表 — MySQL, InnoDB, Undo, 链表, 内存
- 并发冲突避免 — MySQL, InnoDB, Undo, 并发控制, 互斥量
- 分配流程总结 — MySQL, InnoDB, Undo, 总结, 流程

## Repository Paths

- PDF: `collector/dacc7b2ec50c463fd88b3c0f76cfad04.pdf`
- Extracted: `generated/extracted/dacc7b2ec50c463fd88b3c0f76cfad04/full.md`
- Filtered: `generated/filtered/dacc7b2ec50c463fd88b3c0f76cfad04/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
