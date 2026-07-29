---
doc_id: "91fb322e736a26fcf759fec5ed8d65f3"
title: "详解 Redis 分布式锁的 5 种方案-腾讯云开发者社区-腾讯云"
aliases:
  - "详解 Redis 分布式锁的 5 种方案-腾讯云开发者社区-腾讯云"
url: "https://cloud.tencent.com/developer/article/2321395"
source_domain: "cloud.tencent.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "分布式锁"
  - "SETNX"
  - "Lua"
  - "微服务"
  - "缓存击穿"
  - "并发控制"
  - "架构设计"
generated: true
---

# 详解 Redis 分布式锁的 5 种方案-腾讯云开发者社区-腾讯云

> [!info] Provenance
> - doc_id: `91fb322e736a26fcf759fec5ed8d65f3`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cloud.tencent.com/developer/article/2321395)
> - PDF: [open local PDF](../../collector/91fb322e736a26fcf759fec5ed8d65f3.pdf)

## Summary

本文围绕 Redis 分布式锁，从本地锁在分布式场景下的问题出发，依次说明 SETNX、过期时间、原子加锁、唯一锁值、Lua 脚本原子解锁等方案演进，并总结各方案缺陷与改进方向。

## Knowledge Outline

- 本地锁问题 — 本地锁, 分布式, 缓存击穿, 数据一致性
- 分布式锁基本原理 — 分布式锁, 并发控制, Redis
- SETNX 命令 — Redis, SETNX, 命令
- 青铜方案 — Redis, SETNX, Java, 分布式锁
- 青铜缺陷 — 死锁, 异常处理, 过期时间
- 白银方案 — Redis, 过期时间, Java
- 白银缺陷 — 原子性, 死锁, 过期时间
- 黄金方案 — Redis, SET, NX, PX, EX, 原子性
- 黄金示例与缺陷 — 锁误删, 过期时间, 并发冲突
- 铂金方案 — 唯一值, 锁释放, Redis
- 铂金代码 — Java, UUID, Redis, 锁释放
- 铂金缺陷 — 原子性, 锁误删, 竞态条件
- 钻石方案 — Lua, 原子性, Redis
- Lua 解锁脚本 — Lua, Redis, Java, DefaultRedisScript
- 方案总结 — 方案对比, 分布式锁, Redisson

## Repository Paths

- PDF: `collector/91fb322e736a26fcf759fec5ed8d65f3.pdf`
- Extracted: `generated/extracted/91fb322e736a26fcf759fec5ed8d65f3/full.md`
- Filtered: `generated/filtered/91fb322e736a26fcf759fec5ed8d65f3/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
