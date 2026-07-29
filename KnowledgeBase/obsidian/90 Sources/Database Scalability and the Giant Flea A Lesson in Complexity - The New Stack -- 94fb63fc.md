---
doc_id: "94fb63fc6db6864ca91e18cbbe282906"
title: "Database Scalability and the Giant Flea: A Lesson in Complexity - The New Stack"
aliases:
  - "Database Scalability and the Giant Flea: A Lesson in Complexity - The New Stack"
url: "https://thenewstack.io/database-scalability-and-the-giant-flea-a-lesson-in-complexity/"
source_domain: "thenewstack.io"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "資料庫"
  - "Database Scalability"
  - "架構設計"
  - "Operational Complexity"
  - "Sharding"
  - "Distributed SQL"
  - "NoSQL"
  - "Replication Lag"
  - "Eventual Consistency"
generated: true
---

# Database Scalability and the Giant Flea: A Lesson in Complexity - The New Stack

> [!info] Provenance
> - doc_id: `94fb63fc6db6864ca91e18cbbe282906`
> - source_kind: `llm_filtered`
> - source: [original URL](https://thenewstack.io/database-scalability-and-the-giant-flea-a-lesson-in-complexity/)
> - PDF: [open local PDF](../../collector/94fb63fc6db6864ca91e18cbbe282906.pdf)

## Summary

本文以 square-cube law 與巨型跳蚤比喻資料庫擴展：小規模有效的架構無法直接線性放大。文章重點在 technological complexity 與 operational complexity 的取捨，並以 sharding、resharding、replication lag、eventual consistency、NoSQL 與 distributed SQL 說明大規模資料庫在資料分布、一致性、開發者負擔與操作成本上的挑戰。

## Knowledge Outline

- 巨型跳蚤與擴展性比喻 — scalability, complexity, architecture
- 資料庫擴展的複雜性 — database scalability, data distribution, consistency, monitoring, troubleshooting
- 技術複雜性與操作複雜性 — technological complexity, operational complexity, scale-out, automation
- 雲端與超大規模系統的人因問題 — cloud, hyperscale, operations, human factors
- Sharding 的技術優勢 — sharding, latency, throughput, database performance
- Naive Sharding 的操作負擔 — naive sharding, sharding key, hot spots, resharding
- Resharding 的人工成本 — resharding, operational complexity, developer burden, refactoring
- Scaling Out 與資料移動 — scaling out, nodes, redundancy, load sharing, distributed SQL
- Replication Lag 與 DDL — MySQL, replication lag, DDL, consistency
- Eventual Consistency 的取捨 — eventual consistency, strong consistency, MySQL, Amazon Aurora
- 一致性限制轉嫁給開發者 — developer burden, strong consistency, architecture tradeoff
- 複雜性的取捨 — tradeoffs, NoSQL, MongoDB, analytics, enterprise operations
- Distributed SQL 的定位 — Distributed SQL, CockroachDB, TiDB, Google Spanner, horizontal scale-out, DDL replication
- Scale on Paper vs Scale in Practice — database development, operational complexity, scale in practice

## Repository Paths

- PDF: `collector/94fb63fc6db6864ca91e18cbbe282906.pdf`
- Extracted: `generated/extracted/94fb63fc6db6864ca91e18cbbe282906/full.md`
- Filtered: `generated/filtered/94fb63fc6db6864ca91e18cbbe282906/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
