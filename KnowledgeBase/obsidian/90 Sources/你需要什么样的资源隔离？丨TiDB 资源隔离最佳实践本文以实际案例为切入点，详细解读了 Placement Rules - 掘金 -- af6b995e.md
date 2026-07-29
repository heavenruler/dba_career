---
doc_id: "af6b995ef368286d525216dce480e634"
title: "你需要什么样的资源隔离？丨TiDB 资源隔离最佳实践本文以实际案例为切入点，详细解读了 Placement Rules - 掘金"
aliases:
  - "你需要什么样的资源隔离？丨TiDB 资源隔离最佳实践本文以实际案例为切入点，详细解读了 Placement Rules - 掘金"
url: "https://juejin.cn/post/7460215684438818850"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库"
  - "资源隔离"
  - "Placement Rules"
  - "Resource Control"
  - "Runaway Queries"
  - "DBA"
  - "性能优化"
  - "HTAP"
generated: true
---

# 你需要什么样的资源隔离？丨TiDB 资源隔离最佳实践本文以实际案例为切入点，详细解读了 Placement Rules - 掘金

> [!info] Provenance
> - doc_id: `af6b995ef368286d525216dce480e634`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7460215684438818850)
> - PDF: [open local PDF](../../collector/af6b995ef368286d525216dce480e634.pdf)

## Summary

本文介紹 TiDB 資源隔離實務，涵蓋 Placement Rules in SQL 的資料級物理隔離、Follower 副本就近讀、Resource Control 的 RU 流控隔離、Runaway Queries 管理，以及後台任務資源限制等場景。

## Knowledge Outline

- 導讀 — TiDB, 资源隔离, 数据库性能优化
- 隔離層次 — TiDB, 资源隔离
- 中大型系統資料隔離 — Placement Rules in SQL, 物理隔离, TiDB, DBA
- Placement Rules 完全獨占 — Placement Rules in SQL, SQL, TiDB
- Placement Rules Leader 約束 — Placement Rules in SQL, leader_constraints, TiDB
- 系統內負載隔離 — OLTP, ETL, 读写分离, Follower Read, TiFlash
- 就近讀設定 — TiDB, closest-replicas, Follower Read
- 三機房 Placement Rule — Placement Rule, 多机房, TiKV, Follower
- 流控隔離價值 — Resource Control, RU, 流控隔离, 资源管理
- SaaS 租戶資源組 — Resource Control, SaaS, 多租户, RU_PER_SEC
- 批量負載隔離 — Resource Control, 批量作业, OLTP, 负载隔离
- 批量作業資源組 — Resource Control, 批量作业, SQL
- Runaway Queries — Runaway Queries, QUERY_WATCH, QUERY_LIMIT, TiDB
- SQL 限流熔斷 — QUERY_WATCH, SQL DIGEST, SQL限流, SQL熔断
- QUERY_LIMIT 自適應管理 — QUERY_LIMIT, 自适应管理, Runaway Queries
- QUERY_LIMIT 範例 — QUERY_LIMIT, COOLDOWN, SWITCH_GROUP, Resource Control
- 後台任務隔離 — 后台任务, DDL, Resource Control, TiKV
- DDL 後台任務限制 — DDL, BACKGROUND, UTILIZATION_LIMIT, TiDB

## Repository Paths

- PDF: `collector/af6b995ef368286d525216dce480e634.pdf`
- Extracted: `generated/extracted/af6b995ef368286d525216dce480e634/full.md`
- Filtered: `generated/filtered/af6b995ef368286d525216dce480e634/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
