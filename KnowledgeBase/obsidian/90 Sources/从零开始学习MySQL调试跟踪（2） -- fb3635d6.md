---
doc_id: "fb3635d67aa05bfa9595045817adc308"
title: "从零开始学习MySQL调试跟踪（2）"
aliases:
  - "从零开始学习MySQL调试跟踪（2）"
url: "https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653939868&idx=1&sn=117b3ec4105203d206a6eac31c327533&chksm=bd3b72f68a4cfbe0c15b25136e57f49001702457e50f1ec559c5b4aeb46be6b663343b5d04aa&scene=178&cur_album_id=1337959503719137280#rd"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "coredump"
  - "GDB"
  - "故障排查"
  - "事故分析"
generated: true
---

# 从零开始学习MySQL调试跟踪（2）

> [!info] Provenance
> - doc_id: `fb3635d67aa05bfa9595045817adc308`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s?__biz=MjM5NzAzMTY4NQ==&mid=2653939868&idx=1&sn=117b3ec4105203d206a6eac31c327533&chksm=bd3b72f68a4cfbe0c15b25136e57f49001702457e50f1ec559c5b4aeb46be6b663343b5d04aa&scene=178&cur_album_id=1337959503719137280#rd)
> - PDF: [open local PDF](../../collector/fb3635d67aa05bfa9595045817adc308.pdf)

## Summary

本文讲如何通过开启 coredump、制造崩溃场景、结合错误日志与 gdb 回溯来定位 MySQL/GreatSQL 崩溃原因，并给出实际故障分析示例。

## Knowledge Outline

- 启用 coredump — MySQL, coredump, GDB, 故障排查
- 持久化与配置 — MySQL, 配置, coredump
- 制造 coredump 场景 — MySQL, coredump, 错误日志, 事故处理
- 真实故障分析 — GreatSQL, MySQL, InnoDB, crash, gdb, stacktrace
- GDB 定位 — GDB, coredump, MySQL, 故障定位, 源码分析

## Repository Paths

- PDF: `collector/fb3635d67aa05bfa9595045817adc308.pdf`
- Extracted: `generated/extracted/fb3635d67aa05bfa9595045817adc308/full.md`
- Filtered: `generated/filtered/fb3635d67aa05bfa9595045817adc308/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
