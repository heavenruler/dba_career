---
doc_id: "0f81bb5e9e927269f46f5dfa3b2bcbea"
title: "性能运维 -- 借助pstack + strace排查SQL性能问题 - 墨天轮"
aliases:
  - "性能运维 -- 借助pstack + strace排查SQL性能问题 - 墨天轮"
url: "https://www.modb.pro/db/1764818856233734144"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "DBA"
  - "数据库运维"
  - "SQL性能调优"
  - "Linux"
  - "pstack"
  - "strace"
  - "KingbaseES"
  - "执行计划"
  - "IO分析"
generated: true
---

# 性能运维 -- 借助pstack + strace排查SQL性能问题 - 墨天轮

> [!info] Provenance
> - doc_id: `0f81bb5e9e927269f46f5dfa3b2bcbea`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1764818856233734144)
> - PDF: [open local PDF](../../collector/0f81bb5e9e927269f46f5dfa3b2bcbea.pdf)

## Summary

本文介绍使用 pstack 和 strace 排查 SQL 性能问题的方法，包含工具用途、排查步骤、慢 SQL 案例、pstack 调用栈分析、strace 系统调用分析、lsof 确认文件描述符，以及结合执行计划定位 Seq Scan 导致大量文件读取的结论。

## Knowledge Outline

- pstack 用途 — pstack, Linux, 进程栈, 故障排查
- strace 用途 — strace, Linux, 系统调用, 性能分析
- 排查耗时步骤 — 排查流程, sys_stat_activity, pstack, strace
- 慢 SQL 测试 — SQL, EXPLAIN ANALYZE, Hash Anti Join, Seq Scan
- 查询 SQL PID — sys_stat_activity, PID, SQL诊断
- pstack 分析进程 — pstack, 调用栈, SQL执行过程, KingbaseES
- strace 分析 IO — strace, pread64, IO, 文件描述符
- strace 输出片段 — strace, pread64, 系统调用输出
- lsof 确认文件 — lsof, 文件描述符, Seq Scan, IO瓶颈
- 总结 — 总结, 性能瓶颈, 执行计划, pstack, strace

## Repository Paths

- PDF: `collector/0f81bb5e9e927269f46f5dfa3b2bcbea.pdf`
- Extracted: `generated/extracted/0f81bb5e9e927269f46f5dfa3b2bcbea/full.md`
- Filtered: `generated/filtered/0f81bb5e9e927269f46f5dfa3b2bcbea/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
