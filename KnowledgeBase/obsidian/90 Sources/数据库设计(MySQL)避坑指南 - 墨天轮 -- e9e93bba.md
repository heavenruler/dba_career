---
doc_id: "e9e93bba19be3d44d59ca672e4ca49b2"
title: "数据库设计(MySQL)避坑指南 - 墨天轮"
aliases:
  - "数据库设计(MySQL)避坑指南 - 墨天轮"
url: "https://www.modb.pro/db/1762011570709229568"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库设计"
  - "主键设计"
  - "字段设计"
  - "字符集"
  - "读写分离"
  - "架构设计"
generated: true
---

# 数据库设计(MySQL)避坑指南 - 墨天轮

> [!info] Provenance
> - doc_id: `e9e93bba19be3d44d59ca672e4ca49b2`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1762011570709229568)
> - PDF: [open local PDF](../../collector/e9e93bba19be3d44d59ca672e4ca49b2.pdf)

## Summary

这篇文章聚焦 MySQL 数据库设计中的常见坑，主要讨论主键设计、函数确定性、字段类型选择、字符集声明、父子表冗余设计，以及读写分离下的主从延迟风险。内容偏实务，适合做建表和架构设计时的检查清单。

## Knowledge Outline

- 主键设计 — MySQL, 主键设计, 索引, 架构设计
- 函数与字段 — MySQL, 函数, DETERMINISTIC, 字段设计, datetime, varchar, 在线DDL
- 字符集与表关系 — MySQL, 字符集, 排序规则, 表设计, 冗余设计
- 读写分离 — MySQL, 读写分离, 主从延迟, 架构设计, SRE

## Repository Paths

- PDF: `collector/e9e93bba19be3d44d59ca672e4ca49b2.pdf`
- Extracted: `generated/extracted/e9e93bba19be3d44d59ca672e4ca49b2/full.md`
- Filtered: `generated/filtered/e9e93bba19be3d44d59ca672e4ca49b2/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
