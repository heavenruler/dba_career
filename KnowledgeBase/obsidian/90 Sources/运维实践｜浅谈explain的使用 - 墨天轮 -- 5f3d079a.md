---
doc_id: "5f3d079a8a599f1c3f17644b42d1059d"
title: "运维实践｜浅谈explain的使用 - 墨天轮"
aliases:
  - "运维实践｜浅谈explain的使用 - 墨天轮"
url: "https://www.modb.pro/db/1774424140342169600"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "SQL优化"
  - "EXPLAIN"
  - "性能调优"
  - "运维实践"
generated: true
---

# 运维实践｜浅谈explain的使用 - 墨天轮

> [!info] Provenance
> - doc_id: `5f3d079a8a599f1c3f17644b42d1059d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1774424140342169600)
> - PDF: [open local PDF](../../collector/5f3d079a8a599f1c3f17644b42d1059d.pdf)

## Summary

本文介绍 MySQL 8.0.31 环境下 EXPLAIN 的基本用法、输出字段含义，以及 type、key/key_len、ref、filtered、Extra 等关键字段在 SQL 性能排查中的关注点。

## Knowledge Outline

- 问题背景 — SQL优化, 性能排查, 运维
- 演示环境 — MySQL, 测试环境
- EXPLAIN用途 — EXPLAIN, SQL优化, MySQL
- 执行格式 — EXPLAIN, SQL
- 输出字段 — EXPLAIN, MySQL, 执行计划
- SELECT语法参考 — MySQL, SELECT, SQL语法
- 演示表数据 — MySQL, 测试数据, DDL, DML
- type访问类型 — EXPLAIN, type, SQL优化, 索引
- key和key_len — EXPLAIN, key_len, 索引, MySQL
- ref字段 — EXPLAIN, ref, 索引
- filtered字段 — EXPLAIN, filtered, SQL优化
- filtered示例 — EXPLAIN, filtered, SQL
- Extra字段 — EXPLAIN, Extra, SQL优化, MySQL
- 总结 — EXPLAIN, MySQL, SQL优化

## Repository Paths

- PDF: `collector/5f3d079a8a599f1c3f17644b42d1059d.pdf`
- Extracted: `generated/extracted/5f3d079a8a599f1c3f17644b42d1059d/full.md`
- Filtered: `generated/filtered/5f3d079a8a599f1c3f17644b42d1059d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
