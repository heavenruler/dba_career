---
doc_id: "32e1c4ac785a9c814df4739817f6ef6e"
title: "oracle awr 报告详解 - 墨天轮"
aliases:
  - "oracle awr 报告详解 - 墨天轮"
url: "https://www.modb.pro/db/1889567271404711936"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "AWR"
  - "DBA"
  - "性能调优"
  - "RAC"
  - "等待事件"
  - "DB Time"
  - "log file sync"
  - "gc buffer busy"
  - "可观测性"
generated: true
---

# oracle awr 报告详解 - 墨天轮

> [!info] Provenance
> - doc_id: `32e1c4ac785a9c814df4739817f6ef6e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1889567271404711936)
> - PDF: [open local PDF](../../collector/32e1c4ac785a9c814df4739817f6ef6e.pdf)

## Summary

本文介绍 Oracle AWR 报告的关键解读方法，涵盖 DB Time/AAS、Load Profile、实例效率、Shared Pool、Top Foreground Event、常见等待事件、RAC Global Cache、CPU/OS/Memory/Time Model 统计，以及 log file sync、gc buffer busy 等事件关联分析。

## Knowledge Outline

- AWR介绍 — Oracle, AWR, DBA
- AWR维护 — Oracle, AWR, MMON
- DB Time定义 — DB Time, AAS, 性能调优
- DB Time公式 — DB Time, CPU, AAS
- DB Time查询SQL — Oracle, AWR, SQL, DB Time
- Load Profile — AWR, Load Profile, Redo, Logical Read, Physical Read
- 解析指标 — Oracle, Hard Parse, SQL解析, 性能调优
- 硬解析案例结论 — Oracle, Hard Parse, 绑定变量, cursor_sharing
- Cache Sizes — Oracle, SGA, Shared Pool, ASMM, AMM, ORA-04031
- 实例效率指标 — AWR, Instance Efficiency, Buffer Hit, Soft Parse
- 执行解析比 — Oracle, Parse, Latch, CPU
- Shared Pool统计 — Shared Pool, SQL重用, 绑定变量
- DB CPU等待说明 — DB CPU, CPU Queue, AWR
- db file sequential read — Oracle, 等待事件, db file sequential read, IO
- 链式迁移行 — Oracle, 链式行, 迁移行, db file sequential read
- db file scattered read — Oracle, 等待事件, db file scattered read, Full Scan
- Log File Sync关联 — log file sync, 等待事件, enq: TX, gc buffer busy
- Log File Sync案例 — log file parallel write, log file sync, RAC, gc buffer busy
- Redo过高案例 — Redo, log file sync, OLTP, commit
- gc buffer busy定义 — RAC, gc buffer busy, Global Cache, 等待事件
- CPU信息 — CPU, Load Average, AWR
- 实例CPU占用 — Oracle, CPU, AWR, 性能诊断
- OS统计 — V$OSSTAT, DBA_HIST_OSSTAT, CPU, OS统计
- Memory Statistics — Oracle, SGA, PGA, Memory Statistics
- Time Model Statistics — Time Model Statistics, Hard Parse, PL/SQL, Sequence
- RAC纵览 — RAC, AWR, Global Cache, Cluster Wait
- Global Cache Load Profile — RAC, Global Cache, Interconnect, GCS, GES
- Global Cache接收时间 — RAC, Global Cache, AWR指标
- RAC关键指标 — RAC, Interconnect, Global Cache, 性能调优
- RAC响应与Redo — RAC, Interconnect, log file sync, gc buffer busy
- CR Block指标 — RAC, CR Block, Global Cache
- Current Block指标 — RAC, Current Block, Global Cache
- RAC消息统计 — RAC, Messaging, ksxp, LMS, 网络延迟
- RAC流控 — RAC, Flow Control, Interconnect, 网络
- IPC诊断命令 — RAC, IPC, oradebug, netstat, Interconnect
- Global Request查询SQL — Oracle, RAC, v$segment_statistics, v$cr_block_server
- 事件关联 — RAC, Redo, log file sync, gc buffer busy, enq:TX
- gc busy处理 — RAC, gc buffer busy, SQL优化, 逻辑读

## Repository Paths

- PDF: `collector/32e1c4ac785a9c814df4739817f6ef6e.pdf`
- Extracted: `generated/extracted/32e1c4ac785a9c814df4739817f6ef6e/full.md`
- Filtered: `generated/filtered/32e1c4ac785a9c814df4739817f6ef6e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
