---
doc_id: "c878673f99e69883937d54a6b5b740df"
title: "【建议收藏】7000+字的TIDB保姆级简介，你见过吗## TIDB简介 ![Database of Databases - 掘金"
aliases:
  - "【建议收藏】7000+字的TIDB保姆级简介，你见过吗## TIDB简介 ![Database of Databases - 掘金"
url: "https://juejin.cn/post/7213956241613684797"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "NewSQL"
  - "分布式数据库"
  - "MySQL"
  - "HTAP"
  - "OLTP"
  - "OLAP"
  - "Raft"
  - "高可用"
  - "架构设计"
generated: true
---

# 【建议收藏】7000+字的TIDB保姆级简介，你见过吗## TIDB简介 ![Database of Databases - 掘金

> [!info] Provenance
> - doc_id: `c878673f99e69883937d54a6b5b740df`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7213956241613684797)
> - PDF: [open local PDF](../../collector/c878673f99e69883937d54a6b5b740df.pdf)

## Summary

本文介绍 TiDB/NewSQL 的定位、核心特性、整体架构、TiKV Region 调度与高可用机制、应用场景，以及 TiDB 与 MySQL 的兼容性差异。

## Knowledge Outline

- TiDB 定义 — TiDB, NewSQL, HTAP, MySQL
- 传统 SQL 瓶颈 — 传统数据库, 分库分表, 分布式架构
- NoSQL 问题 — NoSQL, 一致性, SQL
- NewSQL 特性 — NewSQL, ACID, 弹性伸缩, 高可用
- TiDB 来源 — TiDB, PingCAP, Spanner, F1
- TiDB 核心特性 — TiDB, ACID, Raft, 高可用, 水平扩展
- HTAP 与云原生 — HTAP, TiKV, TiFlash, TiSpark, Kubernetes, 云原生
- MySQL 兼容性 — TiDB, MySQL, 数据迁移
- OLTP 定义 — OLTP, 事务处理, 数据库
- OLAP 定义 — OLAP, 数据仓库, 分析处理
- OLTP OLAP 对比 — OLTP, OLAP, 数据库设计
- TiDB 优势 — TiDB, 分布式架构, 高可用, ACID
- TiDB 组件 — TiDB, 架构, TiKV, PD, TiSpark
- TiDB Server — TiDB Server, SQL, 负载均衡, 水平扩展
- PD Server — PD, Placement Driver, Raft, 事务 ID, 负载均衡
- TiKV Server — TiKV, Key-Value, Region, Raft Group
- TiSpark TiFlash — TiSpark, TiFlash, OLAP, 列存储
- TiKV 整体架构 — TiKV, Region, Leader, 副本, 水平扩展
- Region 分裂合并 — Region, TiKV, 调度
- Region 调度 — Region, Raft, Leader, Follower, Learner, PD
- 分布式事务 — TiKV, 分布式事务, 两阶段提交, ACID
- 高可用架构 — 高可用, TiDB, TiKV, PD
- TiDB 高可用 — TiDB, 高可用, 负载均衡
- PD 高可用 — PD, Raft, 高可用
- TiKV 高可用 — TiKV, Raft, Region, 高可用
- MySQL 分片合并 — TiDB, MySQL, 分库分表, Syncer
- 替换 MySQL — TiDB, MySQL, OLTP, 水平扩容
- 数据仓库场景 — TiDB, 数据仓库, OLAP, TiSpark, Spark SQL
- 作为其他系统模块 — TiDB, TiKV, Key-Value, API, Redis, HBase
- 兼容性对比 — TiDB, MySQL, 兼容性, 运维工具
- 不支持的 MySQL 特性 — TiDB, MySQL, 兼容性限制
- 自增 ID 限制 — TiDB, AUTO_INCREMENT, 自增 ID
- SELECT 限制 — TiDB, SELECT, MySQL, 兼容性限制
- 视图限制 — TiDB, 视图, 兼容性限制
- 默认设置差异 — TiDB, MySQL, 字符集, 排序规则
- 大小写敏感参数 — TiDB, MySQL, lower_case_table_names
- timestamp 参数 — TiDB, MySQL, timestamp, explicit_defaults_for_timestamp
- 外键支持 — TiDB, MySQL, 外键

## Repository Paths

- PDF: `collector/c878673f99e69883937d54a6b5b740df.pdf`
- Extracted: `generated/extracted/c878673f99e69883937d54a6b5b740df/full.md`
- Filtered: `generated/filtered/c878673f99e69883937d54a6b5b740df/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
