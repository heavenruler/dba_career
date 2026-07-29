---
doc_id: "bb1cb5fccc38cebad1d22ba9963fd05e"
title: "系统容灾体系及架构设计（续）"
aliases:
  - "系统容灾体系及架构设计（续）"
url: "https://mp.weixin.qq.com/s/ZqMGI-u04TCG5tNZEaO9Fg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "容灾"
  - "双机房"
  - "RPO"
  - "RTO"
  - "网络延迟"
  - "脑裂"
  - "演练"
  - "Runbook"
  - "配置中心"
  - "自动化对账"
  - "灰度切流"
  - "数据库选型"
generated: true
---

# 系统容灾体系及架构设计（续）

> [!info] Provenance
> - doc_id: `bb1cb5fccc38cebad1d22ba9963fd05e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/ZqMGI-u04TCG5tNZEaO9Fg)
> - PDF: [open local PDF](../../collector/bb1cb5fccc38cebad1d22ba9963fd05e.pdf)

## Summary

本文延续同城双机房容灾讨论，重点讲网络延时对同步复制的影响、脑裂风险的防护手段、演练与切换落地难点，以及不同数据库/厂商在同城能力、异地容灾和脑裂防护上的对比。

## Knowledge Outline

- 引言 — 容灾, RPO, RTO
- 网络延时与吞吐 — 网络延迟, 吞吐, 同步复制, 数据库, 高可用
- 脑裂风险 — 脑裂, Split-Brain, 仲裁, Raft, Paxos, 分布式锁
- 演练与切换 — 演练, 切换, Runbook, 配置中心, 对账, 灰度切流
- 厂商对比 — 数据库选型, Oracle RAC, OceanBase, GoldenDB, TiDB, KingbaseES, 容灾
- 结语 — 容灾, RPO, RTO, 云厂商, DR

## Repository Paths

- PDF: `collector/bb1cb5fccc38cebad1d22ba9963fd05e.pdf`
- Extracted: `generated/extracted/bb1cb5fccc38cebad1d22ba9963fd05e/full.md`
- Filtered: `generated/filtered/bb1cb5fccc38cebad1d22ba9963fd05e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
