---
doc_id: "220a46a80d79e7909277fef80cca9a77"
title: "用蜜蜂(eBPF)来追踪海豚(MySQL)，性能追的上吗 - 墨天轮"
aliases:
  - "用蜜蜂(eBPF)来追踪海豚(MySQL)，性能追的上吗 - 墨天轮"
url: "https://www.modb.pro/db/1799008894466478080"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "eBPF"
  - "MySQL"
  - "数据库可观测性"
  - "性能测试"
  - "压测"
  - "SRE"
  - "效能调优"
  - "资源消耗"
generated: true
---

# 用蜜蜂(eBPF)来追踪海豚(MySQL)，性能追的上吗 - 墨天轮

> [!info] Provenance
> - doc_id: `220a46a80d79e7909277fef80cca9a77`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1799008894466478080)
> - PDF: [open local PDF](../../collector/220a46a80d79e7909277fef80cca9a77.pdf)

## Summary

这篇文章讨论用 eBPF 做 MySQL 可观测性时的性能开销，重点给出压测设计、典型场景结果、单条 SQL 的探针开销，以及 Agent 自身资源占用。核心结论是：在默认配置下，采集开销主要与 QPS 相关，整体对 MySQL 性能影响约在 2% 以内，1 万 QPS 约增加 0.2c CPU。

## Knowledge Outline

- 问题引入 — eBPF, MySQL, 数据库可观测性, 性能测试
- 开销来源 — eBPF, MySQL, Agent, 性能开销, 资源消耗, OLTP
- 测试设计 — 测试方法, 压测, sysbench, TPC-C, QPS, TPS, MySQL
- 压测结果 — 测试环境, MySQL, ECS, 压测, 基线
- 基准场景结果 — 基准压测, 只读, 只写, 读写混合, QPS, 时延, CPU
- TPC-C 结果 — TPC-C, OLTP, QPS, CPU, 性能测试
- 单条 SQL 开销 — SQL, uprobes, eBPF, 延迟, 性能开销, QPS
- Agent 自身资源 — Agent, 资源占用, CPU, 内存, QPS, 可观测性
- 结论 — 总结, MySQL, eBPF, 性能损耗, 资源消耗

## Repository Paths

- PDF: `collector/220a46a80d79e7909277fef80cca9a77.pdf`
- Extracted: `generated/extracted/220a46a80d79e7909277fef80cca9a77/full.md`
- Filtered: `generated/filtered/220a46a80d79e7909277fef80cca9a77/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
