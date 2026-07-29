---
doc_id: "6d3c6ad70423dbbbbf99c913a48efcf4"
title: "Online DDL in TiDB"
aliases:
  - "Online DDL in TiDB"
url: "https://www.mydbops.com/blog/online-ddl-in-tidb"
source_domain: "www.mydbops.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "Online DDL"
  - "DDL"
  - "HTAP"
  - "資料庫"
  - "DBA"
  - "schema change"
  - "DXF"
  - "效能調優"
  - "分散式資料庫"
generated: true
---

# Online DDL in TiDB

> [!info] Provenance
> - doc_id: `6d3c6ad70423dbbbbf99c913a48efcf4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.mydbops.com/blog/online-ddl-in-tidb)
> - PDF: [open local PDF](../../collector/6d3c6ad70423dbbbbf99c913a48efcf4.pdf)

## Summary

本文整理 TiDB Online DDL 的架構、DDL Owner / job 機制、狀態轉移、DXF 分散重組，以及用 `ADMIN SHOW DDL`、`PAUSE`、`RESUME`、`CANCEL` 監控與管理 schema change。

## Knowledge Outline

- TiDB Online DDL 概觀與架構 — TiDB, DDL Owner, DDL job, schema version, monitoring
- DDL 生命週期與狀態轉移 — TiDB, Online DDL, schema state, lifecycle, ADD INDEX
- 欄位新增與索引建立 — TiDB, ALTER TABLE, ADD COLUMN, ADD INDEX, DDL
- DXF 與 DDL 監控 — TiDB, DXF, DDL monitoring, ADMIN SHOW DDL, pause resume cancel
- DDL 實戰與避免阻塞 — TiDB, incident management, schema change, zero downtime, online DDL

## Repository Paths

- PDF: `collector/6d3c6ad70423dbbbbf99c913a48efcf4.pdf`
- Extracted: `generated/extracted/6d3c6ad70423dbbbbf99c913a48efcf4/full.md`
- Filtered: `generated/filtered/6d3c6ad70423dbbbbf99c913a48efcf4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
