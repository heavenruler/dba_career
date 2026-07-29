---
doc_id: "384e3ca8b05dbed3b6ca32222678ca7f"
title: "TiDB介绍及设计原理TiDB是一个支持海量数据存储的分布式数据库，TiDB需要解决分布式数据存储OLTP需求，并添加支 - 掘金"
aliases:
  - "TiDB介绍及设计原理TiDB是一个支持海量数据存储的分布式数据库，TiDB需要解决分布式数据存储OLTP需求，并添加支 - 掘金"
url: "https://juejin.cn/post/7415672130191556608"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "TiKV"
  - "分布式数据库"
  - "NewSQL"
  - "HTAP"
  - "LSM Tree"
  - "Raft"
  - "MVCC"
  - "分布式事务"
  - "SQL优化"
generated: true
---

# TiDB介绍及设计原理TiDB是一个支持海量数据存储的分布式数据库，TiDB需要解决分布式数据存储OLTP需求，并添加支 - 掘金

> [!info] Provenance
> - doc_id: `384e3ca8b05dbed3b6ca32222678ca7f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7415672130191556608)
> - PDF: [open local PDF](../../collector/384e3ca8b05dbed3b6ca32222678ca7f.pdf)

## Summary

本文介绍 TiDB 的设计原理，涵盖数据库发展、海量数据场景挑战、分布式数据库基础、TiKV 存储结构、Region/Raft/MVCC/事务机制、SQL 到 KV 的映射、计算下推与 HTAP/TiFlash 发展。

## Knowledge Outline

- 数据与数据库产品发展 — 数据库, DBMS, RDBMS, NoSQL, NewSQL, HTAP
- 数据库产品历史 — 数据库历史, NewSQL, HTAP
- 海量数据挑战 — 海量数据, 架构设计, 分布式系统, 云原生
- 分布式系统与CAP — 分布式系统, CAP, GFS, Bigtable, MapReduce
- TiDB设计目标 — TiDB, ACID, 云原生, HTAP
- PD调度职责 — TiDB, PD, 调度, 高可用
- TiKV LSM Tree — TiKV, RocksDB, LSM Tree, 存储引擎, 性能
- Region弹性扩容 — TiKV, Region, 弹性扩容, 高可用, 高并发
- Raft副本一致性 — TiKV, Raft, Replica, 一致性
- TiDB分布式事务 — TiDB, TiKV, 分布式事务, Percolator, Raft
- 事务隔离级别 — 事务隔离级别, ACID, TiDB
- TiKV MVCC机制 — TiKV, MVCC, Key-Value
- 逻辑表到KV映射 — TiDB, SQL引擎, Key-Value, 索引
- KV查询流程 — TiDB, SQL优化, Key Range, TiKV
- 分布式SQL运算 — TiDB, 分布式SQL, 计算下推, RPC, GroupBy
- SQL引擎优化 — TiDB, SQL优化, 计算下推, 分布式优化
- HTAP与TiFlash — HTAP, TiFlash, OLAP, OLTP, 列式存储, Raft Learner

## Repository Paths

- PDF: `collector/384e3ca8b05dbed3b6ca32222678ca7f.pdf`
- Extracted: `generated/extracted/384e3ca8b05dbed3b6ca32222678ca7f/full.md`
- Filtered: `generated/filtered/384e3ca8b05dbed3b6ca32222678ca7f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
