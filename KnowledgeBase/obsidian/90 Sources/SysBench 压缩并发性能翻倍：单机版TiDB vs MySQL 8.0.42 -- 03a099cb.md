---
doc_id: "03a099cb3391000ab587847a092ef3f8"
title: "SysBench 压缩并发性能翻倍：单机版TiDB vs MySQL 8.0.42"
aliases:
  - "SysBench 压缩并发性能翻倍：单机版TiDB vs MySQL 8.0.42"
url: "https://www.modb.pro/db/1966716469840982016"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "数据库"
  - "MySQL"
  - "TiDB"
  - "Sysbench"
  - "OLTP"
  - "性能测试"
  - "并发测试"
  - "存储效率"
  - "技术选型"
generated: true
---

# SysBench 压缩并发性能翻倍：单机版TiDB vs MySQL 8.0.42

> [!info] Provenance
> - doc_id: `03a099cb3391000ab587847a092ef3f8`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1966716469840982016)
> - PDF: [open local PDF](../../collector/03a099cb3391000ab587847a092ef3f8.pdf)

## Summary

本文使用 Sysbench 对 MySQL 8.0.42 与单节点 TiDB 进行 OLTP 混合读写、点查询、索引更新、并发梯度与存储大小对比，保留了测试命令、关键输出、性能对比、选型建议与测试局限性。

## Knowledge Outline

- 测试目标 — Sysbench, MySQL, TiDB, 性能测试
- MySQL 测试范围 — MySQL, Sysbench, 测试范围
- MySQL 数据准备 — MySQL, Sysbench, Prepare
- MySQL 缓存预热 — MySQL, InnoDB, Warm Up, 只读测试
- MySQL OLTP 读写 — MySQL, OLTP, 读写测试, TPS, 延迟
- MySQL 并发梯度 — MySQL, 并发测试, 扩展性, OLTP
- MySQL 存储大小 — MySQL, information_schema, 存储大小, InnoDB
- TiDB 测试提示 — TiDB, Sysbench, 事务模型, 测试注意事项
- TiDB 缓存预热 — TiDB, TiKV, Block Cache, Warm Up
- TiDB OLTP 读写 — TiDB, OLTP, 读写测试, TPS, 延迟
- TiDB 点查询 — TiDB, Point Select, 点查询
- TiDB 索引更新 — TiDB, 索引更新, Update Index
- TiDB 并发梯度 — TiDB, 并发测试, OLTP, 延迟
- TiDB 存储大小 — TiDB, TiKV, RocksDB, 存储大小, 压缩比
- 核心指标对比 — MySQL, TiDB, 性能对比, 压缩比, 并发扩展
- 性能差异总结 — 架构设计, MySQL, TiDB, 技术选型
- 业务选型建议 — 技术选型, MySQL, TiDB, OLTP, HTAP
- 测试局限 — 测试局限, TiDB, 分布式架构, 横向扩展
- 总结展望 — MySQL, TiDB, 高可用, HTAP, 分布式数据库

## Repository Paths

- PDF: `collector/03a099cb3391000ab587847a092ef3f8.pdf`
- Extracted: `generated/extracted/03a099cb3391000ab587847a092ef3f8/full.md`
- Filtered: `generated/filtered/03a099cb3391000ab587847a092ef3f8/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
