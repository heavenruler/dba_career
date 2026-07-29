---
doc_id: "3eb79c4afbd0fc2c42133f9d0b606de1"
title: "MySQL突然崩溃？教你用gdb解剖core文件，快速锁定“元凶”! - 墨天轮"
aliases:
  - "MySQL突然崩溃？教你用gdb解剖core文件，快速锁定“元凶”! - 墨天轮"
url: "https://www.modb.pro/db/1899860365098364928?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "gdb"
  - "core dump"
  - "故障排查"
  - "Linux"
  - "调试"
  - "SRE"
generated: true
---

# MySQL突然崩溃？教你用gdb解剖core文件，快速锁定“元凶”! - 墨天轮

> [!info] Provenance
> - doc_id: `3eb79c4afbd0fc2c42133f9d0b606de1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1899860365098364928?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/3eb79c4afbd0fc2c42133f9d0b606de1.pdf)

## Summary

本文介绍 gdb 的基础用途、常用命令、断点/步进/watchpoint/日志记录等调试操作，并展示如何开启 Linux core dump、模拟 MySQL 崩溃、使用 gdb 加载 mysqld core 文件，通过 bt/where/info threads 等命令分析崩溃调用栈。

## Knowledge Outline

- gdb工具介绍 — gdb, core dump, Linux, 调试
- 安装gdb — gdb, Linux, 安装
- 测试程序 — C, gdb, 编译, 调试
- gdb基本运行 — gdb, run, 调试
- gdb常用命令 — gdb, 命令, 调试
- 断点设置 — gdb, breakpoint, 调试
- 变量查看与步进 — gdb, print, next, 变量, 调试
- step进入函数 — gdb, step, 函数调用, 调试
- gdb调用shell命令 — gdb, shell, 调试
- gdb日志记录 — gdb, logging, 调试
- watchpoint观察变量 — gdb, watchpoint, 变量, 调试
- MySQL core文件分析概念 — MySQL, core dump, gdb, 故障排查
- 开启coredump — Linux, coredump, ulimit, MySQL
- 模拟MySQL异常 — MySQL, SIGSEGV, core dump, 故障复现
- 加载MySQL core文件 — MySQL, gdb, core dump, bt
- 崩溃堆栈回溯 — MySQL, gdb, backtrace, 故障排查
- 查看所有线程 — MySQL, gdb, threads, 故障排查
- 紧急修改MySQL连接数 — MySQL, gdb, max_connections, 应急处理
- 总结 — MySQL, core dump, DBA, 故障排查

## Repository Paths

- PDF: `collector/3eb79c4afbd0fc2c42133f9d0b606de1.pdf`
- Extracted: `generated/extracted/3eb79c4afbd0fc2c42133f9d0b606de1/full.md`
- Filtered: `generated/filtered/3eb79c4afbd0fc2c42133f9d0b606de1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
