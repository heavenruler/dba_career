---
doc_id: "34f15cccf3863a41e0bad97c386b1e32"
title: "RocketMQ大战Kafka：Kafka有100W级吞吐，为何却死磕RocketMQ？"
aliases:
  - "RocketMQ大战Kafka：Kafka有100W级吞吐，为何却死磕RocketMQ？"
url: "https://mp.weixin.qq.com/s/q6xmxqdwMEvBZAjJLZwfjA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "消息中间件"
  - "Kafka"
  - "RocketMQ"
  - "架构设计"
  - "高并发"
  - "电商系统"
  - "性能调优"
  - "系统设计面试"
generated: true
---

# RocketMQ大战Kafka：Kafka有100W级吞吐，为何却死磕RocketMQ？

> [!info] Provenance
> - doc_id: `34f15cccf3863a41e0bad97c386b1e32`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/q6xmxqdwMEvBZAjJLZwfjA)
> - PDF: [open local PDF](../../collector/34f15cccf3863a41e0bad97c386b1e32.pdf)

## Summary

本文围绕 Kafka 与 RocketMQ 的消息中间件选型，比较二者在存储模型、零拷贝、批量压缩、扩展能力、事务/延迟/顺序消息等方面的差异，并给出电商大促场景下选择 RocketMQ 及系统级削峰优化的技术论证。

## Knowledge Outline

- 设计哲学 — Kafka, RocketMQ, 技术选型
- 存储模型差异 — 存储模型, Kafka, RocketMQ, 性能
- 写入路径拷贝 — RocketMQ, 内存拷贝, Broker, 性能
- Kafka IO 优化 — Kafka, IO, PageCache, mmap, 顺序写
- RocketMQ 索引结构 — RocketMQ, CommitLog, ConsumeQueue, 索引
- 二级索引流程 — RocketMQ, 索引构建, CommitLog, ConsumeQueue
- 批量压缩与零拷贝 — Kafka, 批量发送, 压缩, 零拷贝
- 水平扩展对比 — 水平扩展, Kafka, RocketMQ, Partition, Queue
- RocketMQ 扩容困境 — RocketMQ, 扩容, Queue, 运维
- 功能与性能权衡 — 性能, RocketMQ, Kafka, 技术选型
- 事务消息场景 — RocketMQ, 事务消息, 电商, 一致性
- 延迟消息场景 — RocketMQ, 延迟消息, 订单系统
- 顺序消息场景 — RocketMQ, 顺序消息, 订单状态
- 生产者优化 — RocketMQ, 性能调优, 生产者, 批量发送, 压缩
- Broker 配置优化 — RocketMQ, Broker, 异步刷盘, 性能调优
- Topic Queue 扩容 — RocketMQ, Topic, Queue, 扩容
- Broker 集群扩容 — RocketMQ, Broker, 主从架构, 扩容, 容灾
- 网关削峰 — 削峰填谷, RocketMQ, API网关, 高并发
- 选型总结 — 技术选型, Kafka, RocketMQ, 架构设计
- RocketMQ 写磁盘复制次数 — RocketMQ, CPU拷贝, Netty, mmap, CommitLog
- 核心复制 1 — RocketMQ, Netty, DirectByteBuffer, 网络栈
- 核心复制 2 — RocketMQ, mmap, CommitLog, MappedByteBuffer
- 堆外内存路径 — RocketMQ, 堆外内存, JVM, GC, Direct Memory
- CommitLog 不进 JVM 堆 — RocketMQ, CommitLog, JVM堆, 堆外内存, GC
- Disruptor 缓冲架构 — Disruptor, 削峰, RocketMQ, 批量发送, 降级
- 三级降级能力 — 降级, 高可用, RocketMQ, 大促
- 架构分层选型 — 架构分层, 技术选型, Kafka, RocketMQ, 削峰

## Repository Paths

- PDF: `collector/34f15cccf3863a41e0bad97c386b1e32.pdf`
- Extracted: `generated/extracted/34f15cccf3863a41e0bad97c386b1e32/full.md`
- Filtered: `generated/filtered/34f15cccf3863a41e0bad97c386b1e32/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
