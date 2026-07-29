---
doc_id: "9ab508ea9d37ca7e68022a4d97c17d86"
title: "高性能无锁并发框架Disruptor，太强了！前言 Disruptor是一个开源框架，研发的初衷是为了解决高并发下队列锁 - 掘金"
aliases:
  - "高性能无锁并发框架Disruptor，太强了！前言 Disruptor是一个开源框架，研发的初衷是为了解决高并发下队列锁 - 掘金"
url: "https://juejin.cn/post/7325684511253839898"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Java"
  - "并发"
  - "无锁队列"
  - "性能调优"
  - "SRE"
  - "面试"
generated: true
---

# 高性能无锁并发框架Disruptor，太强了！前言 Disruptor是一个开源框架，研发的初衷是为了解决高并发下队列锁 - 掘金

> [!info] Provenance
> - doc_id: `9ab508ea9d37ca7e68022a4d97c17d86`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7325684511253839898)
> - PDF: [open local PDF](../../collector/9ab508ea9d37ca7e68022a4d97c17d86.pdf)

## Summary

这篇文章介绍了 Disruptor 的产生背景、核心概念、等待策略、使用示例、设计原理、数据结构与典型使用场景。重点是用环形数组、序列号和 CAS 实现高性能无锁并发，并说明它适合顺序处理、生产者-消费者场景。

## Knowledge Outline

- 前言与动机 — Java, 并发, 无锁队列, 性能
- 为什么会产生 — Java, 并发, CAS, 无锁设计, 性能
- 基本概念 — Java, 并发, RingBuffer, Sequence, 架构
- 等待策略 — Java, 并发, 低延迟, 等待策略, 性能调优
- 使用举例 — Java, Disruptor, 代码示例, 生产者-消费者, RingBuffer
- 核心设计原理 — Java, 并发, 无锁设计, 环形数组, CAS, 性能
- 数据结构 — RingBuffer, Sequence, 数据结构, Java, 并发
- Sequence — Sequence, HashMap, 索引, 位运算, 性能
- 写数据流程 — 写入流程, 生产者, RingBuffer, 并发
- 使用场景 — 使用场景, 性能对比, 生产者-消费者, MySQL, ElasticSearch, 顺序处理

## Repository Paths

- PDF: `collector/9ab508ea9d37ca7e68022a4d97c17d86.pdf`
- Extracted: `generated/extracted/9ab508ea9d37ca7e68022a4d97c17d86/full.md`
- Filtered: `generated/filtered/9ab508ea9d37ca7e68022a4d97c17d86/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
