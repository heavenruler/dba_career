---
doc_id: "c5ea9a4541563d9f85de80b1f27011a1"
title: "揭开 PostgreSQL 读取效率问题的真相"
aliases:
  - "揭开 PostgreSQL 读取效率问题的真相"
url: "https://www.modb.pro/db/2026918098960474112"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "数据库性能"
  - "Bloat"
  - "数据局部性"
  - "索引重建"
  - "autovacuum"
  - "HOT Update"
  - "pg_repack"
  - "EXPLAIN ANALYZE"
generated: true
---

# 揭开 PostgreSQL 读取效率问题的真相

> [!info] Provenance
> - doc_id: `c5ea9a4541563d9f85de80b1f27011a1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2026918098960474112)
> - PDF: [open local PDF](../../collector/c5ea9a4541563d9f85de80b1f27011a1.pdf)

## Summary

本文围绕 PostgreSQL 查询读取效率下降，拆解堆表/索引膨胀与数据局部性两类原因，并给出 EXPLAIN ANALYZE、pg_stat_statements、REINDEX CONCURRENTLY、CLUSTER、pg_repack/pg_squeeze、HOT 和 fillfactor 等识别、修复与预防手段。

## Knowledge Outline

- 读取效率概念 — PostgreSQL, 数据库性能, Bloat, 数据局部性, EXPLAIN ANALYZE
- 膨胀示例 — PostgreSQL, Bloat, 索引重建, REINDEX CONCURRENTLY, VACUUM FULL, CLUSTER, pg_repack, autovacuum
- 数据局部性 — PostgreSQL, 数据局部性, CLUSTER, HOT Update, fillfactor, Index Only Scan, pg_repack, pg_squeeze
- 结论 — PostgreSQL, 性能诊断, Bloat, 数据局部性, EXPLAIN ANALYZE, autovacuum, pg_repack, pg_squeeze

## Repository Paths

- PDF: `collector/c5ea9a4541563d9f85de80b1f27011a1.pdf`
- Extracted: `generated/extracted/c5ea9a4541563d9f85de80b1f27011a1/full.md`
- Filtered: `generated/filtered/c5ea9a4541563d9f85de80b1f27011a1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
