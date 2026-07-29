---
doc_id: "8e431cf3f342da1daa965db08504102f"
title: "How a new database architecture supports scale and reliability in TiDB | InfoWorld"
aliases:
  - "How a new database architecture supports scale and reliability in TiDB | InfoWorld"
url: "https://www.infoworld.com/article/2336288/how-a-new-database-architecture-supports-scale-and-reliability-in-tidb.html"
source_domain: "www.infoworld.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "distributed SQL"
  - "database architecture"
  - "scalability"
  - "reliability"
  - "Raft"
  - "distributed transactions"
  - "disaster recovery"
  - "high availability"
  - "database operations"
generated: true
---

# How a new database architecture supports scale and reliability in TiDB | InfoWorld

> [!info] Provenance
> - doc_id: `8e431cf3f342da1daa965db08504102f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.infoworld.com/article/2336288/how-a-new-database-architecture-supports-scale-and-reliability-in-tidb.html)
> - PDF: [open local PDF](../../collector/8e431cf3f342da1daa965db08504102f.pdf)

## Summary

本文說明 TiDB 作為分散式 SQL 資料庫的架構設計，重點包含儲存與計算解耦、原生水平擴展、TiKV、Raft 複製與一致性、auto-sharding、分散式交易、智慧排程、高可用、auto-healing 與災難復原能力。

## Knowledge Outline

- Modern Database Requirements — relational databases, ACID, real-time analytics, business operations
- Scalable Reliable Architecture — TiDB, distributed SQL, scalability, reliability
- Storage Compute Decoupling — architecture, storage compute separation, resource allocation
- Native Horizontal Scaling — horizontal scaling, sharding, transactions, availability
- TiKV Storage Engine — TiKV, key-value storage, Raft, high availability
- Raft Replication — Raft, replication, consistency, regions
- Auto Sharding — auto-sharding, regions, horizontal scaling
- Leader Failover — failover, Raft, high availability, network partitions
- Transparent Resharding — auto-split, resharding, data consistency, developer productivity
- Distributed Transactions — distributed transactions, ACID, strong consistency
- Eliminating Single Writer — single-writer bottleneck, TPS, horizontal scalability, SQL layer
- Workload Scheduling — QPS, workload management, scheduling, performance bottlenecks
- DDL Operations — DDL, schema changes, database operations
- Scalability Examples — case study, 500TB, 1 million QPS, Flipkart
- Reliability Requirements — reliability, high availability, data protection
- Replica Placement — replica placement, availability zones, failure domains, data placement
- Auto Healing — auto-healing, Raft, replica rebalancing, zone outage
- Disaster Recovery — disaster recovery, TiCDC, Flashback, PiTR, backup restore
- Database Designed For Change — distributed SQL, change management, scale, reliability

## Repository Paths

- PDF: `collector/8e431cf3f342da1daa965db08504102f.pdf`
- Extracted: `generated/extracted/8e431cf3f342da1daa965db08504102f/full.md`
- Filtered: `generated/filtered/8e431cf3f342da1daa965db08504102f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
