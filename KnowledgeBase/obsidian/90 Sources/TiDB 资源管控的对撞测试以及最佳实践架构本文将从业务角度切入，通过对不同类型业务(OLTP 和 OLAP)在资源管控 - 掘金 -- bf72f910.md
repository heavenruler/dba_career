---
doc_id: "bf72f910f228526b8a13ab54f5299b4c"
title: "TiDB 资源管控的对撞测试以及最佳实践架构本文将从业务角度切入，通过对不同类型业务(OLTP 和 OLAP)在资源管控 - 掘金"
aliases:
  - "TiDB 资源管控的对撞测试以及最佳实践架构本文将从业务角度切入，通过对不同类型业务(OLTP 和 OLAP)在资源管控 - 掘金"
url: "https://juejin.cn/post/7387568946339774516"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "资源管控"
  - "OLTP"
  - "OLAP"
  - "架构"
  - "性能调优"
  - "DBA"
generated: true
---

# TiDB 资源管控的对撞测试以及最佳实践架构本文将从业务角度切入，通过对不同类型业务(OLTP 和 OLAP)在资源管控 - 掘金

> [!info] Provenance
> - doc_id: `bf72f910f228526b8a13ab54f5299b4c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7387568946339774516)
> - PDF: [open local PDF](../../collector/bf72f910f228526b8a13ab54f5299b4c.pdf)

## Summary

本文通过对 TiDB 资源管控在 OLTP 与 OLAP 负载下的对撞测试，观察同节点与异节点、不同 RU 配置对 TPS/QPS/P95 的影响，并提出以计算节点 VIP 隔离、存储层 RU 限制为核心的最佳实践架构。

## Knowledge Outline

- 导读 — TiDB, 资源管控, 存算分离, 架构, DBA
- 验证目标与环境 — TiDB, 资源管控, OLTP, OLAP, 压测, 实验设计
- 实验结论 — TiDB, 资源管控, OLTP, OLAP, P95, RU, 性能测试
- 最佳实践架构 — TiDB, 资源管控, 架构, 稳定性, 隔离

## Repository Paths

- PDF: `collector/bf72f910f228526b8a13ab54f5299b4c.pdf`
- Extracted: `generated/extracted/bf72f910f228526b8a13ab54f5299b4c/full.md`
- Filtered: `generated/filtered/bf72f910f228526b8a13ab54f5299b4c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
