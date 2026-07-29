---
doc_id: "8afe88f0d8aa0f874c0ff4603080c299"
title: "可以不用，但是不能不会的MySQL进阶技能"
aliases:
  - "可以不用，但是不能不会的MySQL进阶技能"
url: "https://mp.weixin.qq.com/s/GHm3awuOCfXkBkOYJs1N2A"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "gdb"
  - "源码调试"
  - "InnoDB"
  - "信号量"
  - "互斥锁"
  - "Linux内核锁"
  - "故障排查"
generated: true
---

# 可以不用，但是不能不会的MySQL进阶技能

> [!info] Provenance
> - doc_id: `8afe88f0d8aa0f874c0ff4603080c299`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/GHm3awuOCfXkBkOYJs1N2A)
> - PDF: [open local PDF](../../collector/8afe88f0d8aa0f874c0ff4603080c299.pdf)

## Summary

本文以 MySQL 源码调试为主线，讲了 gdb 的安装与常用命令、InnoDB 后台线程与信号量等待、Linux 内核锁的基本概念、trx_sys 和 dict_sys 互斥锁的典型使用场景，以及用 gdb 排查 LSN、mutex 和 show slave status 阻塞的思路。

## Knowledge Outline

- 源码调试的必要性 — MySQL, DBA, 源码调试, 职场竞争力
- gdb 安装与常用命令 — MySQL, gdb, 调试命令, 多线程, 断点
- 系统线程与信号量 — MySQL, InnoDB, 后台线程, 信号量, 故障排查
- 内核锁与互斥锁 — Linux, MySQL, InnoDB, mutex, rwlock, spinlock, semaphore
- LSN、Mutex 与 show slave status — MySQL, gdb, LSN, mutex, show slave status, 源码路径
- 文章小结 — MySQL, 源码调试, gdb, DBA学习

## Repository Paths

- PDF: `collector/8afe88f0d8aa0f874c0ff4603080c299.pdf`
- Extracted: `generated/extracted/8afe88f0d8aa0f874c0ff4603080c299/full.md`
- Filtered: `generated/filtered/8afe88f0d8aa0f874c0ff4603080c299/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
