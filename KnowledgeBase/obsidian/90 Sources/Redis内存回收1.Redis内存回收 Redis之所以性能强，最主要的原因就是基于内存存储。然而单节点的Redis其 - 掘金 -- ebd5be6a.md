---
doc_id: "ebd5be6a2515570bc962b5b5532c9494"
title: "Redis内存回收1.Redis内存回收 Redis之所以性能强，最主要的原因就是基于内存存储。然而单节点的Redis其 - 掘金"
aliases:
  - "Redis内存回收1.Redis内存回收 Redis之所以性能强，最主要的原因就是基于内存存储。然而单节点的Redis其 - 掘金"
url: "https://juejin.cn/post/7405770868506492943"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "内存回收"
  - "过期删除"
  - "内存淘汰"
  - "LRU"
  - "LFU"
  - "数据库"
generated: true
---

# Redis内存回收1.Redis内存回收 Redis之所以性能强，最主要的原因就是基于内存存储。然而单节点的Redis其 - 掘金

> [!info] Provenance
> - doc_id: `ebd5be6a2515570bc962b5b5532c9494`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7405770868506492943)
> - PDF: [open local PDF](../../collector/ebd5be6a2515570bc962b5b5532c9494.pdf)

## Summary

本文讲 Redis 的内存回收机制，核心分成两部分：过期 KEY 的删除，以及内存达到阈值后的淘汰。重点解释了 Redis 如何记录过期时间、惰性删除与周期删除的触发方式，以及 LRU/LFU 等淘汰策略的实现思路。

## Knowledge Outline

- 内存回收概览 — Redis, 内存回收, 配置, 数据库
- 过期判断与删除 — Redis, 过期时间, 惰性删除, 源码, 数据库
- 周期删除规则 — Redis, 过期删除, 定时任务, 性能
- 内存淘汰策略 — Redis, 内存淘汰, LRU, LFU, 性能
- LRU 与 LFU — Redis, LRU, LFU, 抽样算法, 近似LRU, 性能

## Repository Paths

- PDF: `collector/ebd5be6a2515570bc962b5b5532c9494.pdf`
- Extracted: `generated/extracted/ebd5be6a2515570bc962b5b5532c9494/full.md`
- Filtered: `generated/filtered/ebd5be6a2515570bc962b5b5532c9494/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
