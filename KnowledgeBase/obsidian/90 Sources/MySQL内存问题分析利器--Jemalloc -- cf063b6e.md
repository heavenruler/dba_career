---
doc_id: "cf063b6e344bb94de337aa8099ec0765"
title: "MySQL内存问题分析利器--Jemalloc"
aliases:
  - "MySQL内存问题分析利器--Jemalloc"
url: "https://mp.weixin.qq.com/s/6_owYVqub2uok32EvgpneA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "Jemalloc"
  - "内存分析"
  - "内存泄漏"
  - "性能调优"
  - "UDF"
  - "gdb"
  - "jeprof"
  - "AliSQL"
generated: true
---

# MySQL内存问题分析利器--Jemalloc

> [!info] Provenance
> - doc_id: `cf063b6e344bb94de337aa8099ec0765`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/6_owYVqub2uok32EvgpneA)
> - PDF: [open local PDF](../../collector/cf063b6e344bb94de337aa8099ec0765.pdf)

## Summary

本文介绍 Jemalloc 用于 MySQL 内存问题分析的价值、两个案例、MySQL 启用 Jemalloc profiling 的方法、自动/手动生成内存快照、通过 gdb 与 UDF 控制 profiling 和 dump 快照，以及使用 jeprof 生成调用关系图与 diff 图。

## Knowledge Outline

- Jemalloc 价值 — MySQL, Jemalloc, Performance Schema, 内存监控
- Clone_persist_gtid 内存泄漏 — MySQL, 内存泄漏, Clone_persist_gtid, GTID, AliSQL
- AHI 内存浪费 — MySQL, AHI, Buffer Pool, 内存浪费, mmap
- MySQL 使用 Jemalloc — MySQL, Jemalloc, LD_PRELOAD, mysqld_safe
- 开启 Jemalloc Profiling — Jemalloc, profiling, MALLOC_CONF, MySQL
- 性能影响 — Jemalloc, sysbench, 性能
- 自动生成快照 — Jemalloc, 内存快照, lg_prof_interval, prof_gdump
- 手动生成快照 — MySQL, Jemalloc, 内存快照, gdb, UDF
- gdb 产生快照 — gdb, Jemalloc, mallctl, prof.dump
- gdb 控制状态 — gdb, Jemalloc, prof.active, mallctl
- UDF 快照机制 — MySQL, UDF, Jemalloc, 生产环境
- UDF C 代码 — C, MySQL UDF, Jemalloc, mallctl
- 编译与加载 UDF — MySQL UDF, jemalloc-devel, gcc, plugin_dir
- UDF 函数说明 — MySQL UDF, Jemalloc, prof.active, 内存快照
- jeprof 调用关系图 — jeprof, Jemalloc, 调用关系图, diff
- 总结 — Jemalloc, MySQL, 内存分析, UDF

## Repository Paths

- PDF: `collector/cf063b6e344bb94de337aa8099ec0765.pdf`
- Extracted: `generated/extracted/cf063b6e344bb94de337aa8099ec0765/full.md`
- Filtered: `generated/filtered/cf063b6e344bb94de337aa8099ec0765/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
