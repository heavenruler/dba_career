---
doc_id: "512959109954895d2d6cfaed633e493f"
title: "Zero-Downtime Upgrades: How TiDB Powers Always-On Databases"
aliases:
  - "Zero-Downtime Upgrades: How TiDB Powers Always-On Databases"
url: "https://www.pingcap.com/blog/achieving-zero-downtime-upgrades-tidb"
source_domain: "www.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "DBA"
  - "distributed SQL"
  - "zero downtime"
  - "rolling upgrade"
  - "online DDL"
  - "SRE"
  - "DevOps"
  - "database operations"
  - "observability"
  - "high availability"
generated: true
---

# Zero-Downtime Upgrades: How TiDB Powers Always-On Databases

> [!info] Provenance
> - doc_id: `512959109954895d2d6cfaed633e493f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.pingcap.com/blog/achieving-zero-downtime-upgrades-tidb)
> - PDF: [open local PDF](../../collector/512959109954895d2d6cfaed633e493f.pdf)

## Summary

本文說明 TiDB 透過分散式 SQL 架構、PD/TiKV/TiDB 元件滾動升級、TiProxy session migration、Raft replication、online DDL 與可觀測性檢查，實現零停機升級與線上 schema change。內容包含停機成本、傳統資料庫升級風險、TiDB 架構機制、AWS demo 觀察、升級命令、SQL 範例與營運最佳實務。

## Knowledge Outline

- 升級挑戰與 TiDB 解法 — TiDB, zero downtime, rolling upgrade
- 停機成本 — SRE, SLO, downtime cost, change safety
- 傳統資料庫升級風險 — database upgrade, blocking DDL, risk, multi-region
- TiDB 滾動升級順序 — TiDB, rolling upgrade, PD, TiKV, TiDB Server
- 元件自動升級機制 — PD, TiKV, TiProxy, session migration, TSO
- 雲原生擴展架構 — cloud-native, shared-nothing, Raft, TiFlash, observability, MTTR
- PD 高可用控制平面 — PD, high availability, TSO, leader election, Placement Rules
- 示範環境與目的 — AWS, self-hosted TiDB, CloudFormation, demo
- 升級前擴展建議 — capacity planning, scale-out, scale-in, online upgrade
- 升級前觀察 — TiProxy, load balancer, database connections, workload observation
- 叢集版本檢查 — tiup, cluster status, TiDB version, Grafana
- 生產查詢監控 — observability, Top SQL, p95, p99, query monitoring, on-call
- 升級命令 — tiup, upgrade command, TiDB 6.5.2
- PD 升級過程 — PD, rolling upgrade, tiup
- TiKV 升級過程 — TiKV, leader transfer, Raft, rolling upgrade
- TiDB Session 遷移 — TiDB Server, TiProxy, session migration, zero disruption
- 不中斷滾動升級步驟 — rolling upgrade, QPS, TPS, tail latency, load balancer
- Online Schema Change — online DDL, schema migration, index backfill, EXPLAIN ANALYZE
- 滾動更新排程 — change management, maintenance window, rollback, BR, PITR
- 升級期間健康監控 — monitoring, p95, p99, Top SQL, TiKV, PD, information_schema
- MySQL 相容遷移 — MySQL compatibility, migration, Dumpling, Lightning, TiCDC, blue-green cutover
- 結論 — always-on database, SLO, high availability, horizontal scalability

## Repository Paths

- PDF: `collector/512959109954895d2d6cfaed633e493f.pdf`
- Extracted: `generated/extracted/512959109954895d2d6cfaed633e493f/full.md`
- Filtered: `generated/filtered/512959109954895d2d6cfaed633e493f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
