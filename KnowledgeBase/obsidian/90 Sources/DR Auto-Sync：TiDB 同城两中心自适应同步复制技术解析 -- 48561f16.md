---
doc_id: "48561f1691da582df595307bd02a614b"
title: "DR Auto-Sync：TiDB 同城两中心自适应同步复制技术解析"
aliases:
  - "DR Auto-Sync：TiDB 同城两中心自适应同步复制技术解析"
url: "https://mp.weixin.qq.com/s?__biz=MzI3NDIxNTQyOQ==&mid=2247522427&idx=1&sn=f263d59ee39aaf896cc29354c01480b9&scene=21#wechat_redirect"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "Raft"
  - "DR Auto-Sync"
  - "同城双中心"
  - "容灾"
  - "高可用"
  - "分布式共识"
  - "RPO"
  - "RTO"
  - "数据库架构"
generated: true
---

# DR Auto-Sync：TiDB 同城两中心自适应同步复制技术解析

> [!info] Provenance
> - doc_id: `48561f1691da582df595307bd02a614b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MzI3NDIxNTQyOQ==&mid=2247522427&idx=1&sn=f263d59ee39aaf896cc29354c01480b9&scene=21#wechat_redirect)
> - PDF: [open local PDF](../../collector/48561f1691da582df595307bd02a614b.pdf)

## Summary

本文讲解 TiDB 的 DR Auto-Sync 在同城双中心场景下如何通过 Raft 扩展、commit group、阻塞窗口和状态机切换，在可用性、RPO=0 和故障恢复之间取得平衡，并对同城双中心、同城三中心、两地三中心方案做了对比。

## Knowledge Outline

- 背景与目标 — TiDB, DR Auto-Sync, 同城双中心, 容灾, 高可用
- Raft 基础与限制 — Raft, 分布式共识, 高可用, 容灾, 副本, 一致性
- DR 架构 — TiDB, DR Auto-Sync, TiKV, PD, Raft, 双活, 容灾
- 同步状态与恢复 — 同步复制, 异步复制, RPO, RTO, PD, TiKV, 状态机
- Raft commit group — Raft, commit group, AZ, 容灾, 一致性, 数据安全
- 请求阻塞窗口 — 阻塞窗口, 同步复制, 容灾, 可用性, RPO
- 自适应复制状态切换 — 状态机, 同步复制, 异步复制, TiKV, Raft, RPO=0
- 少数派灾难恢复 — 灾难恢复, 少数派, Leader, Learner, PD, Raft
- 部署方案对比 — 同城双中心, 同城三中心, 两地三中心, TiDB, 容灾, 高可用, 性能影响

## Repository Paths

- PDF: `collector/48561f1691da582df595307bd02a614b.pdf`
- Extracted: `generated/extracted/48561f1691da582df595307bd02a614b/full.md`
- Filtered: `generated/filtered/48561f1691da582df595307bd02a614b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
