---
doc_id: "f7a8df8b89aff3049775b4d17e41f7a7"
title: "sql调优实战：分页语句中你真的了解count stokey吗？sort order by的存在就一定很糟？ - 墨天轮"
aliases:
  - "sql调优实战：分页语句中你真的了解count stokey吗？sort order by的存在就一定很糟？ - 墨天轮"
url: "https://www.modb.pro/db/1856961890262462464"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "Oracle"
  - "SQL调优"
  - "分页查询"
  - "count stopkey"
  - "sort order by"
  - "索引设计"
  - "执行计划"
  - "性能优化"
generated: true
---

# sql调优实战：分页语句中你真的了解count stokey吗？sort order by的存在就一定很糟？ - 墨天轮

> [!info] Provenance
> - doc_id: `f7a8df8b89aff3049775b4d17e41f7a7`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1856961890262462464)
> - PDF: [open local PDF](../../collector/f7a8df8b89aff3049775b4d17e41f7a7.pdf)

## Summary

Oracle SQL 分页调优案例，围绕 rownum、count stopkey、sort order by、NL/hash/merge join、索引列顺序与实际执行计划差异展开，记录了从原始慢 SQL 到多种索引与改写方案的实验过程。

## Knowledge Outline

- 问题背景与原始SQL — Oracle, SQL调优, 慢SQL, 分页查询
- 初始执行计划判断 — 执行计划, count stopkey, NL嵌套循环, 逻辑读
- 第一次改写分页框架 — 分页查询, rownum, 索引, sort order by
- 调整驱动表与索引 — Hint, leading, use_nl, 索引设计
- 排序列放首位后的反效果 — sort order by, 索引列顺序, 范围扫描, 性能权衡
- 测试环境验证 — 测试验证, dba_objects, count stopkey, Join
- 消除排序的索引实验 — 索引, 常量列, Hint, 索引全扫
- 排序列单列索引观察 — Oracle索引, 空值, 排序列, 实验结论
- 业务SQL回测 — 业务SQL, 索引全扫, count stopkey, 执行计划
- 逐步增加关联条件 — 逐步验证, rownum, 关联查询, count stopkey
- 过滤条件导致性能下降 — 过滤条件, 性能下降, NL循环, 执行计划
- count stopkey 行为结论 — count stopkey, 分页查询, 驱动表, 关联匹配
- 优化方向判断 — 优化策略, NL Join, Hash Join, Merge Join, 结果集
- 方法一 — CTE, hash semi join, union-all, 索引范围扫描
- 方法二 — NL Join, 索引范围扫描, sort order by, 逻辑读
- 方法取舍 — 方案取舍, 逻辑读, 执行时间, IO优化

## Repository Paths

- PDF: `collector/f7a8df8b89aff3049775b4d17e41f7a7.pdf`
- Extracted: `generated/extracted/f7a8df8b89aff3049775b4d17e41f7a7/full.md`
- Filtered: `generated/filtered/f7a8df8b89aff3049775b4d17e41f7a7/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
