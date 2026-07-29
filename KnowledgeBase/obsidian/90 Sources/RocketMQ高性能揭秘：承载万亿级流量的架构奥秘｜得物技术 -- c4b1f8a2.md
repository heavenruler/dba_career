---
doc_id: "c4b1f8a2766668109219f8713e36d377"
title: "RocketMQ高性能揭秘：承载万亿级流量的架构奥秘｜得物技术"
aliases:
  - "RocketMQ高性能揭秘：承载万亿级流量的架构奥秘｜得物技术"
url: "https://juejin.cn/post/7589325011543932966"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "RocketMQ"
  - "消息队列"
  - "分布式系统"
  - "架构设计"
  - "Broker"
  - "NameServer"
  - "CommitLog"
  - "ConsumeQueue"
  - "IndexFile"
  - "高可用"
  - "性能优化"
  - "Kafka对比"
generated: true
---

# RocketMQ高性能揭秘：承载万亿级流量的架构奥秘｜得物技术

> [!info] Provenance
> - doc_id: `c4b1f8a2766668109219f8713e36d377`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7589325011543932966)
> - PDF: [open local PDF](../../collector/c4b1f8a2766668109219f8713e36d377.pdf)

## Summary

本文解析 RocketMQ 的核心架构、NameServer、Broker 存储文件设计、CommitLog/ConsumeQueue/IndexFile、读写分离、写入与消费流程、Kafka 对比、高可用、刷盘、Producer/Consumer 模型与性能优化。

## Knowledge Outline

- RocketMQ 架构总览 — RocketMQ, 架构设计, Producer, Consumer, NameServer, Broker
- Broker 核心职责 — Broker, 高可用, 主从架构
- NameServer 设计 — NameServer, 服务发现, 路由, 最终一致性
- NameServer 与 Kafka KRaft — NameServer, Kafka, KRaft, 一致性, 运维成本
- Broker 存储目录 — Broker, 存储设计, CommitLog, ConsumeQueue, IndexFile
- CommitLog 设计 — CommitLog, 顺序写, 存储设计
- ConsumeQueue 设计 — ConsumeQueue, 消费索引, CommitLog, 性能优化
- IndexFile 结构 — IndexFile, 消息查询, 哈希索引
- IndexFile 查询流程 — IndexFile, 查询流程, Key查询
- 混合存储与读写分离 — 混合存储, 读写分离, CommitLog, ConsumerQueue, IndexFile
- 写入流程 — 写入流程, CommitLog, MappedFile, 顺序性
- 刷盘策略 — 刷盘, SYNC_FLUSH, ASYNC_FLUSH, 可靠性, 性能
- 异步索引构建 — ReputMessageService, 异步索引, ConsumeQueue, IndexFile
- 消费流程 — Consumer, 负载均衡, PullMessageService, offset
- 消费位点与重试 — 消费位点, OffsetStore, 重试, 死信队列, DLQ
- Kafka 与 RocketMQ 架构差异 — Kafka, RocketMQ, 读写一体, 读写分离, 架构设计
- 随机读取优化 — 随机IO, ConsumeQueue, PageCache, 性能优化
- PageCache 优化 — PageCache, CommitLog, 性能优化
- 高可用设计 — 高可用, Master-Slave, Dledger, Raft, 多副本
- 同步异步复制 — 同步复制, SYNC_MASTER, 强一致, 可靠性
- 异步复制配置 — 异步复制, ASYNC_MASTER, 吞吐量, 风险窗口
- 刷盘工程优化 — SYNC_FLUSH, ASYNC_FLUSH, PageCache, SSD, TPS
- Producer 发送模型 — Producer, 同步发送, 异步发送, 单向发送, 重试, 熔断
- Consumer 并发参数 — Consumer, 并发控制, 流控, PullBatchSize
- 核心特性支撑 — 顺序消息, 事务消息, 延时消息, 最终一致性
- 其他性能优化 — Zero-copy, sendfile, mmap, 堆外内存, 文件预热
- 架构设计启示 — 架构设计, NameServer, 写优化, 读优化

## Repository Paths

- PDF: `collector/c4b1f8a2766668109219f8713e36d377.pdf`
- Extracted: `generated/extracted/c4b1f8a2766668109219f8713e36d377/full.md`
- Filtered: `generated/filtered/c4b1f8a2766668109219f8713e36d377/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
