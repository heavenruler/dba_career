---
doc_id: "605c8df3f7810b55f87fb6656e8e5e94"
title: "拼多多一面：说说缓存淘汰机制 LRU 和 LFU 的区别，秒杀场景下应该如何选择？"
aliases:
  - "拼多多一面：说说缓存淘汰机制 LRU 和 LFU 的区别，秒杀场景下应该如何选择？"
url: "https://mp.weixin.qq.com/s/bt_zQdNoio8Swm8GoiKL8Q"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "缓存"
  - "LRU"
  - "LFU"
  - "秒杀"
  - "电商架构"
  - "面试"
  - "性能调优"
generated: true
---

# 拼多多一面：说说缓存淘汰机制 LRU 和 LFU 的区别，秒杀场景下应该如何选择？

> [!info] Provenance
> - doc_id: `605c8df3f7810b55f87fb6656e8e5e94`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/bt_zQdNoio8Swm8GoiKL8Q)
> - PDF: [open local PDF](../../collector/605c8df3f7810b55f87fb6656e8e5e94.pdf)

## Summary

这篇文章集中讲缓存淘汰策略的核心差异：LRU 侧重最近访问时间，适合热点变化快的秒杀场景；LFU 侧重访问频率，适合长期稳定高频访问的数据。文中还给出 Java 实现思路、优缺点和电商场景下的选择建议。

## Knowledge Outline

- 背景 — 缓存, LRU, LFU, 电商架构, 秒杀
- LRU — LRU, 缓存, 秒杀, Java, 面试
- LFU — LFU, 缓存, Java, 面试, 性能调优
- 选型 — LRU, LFU, 秒杀, 电商架构, 缓存, 决策框架

## Repository Paths

- PDF: `collector/605c8df3f7810b55f87fb6656e8e5e94.pdf`
- Extracted: `generated/extracted/605c8df3f7810b55f87fb6656e8e5e94/full.md`
- Filtered: `generated/filtered/605c8df3f7810b55f87fb6656e8e5e94/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
