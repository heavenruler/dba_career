---
doc_id: "41446ccd753567640b5543201715fb85"
title: "Cutting over: Our journey from AWS Aurora MySQL to TiDB | Plaid"
aliases:
  - "Cutting over: Our journey from AWS Aurora MySQL to TiDB | Plaid"
url: "https://plaid.com/blog/switching-to-tidb/"
source_domain: "plaid.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "資料庫遷移"
  - "TiDB"
  - "Aurora MySQL"
  - "分散式 SQL"
  - "SRE"
  - "可靠性"
  - "DevOps"
  - "平台工程"
  - "可觀測性"
  - "效能調優"
  - "runbook"
  - "事故預防"
  - "溝通"
generated: true
---

# Cutting over: Our journey from AWS Aurora MySQL to TiDB | Plaid

> [!info] Provenance
> - doc_id: `41446ccd753567640b5543201715fb85`
> - source_kind: `llm_filtered`
> - source: [original URL](https://plaid.com/blog/switching-to-tidb/)
> - PDF: [open local PDF](../../collector/41446ccd753567640b5543201715fb85.pdf)

## Summary

Plaid 分享從 AWS Aurora MySQL 遷移到 TiDB 的動機、技術規模、服務切換流程、驗證與 rollback 策略、動態 runbook 自動化，以及遷移中的成效與教訓。主題涵蓋資料庫平台替換、分散式 SQL、SRE/可靠性、資料一致性驗證、DevOps 自動化與跨團隊溝通。

## Knowledge Outline

- Project Overview — 資料庫遷移, TiDB, Aurora MySQL, 平台工程
- Motivation — 架構設計, 資料庫平台, 技術決策
- Technical Landscape — 容量規劃, SLA, QPS, 資料庫規模
- Why Move Off Aurora MySQL — Aurora MySQL, 可靠性, 開發效率, sharding, MySQL 5.7
- Timeline — 專案規劃, 遷移時程, RFC
- Service Transition Phases — runbook, 資料庫遷移, 服務切換
- Remove Incompatibilities — TiCDC, primary key, foreign key, transaction isolation, auto-increment
- Replicate Data — replication, TiDB Lightning, rollback, feature flag
- Validate — 資料一致性, sync-diff-inspector, dual writes, query plan, performance benchmark
- Switchover — cutover, feature flag, write downtime, rollback, 一致性
- Acceleration Strategy — 平台工程, 自動化, rollback, runbook
- Centralize Work — 組織協作, 平台團隊, 效率
- Dynamic Runbooks — dynamic runbook, Jupyter, TypeScript, CLI, SDK, DevOps
- Deno Runbook Stack — Deno, TypeScript, Jupyter, dax, 工具選型
- Runbook Impact — 自動化, Slack audit, 流程標準化, 效率提升
- What Went Well — 效能測試, rolling upgrade, online schema change, vendor support, 溝通
- What Could Improve — TiCDC, TiDB Lightning, query hints, resource isolation, configuration
- Conclusion And Advice — 資料庫遷移, 自動化, 觀測性, DDL, 溝通

## Repository Paths

- PDF: `collector/41446ccd753567640b5543201715fb85.pdf`
- Extracted: `generated/extracted/41446ccd753567640b5543201715fb85/full.md`
- Filtered: `generated/filtered/41446ccd753567640b5543201715fb85/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
