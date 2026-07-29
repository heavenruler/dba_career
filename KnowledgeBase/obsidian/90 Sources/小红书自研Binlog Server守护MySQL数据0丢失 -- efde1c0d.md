---
doc_id: "efde1c0d259b1f325219ed58c751fad6"
title: "小红书自研Binlog Server守护MySQL数据0丢失"
aliases:
  - "小红书自研Binlog Server守护MySQL数据0丢失"
url: "https://mp.weixin.qq.com/s/0Lu7_XVCbMIOJkN9h_0o6g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Binlog Server"
  - "RPO=0"
  - "半同步复制"
  - "高可用"
  - "数据库架构"
  - "故障切换"
  - "ORC"
  - "数据一致性"
generated: true
---

# 小红书自研Binlog Server守护MySQL数据0丢失

> [!info] Provenance
> - doc_id: `efde1c0d259b1f325219ed58c751fad6`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/0Lu7_XVCbMIOJkN9h_0o6g)
> - PDF: [open local PDF](../../collector/efde1c0d259b1f325219ed58c751fad6.pdf)

## Summary

这篇文章围绕 MySQL 在故障切换时如何实现 RPO=0 展开，介绍了小红书自研 Binlog Server 的设计目标、性能验证、协议与 SQL 支持、半同步复制处理、文件一致性保障，以及与 ORC 高可用切换配合实现数据补齐的机制。

## Knowledge Outline

- 方案概览 — MySQL, Binlog Server, 高可用, 数据一致性, 故障切换
- RPO 与方案选择 — RPO=0, MySQL, 半同步复制, 数据一致性, 高可用
- 性能验证 — Binlog Server, 性能验证, 高可用, ORC, 故障切换, 数据一致性
- 架构与需求 — MySQL, Binlog Server, 复制延迟, 系统设计, 需求分析, 高可用
- 协议与 SQL 支持 — MySQL协议, SQL解析, 运维命令, Binlog Server, 级联架构, MySQL
- 半同步与一致性 — 半同步复制, ACK, Crash Safe, 数据一致性, Binlog, MySQL
- 高可用切换 — ORC, 高可用, GTID, 故障恢复, Binlog Server, 数据补齐

## Repository Paths

- PDF: `collector/efde1c0d259b1f325219ed58c751fad6.pdf`
- Extracted: `generated/extracted/efde1c0d259b1f325219ed58c751fad6/full.md`
- Filtered: `generated/filtered/efde1c0d259b1f325219ed58c751fad6/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
