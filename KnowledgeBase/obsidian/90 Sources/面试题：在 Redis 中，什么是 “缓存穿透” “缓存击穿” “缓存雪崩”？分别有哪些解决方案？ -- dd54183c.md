---
doc_id: "dd54183c3ee2b4ab14b53296108bb227"
title: "面试题：在 Redis 中，什么是 “缓存穿透” “缓存击穿” “缓存雪崩”？分别有哪些解决方案？"
aliases:
  - "面试题：在 Redis 中，什么是 “缓存穿透” “缓存击穿” “缓存雪崩”？分别有哪些解决方案？"
url: "https://mp.weixin.qq.com/s/bRLe9yO40FmRrlSF5utHog"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "缓存穿透"
  - "缓存击穿"
  - "缓存雪崩"
  - "面试"
  - "数据库"
  - "缓存"
generated: true
---

# 面试题：在 Redis 中，什么是 “缓存穿透” “缓存击穿” “缓存雪崩”？分别有哪些解决方案？

> [!info] Provenance
> - doc_id: `dd54183c3ee2b4ab14b53296108bb227`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/bRLe9yO40FmRrlSF5utHog)
> - PDF: [open local PDF](../../collector/dd54183c3ee2b4ab14b53296108bb227.pdf)

## Summary

这篇文章用面试题形式说明了 Redis 场景下的三类缓存问题：缓存穿透、缓存击穿、缓存雪崩，并分别给出空值缓存、布隆过滤器、参数校验、互斥锁、逻辑过期、随机过期时间、高可用集群、熔断限流等方案。

## Knowledge Outline

- 引言 — Redis, 缓存, 数据库, 面试
- 缓存穿透 — Redis, 缓存穿透, 布隆过滤器, 参数校验, 面试
- 缓存击穿 — Redis, 缓存击穿, 热点Key, 互斥锁, 逻辑过期, 面试
- 缓存雪崩 — Redis, 缓存雪崩, 高可用, 限流, 熔断, 面试

## Repository Paths

- PDF: `collector/dd54183c3ee2b4ab14b53296108bb227.pdf`
- Extracted: `generated/extracted/dd54183c3ee2b4ab14b53296108bb227/full.md`
- Filtered: `generated/filtered/dd54183c3ee2b4ab14b53296108bb227/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
