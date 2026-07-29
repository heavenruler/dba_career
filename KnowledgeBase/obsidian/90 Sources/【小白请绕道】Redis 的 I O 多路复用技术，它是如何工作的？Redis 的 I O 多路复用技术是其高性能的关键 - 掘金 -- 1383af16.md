---
doc_id: "1383af16f652ba96ef3a1a2ccd7811cb"
title: "【小白请绕道】Redis 的 I/O 多路复用技术，它是如何工作的？Redis 的 I/O 多路复用技术是其高性能的关键 - 掘金"
aliases:
  - "【小白请绕道】Redis 的 I/O 多路复用技术，它是如何工作的？Redis 的 I/O 多路复用技术是其高性能的关键 - 掘金"
url: "https://juejin.cn/post/7417746324387135539"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "I/O多路复用"
  - "epoll"
  - "Reactor"
  - "Linux"
  - "高并发"
  - "性能优化"
  - "C语言"
generated: true
---

# 【小白请绕道】Redis 的 I/O 多路复用技术，它是如何工作的？Redis 的 I/O 多路复用技术是其高性能的关键 - 掘金

> [!info] Provenance
> - doc_id: `1383af16f652ba96ef3a1a2ccd7811cb`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7417746324387135539)
> - PDF: [open local PDF](../../collector/1383af16f652ba96ef3a1a2ccd7811cb.pdf)

## Summary

本文解释了 Redis 为什么依赖 I/O 多路复用来处理高并发连接，比较了 select、poll、epoll、kqueue 的工作方式，说明了 Redis Reactor 模式的事件分派逻辑，并给出 epoll 的示例代码与性能优化建议。

## Knowledge Outline

- I/O 多路复用 — Redis, I/O多路复用, 高并发
- 工作方式 — I/O多路复用, 网络服务器, 上下文切换
- I/O 多路复用技术 — select, poll, epoll, kqueue, Linux, BSD
- 工作流程 — I/O多路复用, 工作流程, 网络服务器
- Reactor 模式 — Redis, Reactor模式, 事件驱动, I/O多路复用
- Reactor 模式的代码实现 — epoll, Reactor模式, C语言, Linux
- 性能优化 — 性能优化, Redis, Pipeline, Lettuce
- 总结 — Redis, I/O多路复用, 高性能, 多线程

## Repository Paths

- PDF: `collector/1383af16f652ba96ef3a1a2ccd7811cb.pdf`
- Extracted: `generated/extracted/1383af16f652ba96ef3a1a2ccd7811cb/full.md`
- Filtered: `generated/filtered/1383af16f652ba96ef3a1a2ccd7811cb/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
