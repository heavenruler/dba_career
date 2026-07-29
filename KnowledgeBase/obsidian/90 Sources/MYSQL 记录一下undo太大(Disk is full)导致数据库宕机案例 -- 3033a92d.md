---
doc_id: "3033a92d5b8ec0a31605d0312ae9898d"
title: "[MYSQL] 记录一下undo太大(Disk is full)导致数据库宕机案例"
aliases:
  - "[MYSQL] 记录一下undo太大(Disk is full)导致数据库宕机案例"
url: "https://mp.weixin.qq.com/s/7_yYa6G9dfeU1dXHFUNMHw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "undo"
  - "事故覆盘"
  - "故障排查"
  - "磁盘满"
  - "DBA"
generated: true
---

# [MYSQL] 记录一下undo太大(Disk is full)导致数据库宕机案例

> [!info] Provenance
> - doc_id: `3033a92d5b8ec0a31605d0312ae9898d`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/7_yYa6G9dfeU1dXHFUNMHw)
> - PDF: [open local PDF](../../collector/3033a92d5b8ec0a31605d0312ae9898d.pdf)

## Summary

记录一个 MySQL 因 undo 表空间过大、磁盘空间不足导致宕机的案例，重点包括报错现象、判断思路、现场处理方式，以及 8.0 下的手动清理 undo 方法。

## Knowledge Outline

- 背景 — MySQL, InnoDB, 文件系统, 运维
- 报错与分析 — MySQL, InnoDB, 故障排查, 磁盘满, undo
- 处理过程 — MySQL, InnoDB, undo, 磁盘满, 运维
- 启动与回收 — MySQL, InnoDB, History list length, undo, 事务
- 8.0 手动清理 undo — MySQL, 8.0, undo, SQL, DBA
- 总结 — MySQL, 事故覆盘, 磁盘满, undo, 运维

## Repository Paths

- PDF: `collector/3033a92d5b8ec0a31605d0312ae9898d.pdf`
- Extracted: `generated/extracted/3033a92d5b8ec0a31605d0312ae9898d/full.md`
- Filtered: `generated/filtered/3033a92d5b8ec0a31605d0312ae9898d/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
