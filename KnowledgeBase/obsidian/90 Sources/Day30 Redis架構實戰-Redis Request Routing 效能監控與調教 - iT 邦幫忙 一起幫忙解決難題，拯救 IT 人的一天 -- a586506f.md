---
doc_id: "a586506fbf5e39188e8662c2a5ef36ae"
title: "Day30 Redis架構實戰-Redis Request Routing/效能監控與調教 - iT 邦幫忙::一起幫忙解決難題，拯救 IT 人的一天"
aliases:
  - "Day30 Redis架構實戰-Redis Request Routing/效能監控與調教 - iT 邦幫忙::一起幫忙解決難題，拯救 IT 人的一天"
url: "https://ithelp.ithome.com.tw/articles/10281889"
source_domain: "ithelp.ithome.com.tw"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "DBA"
  - "SRE"
  - "效能調校"
  - "可觀測性"
  - "架構設計"
generated: true
---

# Day30 Redis架構實戰-Redis Request Routing/效能監控與調教 - iT 邦幫忙::一起幫忙解決難題，拯救 IT 人的一天

> [!info] Provenance
> - doc_id: `a586506fbf5e39188e8662c2a5ef36ae`
> - source_kind: `llm_filtered`
> - source: [original URL](https://ithelp.ithome.com.tw/articles/10281889)
> - PDF: [open local PDF](../../collector/a586506fbf5e39188e8662c2a5ef36ae.pdf)

## Summary

這篇主要是 Redis 叢集的 Request Routing、效能監控與調教實務，包括 MOVED redirect、`redis-cli -c`、read-only/read-write 切換、benchmark、slowlog、memory 觀察、eviction policy、記憶體最佳化與 BGSAVE 失敗原因。

## Knowledge Outline

- Request Routing — Redis, Request Routing, Cluster, DBA
- 最差與最佳實踐 — Redis, 最佳實踐, 效能調校, DBA
- 效能測試與慢日誌 — Redis, Benchmark, Slowlog, 可觀測性, 效能調校
- 驅逐政策與記憶體 — Redis, Eviction, Memory, 效能調校, DBA
- BGSAVE 錯誤 — Redis, BGSAVE, Linux, Troubleshooting, DBA

## Repository Paths

- PDF: `collector/a586506fbf5e39188e8662c2a5ef36ae.pdf`
- Extracted: `generated/extracted/a586506fbf5e39188e8662c2a5ef36ae/full.md`
- Filtered: `generated/filtered/a586506fbf5e39188e8662c2a5ef36ae/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
