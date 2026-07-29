---
doc_id: "d4e783dc4c78c15bde1f58f19bcd1e21"
title: "基于时间维度水平拆分的多 TiDB 集群统一数据路由/联邦查询技术的实践"
aliases:
  - "基于时间维度水平拆分的多 TiDB 集群统一数据路由/联邦查询技术的实践"
url: "https://mp.weixin.qq.com/s/r4hKZdRrQ9fVF7I2acs4-g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据路由"
  - "联邦查询"
  - "水平拆分"
  - "数据库架构"
  - "性能调优"
  - "金融场景"
generated: true
---

# 基于时间维度水平拆分的多 TiDB 集群统一数据路由/联邦查询技术的实践

> [!info] Provenance
> - doc_id: `d4e783dc4c78c15bde1f58f19bcd1e21`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/r4hKZdRrQ9fVF7I2acs4-g)
> - PDF: [open local PDF](../../collector/d4e783dc4c78c15bde1f58f19bcd1e21.pdf)

## Summary

本文围绕银行超长时间跨度交易明细场景，讲解如何按交易时间维度将数据水平拆分到多个 TiDB 物理集群，并通过自研轻量级数据路由 SDK 实现跨集群查询、修改、结果归并、配置热更新与容量管理。

## Knowledge Outline

- 业务背景 — TiDB, 金融场景, 水平拆分, 联邦查询, 数据库架构
- 访问模式 — 数据路由, 跨库查询, 分页, 汇总, TiDB
- 时间拆分 — 集群拆分, 容量规划, ETL, 数据生命周期, 冗余设计
- 组件架构 — 架构设计, Java, Spring Boot, Mybatis, TiDB, SDK
- 路由实现 — 配置管理, 路由配置, 热更新, SQL, TiDB
- 执行归并 — 动态路由, 结果集归并, 分页, 聚合查询, 跨集群DML, TiDB

## Repository Paths

- PDF: `collector/d4e783dc4c78c15bde1f58f19bcd1e21.pdf`
- Extracted: `generated/extracted/d4e783dc4c78c15bde1f58f19bcd1e21/full.md`
- Filtered: `generated/filtered/d4e783dc4c78c15bde1f58f19bcd1e21/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
