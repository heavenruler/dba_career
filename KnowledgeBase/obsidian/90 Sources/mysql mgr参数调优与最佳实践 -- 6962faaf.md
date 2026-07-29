---
doc_id: "6962faaf603def99caf469a99c3fef6e"
title: "mysql mgr参数调优与最佳实践"
aliases:
  - "mysql mgr参数调优与最佳实践"
url: "https://www.modb.pro/db/1953351762266566656"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "MySQL"
  - "MGR"
  - "Group Replication"
  - "DBA"
  - "数据库高可用"
  - "参数调优"
  - "故障切换"
  - "Paxos"
  - "复制"
  - "最佳实践"
generated: true
---

# mysql mgr参数调优与最佳实践

> [!info] Provenance
> - doc_id: `6962faaf603def99caf469a99c3fef6e`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1953351762266566656)
> - PDF: [open local PDF](../../collector/6962faaf603def99caf469a99c3fef6e.pdf)

## Summary

本文总结 MySQL Group Replication（MGR）生产实践中的参数建议、常见避坑点、故障切换流程、故障检测机制与推荐配置，重点涉及单主模式、InnoDB、主键要求、大事务限制、隔离级别、压缩、流控、hash_scan、节点驱逐、少数派超时、auto-rejoin 与完整 mysqld 参数模板。

## Knowledge Outline

- MGR 简介 — MySQL, MGR, 高可用
- 单主模式建议 — MGR, 单主模式, Paxos, DDL
- 存储引擎建议 — MGR, InnoDB, ACID, MySQL Clone
- 强制主键 — MGR, 主键, binlog, ROW, 复制效率
- 限制大事务 — MGR, 大事务, XCom, 心跳检测, 性能调优
- 表名大小写设置 — MGR, 元数据, 冲突检测
- 隔离级别 — MGR, InnoDB, 隔离级别, Gap Lock, Write Set
- 禁用压缩 — MGR, 压缩, binlog, 数据恢复
- 关闭流控 — MGR, 流控, 高并发, 延迟
- 禁用 hash_scan 算法 — MySQL, 复制, HASH_SCAN, 数据一致性
- 故障测试参数与初始状态 — MGR, 故障测试, PRIMARY, SECONDARY
- 故障日志变化 — MGR, 故障切换, 心跳检测, 节点驱逐, 日志
- 少数派 auto-rejoin 日志 — MGR, auto-rejoin, 少数派, 日志
- 少数派集群视图变化 — MGR, UNREACHABLE, ERROR, 集群视图
- 集群状态变化时间点 — MGR, 故障切换, 时间线, 节点驱逐
- 故障切换参数作用 — MGR, group_replication_member_expel_timeout, group_replication_unreachable_majority_timeout, XCom, auto-rejoin
- 故障检测流程 — MGR, 故障检测, 心跳, UNREACHABLE, XCom Cache, auto-rejoin, exit_state_action
- 故障切换推荐参数 — MGR, 故障切换, 参数优化, 双主
- MGR 参数优化总结 — MGR, MySQL, mysqld, 参数模板, 最佳实践

## Repository Paths

- PDF: `collector/6962faaf603def99caf469a99c3fef6e.pdf`
- Extracted: `generated/extracted/6962faaf603def99caf469a99c3fef6e/full.md`
- Filtered: `generated/filtered/6962faaf603def99caf469a99c3fef6e/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
