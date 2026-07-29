---
doc_id: "4161c619d44a078a2cbebea93dd7a452"
title: "MySQL 优化利器 SHOW PROFILE 的实现原理 - 墨天轮"
aliases:
  - "MySQL 优化利器 SHOW PROFILE 的实现原理 - 墨天轮"
url: "https://www.modb.pro/db/1870997338144124928"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "SHOW PROFILE"
  - "性能分析"
  - "源码分析"
  - "DBA"
  - "SQL优化"
  - "表空间导入"
generated: true
---

# MySQL 优化利器 SHOW PROFILE 的实现原理 - 墨天轮

> [!info] Provenance
> - doc_id: `4161c619d44a078a2cbebea93dd7a452`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1870997338144124928)
> - PDF: [open local PDF](../../collector/4161c619d44a078a2cbebea93dd7a452.pdf)

## Summary

本文说明 MySQL SHOW PROFILE 的用法、源码实现、数据采集与计算方式，并解释表空间导入操作中耗时被显示为 System lock 的原因。

## Knowledge Outline

- 背景案例 — MySQL, SHOW PROFILE, 表空间导入, 性能分析
- Processlist 状态误导 — SHOW PROCESSLIST, System lock, MySQL
- SHOW PROFILE 用法 — SHOW PROFILE, MySQL, SQL优化
- SHOW PROFILE all 注意事项 — SHOW PROFILE, 资源使用, 性能分析
- 实现原理概览 — MySQL源码, sql_profile.cc, SHOW PROFILE
- 数据采集埋点 — THD_STAGE_INFO, MySQL源码, SHOW PROFILE
- new_status 采集逻辑 — MySQL源码, QUERY_PROFILE, PROF_MEASUREMENT
- PROF_MEASUREMENT 初始化 — PROF_MEASUREMENT, getrusage, MySQL源码
- collect 函数作用 — getrusage, 资源采集, SHOW PROFILE
- 数据计算入口 — information_schema.profiling, PROFILING, MySQL源码
- fill_statistics_info 逻辑 — PROFILING, information_schema.profiling, MySQL源码
- Duration 计算含义 — Duration, SHOW PROFILE, 性能分析
- 表空间导入源码 — 表空间导入, mysql_discard_or_import_tablespace, MySQL源码
- System lock 原因 — System lock, open_and_lock_tables, SHOW PROCESSLIST
- 真实耗时来源 — 表空间导入, ha_discard_or_import_tablespace, 性能分析
- 总结 — SHOW PROFILE, MySQL 8.4, 总结

## Repository Paths

- PDF: `collector/4161c619d44a078a2cbebea93dd7a452.pdf`
- Extracted: `generated/extracted/4161c619d44a078a2cbebea93dd7a452/full.md`
- Filtered: `generated/filtered/4161c619d44a078a2cbebea93dd7a452/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
