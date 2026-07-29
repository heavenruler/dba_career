---
doc_id: "0a5cc77baa6fdac01c4cad8e5669fa86"
title: "搞懂Redo Log与Binlog，就搞懂了MySQL数据安全的半壁江山"
aliases:
  - "搞懂Redo Log与Binlog，就搞懂了MySQL数据安全的半壁江山"
url: "https://mp.weixin.qq.com/s/jp0YvywiQl57EppNjNNFng"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "Redo Log"
  - "Binlog"
  - "InnoDB"
  - "2PC"
  - "主从复制"
  - "崩溃恢复"
  - "数据一致性"
generated: true
---

# 搞懂Redo Log与Binlog，就搞懂了MySQL数据安全的半壁江山

> [!info] Provenance
> - doc_id: `0a5cc77baa6fdac01c4cad8e5669fa86`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/jp0YvywiQl57EppNjNNFng)
> - PDF: [open local PDF](../../collector/0a5cc77baa6fdac01c4cad8e5669fa86.pdf)

## Summary

本文系统说明 MySQL 中 Redo Log 与 Binlog 的职责、差异，以及两阶段提交如何保证崩溃恢复与主从一致性，并解释为什么 Binlog 不能单独承担 crash-safe。

## Knowledge Outline

- MySQL 架构 — MySQL, 架构设计, InnoDB
- Redo Log 与 Binlog — MySQL, Redo Log, Binlog, InnoDB, 主从复制, 时间点恢复
- 两阶段提交 — MySQL, 2PC, Redo Log, Binlog, 数据一致性
- 为什么 Binlog 不能单独 crash-safe — MySQL, Binlog, crash-safe, 恢复, 数据一致性

## Repository Paths

- PDF: `collector/0a5cc77baa6fdac01c4cad8e5669fa86.pdf`
- Extracted: `generated/extracted/0a5cc77baa6fdac01c4cad8e5669fa86/full.md`
- Filtered: `generated/filtered/0a5cc77baa6fdac01c4cad8e5669fa86/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
