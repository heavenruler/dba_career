---
doc_id: "ba66f907d6293014bd76b120e9e5b65c"
title: "TiDB集群可用区级别改造的探索与实践"
aliases:
  - "TiDB集群可用区级别改造的探索与实践"
url: "https://mp.weixin.qq.com/s/c_Kh6mPSVvwvByoRyNBTyw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "容灾"
  - "可用区"
  - "高可用"
  - "RTO"
  - "RPO"
  - "分布式数据库"
  - "性能延时"
  - "事故演练"
generated: true
---

# TiDB集群可用区级别改造的探索与实践

> [!info] Provenance
> - doc_id: `ba66f907d6293014bd76b120e9e5b65c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/c_Kh6mPSVvwvByoRyNBTyw)
> - PDF: [open local PDF](../../collector/ba66f907d6293014bd76b120e9e5b65c.pdf)

## Summary

本文介绍 TiDB 集群从单可用区三副本升级到三可用区三副本的改造实践，覆盖 RTO/RPO 概念、改造前后拓扑、风险控制、延时影响和容灾演练结果。

## Knowledge Outline

- 前言 — TiDB, 容灾, 高可用, 可用区
- RTO 与 RPO — RTO, RPO, 容灾, 高可用
- 改造前拓扑 — TiDB, 拓扑, 容灾, 可用区, 三副本
- 改造后拓扑 — TiDB, 拓扑, 容灾, 可用区, 三副本
- 理论影响 — TiDB, 性能调优, 延时, 可用区, 分布式数据库
- 风险控制 — TiDB, 风险控制, 压测, 扩缩容, 可用区
- 延时对比 — TiDB, 性能, 延时, 高可用
- 容灾效果 — TiDB, 容灾演练, RTO, RPO, 高可用
- 总结 — TiDB, 容灾, RTO, RPO, 多可用区, 多云

## Repository Paths

- PDF: `collector/ba66f907d6293014bd76b120e9e5b65c.pdf`
- Extracted: `generated/extracted/ba66f907d6293014bd76b120e9e5b65c/full.md`
- Filtered: `generated/filtered/ba66f907d6293014bd76b120e9e5b65c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
