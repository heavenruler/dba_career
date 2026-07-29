---
doc_id: "efdce531a066312521594d378fbec0b1"
title: "如何准确获取 MySQL 主从延迟时间？"
aliases:
  - "如何准确获取 MySQL 主从延迟时间？"
url: "https://mp.weixin.qq.com/s/jkKCw8aJJ528s5fL3RwAzA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "主从复制"
  - "pt-heartbeat"
  - "复制延迟"
  - "数据库"
  - "Percona Toolkit"
generated: true
---

# 如何准确获取 MySQL 主从延迟时间？

> [!info] Provenance
> - doc_id: `efdce531a066312521594d378fbec0b1`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/jkKCw8aJJ528s5fL3RwAzA)
> - PDF: [open local PDF](../../collector/efdce531a066312521594d378fbec0b1.pdf)

## Summary

本文分析了 MySQL 5.7 的 `Seconds_Behind_Master` 为何不可靠，并给出使用 `pt-heartbeat` 精确测量主从延迟的方案，重点解释了大事务、并行复制和 I/O 延迟下的误差来源。

## Knowledge Outline

- 背景 — MySQL, 主从复制, 复制延迟, 数据库
- Seconds_Behind_Master 可靠吗？ — MySQL, Seconds_Behind_Master, 主从复制, 并行复制, I/O, 源码分析
- pt-heartbeat 方案 — pt-heartbeat, MySQL, 主从复制, 延迟测量, Percona Toolkit
- 准确性分析与建议 — pt-heartbeat, MySQL, 可观测性, 复制延迟, NTP, 告警

## Repository Paths

- PDF: `collector/efdce531a066312521594d378fbec0b1.pdf`
- Extracted: `generated/extracted/efdce531a066312521594d378fbec0b1/full.md`
- Filtered: `generated/filtered/efdce531a066312521594d378fbec0b1/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
