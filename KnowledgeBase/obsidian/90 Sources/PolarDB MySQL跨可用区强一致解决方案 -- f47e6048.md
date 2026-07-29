---
doc_id: "f47e6048987f7b4eeb3199c1fc30c45c"
title: "PolarDB MySQL跨可用区强一致解决方案"
aliases:
  - "PolarDB MySQL跨可用区强一致解决方案"
url: "https://mysql.taobao.org/monthly/2025/02/01/"
source_domain: "mysql.taobao.org"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PolarDB"
  - "MySQL"
  - "数据库内核"
  - "强一致性"
  - "跨可用区"
  - "X-Paxos"
  - "Redo日志"
  - "高可用"
  - "性能调优"
generated: true
---

# PolarDB MySQL跨可用区强一致解决方案

> [!info] Provenance
> - doc_id: `f47e6048987f7b4eeb3199c1fc30c45c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mysql.taobao.org/monthly/2025/02/01/)
> - PDF: [open local PDF](../../collector/f47e6048987f7b4eeb3199c1fc30c45c.pdf)

## Summary

本文介绍 PolarDB MySQL 的跨可用区强一致方案，重点涵盖三可用区架构、基于 Redo 和 X-Paxos 的一致性控制、故障切换机制，以及相较 MGR 和 Binlog 同步的性能优势。

## Knowledge Outline

- 背景 — PolarDB, MySQL, 跨可用区, 强一致性, 高可用
- 架构 — PolarDB, MySQL, 架构设计, 强一致性, X-Paxos, MGR
- 关键点 — 数据库内核, Redo日志, LSN, 一致性
- Buffer Pool刷脏限制 — Buffer Pool, 刷脏, 一致性, 数据库内核
- Checkpoint推进 — Checkpoint, Redo日志, 一致性, 数据库内核
- 节点启动 — 启动流程, 选主, Redo日志, 崩溃恢复
- 备节点日志回放 — 备节点, 日志回放, 一致性
- 事务提交 — 事务提交, 一致性, 故障恢复
- DDL — DDL, 文件操作, 故障恢复, 一致性
- Redo log — Redo log, 内存, 消息发送, 性能
- 高可用 — 高可用, 心跳, 故障切换, Leader
- 性能 — 性能, Binlog, Redo日志, Sysbench, X-Paxos

## Repository Paths

- PDF: `collector/f47e6048987f7b4eeb3199c1fc30c45c.pdf`
- Extracted: `generated/extracted/f47e6048987f7b4eeb3199c1fc30c45c/full.md`
- Filtered: `generated/filtered/f47e6048987f7b4eeb3199c1fc30c45c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
