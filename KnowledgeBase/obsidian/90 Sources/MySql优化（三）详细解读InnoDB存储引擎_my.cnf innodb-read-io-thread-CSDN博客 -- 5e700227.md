---
doc_id: "5e700227287ae6f14ad8d3a305c804ab"
title: "MySql优化（三）详细解读InnoDB存储引擎_my.cnf innodb-read-io-thread-CSDN博客"
aliases:
  - "MySql优化（三）详细解读InnoDB存储引擎_my.cnf innodb-read-io-thread-CSDN博客"
url: "https://blog.csdn.net/cyl101816/article/details/115794170"
source_domain: "blog.csdn.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "DBA"
  - "数据库"
  - "性能优化"
  - "存储引擎"
  - "Buffer Pool"
  - "Checkpoint"
  - "Redo Log"
generated: true
---

# MySql优化（三）详细解读InnoDB存储引擎_my.cnf innodb-read-io-thread-CSDN博客

> [!info] Provenance
> - doc_id: `5e700227287ae6f14ad8d3a305c804ab`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.csdn.net/cyl101816/article/details/115794170)
> - PDF: [open local PDF](../../collector/5e700227287ae6f14ad8d3a305c804ab.pdf)

## Summary

本文介绍 InnoDB 存储引擎架构、内存结构、后台线程、checkpoint、Master Thread 工作方式、关键特性，以及启动、关闭与恢复相关参数。

## Knowledge Outline

- InnoDB 概述 — InnoDB, MVCC, OLTP
- InnoDB 体系架构 — InnoDB, 线程, 内存池, Redo Log
- 缓冲池 — Buffer Pool, LRU, Checkpoint, innodb_buffer_pool_size
- LRU Free Flush List — LRU, Flush List, Dirty Page, show engine innodb status
- 重做日志缓冲 — Redo Log, innodb_log_buffer_size, 内存池
- 后台线程 — InnoDB Thread, Master Thread, IO Thread, Purge Thread, Page Cleaner
- Checkpoint — Checkpoint, WAL, Dirty Page, innodb_max_dirty_pages_pct
- Master Thread 工作方式 — Master Thread, innodb_io_capacity, innodb_adaptive_flushing, innodb_purge_batch_size
- InnoDB 关键特性 — Insert Buffer, Double Write, Adaptive Hash Index, Async IO
- Insert Buffer — Insert Buffer, B+树, 辅助索引
- Double Write — Double Write, Redo Log, Crash Recovery
- Adaptive Hash Index — Adaptive Hash Index, AHI, show engine innodb status
- Async IO — Async IO, AIO, IO 优化
- 刷新临近页 — Flush Neighbor Page, innodb_flush_neighbors, SSD, AIO
- 启动关闭恢复 — innodb_fast_shutdown, Full Purge, Recovery
- Force Recovery — innodb_force_recovery, Crash Recovery, Undo Log, Redo Log

## Repository Paths

- PDF: `collector/5e700227287ae6f14ad8d3a305c804ab.pdf`
- Extracted: `generated/extracted/5e700227287ae6f14ad8d3a305c804ab/full.md`
- Filtered: `generated/filtered/5e700227287ae6f14ad8d3a305c804ab/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
