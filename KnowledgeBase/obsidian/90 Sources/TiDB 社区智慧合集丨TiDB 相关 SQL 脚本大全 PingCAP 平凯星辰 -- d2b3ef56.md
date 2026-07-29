---
doc_id: "d2b3ef56ccfd2ae6244fd35de8c7c8bd"
title: "TiDB 社区智慧合集丨TiDB 相关 SQL 脚本大全 | PingCAP 平凯星辰"
aliases:
  - "TiDB 社区智慧合集丨TiDB 相关 SQL 脚本大全 | PingCAP 平凯星辰"
url: "https://cn.pingcap.com/blog/tidb-related-sql-script-collection/"
source_domain: "cn.pingcap.com"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "TiDB"
  - "DBA"
  - "SQL"
  - "数据库运维"
  - "慢查询"
  - "性能调优"
  - "TiFlash"
  - "Region"
  - "统计信息"
  - "故障排查"
generated: true
---

# TiDB 社区智慧合集丨TiDB 相关 SQL 脚本大全 | PingCAP 平凯星辰

> [!info] Provenance
> - doc_id: `d2b3ef56ccfd2ae6244fd35de8c7c8bd`
> - source_kind: `llm_filtered`
> - source: [original URL](https://cn.pingcap.com/blog/tidb-related-sql-script-collection/)
> - PDF: [open local PDF](../../collector/d2b3ef56ccfd2ae6244fd35de8c7c8bd.pdf)

## Summary

TiDB 社区常用 SQL 与运维脚本合集，涵盖缓存表、TSO 时间转换、历史数据读取、慢查询分析、表大小与 Region 分布、统计信息、执行计划、TiFlash、日志排错、CPU 使用率查询与大批量数据清理。

## Knowledge Outline

- 缓存表 — TiDB, SQL, 缓存表
- TSO 时间转换 — TiDB, TSO, pd-ctl
- 读取历史数据 — TiDB, 历史数据, AS OF TIMESTAMP
- tidb_snapshot — TiDB, tidb_snapshot, 历史数据
- GC 参数查询 — TiDB, TiKV, GC
- 用户 TopN 慢查询 — TiDB, 慢查询, SQL
- 间隔统计 — SQL, 统计
- Digest 反解析 — TiDB, digest, SQL
- 非分区表使用情况 — TiDB, 表大小, information_schema
- 分区表资源使用情况 — TiDB, 分区表, 表大小
- 配置参数查看 — TiDB, SHOW CONFIG, 配置
- 热点 Region — TiDB, TiKV, 热点 Region
- 参数和变量脚本 — TiDB, shell, 配置
- 重复记录查询 — SQL, 重复记录
- 耗时最高慢 SQL — TiDB, 慢查询, 性能调优
- 日常维护 SQL — TiDB, 运维, processlist
- 恢复数据 — TiDB, 数据恢复, FLASHBACK
- 高并发场景获取 SQL — TiDB, 高并发, processlist
- 查看 Schema 表 — TiDB, schema
- Shell 加速别名 — TiDB, shell, tiup
- 恢复到新数据库 — TiDB, loader, 数据恢复
- 开启 TiFlash — TiDB, TiFlash
- 表 Region 分布 — TiDB, Region, TiKV
- 列元数据 — TiDB, 统计信息, 元数据
- 表存储位置 — TiDB, TiKV, store, peer
- 在线升级 — TiDB, tiup, 升级
- 统计信息 — TiDB, 统计信息, analyze
- 统计健康与 Analyze — TiDB, 统计信息, analyze
- 执行计划绑定 — TiDB, 执行计划, binding
- Explain — TiDB, 执行计划, explain
- 查看 Regions — TiDB, Region
- 统计读写热点表 — TiDB, 热点表, Region
- TiFlash 操作 — TiDB, TiFlash
- Admin 命令 — TiDB, admin, DDL
- 隔离参数 — TiDB, TiFlash, 隔离参数
- 日志排错 — TiDB, 日志, 故障排查
- OS CPU 使用率 — TiDB, 可观测性, CPU
- CPU 查询输出示例 — TiDB, 可观测性, CPU
- 大量数据清理 — TiDB, 批量删除, 运维

## Repository Paths

- PDF: `collector/d2b3ef56ccfd2ae6244fd35de8c7c8bd.pdf`
- Extracted: `generated/extracted/d2b3ef56ccfd2ae6244fd35de8c7c8bd/full.md`
- Filtered: `generated/filtered/d2b3ef56ccfd2ae6244fd35de8c7c8bd/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
