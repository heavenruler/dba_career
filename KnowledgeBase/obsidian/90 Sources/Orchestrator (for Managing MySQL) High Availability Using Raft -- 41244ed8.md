---
doc_id: "41244ed80cb02c95a173325114b0285b"
title: "Orchestrator (for Managing MySQL) High Availability Using Raft"
aliases:
  - "Orchestrator (for Managing MySQL) High Availability Using Raft"
url: "https://www.percona.com/blog/orchestrator-for-managing-mysql-high-availability-using-raft/"
source_domain: "www.percona.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Orchestrator"
  - "Raft"
  - "高可用"
  - "資料庫"
  - "DBA"
  - "故障轉移"
  - "SQLite"
  - "Percona"
generated: true
---

# Orchestrator (for Managing MySQL) High Availability Using Raft

> [!info] Provenance
> - doc_id: `41244ed80cb02c95a173325114b0285b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.percona.com/blog/orchestrator-for-managing-mysql-high-availability-using-raft/)
> - PDF: [open local PDF](../../collector/41244ed80cb02c95a173325114b0285b.pdf)

## Summary

本文說明如何使用 Raft consensus 讓管理 MySQL 的 Orchestrator 本身具備高可用與容錯能力，包含三節點拓撲、Percona 套件安裝、MySQL/SQLite backend 設定、Raft 節點設定、健康檢查、leader failover/switchover 與 production quorum 建議。

## Knowledge Outline

- Orchestrator HA 目標 — MySQL, Orchestrator, 高可用
- Raft 概念 — Raft, consensus, fencing, network partition
- 部署拓撲 — 部署, Raft, SQLite
- 安裝套件 — Percona, 安裝, Openark
- 建立 Orchestrator Metadata — MySQL, metadata, cluster alias
- 建立 MySQL 使用者 — MySQL, 權限, Orchestrator
- 設定檔與 Topology Credentials — Orchestrator, 設定檔, MySQL
- SQLite Backend 設定 — SQLite, Orchestrator backend
- MySQL Backend 替代設定 — MySQL, Orchestrator backend
- Cluster Alias 與 Auto Failover — failover, cluster, recovery
- Raft Node 設定 — Raft, Orchestrator, port 10008
- 啟動服務 — systemd, Orchestrator
- SQLite Database 檢視 — SQLite, Orchestrator, 資料表
- 健康檢查 — health check, journalctl, Raft leader
- API Status Output — API, status, Raft
- Raft Leader Failover — Raft, failover, leader election
- 手動 Switchover — switchover, Raft leader, Orchestrator
- 資料庫節點 Auto Failover — auto failover, MySQL, recovery
- Production Quorum 建議 — quorum, production, 高可用, fencing

## Repository Paths

- PDF: `collector/41244ed80cb02c95a173325114b0285b.pdf`
- Extracted: `generated/extracted/41244ed80cb02c95a173325114b0285b/full.md`
- Filtered: `generated/filtered/41244ed80cb02c95a173325114b0285b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
