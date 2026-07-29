---
doc_id: "092ce3de80a63a589d6aa18c2a35a3b7"
title: "Migrating Facebook to MySQL 8.0 - Engineering at Meta"
aliases:
  - "Migrating Facebook to MySQL 8.0 - Engineering at Meta"
url: "https://engineering.fb.com/2021/07/22/core-infra/mysql/"
source_domain: "engineering.fb.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "資料庫遷移"
  - "MyRocks"
  - "replication"
  - "SRE"
  - "平台工程"
  - "自動化"
  - "效能調優"
  - "相容性"
  - "事故風險"
generated: true
---

# Migrating Facebook to MySQL 8.0 - Engineering at Meta

> [!info] Provenance
> - doc_id: `092ce3de80a63a589d6aa18c2a35a3b7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://engineering.fb.com/2021/07/22/core-infra/mysql/)
> - PDF: [open local PDF](../../collector/092ce3de80a63a589d6aa18c2a35a3b7.pdf)

## Summary

Meta/Facebook MySQL 5.6 到 8.0 遷移案例，涵蓋自訂 patch 移植、replica set 遷移路徑、row-based replication 標準化、自動化與應用驗證、相容性與效能問題，以及跳過 5.7 的經驗教訓。

## Knowledge Outline

- MySQL 8.0 遷移背景 — MySQL, MyRocks, 資料庫遷移, replication
- 選擇遷移到 8.0 的原因 — MySQL 8.0, atomic DDL, Document Store, Instant DDL
- 遷移難點範圍 — patch migration, API compatibility, MyRocks, backup, automation
- Code Patches 分類與追蹤 — patch migration, technical debt, migration tracking, MySQL
- Release Milestones 與相容性修補 — release milestone, binlog, compatibility, MySQL 8.0
- Replica Set 遷移路徑 — replica set, mysqldump, rollback, automation, failover
- Row-Based Replication 標準化 — row-based replication, statement-based replication, primary key, MyRocks
- Automation Validation — automation, integration testing, utf8mb4, collation, dynamic privileges, schema verification
- Application Validation — shadow testing, reserved keywords, REGEXP, deadlock, isolation level, Document Store, JSON
- Performance 與 Memory 問題 — performance tuning, mutex contention, ACL cache, binlog, temp table, performance_schema, memory
- 跳過 5.7 的經驗教訓 — major version upgrade, logical dump, restore, API changes, deprecation, shadow testing
- 混合版本 Replica Set 風險 — mixed-version replication, utf8mb4_0900, Document Store, Instant DDL, MySQL 8.0

## Repository Paths

- PDF: `collector/092ce3de80a63a589d6aa18c2a35a3b7.pdf`
- Extracted: `generated/extracted/092ce3de80a63a589d6aa18c2a35a3b7/full.md`
- Filtered: `generated/filtered/092ce3de80a63a589d6aa18c2a35a3b7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
