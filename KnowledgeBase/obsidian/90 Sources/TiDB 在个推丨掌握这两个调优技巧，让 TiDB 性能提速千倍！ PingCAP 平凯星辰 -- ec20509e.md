---
doc_id: "ec20509e594012ab4e3a3bc4200fc1ab"
title: "TiDB 在个推丨掌握这两个调优技巧，让 TiDB 性能提速千倍！ | PingCAP 平凯星辰"
aliases:
  - "TiDB 在个推丨掌握这两个调优技巧，让 TiDB 性能提速千倍！ | PingCAP 平凯星辰"
url: "https://cn.pingcap.com/blog/tidb-in-getui/"
source_domain: "cn.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库调优"
  - "热点问题"
  - "分布式数据库"
  - "MySQL迁移"
  - "性能优化"
  - "SQL优化"
  - "架构设计"
generated: true
---

# TiDB 在个推丨掌握这两个调优技巧，让 TiDB 性能提速千倍！ | PingCAP 平凯星辰

> [!info] Provenance
> - doc_id: `ec20509e594012ab4e3a3bc4200fc1ab`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cn.pingcap.com/blog/tidb-in-getui/)
> - PDF: [open local PDF](../../collector/ec20509e594012ab4e3a3bc4200fc1ab.pdf)

## Summary

这篇文章讲的是个推把 MySQL 迁移到 TiDB 后，因自增主键和批量导入导致写入热点、负载不均与慢 SQL 的问题，最终通过表结构改造、SHARD_ROW_ID_BITS / PRE_SPLIT_REGIONS 调优和索引优化，把导入性能提升到秒级。

## Knowledge Outline

- 个推与 TiDB 的结缘 — TiDB, MySQL迁移, 分布式数据库, 数据迁移, HTAP
- 反模式排查 — TiDB, 慢SQL, 负载均衡, 写入热点, 故障排查, 性能问题
- 热点成因 — TiDB, TiKV, Region, Raft, 热点问题, 主键设计, 分布式存储
- 表结构改造与参数 — TiDB, SQL, 建表, 参数调优, SHARD_ROW_ID_BITS, PRE_SPLIT_REGIONS, 索引优化
- 优化成果 — TiDB, 性能优化, 监控, 负载均衡, 结果复盘
- 总结 — TiDB, OLTP, OLAP, 总结, 数据分析

## Repository Paths

- PDF: `collector/ec20509e594012ab4e3a3bc4200fc1ab.pdf`
- Extracted: `generated/extracted/ec20509e594012ab4e3a3bc4200fc1ab/full.md`
- Filtered: `generated/filtered/ec20509e594012ab4e3a3bc4200fc1ab/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
