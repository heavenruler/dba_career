---
doc_id: "952a764dbd7eedde0553cb5770b52c05"
title: "一名开发者眼中的 TiDB 与 MySQL 的选择丨TiDB Community | PingCAP 平凯星辰"
aliases:
  - "一名开发者眼中的 TiDB 与 MySQL 的选择丨TiDB Community | PingCAP 平凯星辰"
url: "https://cn.pingcap.com/blog/choice-between-tidb-and-mysql/"
source_domain: "cn.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "MySQL"
  - "分布式数据库"
  - "数据库架构"
  - "HTAP"
  - "CH-Benchmark"
  - "性能测试"
  - "数据库选型"
generated: true
---

# 一名开发者眼中的 TiDB 与 MySQL 的选择丨TiDB Community | PingCAP 平凯星辰

> [!info] Provenance
> - doc_id: `952a764dbd7eedde0553cb5770b52c05`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cn.pingcap.com/blog/choice-between-tidb-and-mysql/)
> - PDF: [open local PDF](../../collector/952a764dbd7eedde0553cb5770b52c05.pdf)

## Summary

本文从开发者视角比较 TiDB 与 MySQL，在数据库类型、引擎、架构、存储结构、扩展方式、分布式数据库请求流程、CH-Benchmark 测试方法与结果等方面提供选型参考。

## Knowledge Outline

- 導讀 — 数据库选型, TiDB, MySQL
- TiDB 與 MySQL 基本差異 — 数据库架构, 扩展性, 存储引擎
- 架構對比 — TiDB, MySQL, 计算层, 存储层, 协调层
- 存儲結構與處理 — B+树, LSM树, TiKV, TiFlash, 读放大
- 產品與擴展 — OLTP, InnoDB, TiUP, 扩展性, 运维
- 分布式数据库请求流程 — 分布式数据库, 请求流程, 查询优化
- 中心化與存算分離 — 中心化架构, 去中心化架构, 存算分离, PD, TiKV
- CH-Benchmark 模型 — TPC-CH, TPC-C, TPC-H, CH-Benchmark, HTAP
- 测试环境 — 测试环境, MySQL 8.0, TiDB 6.0, CentOS
- 生成数据 — CH-Benchmark, 数据生成, TiDB Bench
- TiFlash 副本与导入数据 — TiFlash, LOAD DATA, tpcch, 数据导入
- 运行压测命令 — tiup bench, 压测, HTAP, TPC-CH
- 测试摘要 — 性能测试, tpmC, QphH, MySQL, TiDB
- 测试总结 — 测试总结, 性能调优, MySQL 8.0, TiDB 6.0
- TiDB 展望 — TiDB, TiKV, PD, 分布式计算, 分布式存储

## Repository Paths

- PDF: `collector/952a764dbd7eedde0553cb5770b52c05.pdf`
- Extracted: `generated/extracted/952a764dbd7eedde0553cb5770b52c05/full.md`
- Filtered: `generated/filtered/952a764dbd7eedde0553cb5770b52c05/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
