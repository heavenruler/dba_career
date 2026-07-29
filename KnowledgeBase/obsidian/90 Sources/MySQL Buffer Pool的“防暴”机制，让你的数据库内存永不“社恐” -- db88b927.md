---
doc_id: "db88b92775464cd4e325dfcf2d2a4c66"
title: "MySQL Buffer Pool的“防暴”机制，让你的数据库内存永不“社恐”"
aliases:
  - "MySQL Buffer Pool的“防暴”机制，让你的数据库内存永不“社恐”"
url: "https://mp.weixin.qq.com/s/srAbsTFCKxEYn-cmeFSa2Q"
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
  - "全表扫描"
  - "性能调优"
  - "数据库"
generated: true
---

# MySQL Buffer Pool的“防暴”机制，让你的数据库内存永不“社恐”

> [!info] Provenance
> - doc_id: `db88b92775464cd4e325dfcf2d2a4c66`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/srAbsTFCKxEYn-cmeFSa2Q)
> - PDF: [open local PDF](../../collector/db88b92775464cd4e325dfcf2d2a4c66.pdf)

## Summary

这篇文章讲 InnoDB Buffer Pool 如何通过改进版 LRU、Midpoint 插入和 innodb_old_blocks_time 抑制全表扫描污染，并给出相关监控指标、参数调整注意事项与 SQL 示例。

## Knowledge Outline

- Buffer Pool 基础 — MySQL, InnoDB, Buffer Pool, 性能调优
- 传统 LRU 问题 — MySQL, LRU, Buffer Pool, 全表扫描, 性能调优
- Midpoint 机制 — MySQL, InnoDB, LRU, Midpoint, innodb_old_blocks_time, 性能调优
- 实战流程 — MySQL, InnoDB, Buffer Pool, 全表扫描, 性能调优
- 监控与调参 — MySQL, InnoDB, 监控, 性能调优, innodb_old_blocks_time
- SQL 示例 — MySQL, SQL, InnoDB, Buffer Pool, 全表扫描

## Repository Paths

- PDF: `collector/db88b92775464cd4e325dfcf2d2a4c66.pdf`
- Extracted: `generated/extracted/db88b92775464cd4e325dfcf2d2a4c66/full.md`
- Filtered: `generated/filtered/db88b92775464cd4e325dfcf2d2a4c66/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
