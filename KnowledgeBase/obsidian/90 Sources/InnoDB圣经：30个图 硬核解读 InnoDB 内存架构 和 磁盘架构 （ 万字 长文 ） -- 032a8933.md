---
doc_id: "032a893337606d370fd014049066b747"
title: "InnoDB圣经：30个图 硬核解读 InnoDB 内存架构 和 磁盘架构 （ 万字 长文 ）"
aliases:
  - "InnoDB圣经：30个图 硬核解读 InnoDB 内存架构 和 磁盘架构 （ 万字 长文 ）"
url: "https://mp.weixin.qq.com/s/cTo35wu9PBkRRrrm5QU-sQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "DBA"
  - "数据库架构"
  - "事务"
  - "性能调优"
  - "存储引擎"
  - "Redo Log"
  - "Undo Log"
  - "Buffer Pool"
generated: true
---

# InnoDB圣经：30个图 硬核解读 InnoDB 内存架构 和 磁盘架构 （ 万字 长文 ）

> [!info] Provenance
> - doc_id: `032a893337606d370fd014049066b747`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/cTo35wu9PBkRRrrm5QU-sQ)
> - PDF: [open local PDF](../../collector/032a893337606d370fd014049066b747.pdf)

## Summary

本文系统整理 MySQL InnoDB 的内存架构与磁盘架构，涵盖 Buffer Pool、Change Buffer、Log Buffer、Adaptive Hash Index、Redo Log、Undo Log、Binlog、表空间、临时表空间与 Doublewrite Buffer，并包含关键配置、监控命令、刷盘策略与事务恢复机制。

## Knowledge Outline

- MySQL 与 InnoDB 分层 — MySQL, InnoDB, 架构
- InnoDB 特性 — InnoDB, ACID, MVCC, OLTP
- 读写与恢复流程 — InnoDB, Redo Log, 崩溃恢复, I/O
- 内存架构组件 — InnoDB, 内存架构, Buffer Pool, Log Buffer, Change Buffer
- Buffer Pool 定义 — Buffer Pool, 缓存, 性能调优
- Buffer Pool 读取 — Buffer Pool, LRU, 缓存命中
- 冷热迁移机制 — Buffer Pool, LRU, 冷热分离, 参数
- 冷热迁移规则 — Buffer Pool, LRU, 淘汰策略
- 全表扫描保护 — Buffer Pool, 全表扫描, 缓存污染, LRU
- 脏页与 Checkpoint — 脏页, Checkpoint, Buffer Pool, Redo Log
- Checkpoint 类型 — Checkpoint, 脏页刷盘, 恢复时间, Redo Log
- Buffer Pool 调优 — Buffer Pool, 性能调优, 监控
- Change Buffer — Change Buffer, 二级索引, 写入性能, InnoDB
- Change Buffer 调优 — Change Buffer, 参数, 监控, SQL
- Log Buffer — Log Buffer, Redo Log, 事务, I/O
- Log Buffer 刷盘 — Log Buffer, Checkpoint, 刷盘策略, ACID
- Log Buffer 调优 — Log Buffer, 参数, LSN, 监控
- Adaptive Hash Index — Adaptive Hash Index, AHI, B+Tree, 索引
- AHI 适用条件 — AHI, 等值查询, 索引优化
- AHI 调优 — AHI, 性能调优, 参数
- 磁盘架构组件 — InnoDB, 磁盘架构, Redo Log, Undo Log, 表空间
- Redo Log 与 WAL — Redo Log, WAL, ACID, 持久性
- Redo 与 Undo 协作 — Redo Log, Undo Log, Checkpoint, 崩溃恢复
- Redo Log 刷盘策略 — Redo Log, fsync, OS cache, 刷盘
- innodb_flush_log_at_trx_commit — Redo Log, 刷盘策略, ACID, 性能
- Undo Log — Undo Log, 事务, 原子性, MVCC
- Undo Log 与 MVCC — Undo Log, MVCC, ReadView, 隔离性
- Binlog — Binlog, Redo Log, 主从复制, 数据恢复
- Binlog 与 Redo Log 对比 — Binlog, Redo Log, 日志格式, 复制
- 表空间类型 — 表空间, ibdata1, ibd, MySQL 8.0
- 表空间结构 — 表空间, page, extent, segment
- InnoDB Page — InnoDB Page, 16KB, 表空间
- 系统表空间 — 系统表空间, ibdata1, Undo Log, Doublewrite Buffer
- 系统表空间配置 — 系统表空间, my.cnf, innodb_file_per_table
- 独立表空间 — 独立表空间, ibd, 运维, 备份
- 通用表空间命令 — 通用表空间, CREATE TABLESPACE, SQL, InnoDB
- 撤销表空间 — 撤销表空间, Undo Log, MySQL 8.0, MVCC
- Undo 表空间层级 — Undo Tablespace, Rollback Segment, Undo Segment, 并发事务
- 临时表空间 — 临时表空间, ibtmp1, MySQL 8.0, DDL
- 临时表空间角色 — Session Temporary Tablespace, Global Temporary Tablespace, ibtmp1
- Doublewrite Buffer — Doublewrite Buffer, Partial Page Write, 崩溃恢复, 数据完整性
- Partial Page Write — Partial Page Write, Redo Log, Doublewrite Buffer, Linux
- Doublewrite 原理 — Doublewrite Buffer, fsync, Buffer Pool, Redo Log
- Doublewrite 恢复 — Doublewrite Buffer, 崩溃恢复, Redo Log, 数据完整性
- Doublewrite 参数 — Doublewrite Buffer, 参数, InnoDB
- Doublewrite 与 Redo Log — Doublewrite Buffer, Redo Log, WAL, 持久性

## Repository Paths

- PDF: `collector/032a893337606d370fd014049066b747.pdf`
- Extracted: `generated/extracted/032a893337606d370fd014049066b747/full.md`
- Filtered: `generated/filtered/032a893337606d370fd014049066b747/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
