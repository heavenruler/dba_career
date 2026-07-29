---
doc_id: "5db25a77c7a120bb8ea0b1b1bf9ad498"
title: "PostgreSQL 18 核心新特性解析"
aliases:
  - "PostgreSQL 18 核心新特性解析"
url: "https://mp.weixin.qq.com/s/JwGPhg6Bd3rQxJ6IKCR3JQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "DBA"
  - "資料庫"
  - "效能調優"
  - "架構設計"
  - "雲端"
  - "可觀測性"
  - "DevOps"
  - "資料庫升級"
  - "安全認證"
generated: true
---

# PostgreSQL 18 核心新特性解析

> [!info] Provenance
> - doc_id: `5db25a77c7a120bb8ea0b1b1bf9ad498`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/JwGPhg6Bd3rQxJ6IKCR3JQ)
> - PDF: [open local PDF](../../collector/5db25a77c7a120bb8ea0b1b1bf9ad498.pdf)

## Summary

本文整理 PostgreSQL 18 的核心新特性，包括异步 I/O、UUIDv7、虚拟生成列、B-tree Skip Scan、时间约束、RETURNING 增强、pg_upgrade 统计信息保留、OAuth 2.0、pg_stat_io/EXPLAIN 改进、数据校验和默认启用，以及升级建议。

## Knowledge Outline

- 摘要 — PostgreSQL, 版本特性
- 异步 I/O 设计动机 — PostgreSQL, AIO, 效能調優, 雲端
- 异步 I/O 配置 — PostgreSQL, AIO, 參數
- 异步 I/O 性能 — PostgreSQL, AIO, benchmark
- 异步 I/O 实践 — PostgreSQL, AIO, io_uring, 監控
- UUIDv7 优势 — PostgreSQL, UUIDv7, 分散式系統, 主鍵設計
- UUIDv7 函数 — PostgreSQL, UUIDv7, SQL
- UUIDv7 表设计 — PostgreSQL, UUIDv7, 資料模型
- 虚拟生成列 — PostgreSQL, 生成列, 存儲優化
- 虚拟列限制 — PostgreSQL, 生成列, 限制
- 虚拟列实践 — PostgreSQL, 生成列, SQL
- B-tree 跳跃扫描 — PostgreSQL, B-tree, 索引, 效能調優
- Skip Scan 原理与性能 — PostgreSQL, Skip Scan, benchmark
- 时间约束 — PostgreSQL, 時間約束, 資料完整性
- WITHOUT OVERLAPS 示例 — PostgreSQL, WITHOUT OVERLAPS, GiST
- 时间约束注意 — PostgreSQL, WITHOUT OVERLAPS, GiST
- RETURNING 增强 — PostgreSQL, RETURNING, DML
- RETURNING 审计示例 — PostgreSQL, RETURNING, 審計
- RETURNING 性能优势 — PostgreSQL, RETURNING, 效能
- pg_upgrade 统计信息保留 — PostgreSQL, pg_upgrade, ANALYZE, 升級
- pg_upgrade 命令 — PostgreSQL, pg_upgrade, 升級
- 升级限制 — PostgreSQL, pg_upgrade, 統計資訊
- OAuth 2.0 配置 — PostgreSQL, OAuth, 安全認證
- OAuth 认证流程 — PostgreSQL, OAuth, JWT
- MD5 废弃与 TLS — PostgreSQL, SCRAM-SHA-256, TLS, 安全
- pg_stat_io 增强 — PostgreSQL, pg_stat_io, 可觀測性, WAL
- I/O 监控 SQL — PostgreSQL, pg_stat_io, 監控, WAL
- EXPLAIN 默认 BUFFERS — PostgreSQL, EXPLAIN, 效能調優
- 数据校验和默认启用 — PostgreSQL, data checksums, 資料安全
- 校验和性能与升级 — PostgreSQL, data checksums, 升級
- 其他重要特性 — PostgreSQL, GIN, JSONB, 邏輯複製, 協議
- 升级建议 — PostgreSQL, 升級, 檢查清單
- 建议升级路径 — PostgreSQL, pg_upgrade, 升級流程
- 结语 — PostgreSQL, 升級建議, AIO, UUIDv7

## Repository Paths

- PDF: `collector/5db25a77c7a120bb8ea0b1b1bf9ad498.pdf`
- Extracted: `generated/extracted/5db25a77c7a120bb8ea0b1b1bf9ad498/full.md`
- Filtered: `generated/filtered/5db25a77c7a120bb8ea0b1b1bf9ad498/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
