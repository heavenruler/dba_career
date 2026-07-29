---
doc_id: "20ebd916b868d194b735cd2e2e7de577"
title: "Redis 性能刺客，大key在使用 Redis 的过程中，如果未能及时发现并处理 Big keys（`大Key`”）， - 掘金"
aliases:
  - "Redis 性能刺客，大key在使用 Redis 的过程中，如果未能及时发现并处理 Big keys（`大Key`”）， - 掘金"
url: "https://juejin.cn/post/7298989375370166298"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "性能优化"
  - "大Key"
  - "后端"
  - "数据库"
generated: true
---

# Redis 性能刺客，大key在使用 Redis 的过程中，如果未能及时发现并处理 Big keys（`大Key`”）， - 掘金

> [!info] Provenance
> - doc_id: `20ebd916b868d194b735cd2e2e7de577`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7298989375370166298)
> - PDF: [open local PDF](../../collector/20ebd916b868d194b735cd2e2e7de577.pdf)

## Summary

本文说明 Redis 大Key 的定义、造成的问题、常见成因，以及排查和优化方法，重点包括拆分、清理和定期处理过期数据。

## Knowledge Outline

- 引言 — Redis, 大Key, 性能优化
- 大Key 的定义 — Redis, 大Key, 内存, 数据结构
- 大Key 引发的问题 — Redis, 大Key, 性能, 内存, 复制
- 大Key 产生的原因 — Redis, 大Key, 原因, 数据结构, 缓存
- 如何快速找出大Key — Redis, 大Key, 排查, SCAN, Lua
- 大Key 的优化方案 — Redis, 大Key, 优化, 拆分, 清理, UNLINK, HSCAN
- 总结 — Redis, 大Key, 总结, 性能优化

## Repository Paths

- PDF: `collector/20ebd916b868d194b735cd2e2e7de577.pdf`
- Extracted: `generated/extracted/20ebd916b868d194b735cd2e2e7de577/full.md`
- Filtered: `generated/filtered/20ebd916b868d194b735cd2e2e7de577/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
