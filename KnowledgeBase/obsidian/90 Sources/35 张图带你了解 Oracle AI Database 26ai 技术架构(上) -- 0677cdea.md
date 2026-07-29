---
doc_id: "0677cdea45b5e1bbdaf50d1c4afded76"
title: "35 张图带你了解 Oracle AI Database 26ai 技术架构(上)"
aliases:
  - "35 张图带你了解 Oracle AI Database 26ai 技术架构(上)"
url: "https://mp.weixin.qq.com/s/_t5xua7S1CGjHIxes91LgQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "Oracle AI Database 26ai"
  - "DBA"
  - "数据库架构"
  - "SGA"
  - "PGA"
  - "Vector Pool"
  - "In-Memory"
  - "性能调优"
generated: true
---

# 35 张图带你了解 Oracle AI Database 26ai 技术架构(上)

> [!info] Provenance
> - doc_id: `0677cdea45b5e1bbdaf50d1c4afded76`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/_t5xua7S1CGjHIxes91LgQ)
> - PDF: [open local PDF](../../collector/0677cdea45b5e1bbdaf50d1c4afded76.pdf)

## Summary

本文介绍 Oracle AI Database 26ai 本地部署版本的数据库服务、实例、SGA/PGA、后台进程、共享池、大池、向量池、缓冲区缓存与 In-Memory 区域等体系结构重点。

## Knowledge Outline

- 前言与架构变化 — Oracle, 数据库架构, Vector Pool
- Database Server — Oracle, Database Server, CDB, RAC, Oracle Net
- 数据库管理工具 — Oracle, DBA, 工具
- Database Instance — Oracle, Database Instance, SGA, PGA, CDB, PDB
- SGA — Oracle, SGA, Shared Pool, Vector Pool, Flashback
- SGA 可选组件 — Oracle, SGA, Large Pool, In-Memory, Memoptimized Rowstore
- PGA — Oracle, PGA, UGA, SQL 工作区
- 后台进程 — Oracle, 后台进程, PMON, SMON, DBWn, LGWR
- 共享池 — Oracle, Shared Pool, Library Cache, 软解析, 硬解析
- 大池 — Oracle, Large Pool, UGA, RMAN, MEMOPTIMIZE
- 共享服务器请求流程 — Oracle, 共享服务器, Large Pool, Dnnn, Snnn
- Vector Pool — Oracle, Vector Pool, HNSW, IVF, VECTOR_MEMORY_SIZE
- Vector Pool 参数示例 — Oracle, SQL, VECTOR_MEMORY_SIZE, PDB
- Vector Pool 自动增长 — Oracle, Vector Pool, HNSW, sga_target, V$VECTOR_MEMORY_POOL
- 缓冲区缓存 — Oracle, Buffer Cache, SGA, LRU, I/O
- 缓冲区缓存组成 — Oracle, Buffer Cache, 默认池, 保留池, 回收池
- IM 内存区域 — Oracle, In-Memory, IM 列式存储, OLTP, 分析查询
- IMCU 与 IMEU — Oracle, IMCU, SMU, ESS, IMEU
- In-Memory 参数与限制 — Oracle, In-Memory, INMEMORY_SIZE, IMCU, SMU
- In-Memory 运行机制 — Oracle, In-Memory, IMCU, 混合扫描, INMEMORY_AUTOMATIC_LEVEL
- In-Memory 后台与向量化 — Oracle, In-Memory, IMCO, SMCO, SIMD, INMEMORY_DEEP_VECTORIZATION

## Repository Paths

- PDF: `collector/0677cdea45b5e1bbdaf50d1c4afded76.pdf`
- Extracted: `generated/extracted/0677cdea45b5e1bbdaf50d1c4afded76/full.md`
- Filtered: `generated/filtered/0677cdea45b5e1bbdaf50d1c4afded76/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
