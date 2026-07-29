---
doc_id: "8feff8720c498d0cc1d51b5c453d23c9"
title: "Multi-Region Distributed SQL Transaction Latency - DEV Community"
aliases:
  - "Multi-Region Distributed SQL Transaction Latency - DEV Community"
url: "https://dev.to/aws-heroes/multi-region-distributed-sql-transaction-latency-512n"
source_domain: "dev.to"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "AWS"
  - "Aurora DSQL"
  - "YugabyteDB"
  - "Distributed SQL"
  - "PostgreSQL"
  - "multi-region"
  - "transaction latency"
  - "database performance"
  - "PgBench"
  - "concurrency control"
  - "replication"
  - "architecture trade-offs"
generated: true
---

# Multi-Region Distributed SQL Transaction Latency - DEV Community

> [!info] Provenance
> - doc_id: `8feff8720c498d0cc1d51b5c453d23c9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://dev.to/aws-heroes/multi-region-distributed-sql-transaction-latency-512n)
> - PDF: [open local PDF](../../collector/8feff8720c498d0cc1d51b5c453d23c9.pdf)

## Summary

本文比較 Aurora DSQL 與 YugabyteDB 在多區域部署下的分散式 SQL 交易延遲，重點涵蓋 optimistic concurrency control、MVCC、single-shard 與 multi-shard transaction、secondary index 對延遲的影響、PgBench 測試結果，以及資料庫架構選型的取捨。

## Knowledge Outline

- 分散式系統取捨 — Distributed SQL, Aurora DSQL, MVCC, Optimistic Concurrency Control, trade-offs
- 部署比較 — Aurora DSQL, YugabyteDB, multi-region, replication
- 多區域部署目的 — high availability, resilience, geo-partitioning, data sovereignty
- 區域連線差異 — latency, round-trip time, leader preference
- 測試資料表 — SQL, PostgreSQL, PgBench, test setup
- PgBench 更新腳本 — PgBench, benchmark, SQL
- 單分片交易定義 — single-shard transaction, primary key, DML
- Aurora DSQL 單分片遠端結果解讀 — Aurora DSQL, PgBench, latency
- YugabyteDB 單分片結果解讀 — YugabyteDB, Raft, single-shard transaction, PostgreSQL concurrency control
- 多分片交易與索引 — multi-shard transaction, secondary index, transaction table, YugabyteDB
- Aurora DSQL 非同步索引 — Aurora DSQL, ASYNC index, backfill, DDL
- Aurora DSQL 多分片延遲 — Aurora DSQL, multi-shard transaction, commit coordination, latency
- YugabyteDB 多分片延遲 — YugabyteDB, transaction resiliency, PostgreSQL compatibility, synchronization, latency
- YugabyteDB EXPLAIN ANALYZE — YugabyteDB, EXPLAIN ANALYZE, query plan, storage requests, performance
- IntentsDB 與提交流程 — Optimistic Concurrency Control, IntentsDB, multi-shard transaction, commit, latency
- 遠端讀取最佳化 — tablespaces, partitions, leader placement, covering indexes, follower reads
- 初始連線時間 — PgBench, connection time, connection pool, DDL, SQL catalog, metadata
- 結論 — architecture trade-offs, availability, performance, PostgreSQL compatibility, fault tolerance, schema design
- 測試摘要 — PgBench, benchmark summary, Aurora DSQL, YugabyteDB
- 延遲摘要表 — latency summary, multi-shard transaction, secondary index, Aurora DSQL, YugabyteDB

## Repository Paths

- PDF: `collector/8feff8720c498d0cc1d51b5c453d23c9.pdf`
- Extracted: `generated/extracted/8feff8720c498d0cc1d51b5c453d23c9/full.md`
- Filtered: `generated/filtered/8feff8720c498d0cc1d51b5c453d23c9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
