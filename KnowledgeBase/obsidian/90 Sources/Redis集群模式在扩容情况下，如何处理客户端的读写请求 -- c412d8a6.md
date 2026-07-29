---
doc_id: "c412d8a69cf951e567b5711fd8c974ce"
title: "Redis集群模式在扩容情况下，如何处理客户端的读写请求"
aliases:
  - "Redis集群模式在扩容情况下，如何处理客户端的读写请求"
url: "https://mp.weixin.qq.com/s/UQHlSKBACY8b4qzorzpiHw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "集群模式"
  - "扩容"
  - "槽位迁移"
  - "ASK重定向"
  - "分布式系统"
generated: true
---

# Redis集群模式在扩容情况下，如何处理客户端的读写请求

> [!info] Provenance
> - doc_id: `c412d8a69cf951e567b5711fd8c974ce`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/UQHlSKBACY8b4qzorzpiHw)
> - PDF: [open local PDF](../../collector/c412d8a69cf951e567b5711fd8c974ce.pdf)

## Summary

本文说明 Redis 集群扩容时的槽位迁移流程，以及迁移过程中客户端读写请求如何通过源节点返回数据或 ASK 重定向到新节点继续查询。

## Knowledge Outline

- 集群扩容概述 — Redis, 集群模式, 扩容, 槽位
- 集群扩容过程 — Redis, 集群模式, 扩容, 槽位迁移, migrating, importing
- 迁移中查询 — Redis, 槽位迁移, ASK重定向, asking命令, 读请求, 服务可用性
- 总结 — Redis, 集群模式, 扩容, 总结, ASK重定向

## Repository Paths

- PDF: `collector/c412d8a69cf951e567b5711fd8c974ce.pdf`
- Extracted: `generated/extracted/c412d8a69cf951e567b5711fd8c974ce/full.md`
- Filtered: `generated/filtered/c412d8a69cf951e567b5711fd8c974ce/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
