---
doc_id: "371e949e7e669478182b96cd8012ef2f"
title: "How We Optimize RocksDB in TiKV — Write Batch Optimization"
aliases:
  - "How We Optimize RocksDB in TiKV — Write Batch Optimization"
url: "https://medium.com/@siddontang/how-we-optimize-rocksdb-in-tikv-write-batch-optimization-28751a4bdd8b"
source_domain: "medium.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiKV"
  - "RocksDB"
  - "Write Path"
  - "LSM Tree"
  - "Distributed Database"
  - "Performance Tuning"
  - "Concurrency"
  - "Raft"
  - "MVCC"
  - "TiDB X"
generated: true
---

# How We Optimize RocksDB in TiKV — Write Batch Optimization

> [!info] Provenance
> - doc_id: `371e949e7e669478182b96cd8012ef2f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://medium.com/@siddontang/how-we-optimize-rocksdb-in-tikv-write-batch-optimization-28751a4bdd8b)
> - PDF: [open local PDF](../../collector/371e949e7e669478182b96cd8012ef2f.pdf)

## Summary

本文說明 RocksDB 預設協調寫入模型在高併發下的 HOL blocking、mutex contention、write stall amplification 問題，並介紹 allow_concurrent_memtable_write、enable_pipelined_write、enable_unordered_write 的限制。核心內容是 TiKV 的 enable_multi_batch_write 如何透過協調 commit scheduler 與 helper mode 消除 pipeline bubble，同時保留 MVCC 與 snapshot isolation 所需的正確性。後段比較 TiDB X 以 per-Region LSM、Raft log 取代 WAL、物件儲存承載大 batch 等方式改變寫入路徑。

## Knowledge Outline

- 寫入批次是 RocksDB 寫入路徑核心 — TiKV, RocksDB, Write Path, Concurrency
- 預設協調寫入模型 — RocksDB, Write Path, Scalability, Mutex
- 預設協調寫入階段 — RocksDB, WAL, MemTable, Sequence Number
- 預設模型瓶頸 — HOL Blocking, Mutex Contention, Write Stall, Tail Latency
- allow_concurrent_memtable_write 限制 — RocksDB, MemTable, Concurrency, HOL Blocking
- enable_pipelined_write 架構變化 — RocksDB, Pipelined Write, WAL, MemTable, Throughput
- Pipeline Bubble 問題 — Pipeline Bubble, Tail Latency, Sequence Number, Visibility
- Pipeline Stall 對 TiKV 的影響 — TiKV, Raft, MVCC, Distributed Transaction, Latency
- enable_unordered_write 不適用 TiKV — TiKV, MVCC, Snapshot Isolation, Correctness
- TiKV Multi-Batch Write — TiKV, Multi-Batch Write, Commit Scheduler, RocksDB
- Multi-Batch Write 核心機制 — TiKV, Fairness, Helper Mode, Commit Scheduler
- Multi-Batch Write 效果 — TiKV, Tail Latency, Pipeline Bubble, Performance
- Production-Grade RocksDB — RocksDB, TiKV, Production, Correctness
- TiDB X 寫入路徑重想 — TiDB X, LSM Tree, Object Storage, Compute Storage Separation
- Per-Region Dedicated LSM Trees — TiDB X, LSM Tree, Region, Scalability
- Raft Log 取代 WAL — TiDB X, Raft, WAL, Write Amplification, Durability
- 大批次直接寫入物件儲存 — TiDB X, Object Storage, MemTable, SST, Write Latency

## Repository Paths

- PDF: `collector/371e949e7e669478182b96cd8012ef2f.pdf`
- Extracted: `generated/extracted/371e949e7e669478182b96cd8012ef2f/full.md`
- Filtered: `generated/filtered/371e949e7e669478182b96cd8012ef2f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
