---
doc_id: "75f22d95afec6fbdec8ad6a7b593cde7"
title: "MySQL 8.0不再担心被垃圾SQL搞爆内存"
aliases:
  - "MySQL 8.0不再担心被垃圾SQL搞爆内存"
url: "https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653939777&idx=1&sn=da6b97b8d302b0b910fa52147e0f6854&scene=21&poc_token=HFD5m2ijUGUOXzkmhBJ8wY9qIySDJMglxglVMSik"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "内存管理"
  - "性能调优"
  - "SRE"
  - "资源隔离"
generated: true
---

# MySQL 8.0不再担心被垃圾SQL搞爆内存

> [!info] Provenance
> - doc_id: `75f22d95afec6fbdec8ad6a7b593cde7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653939777&idx=1&sn=da6b97b8d302b0b910fa52147e0f6854&scene=21&poc_token=HFD5m2ijUGUOXzkmhBJ8wY9qIySDJMglxglVMSik)
> - PDF: [open local PDF](../../collector/75f22d95afec6fbdec8ad6a7b593cde7.pdf)

## Summary

本文介绍 MySQL 8.0.28 新增的连接内存统计与限制机制，说明如何通过 global_connection_memory_tracking、connection_memory_limit、connection_memory_chunk_size 控制单个会话和全局连接的内存消耗，并给出普通用户与 root 用户的行为差异、内存估算方法，以及在 96GB 物理内存机器上的参数规划建议。

## Knowledge Outline

- 新功能概述 — MySQL, 数据库, 内存管理, 性能调优
- 内存限制示例 — MySQL, 数据库, 内存管理, 性能调优
- 权限与调参建议 — MySQL, 数据库, 内存管理, 资源规划, 性能调优

## Repository Paths

- PDF: `collector/75f22d95afec6fbdec8ad6a7b593cde7.pdf`
- Extracted: `generated/extracted/75f22d95afec6fbdec8ad6a7b593cde7/full.md`
- Filtered: `generated/filtered/75f22d95afec6fbdec8ad6a7b593cde7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
