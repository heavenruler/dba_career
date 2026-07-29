---
doc_id: "6424dd3cd2dcf41a682a292d0693b88c"
title: "[MYSQL] 漏扫发现驱动存在漏洞, 怎么快速查找客户端的驱动版本呢? - 墨天轮"
aliases:
  - "[MYSQL] 漏扫发现驱动存在漏洞, 怎么快速查找客户端的驱动版本呢? - 墨天轮"
url: "https://www.modb.pro/db/1902590635555696640?utm_source=index_ori"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "安全"
  - "漏洞处置"
  - "驱动版本"
  - "performance_schema"
  - "session_connect_attrs"
  - "连接属性"
generated: true
---

# [MYSQL] 漏扫发现驱动存在漏洞, 怎么快速查找客户端的驱动版本呢? - 墨天轮

> [!info] Provenance
> - doc_id: `6424dd3cd2dcf41a682a292d0693b88c`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1902590635555696640?utm_source=index_ori)
> - PDF: [open local PDF](../../collector/6424dd3cd2dcf41a682a292d0693b88c.pdf)

## Summary

文章说明如何利用 MySQL 连接握手中的 `attrs`，以及 `performance_schema.session_connect_attrs` 来定位客户端驱动版本；并给出在无法升级时，修改 `mysql-connector-python` 版本字符串的处理思路。

## Knowledge Outline

- 漏洞背景 — MySQL, 漏洞处置, 安全, DBA
- 客户端版本信息 — MySQL, 驱动版本, 连接属性, 抓包, DBA
- 服务端查找 — MySQL, performance_schema, session_connect_attrs, SQL, 驱动版本
- 处理与总结 — MySQL, 漏洞处置, 兼容性, 升级, DBA

## Repository Paths

- PDF: `collector/6424dd3cd2dcf41a682a292d0693b88c.pdf`
- Extracted: `generated/extracted/6424dd3cd2dcf41a682a292d0693b88c/full.md`
- Filtered: `generated/filtered/6424dd3cd2dcf41a682a292d0693b88c/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
