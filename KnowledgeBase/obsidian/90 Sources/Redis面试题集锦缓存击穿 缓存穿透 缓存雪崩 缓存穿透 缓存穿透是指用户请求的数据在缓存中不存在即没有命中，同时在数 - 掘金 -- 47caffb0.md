---
doc_id: "47caffb02a1d2f628c02e1ee74619b99"
title: "Redis面试题集锦缓存击穿/缓存穿透/缓存雪崩 缓存穿透 缓存穿透是指用户请求的数据在缓存中不存在即没有命中，同时在数 - 掘金"
aliases:
  - "Redis面试题集锦缓存击穿/缓存穿透/缓存雪崩 缓存穿透 缓存穿透是指用户请求的数据在缓存中不存在即没有命中，同时在数 - 掘金"
url: "https://juejin.cn/post/7323203575618076687"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "缓存"
  - "面试"
  - "数据库"
  - "高可用"
  - "持久化"
  - "主从复制"
  - "哨兵模式"
  - "性能调优"
generated: true
---

# Redis面试题集锦缓存击穿/缓存穿透/缓存雪崩 缓存穿透 缓存穿透是指用户请求的数据在缓存中不存在即没有命中，同时在数 - 掘金

> [!info] Provenance
> - doc_id: `47caffb02a1d2f628c02e1ee74619b99`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7323203575618076687)
> - PDF: [open local PDF](../../collector/47caffb02a1d2f628c02e1ee74619b99.pdf)

## Summary

本文整理 Redis 面试知识点，涵盖缓存穿透、击穿、雪崩及对应治理策略，Redis 单线程与多线程 I/O、AOF/RDB/混合持久化、主从复制、哨兵故障转移、过期删除与内存淘汰策略。

## Knowledge Outline

- 缓存穿透 — Redis, 缓存穿透, 数据库
- 布隆过滤器原理 — 布隆过滤器, 数据结构, 缓存穿透
- 布隆过滤器设计思想 — 布隆过滤器, 哈希, 假阳性
- 布隆过滤器优缺点 — 布隆过滤器, 应用场景
- 缓存空对象 — 缓存穿透, 缓存空对象, 一致性
- 缓存击穿 — 缓存击穿, 高并发, 数据库
- 缓存击穿治理 — 缓存击穿, 互斥锁, 热点数据
- 缓存雪崩 — 缓存雪崩, 缓存击穿, 数据库
- 缓存雪崩治理 — 缓存雪崩, 双层缓存, 高可用
- 缓存预热与降级 — 缓存预热, 缓存降级, 高并发
- Redis 线程模型 — Redis, 线程模型, lazyfree, 大 key
- Redis 单线程性能原因 — Redis, 单线程, I/O 多路复用, 性能
- Redis 6 多线程 — Redis 6.0, 多线程, 网络 I/O
- Redis 持久化方式 — Redis, 持久化, AOF, RDB
- AOF 写回策略 — AOF, appendfsync, 持久化
- AOF 重写机制 — AOF, AOF 重写, 持久化
- RDB 快照阻塞 — RDB, SAVE, BGSAVE, 阻塞
- RDB 写时复制 — RDB, BGSAVE, COW, fork
- 混合持久化 — 混合持久化, AOF, RDB, Redis 4.0
- 大 key 影响 — 大 key, 性能调优, 网络阻塞
- 主从复制一致性 — 主从复制, 异步复制, 一致性
- 主从初次同步 — 主从复制, 全量复制, 同步
- 增量复制 — 增量复制, psync, Redis 2.8
- repl_backlog_buffer 调整 — repl_backlog_buffer, 主从复制, 容量规划
- 异步复制丢失治理配置 — 主从复制, 数据丢失, 配置
- 脑裂数据丢失 — 脑裂, 数据丢失, 高可用
- 哨兵模式 — Redis Sentinel, 哨兵模式, 故障转移
- 主观下线与客观下线 — 哨兵模式, 主观下线, 客观下线
- 哨兵 Leader 选举 — 哨兵模式, Leader 选举, quorum
- 故障转移步骤 — 故障转移, 哨兵模式, 主从切换
- 新主节点选择规则 — 哨兵模式, 故障转移, 选主
- Redis 过期删除 — Redis, 过期删除, 过期字典
- 定期删除策略 — 过期删除, 定期删除, CPU
- Redis 内存淘汰 — Redis, 内存淘汰, LRU, LFU

## Repository Paths

- PDF: `collector/47caffb02a1d2f628c02e1ee74619b99.pdf`
- Extracted: `generated/extracted/47caffb02a1d2f628c02e1ee74619b99/full.md`
- Filtered: `generated/filtered/47caffb02a1d2f628c02e1ee74619b99/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
