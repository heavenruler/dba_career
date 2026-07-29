---
doc_id: "0af9a91eb4e5ff6d75d3b951a1a9b6e2"
title: "专栏 - TIDB数据库在某省妇幼业务系统应用 | TiDB 社区"
aliases:
  - "专栏 - TIDB数据库在某省妇幼业务系统应用 | TiDB 社区"
url: "https://tidb.net/blog/04f1c28f"
source_domain: "tidb.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "MySQL"
  - "StarRocks"
  - "TiFlash"
  - "CloudCanal"
  - "数据库架构"
  - "数据库合并"
  - "SQL优化"
  - "备份恢复"
  - "灾备"
  - "自动化审计"
  - "SRE"
  - "运维"
generated: true
---

# 专栏 - TIDB数据库在某省妇幼业务系统应用 | TiDB 社区

> [!info] Provenance
> - doc_id: `0af9a91eb4e5ff6d75d3b951a1a9b6e2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://tidb.net/blog/04f1c28f)
> - PDF: [open local PDF](../../collector/0af9a91eb4e5ff6d75d3b951a1a9b6e2.pdf)

## Summary

这篇文章主要讲某省妇幼业务系统从 MySQL + DataX + CloudCanal + StarRocks 迁移/整合到 TiDB 的背景、痛点、选型、架构改造、SQL 优化、监控、备份恢复与容灾实践。对数据库合并、分析层替换、自动化审计、在线 DDL、灾备恢复和运维成本评估有较高知识价值。

## Knowledge Outline

- 业务背景 — 业务背景, 数据库, 医疗信息系统
- 原有架构与痛点 — MySQL, StarRocks, CloudCanal, DataX, 痛点, 数据库架构, DDL, SQL审计, 运维
- 数据库合并与选型 — TiDB, 数据库合并, MySQL兼容, 弹性扩展, 分布式事务, 高可用
- 新架构与审计平台 — TiDB, TiFlash, CloudCanal, Yearning, SQL审计, 自动化, 权限管理
- SQL 优化与监控 — SQL优化, 慢查询, 监控, TiDB Dashboard, 性能调优, StarRocks
- 删库删表恢复与备份 — TiDB, BR, Flashback, 备份恢复, 数据保护, MinIO
- 一地两中心与慢 SQL 处理 — TiCDC, 容灾, 一地两中心, pt-kill, 慢SQL, 告警, DML, DDL
- 效果与规划 — TiDB, 运维成本, 资源利用, JDBC, 架构演进, 规划

## Repository Paths

- PDF: `collector/0af9a91eb4e5ff6d75d3b951a1a9b6e2.pdf`
- Extracted: `generated/extracted/0af9a91eb4e5ff6d75d3b951a1a9b6e2/full.md`
- Filtered: `generated/filtered/0af9a91eb4e5ff6d75d3b951a1a9b6e2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
