---
doc_id: "83bd3cfd4b71fc8fb1ebfbc9cc02eb91"
title: "(2 封私信) Redis LRU 算法和LFU算法 - 知乎"
aliases:
  - "(2 封私信) Redis LRU 算法和LFU算法 - 知乎"
url: "https://zhuanlan.zhihu.com/p/363750871"
source_domain: "zhuanlan.zhihu.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "LRU"
  - "LFU"
  - "缓存淘汰"
  - "MySQL Buffer Pool"
  - "数据结构"
  - "Java"
generated: true
---

# (2 封私信) Redis LRU 算法和LFU算法 - 知乎

> [!info] Provenance
> - doc_id: `83bd3cfd4b71fc8fb1ebfbc9cc02eb91`
> - source_kind: `llm_filtered`
> - source: [original URL](https://zhuanlan.zhihu.com/p/363750871)
> - PDF: [open local PDF](../../collector/83bd3cfd4b71fc8fb1ebfbc9cc02eb91.pdf)

## Summary

本文介绍 LRU 与 LFU 缓存淘汰算法，包括数组、链表、双向链表+哈希表的 LRU 实现思路，MySQL Buffer Pool 中 LRU 的应用与问题，以及 LFU 的 O(N) 与 O(1) Java 实现方案。

## Knowledge Outline

- LRU 基本思想 — LRU, 缓存淘汰
- LRU 数组方案 — LRU, 数组, 时间复杂度
- LRU 链表方案 — LRU, 链表, 时间复杂度
- 哈希链表条件 — LRU, 哈希表, 双向链表, LinkedHashMap
- 双链表问题 — LRU, 双向链表, 哈希表
- LinkedHashMap 实现 — LRU, Java, LinkedHashMap
- MySQL Buffer Pool — MySQL, Buffer Pool, LRU, 预读, 全表扫描
- Redis 热点数据 — Redis, 热点数据, 缓存淘汰
- LFU 基本思想 — LFU, LRU, 缓存淘汰
- LFU Cache 接口 — LFU, Java, Cache
- LFU 双向链表思路 — LFU, 双向链表, 频次
- LFU O(N) 解法说明 — LFU, 时间复杂度, 链表
- LFU O(N) Java — LFU, Java, O(N)
- LFU O(1) 三种实现 — LFU, O(1), HashMap, LinkedHashSet, 双向链表
- LFU LinkedHashSet — LFU, Java, LinkedHashSet, O(1)

## Repository Paths

- PDF: `collector/83bd3cfd4b71fc8fb1ebfbc9cc02eb91.pdf`
- Extracted: `generated/extracted/83bd3cfd4b71fc8fb1ebfbc9cc02eb91/full.md`
- Filtered: `generated/filtered/83bd3cfd4b71fc8fb1ebfbc9cc02eb91/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
