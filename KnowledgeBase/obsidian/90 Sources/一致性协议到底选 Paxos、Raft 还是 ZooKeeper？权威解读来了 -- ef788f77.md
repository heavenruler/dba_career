---
doc_id: "ef788f772e3b94f5adcf1c9654232a05"
title: "一致性协议到底选 Paxos、Raft 还是 ZooKeeper？权威解读来了"
aliases:
  - "一致性协议到底选 Paxos、Raft 还是 ZooKeeper？权威解读来了"
url: "https://mp.weixin.qq.com/s/XgTzqJa03o2y41DitvYxvg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "分布式系统"
  - "一致性协议"
  - "Paxos"
  - "Raft"
  - "ZooKeeper"
  - "架构设计"
  - "性能调优"
generated: true
---

# 一致性协议到底选 Paxos、Raft 还是 ZooKeeper？权威解读来了

> [!info] Provenance
> - doc_id: `ef788f772e3b94f5adcf1c9654232a05`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/XgTzqJa03o2y41DitvYxvg)
> - PDF: [open local PDF](../../collector/ef788f772e3b94f5adcf1c9654232a05.pdf)

## Summary

本文系统对比了 Paxos、Raft 与 ZooKeeper 在分布式一致性中的定位、原理、复杂度、性能与适用场景，并给出按一致性要求、团队能力、项目周期与业务约束来选型的建议。

## Knowledge Outline

- 前言与挑战 — 分布式系统, CAP定理, 一致性, 架构设计
- Paxos — Paxos, 分布式一致性, 理论基础, 实现复杂度
- Raft — Raft, 分布式一致性, Leader选举, 日志复制
- ZooKeeper — ZooKeeper, ZAB, 分布式协调, 分布式锁, 配置管理
- 对比分析 — Paxos, Raft, ZooKeeper, 性能, 工程实践, 选型
- 场景选择 — Paxos, Raft, ZooKeeper, 选型, 应用场景, 分布式系统
- 总结建议 — 一致性协议, 选型, 架构决策, 分布式系统

## Repository Paths

- PDF: `collector/ef788f772e3b94f5adcf1c9654232a05.pdf`
- Extracted: `generated/extracted/ef788f772e3b94f5adcf1c9654232a05/full.md`
- Filtered: `generated/filtered/ef788f772e3b94f5adcf1c9654232a05/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
