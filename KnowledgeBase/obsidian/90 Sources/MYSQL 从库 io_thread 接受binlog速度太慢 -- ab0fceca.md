---
doc_id: "ab0fceca2e10d9257ab64bf479662204"
title: "[MYSQL] 从库 io_thread 接受binlog速度太慢?"
aliases:
  - "[MYSQL] 从库 io_thread 接受binlog速度太慢?"
url: "https://www.modb.pro/db/1943498977723297792"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "主从复制"
  - "binlog"
  - "relay log"
  - "IOPS"
  - "性能调优"
  - "故障排查"
  - "Linux"
  - "perf"
  - "gdb"
  - "strace"
generated: true
---

# [MYSQL] 从库 io_thread 接受binlog速度太慢?

> [!info] Provenance
> - doc_id: `ab0fceca2e10d9257ab64bf479662204`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1943498977723297792)
> - PDF: [open local PDF](../../collector/ab0fceca2e10d9257ab64bf479662204.pdf)

## Summary

这篇文章记录了一次 MySQL 主从延迟排查：现象是从库 io_thread 接收 binlog 很慢，最初怀疑网络与 IO，但通过 scp、wget、mysqlbinlog、gdb、strace、perf 和 IO 压测逐步定位，最终发现是大量小事务叠加从库低 IOPS，且从库每次提交都要更新 `mysql.slave_relay_log_info` 并触发双 1 刷盘，导致接收和回放都被卡住。作者给出的处理方向是关闭从库双 1、减少 IO，或合并小事务以提高单次刷盘效率。

## Knowledge Outline

- 问题现象 — MySQL, 主从复制, binlog, relay log, 性能调优
- 同步逻辑 — MySQL, 主从复制, binlog, relay log
- 验证网络 — MySQL, 网络排查, Linux, binlog, IO, 故障排查
- 堆栈分析 — MySQL, gdb, strace, fsync, binlog, relay log, IO
- 重启无效 — MySQL, 故障排查, 重启, 主从复制
- perf 分析 — MySQL, perf, FlameGraph, IO, 两阶段提交, 性能分析
- IO 压测 — IOPS, MySQL, 性能调优, binlog, 小事务, Linux
- 关闭双 1 — MySQL, 双1, sync_binlog, innodb_flush_log_at_timeout, relay log, IOPS, 主从复制
- 总结 — MySQL, IOPS, 小事务, 性能调优, 故障复盘, 事务设计

## Repository Paths

- PDF: `collector/ab0fceca2e10d9257ab64bf479662204.pdf`
- Extracted: `generated/extracted/ab0fceca2e10d9257ab64bf479662204/full.md`
- Filtered: `generated/filtered/ab0fceca2e10d9257ab64bf479662204/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
