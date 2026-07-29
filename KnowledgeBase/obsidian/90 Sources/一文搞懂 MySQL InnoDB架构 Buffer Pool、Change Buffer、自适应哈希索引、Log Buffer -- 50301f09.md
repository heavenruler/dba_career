---
doc_id: "50301f09e4569d3c389c6146db83bd10"
title: "一文搞懂 MySQL InnoDB架构 Buffer Pool、Change Buffer、自适应哈希索引、Log Buffer"
aliases:
  - "一文搞懂 MySQL InnoDB架构 Buffer Pool、Change Buffer、自适应哈希索引、Log Buffer"
url: "https://mp.weixin.qq.com/s/Qo_11gtXLilb-fXLqHEY2g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "Buffer Pool"
  - "Change Buffer"
  - "Adaptive Hash Index"
  - "Log Buffer"
  - "Redo Log"
  - "数据库架构"
  - "性能优化"
generated: true
---

# 一文搞懂 MySQL InnoDB架构 Buffer Pool、Change Buffer、自适应哈希索引、Log Buffer

> [!info] Provenance
> - doc_id: `50301f09e4569d3c389c6146db83bd10`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/Qo_11gtXLilb-fXLqHEY2g)
> - PDF: [open local PDF](../../collector/50301f09e4569d3c389c6146db83bd10.pdf)

## Summary

本文介绍 MySQL InnoDB 内存结构，重点涵盖 Buffer Pool、Buffer Pool LRU 变体、Change Buffer、自适应哈希索引与 Log Buffer 的作用、触发条件、优缺点、刷盘策略和与 Redo Log 的协作。

## Knowledge Outline

- InnoDB 内存结构 — InnoDB, 数据库架构
- Buffer Pool 基本概念 — Buffer Pool, InnoDB, 缓存
- Buffer Pool LRU 算法 — Buffer Pool, LRU, 缓存淘汰
- Buffer Pool 页面老化 — Buffer Pool, LRU, 性能优化
- Change Buffer 写优化 — Change Buffer, 二级索引, 写优化, Redo Log
- Change Buffer 设计原因 — Change Buffer, 二级索引, 随机 I/O
- Change Buffer 不足 — Change Buffer, 性能风险, I/O
- Change Buffer 适用价值 — Change Buffer, DML, 批量插入, I/O 优化
- Adaptive Hash Index 命令 — Adaptive Hash Index, MySQL 参数
- Adaptive Hash Index 概念 — Adaptive Hash Index, 等值查询, B+ 树, 性能优化
- Adaptive Hash Index 触发条件 — Adaptive Hash Index, 触发条件, 生命周期
- Adaptive Hash Index 优缺点 — Adaptive Hash Index, 优缺点, 性能优化
- Adaptive Hash Index 使用建议 — Adaptive Hash Index, OLTP, 配置建议
- Log Buffer 基本概念 — Log Buffer, Redo Log, 事务, I/O 优化
- Log Buffer 实现原理 — Log Buffer, Redo Log, 刷盘, LSN
- 刷盘策略 — Log Buffer, innodb_flush_log_at_trx_commit, fsync, 持久性
- Redo Log 协作 — Redo Log, Log Buffer, 崩溃恢复, Group Commit, LSN
- Log Buffer 配置取舍 — Log Buffer, 事务持久性, 性能优化, 配置

## Repository Paths

- PDF: `collector/50301f09e4569d3c389c6146db83bd10.pdf`
- Extracted: `generated/extracted/50301f09e4569d3c389c6146db83bd10/full.md`
- Filtered: `generated/filtered/50301f09e4569d3c389c6146db83bd10/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
