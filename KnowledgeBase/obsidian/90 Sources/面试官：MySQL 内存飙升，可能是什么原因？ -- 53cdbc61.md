---
doc_id: "53cdbc61c404deac009700776ed6cb31"
title: "面试官：MySQL 内存飙升，可能是什么原因？"
aliases:
  - "面试官：MySQL 内存飙升，可能是什么原因？"
url: "https://mp.weixin.qq.com/s/9gGs9Ll9Gubj7cbEva1VfQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "数据库"
  - "效能調優"
  - "面試"
  - "內存"
generated: true
---

# 面试官：MySQL 内存飙升，可能是什么原因？

> [!info] Provenance
> - doc_id: `53cdbc61c404deac009700776ed6cb31`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/9gGs9Ll9Gubj7cbEva1VfQ)
> - PDF: [open local PDF](../../collector/53cdbc61c404deac009700776ed6cb31.pdf)

## Summary

本文整理了 MySQL 内存升高的常见来源，重点包括 InnoDB buffer pool、sort buffer、join buffer、内部临时表以及其他会话级缓冲区，并给出与 SQL 写法、预读和参数配置相关的影响因素。

## Knowledge Outline

- 内存飙升的背景 — MySQL, 内存, InnoDB
- InnoDB Buffer Pool — MySQL, InnoDB, Buffer Pool, LRU, 效能調優
- Sort Buffer — MySQL, sort buffer, 排序, 效能調優
- Join Buffer — MySQL, JOIN, join buffer, 效能調優
- 临时表 — MySQL, 临时表, SQL, 效能調優
- 其他缓冲区 — MySQL, Read Buffer, Read Rnd Buffer, 效能調優
- 结论 — MySQL, 内存, SQL, 效能調優

## Repository Paths

- PDF: `collector/53cdbc61c404deac009700776ed6cb31.pdf`
- Extracted: `generated/extracted/53cdbc61c404deac009700776ed6cb31/full.md`
- Filtered: `generated/filtered/53cdbc61c404deac009700776ed6cb31/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
