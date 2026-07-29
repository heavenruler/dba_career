---
doc_id: "d74fed5a0ea1396efe26284e1e7e0dc9"
title: "Redis 缓存击穿（失效）、缓存穿透、缓存雪崩怎么解决？-redis缓存穿透"
aliases:
  - "Redis 缓存击穿（失效）、缓存穿透、缓存雪崩怎么解决？-redis缓存穿透"
url: "https://www.51cto.com/article/703396.html"
source_domain: "www.51cto.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "数据库"
  - "缓存"
  - "缓存击穿"
  - "缓存穿透"
  - "缓存雪崩"
  - "高并发"
  - "系统设计"
  - "可用性"
  - "性能"
generated: true
---

# Redis 缓存击穿（失效）、缓存穿透、缓存雪崩怎么解决？-redis缓存穿透

> [!info] Provenance
> - doc_id: `d74fed5a0ea1396efe26284e1e7e0dc9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.51cto.com/article/703396.html)
> - PDF: [open local PDF](../../collector/d74fed5a0ea1396efe26284e1e7e0dc9.pdf)

## Summary

本文说明 Redis 缓存架构中缓存击穿、缓存穿透、缓存雪崩的定义、成因与解决方案，包括随机过期时间、预热、分布式锁、缓存空值、布隆过滤器、限流、熔断与高可用缓存集群。

## Knowledge Outline

- 缓存架构背景 — Redis, 数据库, 缓存架构, 性能
- 缓存击穿定义 — 缓存击穿, Redis, 高并发, 热点数据
- 缓存击穿解决方案 — 缓存击穿, 随机过期时间, 缓存预热, 分布式锁
- 缓存击穿伪代码 — 缓存击穿, 分布式锁, 伪代码, Redis
- 缓存穿透定义 — 缓存穿透, Redis, 数据库
- 缓存穿透解决方案 — 缓存穿透, 缓存空值, 布隆过滤器
- 布隆过滤器原理 — BloomFilter, 布隆过滤器, Hash, 缓存穿透
- 布隆过滤器误判 — BloomFilter, 布隆过滤器, 误判, Hash
- 缓存雪崩定义 — 缓存雪崩, Redis, 数据库, 可用性
- 大量缓存同时过期 — 缓存雪崩, 缓存击穿, 过期时间, 高并发
- 缓存雪崩解决方案 — 缓存雪崩, 随机过期时间, 接口限流, 高并发
- Redis 故障宕机 — Redis, 缓存雪崩, QPS, 数据库
- 故障宕机解决方案 — Redis, 缓存雪崩, 服务熔断, 接口限流, 高可用集群
- 总结 — 缓存穿透, 缓存击穿, 缓存雪崩, Redis

## Repository Paths

- PDF: `collector/d74fed5a0ea1396efe26284e1e7e0dc9.pdf`
- Extracted: `generated/extracted/d74fed5a0ea1396efe26284e1e7e0dc9/full.md`
- Filtered: `generated/filtered/d74fed5a0ea1396efe26284e1e7e0dc9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
