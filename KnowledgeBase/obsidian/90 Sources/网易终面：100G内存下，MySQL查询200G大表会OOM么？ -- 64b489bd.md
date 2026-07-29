---
doc_id: "64b489bde252cbb70863ab7a779b75cf"
title: "网易终面：100G内存下，MySQL查询200G大表会OOM么？"
aliases:
  - "网易终面：100G内存下，MySQL查询200G大表会OOM么？"
url: "https://mp.weixin.qq.com/s/tiY_5PQbRDlGWlUL-vIldA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Buffer Pool"
  - "LRU"
  - "效能调优"
  - "面试"
  - "数据库"
generated: true
---

# 网易终面：100G内存下，MySQL查询200G大表会OOM么？

> [!info] Provenance
> - doc_id: `64b489bde252cbb70863ab7a779b75cf`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/tiY_5PQbRDlGWlUL-vIldA)
> - PDF: [open local PDF](../../collector/64b489bde252cbb70863ab7a779b75cf.pdf)

## Summary

文章重点解释了 MySQL 大查询不会在服务端保存完整结果集，而是边读边发；同时说明 InnoDB Buffer Pool 的作用、命中率，以及通过改进 LRU 来降低全表扫描对热数据的影响。

## Knowledge Outline

- 查询结果发送流程 — MySQL, server层, 网络, 结果集
- Sending 状态含义 — MySQL, 状态, 锁等待, 排查
- Buffer Pool 作用 — InnoDB, Buffer Pool, WAL, 命中率, LRU
- 基本 LRU 问题 — InnoDB, LRU, 全表扫描, Buffer Pool, 性能影响
- 改进 LRU 与小结 — InnoDB, LRU, 全表扫描, Buffer Pool, 小结, IO

## Repository Paths

- PDF: `collector/64b489bde252cbb70863ab7a779b75cf.pdf`
- Extracted: `generated/extracted/64b489bde252cbb70863ab7a779b75cf/full.md`
- Filtered: `generated/filtered/64b489bde252cbb70863ab7a779b75cf/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
