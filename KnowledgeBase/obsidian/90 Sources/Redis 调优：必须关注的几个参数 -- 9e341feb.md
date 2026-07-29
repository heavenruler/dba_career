---
doc_id: "9e341feb75cec583e02f026c736f4ab6"
title: "Redis 调优：必须关注的几个参数"
aliases:
  - "Redis 调优：必须关注的几个参数"
url: "https://www.modb.pro/db/2013076355576569856"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Redis"
  - "性能调优"
  - "Linux"
  - "TCP"
  - "内存管理"
  - "CPU绑定"
  - "SRE"
generated: true
---

# Redis 调优：必须关注的几个参数

> [!info] Provenance
> - doc_id: `9e341feb75cec583e02f026c736f4ab6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/2013076355576569856)
> - PDF: [open local PDF](../../collector/9e341feb75cec583e02f026c736f4ab6.pdf)

## Summary

整理 Redis 在 Linux 上常见的调优参数与其实现细节，涵盖 tcp-backlog、disable-thp、tcp-keepalive、CPU 绑定与 OOM 调整。

## Knowledge Outline

- 背景告警 — Redis, Linux, 警告, 性能调优
- tcp-backlog — Redis, TCP, backlog, Linux, 配置
- disable-thp — Redis, THP, 内存管理, Linux, 配置
- tcp-keepalive — Redis, TCP, Keepalive, 连接管理, Linux, 配置
- CPU 绑定 — Redis, CPU绑定, 性能调优, 线程, Linux
- OOM 调整 — Redis, OOM, Linux, 内存管理, 配置

## Repository Paths

- PDF: `collector/9e341feb75cec583e02f026c736f4ab6.pdf`
- Extracted: `generated/extracted/9e341feb75cec583e02f026c736f4ab6/full.md`
- Filtered: `generated/filtered/9e341feb75cec583e02f026c736f4ab6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
