---
doc_id: "2c5c534818a5d59287014c32c39219cd"
title: "一次线上脑裂故障让我彻底搞懂了Redis集群原理这又是一个线上大规模故障引发的案例，而且居然是罕见的“脑裂”故障，只能说 - 掘金"
aliases:
  - "一次线上脑裂故障让我彻底搞懂了Redis集群原理这又是一个线上大规模故障引发的案例，而且居然是罕见的“脑裂”故障，只能说 - 掘金"
url: "https://juejin.cn/post/7411799494415663138"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "Redis Cluster"
  - "脑裂"
  - "事故复盘"
  - "Gossip"
  - "slot迁移"
  - "config epoch"
  - "运维"
  - "故障排查"
generated: true
---

# 一次线上脑裂故障让我彻底搞懂了Redis集群原理这又是一个线上大规模故障引发的案例，而且居然是罕见的“脑裂”故障，只能说 - 掘金

> [!info] Provenance
> - doc_id: `2c5c534818a5d59287014c32c39219cd`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7411799494415663138)
> - PDF: [open local PDF](../../collector/2c5c534818a5d59287014c32c39219cd.pdf)

## Summary

本文是 Redis 集群缩容迁移 slot 时触发脑裂故障的线上事故复盘，重点解释了 Gossip 消息传播、config epoch 冲突处理、slot 迁入迁出并发导致归属被覆盖的机制，以及操作和社区修复方向。

## Knowledge Outline

- 故障背景 — Redis, 缩容, 事故背景
- 故障现场 — Redis Cluster, MOVED, slot, 故障排查
- 故障时间线 — 时间线, 脑裂, Redis
- 内部通信问题入口 — Redis Cluster, slot分布
- slot分布传播 — Gossip, PING-PONG, config epoch, slot
- 节点维护信息 — Redis源码, configEpoch, currentEpoch, slot owner
- Gossip处理逻辑 — Gossip, UPDATE消息, config epoch, 冲突处理
- 归属权覆盖 — slot迁出, Gossip, 覆盖, config epoch
- slot迁移机制 — slot迁移, cluster setslot, configEpoch
- 问题条件 — 根因分析, slot传播, config epoch, 脑裂
- 现场还原 — 现场还原, Redis Cluster, UPDATE消息, epoch
- 原因总结 — 根因, 迁入迁出, 操作失误, slot分布
- 修复方向 — 修复, Redis7.0, 迁移计划, 运维
- 事故反思 — 事故复盘, 操作风险, Redis bug

## Repository Paths

- PDF: `collector/2c5c534818a5d59287014c32c39219cd.pdf`
- Extracted: `generated/extracted/2c5c534818a5d59287014c32c39219cd/full.md`
- Filtered: `generated/filtered/2c5c534818a5d59287014c32c39219cd/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
