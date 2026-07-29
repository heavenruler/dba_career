---
doc_id: "de0b10ad6a3933d4997a21c64f7947d7"
title: "Raft一致性算法Raft算法是分布式存储比较常用的一致性算法之一，本文主要还是按照论文顺序来拆分讲解下Raft算法。 - 掘金"
aliases:
  - "Raft一致性算法Raft算法是分布式存储比较常用的一致性算法之一，本文主要还是按照论文顺序来拆分讲解下Raft算法。 - 掘金"
url: "https://juejin.cn/post/7390188606256840704"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Raft"
  - "分布式系统"
  - "一致性算法"
  - "日志复制"
  - "Leader Election"
  - "系统设计"
  - "后端"
generated: true
---

# Raft一致性算法Raft算法是分布式存储比较常用的一致性算法之一，本文主要还是按照论文顺序来拆分讲解下Raft算法。 - 掘金

> [!info] Provenance
> - doc_id: `de0b10ad6a3933d4997a21c64f7947d7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7390188606256840704)
> - PDF: [open local PDF](../../collector/de0b10ad6a3933d4997a21c64f7947d7.pdf)

## Summary

本文讲解 Raft 一致性算法的基础概念、服务器状态、任期、日志结构、RPC、领导者选举、日志复制、安全性、成员变更与日志压缩。

## Knowledge Outline

- 算法背景 — Raft, Paxos, 分布式系统
- 复制状态机 — 复制状态机, 日志, 一致性算法
- 服务器状态 — Follower, Candidate, Leader, 状态机
- 任期 — term, Leader Election, 任期
- 日志结构 — log entry, log index, 日志
- 内部状态参数 — currentTerm, votedFor, commitIndex, nextIndex, matchIndex
- Raft五大特性 — Election Safety, Leader Append-Only, Log Matching, Leader Completeness, State Machine Safety
- AppendEntriesRPC — AppendEntriesRPC, 日志复制, RPC
- RequestVoteRPC — RequestVoteRPC, Leader Election, 投票
- 领导者选举 — Leader Election, election timeout, 多数派
- 选举无结果 — 选票分割, election timeout, Leader Election
- 日志复制 — Log Replication, AppendEntriesRPC, Leader Append-Only
- 日志匹配特性 — Log Matching, prevLogIndex, prevLogTerm
- 日志冲突修复 — nextIndex, 日志冲突, Follower
- 选举限制 — Leader Election Restriction, Leader Completeness, RequestVoteRPC
- 复制提交规则 — Log Replication Rules, commit, 多数派
- 安全性推理 — Safety, State Machine Safety, Leader Completeness
- 时间与可用性 — Timing, availability, broadcastTime, electionTimeout, MTBF
- 成员变更 — Cluster membership changes, 脑裂, 集群配置
- 联合共识 — joint consensus, 两阶段方法, 成员变更
- 成员变更阶段 — C-old, C-new, joint consensus
- 成员变更故障 — 成员变更, Leader Crash, C-old,new
- 日志压缩 — Log Compaction, 快照, 状态机
- 结论 — 多数派算法, 安全性, 活性

## Repository Paths

- PDF: `collector/de0b10ad6a3933d4997a21c64f7947d7.pdf`
- Extracted: `generated/extracted/de0b10ad6a3933d4997a21c64f7947d7/full.md`
- Filtered: `generated/filtered/de0b10ad6a3933d4997a21c64f7947d7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
