---
doc_id: "70d6796cf7d059fc575ac8263506713b"
title: "详解MySQL字符集和Collation-阿里云开发者社区"
aliases:
  - "详解MySQL字符集和Collation-阿里云开发者社区"
url: "https://developer.aliyun.com/article/1462909"
source_domain: "developer.aliyun.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库"
  - "DBA"
  - "字符集"
  - "Collation"
  - "Unicode"
  - "UTF-8"
  - "乱码"
  - "排序规则"
  - "SQL"
generated: true
---

# 详解MySQL字符集和Collation-阿里云开发者社区

> [!info] Provenance
> - doc_id: `70d6796cf7d059fc575ac8263506713b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://developer.aliyun.com/article/1462909)
> - PDF: [open local PDF](../../collector/70d6796cf7d059fc575ac8263506713b.pdf)

## Summary

本文系统介绍 MySQL Charset 与 Collation 的概念、查看方式、配置层级、连接相关系统变量、字符串字面量、字符集转换、Unicode/UCA 排序算法、binary Charset 与 _bin Collation 差异，并通过 SQL 示例说明乱码、比较、排序和升级选择中的常见问题。

## Knowledge Outline

- 引言中的乱码示例 — MySQL, 乱码, 字符集, 连接配置
- 字符比较与 Collation — MySQL, Collation, 字符串比较, SQL
- Charset 与 Collation 定义 — MySQL, 字符集, Collation
- MySQL Charset 与 Collation 规则 — MySQL, 字符集, Collation
- Pad Attribute — MySQL, Collation, 字符串比较, LIKE
- Collation 命名规则 — MySQL, Collation, 命名规则
- Unicode 与 UTF-8 — Unicode, UTF-8, 编码
- MySQL Unicode Charset — MySQL, Unicode, utf8mb4, utf8mb3
- 连接相关变量 — MySQL, 系统变量, 连接配置
- 连接变量含义 — MySQL, 乱码, character_set_client, character_set_results
- SET NAMES 与 SET CHARACTER SET — MySQL, SET NAMES, 连接配置
- 库表列 Charset 配置 — MySQL, DDL, Charset, Collation
- 库表列默认规则 — MySQL, DDL, Charset, Collation
- 字符串字面量 Introducer — MySQL, 字符串字面量, Introducer, 乱码
- Introducer 导致乱码示例 — MySQL, Introducer, latin1, 乱码
- 字符集转换场景 — MySQL, 字符集转换, SQL
- 修改列 Charset 注意事项 — MySQL, ALTER TABLE, 字符集转换, 数据丢失
- 表达式 Collation 优先级 — MySQL, COERCIBILITY, Collation, 表达式
- 表达式冲突规则 — MySQL, Collation, Unicode, 表达式
- 源码转换逻辑 — MySQL, 源码, 字符集转换
- 字符集转换源码 — MySQL, 源码, C++, 字符集转换
- 转换失败为问号 — MySQL, 字符集转换, latin1, 乱码
- Unicode 排序层级 — MySQL, Unicode, UCA, 排序算法, Collation
- Sort Key 算法 — MySQL, Unicode, Sort Key, UCA
- General 与 Unicode Collation — MySQL, utf8mb4_general_ci, utf8mb4_unicode_ci, UCA
- General 与 Unicode 建议 — MySQL, Collation, 性能, 最佳实践
- LIKE 特殊性 — MySQL, LIKE, Collation, 字符串比较
- Binary Charset 与 Bin Collation — MySQL, binary, _bin, Collation
- 基本比较单位 — MySQL, binary, utf8mb4_bin, utf8mb4_0900_bin

## Repository Paths

- PDF: `collector/70d6796cf7d059fc575ac8263506713b.pdf`
- Extracted: `generated/extracted/70d6796cf7d059fc575ac8263506713b/full.md`
- Filtered: `generated/filtered/70d6796cf7d059fc575ac8263506713b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
