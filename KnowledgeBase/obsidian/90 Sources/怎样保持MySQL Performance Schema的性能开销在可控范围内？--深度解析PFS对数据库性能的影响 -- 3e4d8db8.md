---
doc_id: "3e4d8db847142e8a85459e10b6868641"
title: "怎样保持MySQL Performance Schema的性能开销在可控范围内？--深度解析PFS对数据库性能的影响"
aliases:
  - "怎样保持MySQL Performance Schema的性能开销在可控范围内？--深度解析PFS对数据库性能的影响"
url: "https://www.modb.pro/db/1940668437475373056"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Performance Schema"
  - "DBA"
  - "性能优化"
  - "可观测性"
  - "数据库监控"
  - "SQL"
  - "插桩"
generated: true
---

# 怎样保持MySQL Performance Schema的性能开销在可控范围内？--深度解析PFS对数据库性能的影响

> [!info] Provenance
> - doc_id: `3e4d8db847142e8a85459e10b6868641`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1940668437475373056)
> - PDF: [open local PDF](../../collector/3e4d8db847142e8a85459e10b6868641.pdf)

## Summary

本文讨论 MySQL Performance Schema 的性能开销、默认配置影响、插桩原理、事件计时成本，以及通过 instruments、账号、对象、线程过滤降低 PFS 开销的方法，并给出只监控表 DDL 操作的配置示例。

## Knowledge Outline

- PFS 诊断能力与性能疑虑 — MySQL, Performance Schema, 可观测性, 性能诊断
- 第三方测试结论 — 性能测试, CPU, MySQL, Performance Schema
- 默认配置下的 PFS 开销 — MySQL 8, Performance Schema, setup_instruments, 性能开销
- PFS 插桩原理与开销类型 — 插桩, CPU, 内存, 锁竞争, Performance Schema
- MUTEX 插桩代码 — MySQL源码, MUTEX, 插桩, Performance Schema
- MUTEX 插桩执行路径 — MUTEX, CPU Cycles, Performance Schema, 性能开销
- 事件计时器开销 — performance_timers, TIMER_OVERHEAD, MySQL 8.4, 性能开销
- Pre-filtering 与 Post-filtering — Performance Schema, 事件过滤, Pre-filtering, Post-filtering
- Instrument 过滤 — setup_instruments, wait, Performance Schema, 配置
- 账号过滤 — setup_actors, 账号过滤, Performance Schema, 配置
- 对象过滤 — setup_objects, 对象过滤, Performance Schema, 配置
- 线程过滤 — setup_threads, 线程过滤, Performance Schema, 配置
- DDL 监控场景 — DDL, MySQL, 审计, Performance Schema
- DDL 监控插桩配置 — DDL, setup_instruments, statement, Performance Schema
- DDL 监控效果验证 — DDL, events_statements_history_long, SQL审计, Performance Schema
- 结论 — MySQL, Performance Schema, 生产环境, 性能开销

## Repository Paths

- PDF: `collector/3e4d8db847142e8a85459e10b6868641.pdf`
- Extracted: `generated/extracted/3e4d8db847142e8a85459e10b6868641/full.md`
- Filtered: `generated/filtered/3e4d8db847142e8a85459e10b6868641/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
