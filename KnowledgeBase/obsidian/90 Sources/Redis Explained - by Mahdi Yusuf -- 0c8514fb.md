---
doc_id: "0c8514fb2935bb0e8dc7f792246a6d3d"
title: "Redis Explained - by Mahdi Yusuf"
aliases:
  - "Redis Explained - by Mahdi Yusuf"
url: "https://architecturenotes.co/p/redis"
source_domain: "architecturenotes.co"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "資料庫"
  - "快取"
  - "分散式系統"
  - "高可用"
  - "Replication"
  - "Sentinel"
  - "Cluster"
  - "Sharding"
  - "Persistence"
  - "RDB"
  - "AOF"
  - "Forking"
  - "Copy-on-write"
  - "系統設計"
generated: true
---

# Redis Explained - by Mahdi Yusuf

> [!info] Provenance
> - doc_id: `0c8514fb2935bb0e8dc7f792246a6d3d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://architecturenotes.co/p/redis)
> - PDF: [open local PDF](../../collector/0c8514fb2935bb0e8dc7f792246a6d3d.pdf)

## Summary

Redis 技術深度文章，涵蓋 Redis 作為 data structure server、快取與資料庫用途、Memcached 比較、單節點部署、高可用、Replication、Sentinel、Cluster、sharding、gossiping、persistence models、RDB/AOF、fsync、forking 與 copy-on-write。

## Knowledge Outline

- Redis 定義 — Redis, 資料庫, Data Structure Server
- Redis 用途 — Redis, 快取, MySQL, PostgreSQL, Pub/Sub, Streaming, Queue
- Redis 作為主資料庫 — Redis, 主資料庫, 高可用, 效能
- Memcached 比較 — Redis, Memcached, 快取, LRU, Multithreading
- Memcached 與 Redis 能力表 — Redis, Memcached, 功能比較
- Redis 架構類型 — Redis, 架構, 高可用, Cluster
- 單一 Redis Instance — Redis, 單節點, 快取, 部署
- 資料持久化流程 — Redis, Persistence, RDB, AOF, Replication
- Redis HA — Redis, 高可用, Replication, Failover
- High Availability 定義 — 高可用, SRE, 分散式系統, Failover
- Redis Replication — Redis, Replication, RDB, Full Sync, Partial Sync
- Replication ID 與 Offset — Redis, Replication, Offset, Partial Sync, Full Sync
- Redis Sentinel 職責 — Redis, Sentinel, 高可用, Service Discovery, Zookeeper, Consul
- Sentinel 責任列表 — Redis, Sentinel, Monitoring, Failover, Configuration Management
- Quorum — Redis, Sentinel, Quorum, 分散式系統, Failover
- Sentinel 部署建議 — Redis, Sentinel, 部署, Best Practices, Quorum
- Sentinel 風險情境 — Redis, Sentinel, Split Brain, Durability, Network Partition
- 降低寫入遺失 — Redis, Replication, Durability, Write Loss
- Redis Cluster 與水平擴展 — Redis, Cluster, 水平擴展, AWS, 記憶體
- 垂直與水平擴展 — 系統設計, Vertical Scaling, Horizontal Scaling, Scalability
- Sharding 與 Key Mapping — Redis, Cluster, Sharding, Hashing
- Resharding 問題 — Redis, Cluster, Resharding, Availability
- Hashslot 解法 — Redis, Cluster, Hashslot, Resharding, Sharding
- Gossiping — Redis, Cluster, Gossip, Split Brain, 高可用
- Redis Persistence Models — Redis, Persistence, Consistency, Durability
- No Persistence — Redis, Persistence, Durability
- RDB Files — Redis, RDB, Persistence, Snapshots, Forking
- AOF — Redis, AOF, Persistence, fsync, Durability
- fsync — fsync, Persistence, 作業系統, Durability
- RDB + AOF — Redis, RDB, AOF, Persistence, Durability
- Forking — Redis, Forking, Copy-on-write, 作業系統, Persistence
- Copy-on-write — Redis, Copy-on-write, Forking, Memory, Snapshots

## Repository Paths

- PDF: `collector/0c8514fb2935bb0e8dc7f792246a6d3d.pdf`
- Extracted: `generated/extracted/0c8514fb2935bb0e8dc7f792246a6d3d/full.md`
- Filtered: `generated/filtered/0c8514fb2935bb0e8dc7f792246a6d3d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
