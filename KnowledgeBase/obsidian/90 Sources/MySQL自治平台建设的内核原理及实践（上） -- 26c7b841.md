---
doc_id: "26c7b841d9c64290bf8f23d5052f45be"
title: "MySQL自治平台建设的内核原理及实践（上）"
aliases:
  - "MySQL自治平台建设的内核原理及实践（上）"
url: "https://tech.meituan.com/2023/07/06/meituan-mysql-autonomous-platform-01.html"
source_domain: "tech.meituan.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库自治"
  - "DBA"
  - "异常检测"
  - "故障诊断"
  - "可观测性"
  - "主从延迟"
  - "大事务"
  - "Core Dump"
  - "SRE"
generated: true
---

# MySQL自治平台建设的内核原理及实践（上）

> [!info] Provenance
> - doc_id: `26c7b841d9c64290bf8f23d5052f45be`
> - source_kind: `llm_filtered`
> - source: [original URL](https://tech.meituan.com/2023/07/06/meituan-mysql-autonomous-platform-01.html)
> - PDF: [open local PDF](../../collector/26c7b841d9c64290bf8f23d5052f45be.pdf)

## Summary

本文介绍美团 MySQL 数据库自治平台的建设思路，涵盖平台分层架构、基于动态阀值的异常发现、基于内核代码路径的主从延迟诊断、大事务诊断的内核增强，以及 MySQL Crash 的 Core Dump 与 Signal 分析方法。

## Knowledge Outline

- 背景与目标 — 数据库自治, DBA, SQL优化, 故障处理
- 平台分层架构 — 平台架构, 数据采集, Flink, Spark, SQL治理
- 异常发现策略 — 异常检测, 动态阀值, 监控, OLTP, OLAP
- 异常检测算法选择 — 异常检测, MAD, Boxplot, EVT, 3Sigma
- 模型选择流程 — 时序分析, 漂移检测, 周期分析, Flink, 告警
- 异常诊断方法 — 根因分析, 内核分析, 故障诊断, Core Dump
- 主从延迟诊断问题 — 主从延迟, seconds_behind_master, 根因分析, MySQL复制
- seconds_behind_master 计算逻辑 — MySQL内核, seconds_behind_master, 源码分析
- last_master_timestamp 来源 — last_master_timestamp, binlog, replication, event group
- last_master_timestamp 代码 — MySQL源码, replication, 代码片段
- 流程分析示例 — 主从延迟, 流程分析, MySQL复制
- checkpoint 与 sql_delay 影响 — slave_checkpoint_period, sql_delay, MySQL复制, 主从延迟
- 大事务诊断挑战 — 大事务, trx_id, SQL列表, 内核增强
- 大事务耗时组成 — 大事务, 耗时分析, 内核埋点, 网络延迟
- Crash 触发方式 — MySQL Crash, Core Dump, Data Corruption, 故障诊断
- Crash 断言流程 — SIGABRT, Core Dump, handle_fatal_signal, errorlog
- Signal 根因方向 — Signal, Crash诊断, 磁盘空间, data corruption, Latch锁
- MySQL Bug Crash 分析 — MySQL Bug, Core Dump, THD, m_query_string, Crash复现
- rec 类型异常案例 — InnoDB, rec_get_offsets_func, gdb, data corruption, Core Dump
- 其他 Signal 类型 — Signal 7, Signal 9, Signal 11, 硬件错误, MySQL Bug

## Repository Paths

- PDF: `collector/26c7b841d9c64290bf8f23d5052f45be.pdf`
- Extracted: `generated/extracted/26c7b841d9c64290bf8f23d5052f45be/full.md`
- Filtered: `generated/filtered/26c7b841d9c64290bf8f23d5052f45be/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
