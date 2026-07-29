---
doc_id: "b7fb2cf132e9b86c3637ef3e3767376b"
title: "技术分享 | 数据库产品选型测试 集中式与分布式 - 墨天轮"
aliases:
  - "技术分享 | 数据库产品选型测试 集中式与分布式 - 墨天轮"
url: "https://www.modb.pro/db/1753305412787064832"
source_domain: "www.modb.pro"
source_kind: "llm_filtered"
pdf_exists: true
knowledge_status: "filtered"
tags:
  - "source"
  - "数据库选型"
  - "MySQL"
  - "ShardingSphere-Proxy"
  - "分布式数据库"
  - "集中式数据库"
  - "sysbench"
  - "性能测试"
  - "分库分表"
  - "事务"
  - "架构设计"
generated: true
---

# 技术分享 | 数据库产品选型测试 集中式与分布式 - 墨天轮

> [!info] Provenance
> - doc_id: `b7fb2cf132e9b86c3637ef3e3767376b`
> - source_kind: `llm_filtered`
> - source: [original URL](https://www.modb.pro/db/1753305412787064832)
> - PDF: [open local PDF](../../collector/b7fb2cf132e9b86c3637ef3e3767376b.pdf)

## Summary

本文记录 MySQL 5.7 单机与 ShardingSphere-Proxy 在不同数据量、CPU 核数、线程数、事务模式和分片规则下的 sysbench 压测过程，讨论集中式与分布式数据库在点查、范围查询、聚合查询、大量插入等场景中的性能差异与选型判断。

## Knowledge Outline

- 测试背景 — 数据库选型, 分布式数据库, 集中式数据库, 分库分表
- 测试环境 — 测试环境, MySQL, ShardingSphere-Proxy
- 测试思路 — 测试方法, sysbench, QPS, TPS, 性能测试
- sysbench 语句覆盖范围 — sysbench, oltp_read_write, QPS, TPS
- sysbench SQL 片段 — sysbench, SQL, oltp_read_write
- 参数前提 — MySQL, ShardingSphere-Proxy, XA事务, 参数配置
- ShardingProxy 配置 — ShardingSphere-Proxy, server.yaml, XA事务
- 启动 ShardingProxy — ShardingSphere-Proxy, 启动命令, Java
- 登录与创建逻辑库 — ShardingSphere-Proxy, MySQL, 逻辑数据库
- 添加数据源 — DistSQL, 数据源, ShardingSphere-Proxy
- 分片规则 — DistSQL, 分片规则, hash_mod, SNOWFLAKE, ShardingSphere-Proxy
- 创建表结构 — MySQL, InnoDB, 表结构, ShardingSphere-Proxy
- 分片映射说明 — 分片, ShardingSphere-Proxy, MySQL
- 导出与压测命令 — mysqldump, sysbench, 压测, MySQL, ShardingSphere-Proxy
- MySQL 压测说明 — MySQL, CPU, 线程, 性能测试
- 单数据源 ShardingProxy — ShardingSphere-Proxy, 单表, 数据源
- 单数据源压测观察 — ShardingSphere-Proxy, MySQL, QPS, TPS, 性能问题
- 按分片规则导入数据 — 分片规则, 数据导入, mysqldump, ShardingSphere-Proxy
- 事务模式与 IO 观察 — ShardingSphere-Proxy, XA事务, LOCAL事务, IO, 性能测试
- MySQL 500万数据测试结果 — MySQL, sysbench, TPS, QPS, CPU
- 过程记录要点 — MySQL, ShardingSphere-Proxy, innodb_buffer, CPU, sysbench, 性能测试
- 聚合查询观察 — 聚合查询, count, ShardingSphere-Proxy, MySQL, 性能测试
- 测试结论 — 数据库选型, MySQL, ShardingSphere-Proxy, 集中式架构, 分布式架构, XA事务, B+树, 聚合查询
- 选型判断 — 数据库选型, 分布式数据库, 2PC, MySQL调优, 架构决策

## Repository Paths

- PDF: `collector/b7fb2cf132e9b86c3637ef3e3767376b.pdf`
- Extracted: `generated/extracted/b7fb2cf132e9b86c3637ef3e3767376b/full.md`
- Filtered: `generated/filtered/b7fb2cf132e9b86c3637ef3e3767376b/knowledge.json`

## Notes

<!-- Add interpretation in Concepts, Runbooks, Cases, or Career notes; do not edit this generated source page. -->
