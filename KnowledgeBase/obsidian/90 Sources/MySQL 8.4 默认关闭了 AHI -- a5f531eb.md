---
doc_id: "a5f531ebc7c13d24d4641fd12a1093d0"
title: "MySQL 8.4 默认关闭了 AHI"
aliases:
  - "MySQL 8.4 默认关闭了 AHI"
url: "https://mp.weixin.qq.com/s/2WzW-bOOZ99xGvMDK5aXWA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "AHI"
  - "性能调优"
  - "数据库"
  - "监控"
generated: true
---

# MySQL 8.4 默认关闭了 AHI

> [!info] Provenance
> - doc_id: `a5f531ebc7c13d24d4641fd12a1093d0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/2WzW-bOOZ99xGvMDK5aXWA)
> - PDF: [open local PDF](../../collector/a5f531ebc7c13d24d4641fd12a1093d0.pdf)

## Summary

这篇文章说明了 MySQL 8.4 将 InnoDB 自适应哈希索引（AHI）的默认值从 ON 改为 OFF，并解释 AHI 的工作方式、在低频访问和高并发下的开销与互斥锁问题，以及如何通过 `SHOW ENGINE INNODB STATUS` 查看 AHI 使用情况。

## Knowledge Outline

- AHI 机制与缺陷 — MySQL, InnoDB, AHI, 性能调优, 数据库
- 监控 AHI 使用 — MySQL, InnoDB, AHI, 监控, 可观测性

## Repository Paths

- PDF: `collector/a5f531ebc7c13d24d4641fd12a1093d0.pdf`
- Extracted: `generated/extracted/a5f531ebc7c13d24d4641fd12a1093d0/full.md`
- Filtered: `generated/filtered/a5f531ebc7c13d24d4641fd12a1093d0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
