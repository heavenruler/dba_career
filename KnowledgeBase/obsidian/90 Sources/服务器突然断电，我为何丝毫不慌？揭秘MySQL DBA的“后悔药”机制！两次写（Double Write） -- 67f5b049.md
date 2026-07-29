---
doc_id: "67f5b0495d2930c7dccaf6f4fde943a3"
title: "服务器突然断电，我为何丝毫不慌？揭秘MySQL DBA的“后悔药”机制！两次写（Double Write）"
aliases:
  - "服务器突然断电，我为何丝毫不慌？揭秘MySQL DBA的“后悔药”机制！两次写（Double Write）"
url: "https://mp.weixin.qq.com/s/rmdXMTqkJ2W57p6Vz3ZYKA"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "DoubleWrite"
  - "DBA"
  - "崩溃恢复"
  - "Partial Page Write"
  - "Checksum"
  - "数据可靠性"
  - "性能优化"
generated: true
---

# 服务器突然断电，我为何丝毫不慌？揭秘MySQL DBA的“后悔药”机制！两次写（Double Write）

> [!info] Provenance
> - doc_id: `67f5b0495d2930c7dccaf6f4fde943a3`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/rmdXMTqkJ2W57p6Vz3ZYKA)
> - PDF: [open local PDF](../../collector/67f5b0495d2930c7dccaf6f4fde943a3.pdf)

## Summary

本文用 MySQL InnoDB 的 DoubleWrite 机制解释部分写失效（Partial Page Write）的成因、刷盘与恢复流程，以及为什么在多数生产环境中不建议关闭 DoubleWrite。

## Knowledge Outline

- 问题定义 — MySQL, InnoDB, Partial Page Write, Redo Log, 崩溃恢复
- DoubleWrite 流程 — MySQL, InnoDB, DoubleWrite, 刷盘, 崩溃恢复
- 实现细节与性能 — MySQL, InnoDB, DoubleWrite, Checksum, 性能, 配置
- 是否关闭 — MySQL, InnoDB, DoubleWrite, 原子写, Checksum, 备份, 生产环境

## Repository Paths

- PDF: `collector/67f5b0495d2930c7dccaf6f4fde943a3.pdf`
- Extracted: `generated/extracted/67f5b0495d2930c7dccaf6f4fde943a3/full.md`
- Filtered: `generated/filtered/67f5b0495d2930c7dccaf6f4fde943a3/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
