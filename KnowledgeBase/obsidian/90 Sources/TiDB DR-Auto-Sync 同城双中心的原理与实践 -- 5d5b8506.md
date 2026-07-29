---
doc_id: "5d5b8506afba43b65c7fd1af35337f77"
title: "TiDB DR-Auto-Sync 同城双中心的原理与实践"
aliases:
  - "TiDB DR-Auto-Sync 同城双中心的原理与实践"
url: "https://mp.weixin.qq.com/s/5CA0ip-Pmu5q424RyMAhww"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "数据库"
  - "高可用"
  - "容灾"
  - "同城双中心"
  - "Raft"
  - "运维"
  - "监控告警"
generated: true
---

# TiDB DR-Auto-Sync 同城双中心的原理与实践

> [!info] Provenance
> - doc_id: `5d5b8506afba43b65c7fd1af35337f77`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/5CA0ip-Pmu5q424RyMAhww)
> - PDF: [open local PDF](../../collector/5d5b8506afba43b65c7fd1af35337f77.pdf)

## Summary

这篇文章围绕 TiDB DR-Auto-Sync 在同城双中心场景下的部署、切换机制、监控告警、注意事项、Raft 扩展原理与方案对比展开，核心信息集中在高可用、容灾切换、RPO/RTO 和实践配置上。

## Knowledge Outline

- 简介与架构 — TiDB, 高可用, 同城双中心, 部署架构
- 容灾切换 — TiDB, 容灾, 切换, RPO, RTO
- 监控与注意事项 — TiDB, 监控告警, 运维, 参数配置, 故障切换
- 原生 Raft 的限制 — Raft, TiDB, 容灾, 分布式系统
- DR Auto-Sync 方案 — TiDB, Raft, 高可用, RPO, RTO
- 原理解读 — TiDB, Raft, 容灾, 架构设计, 分布式系统
- 最佳实践对比 — TiDB, 高可用, 容灾方案, 架构对比, RPO

## Repository Paths

- PDF: `collector/5d5b8506afba43b65c7fd1af35337f77.pdf`
- Extracted: `generated/extracted/5d5b8506afba43b65c7fd1af35337f77/full.md`
- Filtered: `generated/filtered/5d5b8506afba43b65c7fd1af35337f77/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
