---
doc_id: "dc37e86fabf6151f7244030e5ad0f71f"
title: "MySQL8.0参数配置不生效问题排查诊断 - 墨天轮"
aliases:
  - "MySQL8.0参数配置不生效问题排查诊断 - 墨天轮"
url: "https://www.modb.pro/db/1774722559522705408"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "DBA"
  - "参数配置"
  - "故障排查"
  - "SET PERSIST"
  - "mysqld-auto.cnf"
  - "运维"
generated: true
---

# MySQL8.0参数配置不生效问题排查诊断 - 墨天轮

> [!info] Provenance
> - doc_id: `dc37e86fabf6151f7244030e5ad0f71f`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1774722559522705408)
> - PDF: [open local PDF](../../collector/dc37e86fabf6151f7244030e5ad0f71f.pdf)

## Summary

本文记录 MySQL 8.0 中 innodb_buffer_pool_size 在 my.cnf 配置为 48G 但实际生效为 8G 的排查过程，最终定位为 SET PERSIST 生成的 mysqld-auto.cnf 持久化参数覆盖了 my.cnf，并给出使用 reset persist 清理持久化参数的解决方式。

## Knowledge Outline

- 适用范围 — MySQL, 适用范围
- 问题概述 — MySQL, 故障现象, innodb_buffer_pool_size
- 确认参数文件配置 — MySQL, my.cnf, 参数检查
- 检查其他参数文件 — MySQL, 配置文件, 排查
- 查询运行时参数 — MySQL, 运行时参数, innodb_buffer_pool_size
- 重启后仍不匹配 — MySQL, 重启验证, 故障排查
- 发现 mysqld-auto.cnf — MySQL, mysqld-auto.cnf, 故障定位
- SET PERSIST 知识点 — MySQL, SET PERSIST, mysqld-auto.cnf, 持久化参数
- 查询持久化参数 — MySQL, performance_schema, persisted_variables
- 解决方案 — MySQL, RESET PERSIST, 解决方案
- RESET PERSIST 说明 — MySQL, RESET PERSIST, mysqld-auto.cnf
- 总结 — MySQL, SET GLOBAL, SET PERSIST, RESET PERSIST
- 参考文档 — MySQL, 官方文档

## Repository Paths

- PDF: `collector/dc37e86fabf6151f7244030e5ad0f71f.pdf`
- Extracted: `generated/extracted/dc37e86fabf6151f7244030e5ad0f71f/full.md`
- Filtered: `generated/filtered/dc37e86fabf6151f7244030e5ad0f71f/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
