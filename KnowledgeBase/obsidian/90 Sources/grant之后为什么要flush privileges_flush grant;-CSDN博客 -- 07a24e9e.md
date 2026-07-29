---
doc_id: "07a24e9e6324a0563f5cb3deff2b1f58"
title: "grant之后为什么要flush privileges_flush grant;-CSDN博客"
aliases:
  - "grant之后为什么要flush privileges_flush grant;-CSDN博客"
url: "https://blog.csdn.net/MariaOzawa/article/details/107003386"
source_domain: "blog.csdn.net"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "权限管理"
  - "grant"
  - "revoke"
  - "flush privileges"
  - "数据库"
  - "DBA"
generated: true
---

# grant之后为什么要flush privileges_flush grant;-CSDN博客

> [!info] Provenance
> - doc_id: `07a24e9e6324a0563f5cb3deff2b1f58`
> - source_kind: `llm_filtered`
> - source: [original URL](https://blog.csdn.net/MariaOzawa/article/details/107003386)
> - PDF: [open local PDF](../../collector/07a24e9e6324a0563f5cb3deff2b1f58.pdf)

## Summary

这篇文章解释 MySQL 权限管理里 `grant`、`revoke` 与 `flush privileges` 的关系，重点区分全局权限、db 权限、表/列权限在磁盘表和内存结构中的同步方式，以及哪些情况下需要手动刷新权限缓存。

## Knowledge Outline

- 问题背景 — MySQL, 权限管理, 用户创建, acl_users, DBA
- 全局权限 — MySQL, 全局权限, grant, acl_users, DBA
- db 权限与已存在连接 — MySQL, db权限, revoke, 会话, 权限缓存, DBA
- 表权限和列权限 — MySQL, 表权限, 列权限, grant, mysql.tables_priv, mysql.columns_priv
- flush privileges 的场景 — MySQL, flush privileges, 权限一致性, DML, DBA, 故障排查

## Repository Paths

- PDF: `collector/07a24e9e6324a0563f5cb3deff2b1f58.pdf`
- Extracted: `generated/extracted/07a24e9e6324a0563f5cb3deff2b1f58/full.md`
- Filtered: `generated/filtered/07a24e9e6324a0563f5cb3deff2b1f58/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
