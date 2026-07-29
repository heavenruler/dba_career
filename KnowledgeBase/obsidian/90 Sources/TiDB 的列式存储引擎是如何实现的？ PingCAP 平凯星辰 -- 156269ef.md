---
doc_id: "156269ef29fe4a830a34022ba79f9974"
title: "TiDB 的列式存储引擎是如何实现的？ | PingCAP 平凯星辰"
aliases:
  - "TiDB 的列式存储引擎是如何实现的？ | PingCAP 平凯星辰"
url: "https://cn.pingcap.com/blog/how-tidb-implements-columnar-storage-engine/"
source_domain: "cn.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "TiFlash"
  - "列式存储"
  - "Delta Tree"
  - "LSM Tree"
  - "HTAP"
  - "数据库架构"
  - "存储引擎"
  - "事务"
  - "MVCC"
  - "性能优化"
generated: true
---

# TiDB 的列式存储引擎是如何实现的？ | PingCAP 平凯星辰

> [!info] Provenance
> - doc_id: `156269ef29fe4a830a34022ba79f9974`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cn.pingcap.com/blog/how-tidb-implements-columnar-storage-engine/)
> - PDF: [open local PDF](../../collector/156269ef29fe4a830a34022ba79f9974.pdf)

## Summary

本文介绍 TiFlash 列式存储引擎 Delta Tree 的整体架构、Segment/Pack/Delta Layer/Stable Layer 设计、PageStorage 与 DTFile 存储方式、写入与读取优化、Delta Index、事务处理，以及 TiDB HTAP 能力。

## Knowledge Outline

- TiFlash 与 HTAP — TiDB, TiFlash, HTAP, Raft
- Delta Tree 设计目标 — Delta Tree, 列式存储, TPS, 读性能
- 整体架构 — Delta Tree, B+ Tree, LSM Tree, Segment
- Segment — Segment, B+ Tree, Split, Merge
- 双层 LSM 结构 — LSM Tree, Delta Layer, Stable Layer, 写放大, 压缩
- Pack — Pack, Schema, DDL, MVCC, commit timestamp
- Pack 的 IO 与索引单位 — Pack, IO, Scan, Min-Max 索引
- Region 调度兼容 — TiKV, Region, 调度, PK, version
- Delta Layer — Delta Layer, MemTable, Delta Cache, Delta Merge
- Stable Layer — Stable Layer, DTFile, Pack, 全局有序
- Segment Split 与 Merge — Segment, Split, Merge
- 存储方式 — PageStorage, DTFile, Delta Layer, Stable Layer
- PageStorage — PageStorage, Page, PageFile, PageMap, WriteBatch
- PageStorage 更新与 GC — PageStorage, PageFile, GC, 随机读取
- DTFile — DTFile, 列存, Stable Layer, 顺序读取
- DTFile 与 PageStorage 取舍 — DTFile, PageStorage, IO 合并, 小文件, 随机读取
- 写优化 — TiFlash, OLAP, OLTP, 写优化, 批量写入
- Delta Cache — Delta Cache, IOPS, flush, 批量写入
- Raft Log 作为 WAL — Raft, WAL, Delta Cache, raft log, applied index
- 持续写入能力 — Delta Merge, 写放大, 读性能, LSM Tree
- 写入与读取平衡 — write stall, 写入性能, 读取性能, Delta Merge
- 读优化 — 读优化, 读放大, Segment, LSM Tree
- Scan 耗时来源 — Scan, IO, 解压缩, 多路归并, copy
- 减少读放大 — 读放大, Region, TiKV, TiFlash, Segment
- Delta Index 思路 — Delta Index, Scan, 多路归并, B+ Tree
- Delta Index Entry 演进 — Delta Index, Tuple Id, Entry, B+ Tree, 内存优化
- Delta Index 内存开销 — Delta Index, Entry, 内存开销, Delta Layer
- Delta Index Scan 复用 — Delta Index, Scan, Stream, 增量更新
- 批量 Copy 优化 — 批量 copy, CPU cycle, Stable Layer, LSM Tree
- Delta Tree vs LSM Tree — Delta Tree, LSM Tree, 读性能, Scan
- 粗糙索引效果 — ontime, SQL, Scan, Min-Max, 粗糙索引
- 事务支持 — 事务, TiFlash, TiKV, 隔离级别, HTAP
- 事务处理要点 — 事务, MVCC, commit_ts, query_ts, 列存
- Percolator 与锁 — Percolator, 锁, Raft log, Delta Tree, 事务恢复
- 结语 — Delta Tree, 实时更新, 分析数据库, MySQL binlog, Hive
- TiDB 行列融合 — TiDB, TiFlash, 行存, 列存, SQL

## Repository Paths

- PDF: `collector/156269ef29fe4a830a34022ba79f9974.pdf`
- Extracted: `generated/extracted/156269ef29fe4a830a34022ba79f9974/full.md`
- Filtered: `generated/filtered/156269ef29fe4a830a34022ba79f9974/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
