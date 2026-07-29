---
doc_id: "c9cdf8ce5968990b8f343b5fb685942b"
title: "分布式共识算法哪个最通用？Raft协议占有一席之地！（分布式共识算法-中）"
aliases:
  - "分布式共识算法哪个最通用？Raft协议占有一席之地！（分布式共识算法-中）"
url: "https://mp.weixin.qq.com/s/eAoqWT4f0bqyrHiWQw6zWA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Raft"
  - "分布式共识"
  - "分布式系统"
  - "日志复制"
  - "选主"
  - "成员变更"
  - "Paxos"
generated: true
---

# 分布式共识算法哪个最通用？Raft协议占有一席之地！（分布式共识算法-中）

> [!info] Provenance
> - doc_id: `c9cdf8ce5968990b8f343b5fb685942b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/eAoqWT4f0bqyrHiWQw6zWA)
> - PDF: [open local PDF](../../collector/c9cdf8ce5968990b8f343b5fb685942b.pdf)

## Summary

本文系统整理了 Raft 的核心机制，包括节点状态、任期与选举、日志复制与一致性、网络分区处理、成员变更，以及与 Multi-Paxos 的差异。内容偏实现视角，适合用于理解分布式共识、复制日志和集群成员管理的基础设计。

## Knowledge Outline

- Raft 概览与节点状态 — Raft, 分布式共识, 节点状态
- 任期与选举 — Raft, 选主, 任期, 投票, 随机超时
- 日志复制与一致性 — Raft, 日志复制, 一致性, commitIndex, applyIndex
- 网络分区 — Raft, 网络分区, 故障恢复, 一致性
- 成员变更与扩展 — Raft, 成员变更, 集群扩容, NO_OP, 领导者
- 性能扩展与 Paxos 对比 — Raft, Paxos, 性能优化, 分片, 对比

## Repository Paths

- PDF: `collector/c9cdf8ce5968990b8f343b5fb685942b.pdf`
- Extracted: `generated/extracted/c9cdf8ce5968990b8f343b5fb685942b/full.md`
- Filtered: `generated/filtered/c9cdf8ce5968990b8f343b5fb685942b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
