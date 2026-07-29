---
doc_id: "6c436d6832ca311822f9cc006336ff54"
title: "TiDB HTAP 深度解读 - 知乎"
aliases:
  - "TiDB HTAP 深度解读 - 知乎"
url: "https://zhuanlan.zhihu.com/p/205663113"
source_domain: "zhuanlan.zhihu.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "HTAP"
  - "列存"
  - "Raft"
  - "Multi-Raft"
  - "DeltaTree"
  - "CBO"
  - "資料庫架構"
  - "效能調優"
generated: true
---

# TiDB HTAP 深度解读 - 知乎

> [!info] Provenance
> - doc_id: `6c436d6832ca311822f9cc006336ff54`
> - source_kind: `llm_filtered`
> - source: [original URL](https://zhuanlan.zhihu.com/p/205663113)
> - PDF: [open local PDF](../../collector/6c436d6832ca311822f9cc006336ff54.pdf)

## Summary

這篇文章用 TiDB HTAP 架構為主軸，重點講了三件事：可實時更新的列存 DeltaTree、基於 Raft/Multi-Raft 的複製體系、以及透過代價優化自動在行存與列存間做選擇。

## Knowledge Outline

- 重點總結 — TiDB, HTAP, 列存, Raft, CBO, 資料庫架構
- 可更新列存 — TiDB, HTAP, 列存, DeltaTree, Delta Main, Locality, LSM, ClickHouse, 效能調優
- Raft 複製 — TiDB, TiFlash, Raft, Multi-Raft, Learner, MVCC, 一致性, 異步複製, 分布式系統
- 代價選擇 — TiDB, TiFlash, CBO, HTAP, TiSpark, 資料庫架構, DBA, 職涯/實務

## Repository Paths

- PDF: `collector/6c436d6832ca311822f9cc006336ff54.pdf`
- Extracted: `generated/extracted/6c436d6832ca311822f9cc006336ff54/full.md`
- Filtered: `generated/filtered/6c436d6832ca311822f9cc006336ff54/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
