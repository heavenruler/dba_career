---
doc_id: "25c9b2109c8fc4388b2b7714d0cee824"
title: "还在用 VARCHAR(36) 存 UUID？试试 BINARY(16)，性能提升 50%！"
aliases:
  - "还在用 VARCHAR(36) 存 UUID？试试 BINARY(16)，性能提升 50%！"
url: "https://mp.weixin.qq.com/s/VR1XsX-qR_jA_6VEjboJIw"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "UUID"
  - "BINARY(16)"
  - "索引优化"
  - "InnoDB"
  - "性能调优"
  - "数据库设计"
  - "UUID_TO_BIN"
generated: true
---

# 还在用 VARCHAR(36) 存 UUID？试试 BINARY(16)，性能提升 50%！

> [!info] Provenance
> - doc_id: `25c9b2109c8fc4388b2b7714d0cee824`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/VR1XsX-qR_jA_6VEjboJIw)
> - PDF: [open local PDF](../../collector/25c9b2109c8fc4388b2b7714d0cee824.pdf)

## Summary

本文围绕 MySQL 中 UUID 的存储方式展开，重点说明用 BINARY(16) 替代 VARCHAR(36) 的空间与索引收益，并介绍 MySQL 8.0 的 UUID_TO_BIN / BIN_TO_UUID 方案来实现有序 UUID，从而改善 InnoDB 插入性能。

## Knowledge Outline

- UUID 存储问题 — MySQL, UUID, BINARY(16), 索引, InnoDB, 性能优化, 数据库
- MySQL 8.0 之前 — MySQL, UUID, UNHEX, HEX, BINARY(16), 数据库, 迁移
- MySQL 8.0 有序 UUID — MySQL, UUID_TO_BIN, BIN_TO_UUID, UUID, InnoDB, B+树, 性能优化
- 实战场景 — 微服务, 分布式主键, UUID, BINARY(16), 日志, 资源 ID, 数据库设计
- 总结 — MySQL, UUID, BINARY(16), 索引优化, 数据库原理, 性能调优

## Repository Paths

- PDF: `collector/25c9b2109c8fc4388b2b7714d0cee824.pdf`
- Extracted: `generated/extracted/25c9b2109c8fc4388b2b7714d0cee824/full.md`
- Filtered: `generated/filtered/25c9b2109c8fc4388b2b7714d0cee824/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
