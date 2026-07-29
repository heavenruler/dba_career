---
doc_id: "ab87bac92f55d2e012d82cbf529154f5"
title: "Upgrading GitHub.com to MySQL 8.0 - The GitHub Blog"
aliases:
  - "Upgrading GitHub.com to MySQL 8.0 - The GitHub Blog"
url: "https://github.blog/engineering/upgrading-github-com-to-mysql-8-0/"
source_domain: "github.blog"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "資料庫升級"
  - "高可用性"
  - "SRE"
  - "DevOps"
  - "可觀測性"
  - "rollback"
  - "replication"
  - "Vitess"
  - "平台工程"
  - "事故預防"
generated: true
---

# Upgrading GitHub.com to MySQL 8.0 - The GitHub Blog

> [!info] Provenance
> - doc_id: `ab87bac92f55d2e012d82cbf529154f5`
> - source_kind: `llm_filtered`
> - source: [original URL](https://github.blog/engineering/upgrading-github-com-to-mysql-8-0/)
> - PDF: [open local PDF](../../collector/ab87bac92f55d2e012d82cbf529154f5.pdf)

## Summary

GitHub 描述將 1200+ MySQL hosts 升級到 MySQL 8.0 的動機、基礎架構、準備工作、分階段升級策略、rollback 設計、Vitess 與 replication delay 等挑戰，以及對可觀測性、測試、分區、工具與自動化的經驗教訓。

## Knowledge Outline

- 升級背景與規模 — MySQL, SLO, 資料庫升級
- 升級動機 — MySQL 8.0, 安全更新, 效能
- GitHub MySQL 基礎架構 — MySQL, sharding, Vitess, 高可用性, SLO
- 升級需求 — SLO, SLA, rollback, mixed-version
- 基礎設施準備 — benchmarking, automation, MySQL 5.7, MySQL 8.0
- 應用相容性 — CI, 相容性測試, pre-prod
- 內部溝通與排程透明 — 溝通, 專案管理, 升級排程
- 升級策略總覽 — 高可用性, rollback, 升級策略
- Step 1: Rolling Replica Upgrades — replica, monitoring, query latency, rollback
- Step 2: Update Replication Topology — replication topology, primary candidate, rollback
- Step 3: Promote MySQL 8.0 Host To Primary — primary, failover, Orchestrator, blacklist
- Step 4 And Step 5 — backup, validation, traffic cycle
- Rollback 能力 — rollback, backwards replication, MySQL 5.7, MySQL 8.0
- Rollback 相容性問題 — utf8mb4, collation, roles, privileges, replication
- Client Configuration 一致性 — Rails, client configuration, backward replication
- Vitess 升級挑戰 — Vitess, VTgate, sharding, query cache, Java client
- Replication Delay Bug — replication delay, MySQL 8.0.28, replica_preserve_commit_order, bug
- Replication Delay 因應 — GTID, write-heavy, freno, replication lag
- CI 通過但 Production 失敗 — production, WHERE IN, query sampling, observability, Solarwinds DPM
- 升級成果與觀察 — testing, performance tuning, observability, rollback
- Rollback 與可觀測性經驗 — rollback, observability, Trilogy, Rails
- 多語言 Client 設定風險 — client configuration, frameworks, rollback window, guidelines
- 資料分區降低 Blast Radius — partitioning, blast radius, fleet management, observability
- 未來自動化方向 — automation, self-healing, fleet management, maintenance

## Repository Paths

- PDF: `collector/ab87bac92f55d2e012d82cbf529154f5.pdf`
- Extracted: `generated/extracted/ab87bac92f55d2e012d82cbf529154f5/full.md`
- Filtered: `generated/filtered/ab87bac92f55d2e012d82cbf529154f5/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
