---
doc_id: "ec00423c5e1578b5ff5fc4032f41879a"
title: "MySQL出息了! 大败PG用的这个case"
aliases:
  - "MySQL出息了! 大败PG用的这个case"
url: "https://mp.weixin.qq.com/s/XL_319dq6-Edphxgq0KnrQ"
source_domain: "mp.weixin.qq.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "PostgreSQL"
  - "MVCC"
  - "VACUUM"
  - "HOT"
  - "性能调优"
  - "长事务"
  - "数据库管理"
generated: true
---

# MySQL出息了! 大败PG用的这个case

> [!info] Provenance
> - doc_id: `ec00423c5e1578b5ff5fc4032f41879a`
> - source_kind: `llm_filtered`
> - source: [original URL](https://mp.weixin.qq.com/s/XL_319dq6-Edphxgq0KnrQ)
> - PDF: [open local PDF](../../collector/ec00423c5e1578b5ff5fc4032f41879a.pdf)

## Summary

这篇文章在讲一个会放大 PostgreSQL 更新成本的极端 case：长事务一直不结束、同一行反复按主键更新，导致旧 tuple 和索引条目持续堆积；随后说明 autovacuum、HOT、fillfactor、全表扫描与索引扫描在这个场景下的影响，并给出超时、长事务预警和云管控等规避思路。

## Knowledge Outline

- 测试方法 — MySQL, PostgreSQL, 性能测试, 事务, 主键更新
- 原因分析 — PostgreSQL, MVCC, autovacuum, VACUUM, 索引膨胀, HOT, fillfactor, 性能分析
- 规避方法 — PostgreSQL, 长事务, 超时, 告警, 云数据库, 运维管控

## Repository Paths

- PDF: `collector/ec00423c5e1578b5ff5fc4032f41879a.pdf`
- Extracted: `generated/extracted/ec00423c5e1578b5ff5fc4032f41879a/full.md`
- Filtered: `generated/filtered/ec00423c5e1578b5ff5fc4032f41879a/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
