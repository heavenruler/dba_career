---
doc_id: "014f6d8449fb1d87feb08583d79ba2b0"
title: "探索Redis与MySQL的双写问题-阿里云开发者社区"
aliases:
  - "探索Redis与MySQL的双写问题-阿里云开发者社区"
url: "https://developer.aliyun.com/article/1347071"
source_domain: "developer.aliyun.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "MySQL"
  - "缓存一致性"
  - "Cache-Aside"
  - "延时双删"
  - "分布式系统"
  - "数据库"
generated: true
---

# 探索Redis与MySQL的双写问题-阿里云开发者社区

> [!info] Provenance
> - doc_id: `014f6d8449fb1d87feb08583d79ba2b0`
> - source_kind: `llm_filtered`
> - source: [original URL](https://developer.aliyun.com/article/1347071)
> - PDF: [open local PDF](../../collector/014f6d8449fb1d87feb08583d79ba2b0.pdf)

## Summary

本文聚焦 Redis 与 MySQL 双写一致性问题，解释了最终一致性的取舍，比较了 Cache-Aside、Read/Write Through、Write Behind 三种缓存读写模式，并重点讨论了旁路缓存模式下为什么通常采用“先更新数据库，再删除缓存”，以及延时双删的原理与局限。

## Knowledge Outline

- 双写一致问题 — Redis, MySQL, 缓存一致性, CAP理论, 最终一致性
- 缓存读写策略 — 缓存策略, Cache-Aside, 数据库
- 旁路、穿透、写后 — Cache-Aside, Read/Write Through, Write Behind, Redis, MySQL, 缓存策略
- Cache Aside 问题 — Cache-Aside, 缓存一致性, 延时双删, Canal, binlog, Redis, MySQL
- Cache Aside 缺陷 — Cache-Aside, 缓存命中率, 分布式锁, 一致性
- 延时双删 — 延时双删, Redis, MySQL, Java, 缓存一致性, 分布式系统

## Repository Paths

- PDF: `collector/014f6d8449fb1d87feb08583d79ba2b0.pdf`
- Extracted: `generated/extracted/014f6d8449fb1d87feb08583d79ba2b0/full.md`
- Filtered: `generated/filtered/014f6d8449fb1d87feb08583d79ba2b0/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
