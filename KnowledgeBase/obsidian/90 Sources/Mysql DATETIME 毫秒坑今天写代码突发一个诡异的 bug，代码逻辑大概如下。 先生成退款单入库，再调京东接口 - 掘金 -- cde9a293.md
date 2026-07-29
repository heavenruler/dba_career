---
doc_id: "cde9a293df0148928f7f6abdb8d99c8e"
title: "Mysql DATETIME 毫秒坑今天写代码突发一个诡异的 bug，代码逻辑大概如下。 先生成退款单入库，再调京东接口 - 掘金"
aliases:
  - "Mysql DATETIME 毫秒坑今天写代码突发一个诡异的 bug，代码逻辑大概如下。 先生成退款单入库，再调京东接口 - 掘金"
url: "https://juejin.cn/post/7460418134312255514"
source_domain: "juejin.cn"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DATETIME"
  - "SQL"
  - "数据库"
  - "后端"
  - "隐式转换"
  - "优化器"
  - "执行器"
  - "故障排查"
generated: true
---

# Mysql DATETIME 毫秒坑今天写代码突发一个诡异的 bug，代码逻辑大概如下。 先生成退款单入库，再调京东接口 - 掘金

> [!info] Provenance
> - doc_id: `cde9a293df0148928f7f6abdb8d99c8e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://juejin.cn/post/7460418134312255514)
> - PDF: [open local PDF](../../collector/cde9a293df0148928f7f6abdb8d99c8e.pdf)

## Summary

通过一个退款单更新失败的案例，说明 MySQL DATETIME 在插入与查询中的毫秒四舍五入、优化器/执行器比较差异，以及隐式转换的常见坑。

## Knowledge Outline

- 问题现象 — MySQL, 故障排查, 后端, 数据库
- 查询条件 — SQL, MySQL, 数据库, 后端
- 毫秒坑 — MySQL, DATETIME, SQL, 数据库, 后端
- Trace 解析 — MySQL, 优化器, 执行器, DATETIME, 故障排查
- 隐式转换 — MySQL, 隐式转换, SQL, 数据库, 学习方法

## Repository Paths

- PDF: `collector/cde9a293df0148928f7f6abdb8d99c8e.pdf`
- Extracted: `generated/extracted/cde9a293df0148928f7f6abdb8d99c8e/full.md`
- Filtered: `generated/filtered/cde9a293df0148928f7f6abdb8d99c8e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
