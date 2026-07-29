---
doc_id: "5037fe8c2b130ac3ec51ab1522d6e874"
title: "Galera Cluster真的沒有同步延遲嗎?- 進擊的網管Jay"
aliases:
  - "Galera Cluster真的沒有同步延遲嗎?- 進擊的網管Jay"
url: "https://www.sre-devops.info/galera-cluster-sync/"
source_domain: "www.sre-devops.info"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MariaDB"
  - "Galera Cluster"
  - "Replication"
  - "資料庫"
  - "效能調優"
generated: true
---

# Galera Cluster真的沒有同步延遲嗎?- 進擊的網管Jay

> [!info] Provenance
> - doc_id: `5037fe8c2b130ac3ec51ab1522d6e874`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.sre-devops.info/galera-cluster-sync/)
> - PDF: [open local PDF](../../collector/5037fe8c2b130ac3ec51ab1522d6e874.pdf)

## Summary

這篇文章釐清 Galera Cluster 並非真正「沒有同步延遲」，而是採用虛擬同步／邏輯同步；文中說明寫入流程、為何不採全同步，以及如何透過 `wsrep_slave_threads` 與 flow control 降低延遲。

## Knowledge Outline

- 同步延遲 — Galera Cluster, MariaDB, Replication, 資料庫
- 全同步考量 — Galera Cluster, MariaDB, 架構設計, 效能調優
- 降低延遲 — Galera Cluster, MariaDB, 效能調優, SRE

## Repository Paths

- PDF: `collector/5037fe8c2b130ac3ec51ab1522d6e874.pdf`
- Extracted: `generated/extracted/5037fe8c2b130ac3ec51ab1522d6e874/full.md`
- Filtered: `generated/filtered/5037fe8c2b130ac3ec51ab1522d6e874/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
