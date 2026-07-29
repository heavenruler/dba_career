---
doc_id: "3ce26dec621f56b972282463c68c3417"
title: "为什么说MySQL单表行数不要超过2000w?-mysql 查询表行数"
aliases:
  - "为什么说MySQL单表行数不要超过2000w?-mysql 查询表行数"
url: "https://www.51cto.com/article/721621.html"
source_domain: "www.51cto.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "InnoDB"
  - "B+树"
  - "数据库性能"
  - "索引"
  - "表空间"
  - "容量估算"
generated: true
---

# 为什么说MySQL单表行数不要超过2000w?-mysql 查询表行数

> [!info] Provenance
> - doc_id: `3ce26dec621f56b972282463c68c3417`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.51cto.com/article/721621.html)
> - PDF: [open local PDF](../../collector/3ce26dec621f56b972282463c68c3417.pdf)

## Summary

文章用 InnoDB 页、B+ 树层级、索引页容量与叶子页行容量估算 MySQL 单表 2000w 行建议值的来源，并指出该值不是硬性限制，会受行大小、内存、服务器配置、SQL 写法等因素影响。

## Knowledge Outline

- 实验背景 — MySQL, 容量建议
- 测试数据生成 — MySQL, 测试数据, SQL
- 临时表内存报错 — MySQL, InnoDB, 参数
- 测试结果提示 — MySQL, 性能测试
- 单表数量限制 — MySQL, 主键, 容量限制
- 表空间与数据页 — InnoDB, 表空间, 数据页
- 页的数据结构 — InnoDB, Page Directory, 数据页
- User Records 与 Free Space — InnoDB, 页结构, 行格式
- 数据查找过程 — MySQL, 索引, 查询
- 索引的数据结构 — MySQL, 索引, B+树
- B+ 树层级 — B+树, 叶子节点, 非叶子节点
- 行数据查找示例 — MySQL, B+树, 磁盘IO, 查询性能
- 容量公式 — B+树, 容量估算, 公式
- X 与 Y 估算 — InnoDB, 索引页, 容量估算
- 2000w 来源 — MySQL, B+树, 2000w, 磁盘IO
- 行大小影响建议值 — MySQL, 行大小, InnoDB buffer size, 性能调优
- 总结 — MySQL, InnoDB, B+树, 总结

## Repository Paths

- PDF: `collector/3ce26dec621f56b972282463c68c3417.pdf`
- Extracted: `generated/extracted/3ce26dec621f56b972282463c68c3417/full.md`
- Filtered: `generated/filtered/3ce26dec621f56b972282463c68c3417/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
