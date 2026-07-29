---
doc_id: "58c1dbeba8e91e42b491ec2aa92ca656"
title: "数据规模超 1PB ，揭秘网易游戏规模化 TiDB SaaS 服务建设实践_数据库_田维繁_InfoQ精选文章"
aliases:
  - "数据规模超 1PB ，揭秘网易游戏规模化 TiDB SaaS 服务建设实践_数据库_田维繁_InfoQ精选文章"
url: "https://www.infoq.cn/article/JUuV6eTWSmijj8rFkGPI"
source_domain: "www.infoq.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库SaaS"
  - "MySQL"
  - "DTS"
  - "TiCDC"
  - "备份恢复"
  - "资源隔离"
  - "监控调度"
  - "性能优化"
  - "高并发"
  - "SRE"
  - "案例"
generated: true
---

# 数据规模超 1PB ，揭秘网易游戏规模化 TiDB SaaS 服务建设实践_数据库_田维繁_InfoQ精选文章

> [!info] Provenance
> - doc_id: `58c1dbeba8e91e42b491ec2aa92ca656`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.infoq.cn/article/JUuV6eTWSmijj8rFkGPI)
> - PDF: [open local PDF](../../collector/58c1dbeba8e91e42b491ec2aa92ca656.pdf)

## Summary

本文是网易游戏 TiDB SaaS 服务建设实践的案例整理，重点讲了数据库服务生态、套餐定制与资源隔离、备份恢复、MySQL/TiDB 与异构数据同步、监控调度，以及在 36 万 QPS 场景下的热点、GC、Region 过大和 raft 抖动问题处理。

## Knowledge Outline

- 数据库现状与使用场景 — TiDB, 数据库, SaaS, MySQL, OLTP, OLAP, 架构
- 套餐定制与资源隔离 — TiDB, 资源隔离, 虚拟化, LXC, LVM, 性能, SaaS
- 升级与备份恢复 — TiDB, 备份恢复, 快照备份, BR, S3, 灾备, 恢复
- 数据同步 — DTS, TiCDC, MySQL, Kafka, 数据同步, 异构同步, 迁移
- 监控与调度优化 — 监控, 调度, 热点, GC, TiKV, leader抖动, 告警, 自动化
- 高并发运维 — 高并发, TiDB, GC, Region, raft, AUTO_RANDOM, 分区表, 滚动升级, 性能优化

## Repository Paths

- PDF: `collector/58c1dbeba8e91e42b491ec2aa92ca656.pdf`
- Extracted: `generated/extracted/58c1dbeba8e91e42b491ec2aa92ca656/full.md`
- Filtered: `generated/filtered/58c1dbeba8e91e42b491ec2aa92ca656/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
