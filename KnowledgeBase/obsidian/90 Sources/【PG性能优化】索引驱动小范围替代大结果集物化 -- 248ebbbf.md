---
doc_id: "248ebbbf322172edf4bb297f0847fe80"
title: "【PG性能优化】索引驱动小范围替代大结果集物化"
aliases:
  - "【PG性能优化】索引驱动小范围替代大结果集物化"
url: "https://mp.weixin.qq.com/s/1OjzqC-kG4Gf1cTinSEI3g"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "PostgreSQL"
  - "SQL优化"
  - "执行计划"
  - "索引"
  - "Nested Loop"
  - "Hash Join"
  - "性能调优"
generated: true
---

# 【PG性能优化】索引驱动小范围替代大结果集物化

> [!info] Provenance
> - doc_id: `248ebbbf322172edf4bb297f0847fe80`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/1OjzqC-kG4Gf1cTinSEI3g)
> - PDF: [open local PDF](../../collector/248ebbbf322172edf4bb297f0847fe80.pdf)

## Summary

文章围绕一条 PostgreSQL 慢查询做性能优化，核心做法是把过滤子查询前置为 INNER JOIN，先缩小数据范围，再让索引驱动后续 JOIN，使执行计划从大量 Hash Join 转向 Nested Loop，最终把执行时间从 20 多分钟降到 1 秒级。

## Knowledge Outline

- 问题背景与效果 — PostgreSQL, 性能优化, SQL, 业务查询
- 问题分析 — 执行计划, Hash Join, SQL优化, 性能瓶颈
- 改写思路 — PostgreSQL, SQL, 索引, Nested Loop, 过滤前置
- 执行计划 — 执行计划, Nested Loop, Hash Join, PostgreSQL, 性能调优
- 经验总结 — 经验总结, SQL优化, 执行计划, 索引, 性能调优

## Repository Paths

- PDF: `collector/248ebbbf322172edf4bb297f0847fe80.pdf`
- Extracted: `generated/extracted/248ebbbf322172edf4bb297f0847fe80/full.md`
- Filtered: `generated/filtered/248ebbbf322172edf4bb297f0847fe80/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
