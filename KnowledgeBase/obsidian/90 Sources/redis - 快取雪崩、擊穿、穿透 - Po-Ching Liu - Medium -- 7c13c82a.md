---
doc_id: "7c13c82a8913f6c6ef6bc8b0e1b3894d"
title: "redis - 快取雪崩、擊穿、穿透 - Po-Ching Liu - Medium"
aliases:
  - "redis - 快取雪崩、擊穿、穿透 - Po-Ching Liu - Medium"
url: "https://totoroliu.medium.com/redis-%E5%BF%AB%E5%8F%96%E9%9B%AA%E5%B4%A9-%E6%93%8A%E7%A9%BF-%E7%A9%BF%E9%80%8F-8bc02f09fe8f"
source_domain: "totoroliu.medium.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "快取"
  - "高併發"
  - "效能調優"
  - "面試"
  - "資料庫"
generated: true
---

# redis - 快取雪崩、擊穿、穿透 - Po-Ching Liu - Medium

> [!info] Provenance
> - doc_id: `7c13c82a8913f6c6ef6bc8b0e1b3894d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://totoroliu.medium.com/redis-%E5%BF%AB%E5%8F%96%E9%9B%AA%E5%B4%A9-%E6%93%8A%E7%A9%BF-%E7%A9%BF%E9%80%8F-8bc02f09fe8f)
> - PDF: [open local PDF](../../collector/7c13c82a8913f6c6ef6bc8b0e1b3894d.pdf)

## Summary

本文整理高併發、高流量系統使用 in-memory cache / Redis 時常見的三種問題：快取雪崩、快取擊穿、快取穿透，並給出對應的處理方式，內容也點出這些題目常出現在面試中。

## Knowledge Outline

- 導言 — Redis, 快取, 高併發, 面試
- 快取雪崩 — Redis, 快取雪崩, 高併發, 資料庫, DBA
- 快取擊穿 — Redis, 快取擊穿, 高併發, 互斥鎖, 吞吐量
- 快取穿透 — Redis, 快取穿透, Bloom Filter, 高併發, 面試

## Repository Paths

- PDF: `collector/7c13c82a8913f6c6ef6bc8b0e1b3894d.pdf`
- Extracted: `generated/extracted/7c13c82a8913f6c6ef6bc8b0e1b3894d/full.md`
- Filtered: `generated/filtered/7c13c82a8913f6c6ef6bc8b0e1b3894d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
