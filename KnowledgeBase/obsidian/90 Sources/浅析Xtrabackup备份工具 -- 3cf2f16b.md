---
doc_id: "3cf2f16b5ce48c00b76497ffe86cb55f"
title: "浅析Xtrabackup备份工具"
aliases:
  - "浅析Xtrabackup备份工具"
url: "http://mysql.taobao.org/monthly/2025/11/02/"
source_domain: "mysql.taobao.org"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "XtraBackup"
  - "数据库备份"
  - "DBA"
  - "InnoDB"
  - "热备份"
  - "灾难恢复"
  - "源码分析"
generated: true
---

# 浅析Xtrabackup备份工具

> [!info] Provenance
> - doc_id: `3cf2f16b5ce48c00b76497ffe86cb55f`
> - source_kind: `llm_filtered`
> - source: [original URL](http://mysql.taobao.org/monthly/2025/11/02/)
> - PDF: [open local PDF](../../collector/3cf2f16b5ce48c00b76497ffe86cb55f.pdf)

## Summary

本文介绍 Percona XtraBackup 在 MySQL 热备份场景中的用途、优点、版本关系，以及 backup、prepare、copy-back / move-back 的常用命令和源码层面的主要执行流程。

## Knowledge Outline

- 引言 — MySQL, 备份, XtraBackup
- XtraBackup 定义与优点 — XtraBackup, 热备份, InnoDB
- 使用场景与版本关系 — MySQL, 版本兼容, 灾难恢复
- 主要流程 — XtraBackup, 主从复制, 恢复流程
- Backup 命令 — backup, xtrabackup, 命令
- Backup 参数 — backup, 参数, xbstream
- xbstream 流式备份 — xbstream, 流式备份, 跨机备份
- Backup 核心流程 — backup, 源码分析, redo log
- Redo_Log_Data_Manager — Redo_Log_Data_Manager, redo log, 源码
- Redo Manager 初始化 — init, redo log, 源码
- Redo Manager 启动 — start, redo log, checkpoint
- DDL 限制原因 — DDL, 一致性, redo log
- copy_func 逻辑 — copy_func, redo log, 线程
- copy_once 逻辑 — copy_once, redo log, parse
- stop_at 逻辑 — stop_at, LSN, redo log
- Tablespace 扫描 — tablespace, ibd, undo
- 多线程拷贝用户数据 — parallel, 多线程, 数据文件
- 非 InnoDB 文件备份 — non-InnoDB, performance schema, parallel
- 备份结束与元数据 — backup_finish, 元数据, backup-my.cnf
- Prepare 作用 — prepare, 一致性, 恢复
- Prepare 命令 — prepare, 命令, 参数
- Prepare 执行步骤 — prepare, redo log, InnoDB
- Prepare 源码流程 — prepare, 源码, InnoDB
- copy-back / move-back 作用 — copy-back, move-back, 恢复
- copy-back / move-back 命令 — copy-back, move-back, 命令
- copy-back / move-back 核心逻辑 — copy_back, 恢复, 文件拷贝
- copy_back 源码流程 — copy_back, undo, parallel
- 恢复完成 — 恢复, 启动实例, copy-back
- 总结 — XtraBackup, 全量备份, 源码分析

## Repository Paths

- PDF: `collector/3cf2f16b5ce48c00b76497ffe86cb55f.pdf`
- Extracted: `generated/extracted/3cf2f16b5ce48c00b76497ffe86cb55f/full.md`
- Filtered: `generated/filtered/3cf2f16b5ce48c00b76497ffe86cb55f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
