---
doc_id: "d30f1d26fac1b8e04980a7f140c504c4"
title: "guide/数据库规范/Mysql数据结构设计及开发规范.md at master · wanfangdata/guide"
aliases:
  - "guide/数据库规范/Mysql数据结构设计及开发规范.md at master · wanfangdata/guide"
url: "https://github.com/wanfangdata/guide/blob/master/%E6%95%B0%E6%8D%AE%E5%BA%93%E8%A7%84%E8%8C%83/Mysql%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E8%AE%BE%E8%AE%A1%E5%8F%8A%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83.md"
source_domain: "github.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "数据库设计"
  - "开发规范"
  - "索引"
  - "性能优化"
  - "约束"
  - "字符集"
  - "分页"
generated: true
---

# guide/数据库规范/Mysql数据结构设计及开发规范.md at master · wanfangdata/guide

> [!info] Provenance
> - doc_id: `d30f1d26fac1b8e04980a7f140c504c4`
> - source_kind: `llm_filtered`
> - source: [original URL](https://github.com/wanfangdata/guide/blob/master/%E6%95%B0%E6%8D%AE%E5%BA%93%E8%A7%84%E8%8C%83/Mysql%E6%95%B0%E6%8D%AE%E7%BB%93%E6%9E%84%E8%AE%BE%E8%AE%A1%E5%8F%8A%E5%BC%80%E5%8F%91%E8%A7%84%E8%8C%83.md)
> - PDF: [open local PDF](../../collector/d30f1d26fac1b8e04980a7f140c504c4.pdf)

## Summary

這份文件是 MySQL 資料庫結構設計與開發規範，重點涵蓋需求理解、命名一致性、資料表與索引設計、存儲過程與約束、視圖、表結構變更、大小寫規範、資料型別與字元集選擇、NOT NULL、EXPLAIN、隱式型別轉換，以及分頁寫法。

## Knowledge Outline

- 适用范围 — MySQL, 数据库设计, 规范
- 知识体系 — 数据库设计, 学习方法, 故障分析
- 一般要求 — 数据库设计, 需求分析, 命名规范, 可维护性
- 数据库、引擎与用户 — MySQL, 数据库设计, 存储引擎, 版本选择, 命名规范
- 表与索引 — 表设计, 索引, SQL优化, MySQL
- 过程、约束与视图 — 存储过程, 触发器, 约束, 视图, 数据一致性
- 表结构变更与命名规范 — 表结构变更, 命名规范, MySQL, 大小写
- 数据类型与查询 — 字符集, NOT NULL, EXPLAIN, 隐式类型转换, 分页, 性能优化

## Repository Paths

- PDF: `collector/d30f1d26fac1b8e04980a7f140c504c4.pdf`
- Extracted: `generated/extracted/d30f1d26fac1b8e04980a7f140c504c4/full.md`
- Filtered: `generated/filtered/d30f1d26fac1b8e04980a7f140c504c4/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
