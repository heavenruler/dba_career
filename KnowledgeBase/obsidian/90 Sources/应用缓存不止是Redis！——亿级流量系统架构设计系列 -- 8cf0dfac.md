---
doc_id: "8cf0dfac20145d8aad1f1fcc8ef182f6"
title: "应用缓存不止是Redis！——亿级流量系统架构设计系列"
aliases:
  - "应用缓存不止是Redis！——亿级流量系统架构设计系列"
url: "https://mp.weixin.qq.com/s/VVvPhTaH14AddnblSjH3uQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "缓存"
  - "架构设计"
  - "高并发"
  - "性能优化"
  - "Redis"
  - "Guava Cache"
  - "Ehcache"
  - "MapDB"
generated: true
---

# 应用缓存不止是Redis！——亿级流量系统架构设计系列

> [!info] Provenance
> - doc_id: `8cf0dfac20145d8aad1f1fcc8ef182f6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/VVvPhTaH14AddnblSjH3uQ)
> - PDF: [open local PDF](../../collector/8cf0dfac20145d8aad1f1fcc8ef182f6.pdf)

## Summary

本文系统整理了缓存的基础指标、回收策略、多级缓存类型、Guava Cache 与 Ehcache/Terracotta 的配置示例、Cache-Aside / Read-Through / Write-Behind 模式、多级缓存一致性与监控，以及缓存穿透、击穿、雪崩和 GC 优化的处理方式。

## Knowledge Outline

- 缓存基础与命中率 — 缓存, 命中率, 一致性, 高并发
- 缓存回收策略与金字塔模型 — 缓存, LRU, TTL, Ehcache, Redis
- Guava Cache 与 Ehcache 配置 — 缓存, Guava Cache, Ehcache, Terracotta, 配置
- 缓存使用模式 — 缓存模式, Cache-Aside, Read-Through, Write-Through, Write-Behind
- 多级缓存与一致性 — 缓存, 多级缓存, 一致性, 穿透, 监控
- 缓存问题与 GC 优化 — 缓存穿透, 缓存击穿, 缓存雪崩, GC, MapDB
- 总结 — 缓存, 总结, 高可用, 性能优化

## Repository Paths

- PDF: `collector/8cf0dfac20145d8aad1f1fcc8ef182f6.pdf`
- Extracted: `generated/extracted/8cf0dfac20145d8aad1f1fcc8ef182f6/full.md`
- Filtered: `generated/filtered/8cf0dfac20145d8aad1f1fcc8ef182f6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
