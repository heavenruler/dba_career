---
doc_id: "ceb0b611cf2ea95c8d2a8cbcea078de2"
title: "GTID生命周期大揭秘：MySQL复制中的“身份证”如何运转？"
aliases:
  - "GTID生命周期大揭秘：MySQL复制中的“身份证”如何运转？"
url: "https://mp.weixin.qq.com/s/xFL0EsnOr1tv4bBQCtl0fA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "GTID"
  - "复制"
  - "数据库"
  - "binlog"
  - "主从复制"
generated: true
---

# GTID生命周期大揭秘：MySQL复制中的“身份证”如何运转？

> [!info] Provenance
> - doc_id: `ceb0b611cf2ea95c8d2a8cbcea078de2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/xFL0EsnOr1tv4bBQCtl0fA)
> - PDF: [open local PDF](../../collector/ceb0b611cf2ea95c8d2a8cbcea078de2.pdf)

## Summary

本文系统说明了 MySQL GTID 从主库生成、写入二进制日志、进入 gtid_executed、传输到从库、在从库校验与重放、落盘到从库日志或 gtid_executed，以及 gtid_purged 的含义；还补充了复制过滤和多线程复制下的 GTID 处理方式。

## Knowledge Outline

- GTID 诞生 — GTID, MySQL, 主库, 事务, binlog
- 写入二进制日志 — GTID, binlog, Gtid_log_event, mysql.gtid_executed
- 进入 gtid_executed — GTID, gtid_executed, MySQL, binlog
- 传输到从库 — GTID, 从库, relay log, gtid_next, 复制
- 检查是否已使用 — GTID, gtid_owned, 从库, 重复执行, 复制
- 从库重放 — GTID, 从库, 事务重放, GTID_NEXT, 复制
- 从库写日志 — GTID, 从库, log_bin, log_slave_updates, binlog
- 直接写入表 — GTID, mysql.gtid_executed, MySQL 5.7, MySQL 8.0, DDL, 原子性
- 从库的 gtid_executed — GTID, gtid_executed, 从库, binlog, 复制
- 过滤事务 — GTID, 复制过滤, 主从一致性, 空事务, MySQL
- 多线程复制 — GTID, 多线程复制, slave_parallel_workers, 复制间隙, MySQL
- gtid_purged — GTID, gtid_purged, Previous_gtids_log_event, binlog, MySQL

## Repository Paths

- PDF: `collector/ceb0b611cf2ea95c8d2a8cbcea078de2.pdf`
- Extracted: `generated/extracted/ceb0b611cf2ea95c8d2a8cbcea078de2/full.md`
- Filtered: `generated/filtered/ceb0b611cf2ea95c8d2a8cbcea078de2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
