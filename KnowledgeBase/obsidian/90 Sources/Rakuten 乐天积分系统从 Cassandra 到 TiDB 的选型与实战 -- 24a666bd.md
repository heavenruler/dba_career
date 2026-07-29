---
doc_id: "24a666bdd34b1551caf3ff2bdc6133e2"
title: "Rakuten 乐天积分系统从 Cassandra 到 TiDB 的选型与实战"
aliases:
  - "Rakuten 乐天积分系统从 Cassandra 到 TiDB 的选型与实战"
url: "https://mp.weixin.qq.com/s/7iE0YK2zpovvEPsLKBEjyg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "Cassandra"
  - "NewSQL"
  - "数据库选型"
  - "高可用"
  - "运维"
  - "监控"
  - "故障切换"
  - "迁移"
generated: true
---

# Rakuten 乐天积分系统从 Cassandra 到 TiDB 的选型与实战

> [!info] Provenance
> - doc_id: `24a666bdd34b1551caf3ff2bdc6133e2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/7iE0YK2zpovvEPsLKBEjyg)
> - PDF: [open local PDF](../../collector/24a666bdd34b1551caf3ff2bdc6133e2.pdf)

## Summary

文章讲 Rakuten 乐天积分系统从 Cassandra 迁移到 TiDB 的背景、Cassandra 在一致性与运维上的限制、NewSQL 选型理由、POC 与监控告警的验证方式，以及 TiMS 主从切换工具和上线后的应用场景。

## Knowledge Outline

- 业务背景与系统规模 — 业务背景, 数据库架构, TiDB, Cassandra, 高可用
- Cassandra 的限制 — Cassandra, 一致性, 事务, JOIN, 运维, data repair
- 选型要求与验证 — 数据库选型, NewSQL, TiDB, POC, 监控, 混沌工程
- TiMS 主从切换工具 — TiDB, TiCDC, 故障切换, 主从切换, 自动化运维
- 上线与应用场景 — TiDB, 上线, 批处理, 实时流量, 统计分析, 历史数据
- 个人印象与运维体验 — TiDB, MySQL兼容, 运维, 高可用, 性能

## Repository Paths

- PDF: `collector/24a666bdd34b1551caf3ff2bdc6133e2.pdf`
- Extracted: `generated/extracted/24a666bdd34b1551caf3ff2bdc6133e2/full.md`
- Filtered: `generated/filtered/24a666bdd34b1551caf3ff2bdc6133e2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
