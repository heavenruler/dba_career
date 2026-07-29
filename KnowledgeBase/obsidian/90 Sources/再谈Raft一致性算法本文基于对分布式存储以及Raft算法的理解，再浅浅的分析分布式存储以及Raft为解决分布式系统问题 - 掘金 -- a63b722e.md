---
doc_id: "a63b722e337c94c448469cbaeda2780a"
title: "再谈Raft一致性算法本文基于对分布式存储以及Raft算法的理解，再浅浅的分析分布式存储以及Raft为解决分布式系统问题 - 掘金"
aliases:
  - "再谈Raft一致性算法本文基于对分布式存储以及Raft算法的理解，再浅浅的分析分布式存储以及Raft为解决分布式系统问题 - 掘金"
url: "https://juejin.cn/post/7393606971927248911"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Raft"
  - "分布式存储"
  - "CAP"
  - "共识算法"
  - "领导者选举"
  - "日志复制"
  - "成员变更"
  - "高可用"
  - "分布式协调"
  - "容错"
generated: true
---

# 再谈Raft一致性算法本文基于对分布式存储以及Raft算法的理解，再浅浅的分析分布式存储以及Raft为解决分布式系统问题 - 掘金

> [!info] Provenance
> - doc_id: `a63b722e337c94c448469cbaeda2780a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7393606971927248911)
> - PDF: [open local PDF](../../collector/a63b722e337c94c448469cbaeda2780a.pdf)

## Summary

文章从分布式存储、CAP、拜占庭问题到 Raft 的领导者选举、日志复制、成员变更与应用场景，集中梳理了多数派共识在非拜占庭环境下如何保证一致性与可用性。

## Knowledge Outline

- 分布式存储 — 分布式存储, 水平扩展, 垂直扩展, Replication, Partition, 高可用
- 拜占庭与多数派 — 拜占庭问题, PBFT, 多数派算法, 分布式一致性, 容错
- CAP定理 — CAP, 一致性, 可用性, 分区容错性, 分布式系统
- Raft 基础 — Raft, Term, currentTerm, 日志条目, 状态机, 副本集群
- 领导者选举 — 领导者选举, Candidate, Follower, Leader, 选举超时
- 活锁与 Prevote — 活锁, Prevote, 选举优化, 网络分区, Raft
- 日志复制与幽灵复现 — 日志复制, Leader Append-Only, Log Matching Property, 一致性, 幽灵复现
- 成员变更 — 成员变更, 联合共识, 单节点变更, AppendEntriesRPC, 2PC
- 应用场景 — 应用场景, 容错服务, 分布式协调, TCC, Zookeeper

## Repository Paths

- PDF: `collector/a63b722e337c94c448469cbaeda2780a.pdf`
- Extracted: `generated/extracted/a63b722e337c94c448469cbaeda2780a/full.md`
- Filtered: `generated/filtered/a63b722e337c94c448469cbaeda2780a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
