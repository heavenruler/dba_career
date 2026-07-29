---
doc_id: "741dfcb409d3cd9199a0bb815cc32d15"
title: "MySQL防丢数据秘籍：双剑合璧的redo log与binlog"
aliases:
  - "MySQL防丢数据秘籍：双剑合璧的redo log与binlog"
url: "https://mp.weixin.qq.com/s/xoBEWmpBWbOG9JVlBhhX6g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "redo log"
  - "binlog"
  - "崩溃恢复"
  - "主从复制"
  - "两阶段提交"
  - "效能调优"
generated: true
---

# MySQL防丢数据秘籍：双剑合璧的redo log与binlog

> [!info] Provenance
> - doc_id: `741dfcb409d3cd9199a0bb815cc32d15`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/xoBEWmpBWbOG9JVlBhhX6g)
> - PDF: [open local PDF](../../collector/741dfcb409d3cd9199a0bb815cc32d15.pdf)

## Summary

本文讲解 MySQL 中 redo log 与 binlog 的分工、写入机制、关键参数 innodb_flush_log_at_trx_commit 与 sync_binlog，以及通过两阶段提交保证二者一致性的恢复逻辑。

## Knowledge Outline

- 为什么需要双日志 — MySQL, redo log, binlog, InnoDB
- redo log 机制 — MySQL, InnoDB, redo log, 崩溃恢复, 参数
- binlog 机制 — MySQL, binlog, 主从复制, 时间点恢复, 参数, 效能调优
- 两阶段提交 — MySQL, redo log, binlog, 两阶段提交, 崩溃恢复
- 总结 — MySQL, InnoDB, redo log, binlog, 两阶段提交, 崩溃恢复, 主从复制

## Repository Paths

- PDF: `collector/741dfcb409d3cd9199a0bb815cc32d15.pdf`
- Extracted: `generated/extracted/741dfcb409d3cd9199a0bb815cc32d15/full.md`
- Filtered: `generated/filtered/741dfcb409d3cd9199a0bb815cc32d15/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
