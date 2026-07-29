---
doc_id: "afecd65684d2f2a9566d8d83211a72e9"
title: "dragonflydb/dragonfly: A modern replacement for Redis and Memcached"
aliases:
  - "dragonflydb/dragonfly: A modern replacement for Redis and Memcached"
url: "https://github.com/dragonflydb/dragonfly"
source_domain: "github.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "database"
  - "Redis"
  - "Memcached"
  - "in-memory datastore"
  - "performance benchmark"
  - "configuration"
  - "observability"
  - "architecture"
  - "cache"
  - "C++"
generated: true
---

# dragonflydb/dragonfly: A modern replacement for Redis and Memcached

> [!info] Provenance
> - doc_id: `afecd65684d2f2a9566d8d83211a72e9`
> - source_kind: `llm_filtered`
> - source: [original URL](https://github.com/dragonflydb/dragonfly)
> - PDF: [open local PDF](../../collector/afecd65684d2f2a9566d8d83211a72e9.pdf)

## Summary

Dragonfly 是相容 Redis 與 Memcached API 的記憶體資料庫，文件涵蓋效能基準、記憶體效率、常用設定、Roadmap、快取設計、到期精度、HTTP/Prometheus 指標，以及 shared-nothing、VLL、Dash hashtable 等設計背景。

## Knowledge Outline

- 產品定位 — database, Redis, Memcached, in-memory datastore
- Redis 單執行緒基準 — benchmark, Redis, latency, QPS
- 垂直擴展效能 — benchmark, vertical scaling, Redis, CPU
- 高階執行個體吞吐 — benchmark, memtier_benchmark, pipeline, latency
- Memcached 比較 — benchmark, Memcached, latency, throughput
- 記憶體效率 — memory efficiency, snapshot, Redis, benchmark
- Redis 相容參數 — configuration, Redis, authentication, memory
- Dragonfly 專用參數 — configuration, Memcached, cache, cron, TTL
- 管理連線參數 — configuration, admin, HTTP, RESP, cluster
- 啟動與參數來源 — configuration, startup, environment variables, TLS
- Roadmap — roadmap, Redis API, Memcached, replication
- 快取設計 — cache, eviction, memory efficiency
- 到期時間精度 — TTL, expiration, Redis compatibility
- HTTP Console 與 Prometheus — observability, Prometheus, Grafana, HTTP, metrics
- HTTP Console 安全提醒 — security, HTTP console, configuration
- 架構背景 — architecture, shared-nothing, sharding, cloud, latency
- Atomicity 與 VLL — atomicity, transactions, VLL, concurrency, database architecture
- Dash Hashtable — hashtable, Dash, data structures, TTL, snapshot, cache eviction
- API 實作與使命 — Redis API, Memcached, cloud workloads, database

## Repository Paths

- PDF: `collector/afecd65684d2f2a9566d8d83211a72e9.pdf`
- Extracted: `generated/extracted/afecd65684d2f2a9566d8d83211a72e9/full.md`
- Filtered: `generated/filtered/afecd65684d2f2a9566d8d83211a72e9/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
