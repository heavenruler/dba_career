---
doc_id: "34608efa79dafe8421af5c2c7c9d3038"
title: "MySQL底层概述—7.优化原则及慢查询 - 东阳马生架构 - 博客园"
aliases:
  - "MySQL底层概述—7.优化原则及慢查询 - 东阳马生架构 - 博客园"
url: "https://www.cnblogs.com/mjunz/p/18579992"
source_domain: "www.cnblogs.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SQL优化"
  - "Explain"
  - "索引优化"
  - "慢查询"
  - "数据库性能调优"
generated: true
---

# MySQL底层概述—7.优化原则及慢查询 - 东阳马生架构 - 博客园

> [!info] Provenance
> - doc_id: `34608efa79dafe8421af5c2c7c9d3038`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.cnblogs.com/mjunz/p/18579992)
> - PDF: [open local PDF](../../collector/34608efa79dafe8421af5c2c7c9d3038.pdf)

## Summary

本文介绍 MySQL Explain 执行计划字段含义、索引优化原则、慢查询日志配置与慢 SQL 优化思路，重点涵盖 type、key_len、Extra、联合索引最左前缀、索引失效场景、慢查询参数和索引设计判断。

## Knowledge Outline

- Explain 概述 — MySQL, Explain, SQL优化
- Explain 数据准备 — MySQL, Explain, 测试数据
- ID 字段 — MySQL, Explain, 执行计划
- select_type 与 table — MySQL, Explain, select_type
- type 字段 — MySQL, Explain, type, SQL优化
- type 取值说明 — MySQL, Explain, type, 索引
- possible_keys 与 key — MySQL, Explain, 索引
- key_len 字段 — MySQL, Explain, key_len, 索引
- Extra 字段 — MySQL, Explain, Extra
- Extra 指标总结 — MySQL, Explain, Extra, SQL优化
- 索引优化数据准备 — MySQL, 索引优化, 联合索引
- 索引优化原则 — MySQL, 索引优化, SQL优化
- 最左前缀法则 — MySQL, 联合索引, 最左前缀
- 最左前缀原理 — MySQL, InnoDB, B+树, 联合索引
- 索引列计算 — MySQL, 索引失效, 隐式类型转换
- 范围之后失效 — MySQL, 索引优化, 范围查询
- NULL 与 OR — MySQL, 索引失效, SQL优化
- LIKE 索引失效 — MySQL, LIKE, 索引失效, 覆盖索引
- LIKE 失效原理 — MySQL, LIKE, B+树, 索引
- 索引优化总结 — MySQL, 索引优化, SQL优化
- 慢查询介绍 — MySQL, 慢查询, 性能调优
- 慢查询参数 — MySQL, 慢查询, 参数
- 慢查询配置 — MySQL, 慢查询, my.cnf
- 慢查询日志存储 — MySQL, 慢查询, 日志
- 未使用索引记录 — MySQL, 慢查询, 索引
- 慢日志内容 — MySQL, 慢查询, 日志分析
- SQL 性能下降原因 — MySQL, SQL优化, 性能问题
- 慢查询优化思路 — MySQL, 慢查询, SQL优化, 性能调优
- SQL 优化实践 — MySQL, SQL优化, JOIN, 索引
- 是否创建索引 — MySQL, 索引设计, SQL优化
- 选择合适索引 — MySQL, 索引设计, 联合索引

## Repository Paths

- PDF: `collector/34608efa79dafe8421af5c2c7c9d3038.pdf`
- Extracted: `generated/extracted/34608efa79dafe8421af5c2c7c9d3038/full.md`
- Filtered: `generated/filtered/34608efa79dafe8421af5c2c7c9d3038/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
