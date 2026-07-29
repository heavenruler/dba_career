---
doc_id: "9f3f6317d944f32807f64c9f8a6140a6"
title: "MySQL 8.0.34 高可用集群OOM故障分析与解决方案"
aliases:
  - "MySQL 8.0.34 高可用集群OOM故障分析与解决方案"
url: "https://mp.weixin.qq.com/s/4QiCcOsWWXwwK3onftXuKg"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "高可用"
  - "OOM"
  - "事故覆盘"
  - "性能调优"
  - "内存管理"
  - "死锁"
  - "SRE"
  - "数据库"
generated: true
---

# MySQL 8.0.34 高可用集群OOM故障分析与解决方案

> [!info] Provenance
> - doc_id: `9f3f6317d944f32807f64c9f8a6140a6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/4QiCcOsWWXwwK3onftXuKg)
> - PDF: [open local PDF](../../collector/9f3f6317d944f32807f64c9f8a6140a6.pdf)

## Summary

本文复盘了一起 MySQL 8.0.34 双节点高可用集群同时 OOM 的故障，核心原因是连接级缓冲区配置过大、InnoDB buffer pool 占用过高、死锁导致线程阻塞，以及 16GB 物理内存不足。文章给出了紧急参数下调、死锁监控、索引与事务优化、硬件扩容和持续监控的具体做法。

## Knowledge Outline

- 故障概述与现象 — MySQL, 高可用, OOM, 事故覆盘, 内存管理, 数据库
- 问题分析 — MySQL, 性能调优, 内存管理, 死锁, 事故覆盘, 数据库
- 解决方案 — MySQL, 性能调优, SQL, 内存管理, 死锁, 数据库
- 监控与预防 — SRE, 监控, Prometheus, MySQL, 可观测性, 数据库

## Repository Paths

- PDF: `collector/9f3f6317d944f32807f64c9f8a6140a6.pdf`
- Extracted: `generated/extracted/9f3f6317d944f32807f64c9f8a6140a6/full.md`
- Filtered: `generated/filtered/9f3f6317d944f32807f64c9f8a6140a6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
