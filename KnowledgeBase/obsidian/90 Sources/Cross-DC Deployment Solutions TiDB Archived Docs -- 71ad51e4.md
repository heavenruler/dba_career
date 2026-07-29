---
doc_id: "71ad51e40af1dcc472d06992997d0516"
title: "Cross-DC Deployment Solutions | TiDB Archived Docs"
aliases:
  - "Cross-DC Deployment Solutions | TiDB Archived Docs"
url: "https://docs-archive.pingcap.com/tidb/v3.0/geo-redundancy-deployment"
source_domain: "docs-archive.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "database"
  - "cross-DC"
  - "HA"
  - "DR"
  - "performance"
  - "Binlog replication"
  - "architecture"
generated: true
---

# Cross-DC Deployment Solutions | TiDB Archived Docs

> [!info] Provenance
> - doc_id: `71ad51e40af1dcc472d06992997d0516`
> - source_kind: `llm_filtered`
> - source: [original URL](https://docs-archive.pingcap.com/tidb/v3.0/geo-redundancy-deployment)
> - PDF: [open local PDF](../../collector/71ad51e40af1dcc472d06992997d0516.pdf)

## Summary

This document compares TiDB cross-data-center deployment patterns and the tradeoffs between availability, write latency, read locality, and failover behavior. It covers 3-DC, 3-DC in 2 cities, and 2-DC + Binlog replication approaches, then summarizes HA and DR characteristics.

## Knowledge Outline

- Context and 3-DC overview — TiDB, cross-DC, HA, architecture
- 3-DC advantages, disadvantages, and optimization — TiDB, HA, performance, latency, TSO, PD, TiKV
- 3-DC in 2 cities — TiDB, cross-DC, availability, performance, architecture
- 2-DC + Binlog replication — TiDB, Binlog replication, MySQL, HA, DR, multi-active
- 2-DC multi-active and consistency caveat — TiDB, Binlog replication, consistency, latency, DR
- HA and DR summary — HA, DR, TiDB, consistency, failover, architecture

## Repository Paths

- PDF: `collector/71ad51e40af1dcc472d06992997d0516.pdf`
- Extracted: `generated/extracted/71ad51e40af1dcc472d06992997d0516/full.md`
- Filtered: `generated/filtered/71ad51e40af1dcc472d06992997d0516/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
