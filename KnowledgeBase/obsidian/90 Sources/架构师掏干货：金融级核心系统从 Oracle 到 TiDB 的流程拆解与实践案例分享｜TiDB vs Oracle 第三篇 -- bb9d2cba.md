---
doc_id: "bb9d2cba9a3a2219b2597f9d440d9c0e"
title: "架构师掏干货：金融级核心系统从 Oracle 到 TiDB 的流程拆解与实践案例分享｜TiDB vs Oracle 第三篇"
aliases:
  - "架构师掏干货：金融级核心系统从 Oracle 到 TiDB 的流程拆解与实践案例分享｜TiDB vs Oracle 第三篇"
url: "https://mp.weixin.qq.com/s/2xvUNRkPJNbG6rVihseOww"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "Oracle"
  - "数据库迁移"
  - "分布式数据库"
  - "金融核心系统"
  - "架构设计"
  - "性能优化"
  - "高可用"
  - "HTAP"
  - "国产化替换"
generated: true
---

# 架构师掏干货：金融级核心系统从 Oracle 到 TiDB 的流程拆解与实践案例分享｜TiDB vs Oracle 第三篇

> [!info] Provenance
> - doc_id: `bb9d2cba9a3a2219b2597f9d440d9c0e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/2xvUNRkPJNbG6rVihseOww)
> - PDF: [open local PDF](../../collector/bb9d2cba9a3a2219b2597f9d440d9c0e.pdf)

## Summary

文章系统整理了 Oracle 迁移到 TiDB 的标准化流程，重点讲应用适配、数据迁移、SQL 兼容性验证与回退方案，并用五个金融行业案例说明 TiDB 在核心交易、保单、现金管理与 HTAP 查询场景中的落地效果。

## Knowledge Outline

- 切换流程总览 — TiDB, Oracle, 数据库迁移, 实施流程
- 三大关键节点 — TiDB, Oracle, 迁移方法, SQL兼容性, 回退方案, 性能验证
- 案例一 财险核心系统 — 金融, 财险, Oracle RAC, TiDB, 国产化替换, 分布式数据库, 架构演进
- 案例二 保单中心 — 财险, 保单中心, TiDB, 高可用, 性能优化, 成本优化, 分布式架构
- 案例三 城商行核心 — 城商行, 核心系统, TiDB, 微服务, 容灾, RPO=0, 国产化替换
- 案例四 现金管理 — 国有大行, 现金管理, 对公业务, TiDB, 分布式架构, 性能容量, 成本优化
- 案例五 交易查询 HTAP — 国有大行, HTAP, 交易查询, Kafka, 冷热分层, OLTP, OLAP, TiDB
- 结语 — 总结, 金融案例, TiDB, Oracle迁移, 性能优化, 架构升级

## Repository Paths

- PDF: `collector/bb9d2cba9a3a2219b2597f9d440d9c0e.pdf`
- Extracted: `generated/extracted/bb9d2cba9a3a2219b2597f9d440d9c0e/full.md`
- Filtered: `generated/filtered/bb9d2cba9a3a2219b2597f9d440d9c0e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
